"""Trains Echo's own detector for dangerous sounds on top of YAMNet embeddings.

YAMNet alone names real fire alarms "Alarm" (a generic class) instead of "Fire alarm", so the app's
name-based mapping misses them. This script trains a small softmax layer (1024 -> 5) over the YAMNet
embedding the phone already computes, and exports it to app/assets/models/danger_head.json.

Classes: background, fire_alarm, siren, horn, glass_break.

Data (downloaded separately, not in git):
  - ESC-50 (CC BY-NC 3.0): https://github.com/karoldvl/ESC-50/archive/master.zip
    siren, car_horn, glass_breaking are positives; the other 47 categories are background.
    Folds 1-4 train, fold 5 test.
  - Mini LibriSpeech dev-clean-2 (CC BY 4.0): https://www.openslr.org/resources/31/dev-clean-2.tar.gz
    Speech is background (Echo runs in meetings). Split by speaker.
  - Fire alarms: ESC-50 has none, so they are synthesised from the standard patterns (ISO 8201
    temporal-three / temporal-four piezo tones, bells, electronic horns, slow whoop), with reverb,
    microphone colouring and real ESC-50 background noise.
  - Real recordings from Wikimedia Commons (--real, files named <label>__*.ogg): test only, never trained on.

    .venv/Scripts/pip install ai-edge-litert numpy scipy scikit-learn soundfile av
    .venv/Scripts/python tools/train_danger_sounds.py --esc50 data/ESC-50-master --speech data/LibriSpeech/dev-clean-2 \
        --real data/real --model app/assets/models/yamnet.tflite --out app/assets/models/danger_head.json

The browser runs the TF.js YAMNet, whose embeddings differ from the phone's, so it gets its own head
(needs Node and `npm install` in tools/): add `--backend tfjs --max-false-alarms 0.0005 --out app/assets/models/danger_head_web.json`.
"""

import argparse
import csv
import datetime
import glob
import json
import os
import pickle
from math import gcd

import numpy as np
import soundfile as sf
from ai_edge_litert.interpreter import Interpreter
from scipy.signal import butter, fftconvolve, resample_poly, sosfilt
from sklearn.linear_model import LogisticRegression

SR = 16000
WIN = 15600
HOP = 8000
LABELS = ["background", "fire_alarm", "siren", "horn", "glass_break"]
ESC_POSITIVE = {"siren": 2, "car_horn": 3, "glass_breaking": 4}
# Same rule as the app (yamnet_logic.dart): the name-based mapping we compare against.
BASELINE = {
    "Fire alarm": 1, "Smoke detector, smoke alarm": 1, "Siren": 2, "Civil defense siren": 2,
    "Vehicle horn, car horn, honking": 3, "Air horn, truck horn": 3,
}
# Per background clip and class, on held-out training folds. 0.005 finds more alarms but gave 1.5 %
# false alarms on the test set; small MLPs and an MLP ensemble were tried and were no better, or unstable.
MAX_FALSE_ALARMS = 0.002
MIN_THRESHOLD = 0.5


# ---------------------------------------------------------------- audio

def read_audio(path):
    try:
        x, sr = sf.read(path, dtype="float32", always_2d=True)
        x = x.mean(axis=1)
    except Exception:
        import av  # Ogg with a skeleton stream, Opus...

        with av.open(path) as f:
            stream = f.streams.audio[0]
            frames = [fr.to_ndarray() for fr in f.decode(stream)]
            sr = stream.rate
        x = np.concatenate([fr.reshape(fr.shape[0], -1) for fr in frames], axis=1)
        if np.issubdtype(x.dtype, np.integer):
            x = x / np.iinfo(x.dtype).max
        x = x.mean(axis=0)
    if sr != SR:
        g = gcd(sr, SR)
        x = resample_poly(x, SR // g, sr // g)
    return np.asarray(x, dtype=np.float32)


def windows(x):
    if len(x) < WIN:
        x = np.pad(x, (0, WIN - len(x)))
    return np.stack([x[i : i + WIN] for i in range(0, len(x) - WIN + 1, HOP)])


def rms(x, axis=None):
    return np.sqrt(np.mean(np.square(x), axis=axis) + 1e-12)


# ---------------------------------------------------------------- synthetic fire alarms

def _pattern(t, on, off, group, pause, rng):
    """Repeating on/off groups (e.g. temporal-three: 3 x (0.5 on, 0.5 off), then 1.5 s off)."""
    cycle = group * (on + off) + pause
    phase = (t + rng.uniform(0, cycle)) % cycle
    in_group = phase < group * (on + off)
    return (in_group & ((phase % (on + off)) < on)).astype(np.float32)


def synth_fire_alarm(rng, seconds=5.0):
    t = np.arange(int(seconds * SR)) / SR
    kind = rng.choice(["t3", "t4", "bell", "horn", "whoop", "continuous"], p=[0.35, 0.1, 0.15, 0.2, 0.1, 0.1])
    s = rng.uniform(0.9, 1.1)
    if kind in ("t3", "t4", "continuous"):
        f = rng.uniform(2700, 3700)
        vibrato = 1 + rng.uniform(0, 0.01) * np.sin(2 * np.pi * rng.uniform(3, 12) * t)
        phase = 2 * np.pi * f * np.cumsum(vibrato) / SR
        tone = np.sin(phase) + rng.uniform(0, 0.4) * np.sin(3 * phase) + rng.uniform(0, 0.2) * np.sin(5 * phase)
        if kind == "t3":
            env = _pattern(t, 0.5 * s, 0.5 * s, 3, 1.5 * s, rng)
        elif kind == "t4":
            env = _pattern(t, 0.1 * s, 0.1 * s, 4, 1.2 * s, rng)
        else:
            env = np.ones_like(t)
    elif kind == "bell":
        f0 = rng.uniform(900, 2500)
        rate = rng.uniform(14, 26)
        decay = rng.uniform(0.02, 0.06)
        strike = ((t * rate) % 1) / rate
        tone = sum(a * np.sin(2 * np.pi * f0 * r * t) for r, a in [(1, 1), (2.76, 0.5), (5.4, 0.3), (8.9, 0.15)])
        env = np.exp(-strike / decay)
    elif kind == "horn":
        f = rng.uniform(350, 1100)
        saw = 2 * ((t * f) % 1) - 1
        tone = np.sign(np.sin(2 * np.pi * f * t)) * 0.6 + saw * 0.4
        env = _pattern(t, 0.5 * s, 0.5 * s, 3, 1.5 * s, rng) if rng.random() < 0.6 else np.ones_like(t)
    else:  # slow whoop, 500 -> 1200 Hz
        period = rng.uniform(3, 4.5)
        f = 500 + 700 * (((t + rng.uniform(0, period)) % period) / period)
        tone = np.sin(2 * np.pi * np.cumsum(f) / SR)
        env = np.ones_like(t)
    return (tone * env).astype(np.float32)


def reverb(x, rng):
    rt = rng.uniform(0.05, 0.5)
    n = int(rt * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (rt * SR / 6.9))
    ir[0] = 1.0
    wet = fftconvolve(x, ir)[: len(x)]
    wet *= rms(x) / rms(wet)
    mix = rng.uniform(0.1, 0.7)
    return ((1 - mix) * x + mix * wet).astype(np.float32)


def colour(x, rng):
    """A phone / laptop microphone: some high-pass and low-pass."""
    sos = butter(2, [rng.uniform(80, 400), rng.uniform(5500, 7800)], btype="band", fs=SR, output="sos")
    return sosfilt(sos, x).astype(np.float32)


def mix_at_snr(signal, noise, snr_db):
    noise = np.resize(noise, len(signal))
    gain = rms(noise) * 10 ** (snr_db / 20) / rms(signal) if rms(noise) > 1e-4 else 1.0
    return signal * gain, noise


def finish(x, rng):
    peak = np.max(np.abs(x)) + 1e-9
    return (x / peak * rng.uniform(0.05, 0.9)).astype(np.float32)


# ---------------------------------------------------------------- YAMNet

class Yamnet:
    def __init__(self, path):
        self.it = Interpreter(model_path=path)
        self.it.allocate_tensors()
        self.inp = self.it.get_input_details()[0]["index"]
        self.out = [o["index"] for o in self.it.get_output_details()]

    def __call__(self, wins):
        scores, embs = [], []
        for w in wins:
            self.it.set_tensor(self.inp, w.astype(np.float32))
            self.it.invoke()
            scores.append(self.it.get_tensor(self.out[0]).reshape(-1))
            embs.append(self.it.get_tensor(self.out[1]).reshape(-1))
        embs = np.array(embs)
        return np.array(scores), embs / (np.linalg.norm(embs, axis=1, keepdims=True) + 1e-9)


class TfjsYamnet:
    """The browser's YAMNet (TensorFlow.js) through tools/tfjs_yamnet_worker.mjs.

    Its embeddings are not interchangeable with the phone's TFLite ones (cosine ~0.05 on the same
    audio), so the web app gets its own head trained on these.
    """

    def __init__(self, model_dir, workers=4):
        import subprocess

        worker = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tfjs_yamnet_worker.mjs")
        self.procs = [subprocess.Popen(["node", worker, model_dir], stdin=subprocess.PIPE, stdout=subprocess.PIPE) for _ in range(workers)]

    def __call__(self, wins):
        wins = np.asarray(wins, dtype="<f4")
        chunks = [c for c in np.array_split(wins, len(self.procs)) if len(c)]
        for proc, chunk in zip(self.procs, chunks):
            proc.stdin.write(np.uint32(len(chunk)).tobytes() + chunk.tobytes())
            proc.stdin.flush()
        outs = []
        for proc, chunk in zip(self.procs, chunks):
            size = len(chunk) * 1545 * 4
            buf = b""
            while len(buf) < size:
                buf += proc.stdout.read(size - len(buf))
            outs.append(np.frombuffer(buf, dtype="<f4").reshape(len(chunk), 1545))
        out = np.concatenate(outs)
        embs = out[:, 521:]
        return out[:, :521], embs / (np.linalg.norm(embs, axis=1, keepdims=True) + 1e-9)


# ---------------------------------------------------------------- dataset

class Clips:
    """Clip-level records; every clip keeps its windows so detection is judged like the app does."""

    def __init__(self):
        self.items = []  # dict(label, group, split, emb, scores, win_labels, source)

    def add(self, **kw):
        self.items.append(kw)


def window_labels(clean, label, total=None):
    """Positive windows are those where the target sound is clearly present; quiet ones are dropped (-1)."""
    w = windows(clean)
    r = rms(w, axis=1)
    if label == 0:
        return np.zeros(len(w), dtype=int)
    top = r.max()
    lab = np.where(r >= 0.25 * top, label, -1)
    if total is not None:  # synthetic: windows with no alarm at all are plain background
        lab = np.where(r < 0.02 * top, 0, lab)
    return lab


def build(args, yam, rng):
    clips = Clips()
    meta = list(csv.DictReader(open(os.path.join(args.esc50, "meta", "esc50.csv"))))
    audio = {m["filename"]: read_audio(os.path.join(args.esc50, "audio", m["filename"])) for m in meta}
    backgrounds = {split: [audio[m["filename"]] for m in meta if m["category"] not in ESC_POSITIVE and (m["fold"] == "5") == (split == "test")] for split in ("train", "test")}

    for m in meta:
        split = "test" if m["fold"] == "5" else "train"
        label = ESC_POSITIVE.get(m["category"], 0)
        x = audio[m["filename"]]
        variants = [(x, x)]
        if label and split == "train":
            for _ in range(2):  # the same siren / horn / glass over real background noise
                sig, noise = mix_at_snr(colour(x, rng), backgrounds["train"][rng.integers(len(backgrounds["train"]))], rng.uniform(0, 20))
                variants.append((finish(sig + noise, rng), sig))
        for mixed, clean in variants:
            scores, emb = yam(windows(mixed))
            clips.add(label=label, group=f"esc{m['fold']}", split=split, emb=emb, scores=scores,
                      win_labels=window_labels(clean, label), source=f"ESC-50/{m['category']}")

    for split, n in (("train", args.synthetic), ("test", args.synthetic // 4)):
        for i in range(n):
            alarm = reverb(synth_fire_alarm(rng), rng)
            sig, noise = mix_at_snr(colour(alarm, rng), backgrounds[split][rng.integers(len(backgrounds[split]))], rng.uniform(-5, 20))
            scores, emb = yam(windows(finish(sig + noise, rng)))
            clips.add(label=1, group=f"syn{i % 4 + 1}" if split == "train" else "syn5", split=split, emb=emb, scores=scores,
                      win_labels=window_labels(sig, 1, total=True), source="synthetic fire alarm")

    speakers = sorted(os.listdir(args.speech))
    for k, spk in enumerate(speakers):
        split = "test" if k % 5 == 4 else "train"
        files = sorted(glob.glob(os.path.join(args.speech, spk, "*", "*.flac")))[: args.speech_per_speaker]
        for f in files:
            x = read_audio(f)[: 10 * SR]
            scores, emb = yam(windows(x))
            clips.add(label=0, group=f"spk{k % 4 + 1}" if split == "train" else "spk5", split=split, emb=emb, scores=scores,
                      win_labels=np.zeros(len(emb), dtype=int), source="speech")

    for f in sorted(glob.glob(os.path.join(args.real, "*__*"))):
        name = os.path.basename(f).split("__")[0]
        label = LABELS.index(name) if name in LABELS else 0
        scores, emb = yam(windows(read_audio(f)))
        clips.add(label=label, group="real", split="real", emb=emb, scores=scores,
                  win_labels=np.full(len(emb), label), source="real: " + os.path.basename(f))
    return clips


# ---------------------------------------------------------------- train / evaluate

def fold_of(group):
    return int(group[-1])


def train_head(clips, c):
    X = np.concatenate([c_["emb"][c_["win_labels"] >= 0] for c_ in clips])
    y = np.concatenate([c_["win_labels"][c_["win_labels"] >= 0] for c_ in clips])
    model = LogisticRegression(C=c, max_iter=3000, class_weight="balanced")
    model.fit(X, y)
    return model


def probs(model, emb):
    p = np.zeros((len(emb), len(LABELS)))
    p[:, model.classes_] = model.predict_proba(emb)
    return p


def fires(per_window, threshold, consecutive=2):
    """The app's gate: above threshold in `consecutive` windows in a row."""
    hit = per_window >= threshold
    run = 0
    for h in hit:
        run = run + 1 if h else 0
        if run >= consecutive:
            return True
    return False


def baseline_scores(scores, names):
    out = np.zeros((len(scores), len(LABELS)))
    for name, label in BASELINE.items():
        out[:, label] = np.maximum(out[:, label], scores[:, names.index(name)])
    return out


def evaluate(clips, per_clip_probs, thresholds):
    """Clip-level recall per class, critical-level recall, and false alarms on background clips."""
    res = {}
    for label in range(1, len(LABELS)):
        pos = [i for i, c in enumerate(clips) if c["label"] == label]
        if pos:
            res[f"recall_{LABELS[label]}"] = (sum(fires(per_clip_probs[i][:, label], thresholds[label]) for i in pos), len(pos))
    crit = [i for i, c in enumerate(clips) if c["label"] in (1, 2)]
    if crit:
        res["critical_alert_on_fire_or_siren"] = (sum(any(fires(per_clip_probs[i][:, k], thresholds[k]) for k in (1, 2)) for i in crit), len(crit))
    bg = [i for i, c in enumerate(clips) if c["label"] == 0]
    if bg:
        res["false_alarm_clips"] = (sum(any(fires(per_clip_probs[i][:, k], thresholds[k]) for k in range(1, len(LABELS))) for i in bg), len(bg))
    return res


def fmt(res):
    return "  ".join(f"{k}={v[0]}/{v[1]} ({100 * v[0] / max(v[1], 1):.1f}%)" for k, v in res.items())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--esc50", required=True)
    ap.add_argument("--speech", required=True)
    ap.add_argument("--real", required=True)
    ap.add_argument("--model", default="app/assets/models/yamnet.tflite")
    ap.add_argument("--classes", default="app/assets/models/yamnet_class_map.csv")
    ap.add_argument("--out", required=True)
    ap.add_argument("--synthetic", type=int, default=600)
    ap.add_argument("--speech-per-speaker", type=int, default=25)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--cache", help="pickle of the computed embeddings, reused if it exists")
    ap.add_argument("--backend", choices=["tflite", "tfjs"], default="tflite", help="tflite = phone (--model), tfjs = browser (--tfjs-model)")
    ap.add_argument("--tfjs-model", default="app/web/models/yamnet")
    ap.add_argument("--max-false-alarms", type=float, default=MAX_FALSE_ALARMS, help="per background clip and class (the browser model needs 0.0005)")
    args = ap.parse_args()

    rng = np.random.default_rng(args.seed)
    names = [r["display_name"] for r in csv.DictReader(open(args.classes, encoding="utf-8"))]
    if args.cache and os.path.exists(args.cache):
        clips = pickle.load(open(args.cache, "rb"))
    else:
        yam = Yamnet(args.model) if args.backend == "tflite" else TfjsYamnet(args.tfjs_model)
        clips = build(args, yam, rng).items
        if args.cache:
            pickle.dump(clips, open(args.cache, "wb"))
    train = [c for c in clips if c["split"] == "train"]
    print(f"clips: train {len(train)}, test {sum(c['split'] == 'test' for c in clips)}, real {sum(c['split'] == 'real' for c in clips)}")

    # Regularisation and thresholds from 4-fold cross-validation on the training folds only.
    best = None
    for c in (0.3, 1.0, 3.0, 10.0):
        oof = [None] * len(train)
        for k in (1, 2, 3, 4):
            fit = [t for t in train if fold_of(t["group"]) != k]
            model = train_head(fit, c)
            for i, t in enumerate(train):
                if fold_of(t["group"]) == k:
                    oof[i] = probs(model, t["emb"])
        thresholds = [1.0]
        bg = [i for i, t in enumerate(train) if t["label"] == 0]
        for label in range(1, len(LABELS)):
            # Lowest threshold whose false-alarm rate on background clips stays under the limit.
            peaks = sorted((max(np.minimum(oof[i][:-1, label], oof[i][1:, label])) if len(oof[i]) > 1 else oof[i][0, label]) for i in bg)
            limit = peaks[int(np.ceil((1 - args.max_false_alarms) * len(peaks))) - 1]
            thresholds.append(float(max(MIN_THRESHOLD, min(0.99, limit + 1e-3))))
        res = evaluate(train, oof, thresholds)
        score = sum(v[0] / v[1] for k, v in res.items() if k.startswith("recall")) - 5 * res["false_alarm_clips"][0] / res["false_alarm_clips"][1]
        print(f"C={c}: thresholds {np.round(thresholds[1:], 3).tolist()}  {fmt(res)}")
        if best is None or score > best[0]:
            best = (score, c, thresholds)
    _, c, thresholds = best
    print(f"chosen C={c}")

    model = train_head(train, c)
    report = {}
    names_thr = [1.0] + [0.3] * (len(LABELS) - 1)
    for split in ("test", "real"):
        part = [cl for cl in clips if cl["split"] == split]
        trained = [probs(model, cl["emb"]) for cl in part]
        named = [baseline_scores(cl["scores"], names) for cl in part]
        # The app alerts when either says so: scale each by its own threshold and take the max.
        combined = [np.maximum(p / np.array(thresholds), b / np.array(names_thr)) for p, b in zip(trained, named)]
        report[split] = {
            "app": evaluate(part, combined, [1.0] * len(LABELS)),
            "trained_only": evaluate(part, trained, thresholds),
            "yamnet_names_only": evaluate(part, named, names_thr),
        }
        print()
        for name, res in report[split].items():
            print(f"[{split}] {name:17}: {fmt(res)}")
        if split == "real":
            for cl in part:
                p = probs(model, cl["emb"])
                b = baseline_scores(cl["scores"], names)
                hit = [LABELS[k] for k in range(1, len(LABELS)) if fires(p[:, k], thresholds[k])]
                bhit = [LABELS[k] for k in range(1, len(LABELS)) if fires(b[:, k], 0.3)]
                print(f"   {cl['source'][:60]:60} trained={hit or '-'}  names={bhit or '-'}")

    weights = np.zeros((len(LABELS), model.coef_.shape[1]))
    bias = np.full(len(LABELS), -1e4)
    weights[model.classes_] = model.coef_
    bias[model.classes_] = model.intercept_
    check = next(cl for cl in clips if cl["split"] == "real" and cl["label"] == 1)["emb"][0]
    json.dump({
        "about": "Echo danger-sound detector: softmax(W . e + b) over the L2-normalised YAMNet embedding. Trained by tools/train_danger_sounds.py.",
        "trained": datetime.date.today().isoformat(),
        "backend": args.backend,
        "labels": LABELS,
        "thresholds": dict(zip(LABELS[1:], [round(t, 4) for t in thresholds[1:]])),
        "bias": [round(float(v), 5) for v in bias],
        "weights": [[round(float(v), 5) for v in row] for row in weights],
        "evaluation": {s: {m: {k: list(v) for k, v in r.items()} for m, r in rep.items()} for s, rep in report.items()},
        # One real embedding and the expected output, so the app's implementation is checked against this one.
        "check": {"embedding": [round(float(v), 6) for v in check], "probabilities": [round(float(v), 6) for v in probs(model, check[None])[0]]},
    }, open(args.out, "w"), separators=(",", ":"))
    print("\nwrote", args.out, os.path.getsize(args.out) // 1024, "KB")


if __name__ == "__main__":
    main()
