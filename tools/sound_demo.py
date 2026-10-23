"""Echo "Sunetul vizibil" in the terminal, without the app: the same models and rules, for a demo on a laptop.

Listens to the microphone (or reads a file) and prints the alerts by severity, using what the phone uses:
YAMNet (app/assets/models/yamnet.tflite), our trained danger-sound head (danger_head.json), the YAMNet
class names, "2 windows in a row" and "the same alert at most once every 10 s". Nothing leaves the laptop.

    .venv/Scripts/pip install ai-edge-litert numpy scipy scikit-learn soundfile sounddevice   # --file reads audio with train_danger_sounds.py
    .venv/Scripts/python tools/sound_demo.py                       # listen to the microphone
    .venv/Scripts/python tools/sound_demo.py --file alarm.wav      # run on a recording
    .venv/Scripts/python tools/sound_demo.py --learn "Alarma halei 2" --level critical   # learn a workplace sound (3 samples)
"""

import argparse
import csv
import json
import os
import queue
import sys
import time
from math import gcd

import numpy as np
from ai_edge_litert.interpreter import Interpreter
from scipy.signal import resample_poly

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "app", "assets", "models")
LEARNED = os.path.join(os.path.dirname(os.path.abspath(__file__)), "learned_sounds.json")
SR, WIN, HOP = 16000, 15600, 8000

# Same values as app/lib/features/alerts/yamnet_logic.dart.
KIND_THRESHOLD = 0.3
LOCATION_THRESHOLD = 0.8
CONSECUTIVE = 2
COOLDOWN = 10.0
NAMES = {
    "Fire alarm": "fireAlarm", "Smoke detector, smoke alarm": "fireAlarm", "Siren": "siren", "Civil defense siren": "siren",
    "Vehicle horn, car horn, honking": "horn", "Air horn, truck horn": "horn", "Telephone bell ringing": "phone",
    "Ringtone": "phone", "Doorbell": "door", "Ding-dong": "door", "Knock": "door",
}
HEAD = {"fire_alarm": "fireAlarm", "siren": "siren", "horn": "horn", "glass_break": "glassBreak"}
KINDS = {  # label (as in app_ro.arb), level
    "fireAlarm": ("ALARMĂ DE INCENDIU", "critical"), "siren": ("Sirenă", "critical"), "horn": ("Claxon în apropiere", "warning"),
    "glassBreak": ("Geam spart", "warning"), "phone": ("Sună un telefon", "info"), "door": ("Ușă sau sonerie", "info"),
}
STYLE = {"critical": ("\033[97;41;1m", "CRITIC   "), "warning": ("\033[30;43;1m", "ATENȚIE  "), "info": ("\033[30;46m", "INFO     ")}
RESET = "\033[0m"


class Detector:
    def __init__(self):
        self.it = Interpreter(model_path=os.path.join(MODELS, "yamnet.tflite"))
        self.it.allocate_tensors()
        self.inp = self.it.get_input_details()[0]["index"]
        self.out = [o["index"] for o in self.it.get_output_details()]
        self.names = [r["display_name"] for r in csv.DictReader(open(os.path.join(MODELS, "yamnet_class_map.csv"), encoding="utf-8"))]
        self.named = {i: NAMES[n] for i, n in enumerate(self.names) if n in NAMES}
        head = json.load(open(os.path.join(MODELS, "danger_head.json")))
        self.W, self.b = np.array(head["weights"]), np.array(head["bias"])
        self.head_kinds = [HEAD.get(label) for label in head["labels"]]
        self.head_thr = {HEAD[k]: v for k, v in head["thresholds"].items()}
        self.learned = json.load(open(LEARNED, encoding="utf-8")) if os.path.exists(LEARNED) else []
        self.streak, self.last = {}, {}

    def run(self, window):
        self.it.set_tensor(self.inp, window.astype(np.float32))
        self.it.invoke()
        scores = self.it.get_tensor(self.out[0]).reshape(-1)
        emb = self.it.get_tensor(self.out[1]).reshape(-1)
        return scores, emb / (np.linalg.norm(emb) + 1e-9)

    def analyze(self, window, now):
        scores, emb = self.run(window)
        z = self.W @ emb + self.b
        p = np.exp(z - z.max())
        p /= p.sum()
        why = {}
        for i, kind in self.named.items():
            if scores[i] >= KIND_THRESHOLD:
                why.setdefault(kind, []).append(f"YAMNet „{self.names[i]}” {scores[i]:.2f}")
        for c, kind in enumerate(self.head_kinds):
            if kind and p[c] >= self.head_thr[kind]:
                why.setdefault(kind, []).append(f"modelul nostru {p[c]:.2f}")
        for sound in self.learned:
            sim = float(np.dot(emb, sound["print"]))
            if sim >= LOCATION_THRESHOLD:
                why.setdefault("learned:" + sound["label"], []).append(f"seamănă {sim:.2f} cu mostrele")

        alerts = []
        for key in list(self.streak):
            if key not in why:
                del self.streak[key]
        for key, reasons in why.items():
            self.streak[key] = self.streak.get(key, 0) + 1
            if self.streak[key] >= CONSECUTIVE and now - self.last.get(key, -1e9) > COOLDOWN:
                self.last[key] = now
                if key.startswith("learned:"):
                    sound = next(s for s in self.learned if s["label"] == key[8:])
                    alerts.append((sound["label"], sound["level"], reasons))
                else:
                    alerts.append((*KINDS[key], reasons))
        top = int(np.argmax(scores))
        return alerts, f"{self.names[top]} {scores[top]:.2f}"


def show(t, alerts, realtime):
    clear = f"\r{' ' * 70}\r" if realtime else ""  # overwrites the live status line
    for label, level, reasons in alerts:
        colour, name = STYLE[level]
        print(f"{clear}[{t:6.1f}s] {colour} {name}{label} {RESET}  ({'; '.join(reasons)})", flush=True)


def to16k(x, sr):
    g = gcd(sr, SR)
    return resample_poly(x, SR // g, sr // g).astype(np.float32) if sr != SR else x.astype(np.float32)


def microphone():
    """Yields mono 16 kHz blocks of 0.5 s from the default microphone."""
    import sounddevice as sd

    sr = SR
    try:
        sd.check_input_settings(samplerate=SR, channels=1)
    except Exception:
        sr = int(sd.query_devices(kind="input")["default_samplerate"])
    q = queue.Queue()
    with sd.InputStream(samplerate=sr, channels=1, dtype="float32", blocksize=sr // 2, callback=lambda d, *_: q.put(d[:, 0].copy())):
        while True:
            yield to16k(q.get(), sr)


def listen(det, blocks, realtime):
    buf = np.zeros(0, dtype=np.float32)
    t = 0.0
    for block in blocks:
        buf = np.concatenate([buf, block])
        while len(buf) >= WIN:
            alerts, top = det.analyze(buf[:WIN], t)
            show(t + WIN / SR, alerts, realtime)
            if realtime:
                print(f"\r  ascult... aud: {top:<50}", end="", flush=True)
            buf = buf[HOP:]
            t += HOP / SR


def learn(det, label, level, count=3, seconds=2.0):
    import sounddevice as sd

    prints = []
    while len(prints) < count:
        input(f"Mostra {len(prints) + 1} din {count}: apasă Enter, apoi redă sunetul „{label}”...")
        rec = sd.rec(int(seconds * SR), samplerate=SR, channels=1, dtype="float32")
        sd.wait()
        x = rec[:, 0]
        wins = [x[i : i + WIN] for i in range(0, len(x) - WIN + 1, HOP)]
        loud = [w for w in wins if np.sqrt(np.mean(w**2)) >= 0.003]
        if not loud:
            print("  Nu am prins sunetul. Încearcă din nou, mai aproape de sursă.")
            continue
        embs = [det.run(w)[1] for w in loud]
        prints.append(np.mean(embs, axis=0))
        print(f"  Mostra {len(prints)} înregistrată.")
    fp = np.mean([p / np.linalg.norm(p) for p in prints], axis=0)
    fp /= np.linalg.norm(fp)
    det.learned = [s for s in det.learned if s["label"] != label] + [{"label": label, "level": level, "print": fp.round(6).tolist()}]
    json.dump(det.learned, open(LEARNED, "w", encoding="utf-8"), ensure_ascii=False)
    print(f"Sunetul „{label}” a fost învățat (doar amprenta, fără audio) în {LEARNED}.")


def main():
    if sys.platform == "win32":
        os.system("")  # turns on ANSI colours in the Windows console
        sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--file", help="analizează o înregistrare în loc de microfon")
    ap.add_argument("--learn", metavar="NUME", help="învață un sunet al locației din 3 mostre de la microfon")
    ap.add_argument("--level", choices=["critical", "warning", "info"], default="warning")
    ap.add_argument("--forget", action="store_true", help="șterge sunetele învățate")
    args = ap.parse_args()

    det = Detector()
    if args.forget and os.path.exists(LEARNED):
        os.remove(LEARNED)
        det.learned = []
    if args.learn:
        learn(det, args.learn, args.level)
        return
    learned = ", ".join(s["label"] for s in det.learned) or "niciunul"
    print(f"Echo, Sunetul vizibil. Sunete învățate: {learned}.")
    if args.file:
        sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
        from train_danger_sounds import read_audio

        x = read_audio(args.file)
        listen(det, [x[i : i + HOP] for i in range(0, len(x), HOP)], realtime=False)
        print("gata.")
    else:
        print("Ascult microfonul. Ctrl+C ca să oprești.")
        try:
            listen(det, microphone(), realtime=True)
        except KeyboardInterrupt:
            print("\noprit.")


if __name__ == "__main__":
    main()
