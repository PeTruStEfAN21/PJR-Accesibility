"""How well a candidate model tells the speaker from the room.

Two measures: EER on same / different speaker pairs from the held-out Romanian speakers, and, for each
held-out test meeting, the share of speaker lines labelled "Speaker" and of room lines labelled "Din sală".

Usage: python -m echo_voice.evaluate [--candidate base] [--speakers data/speakers] [--meetings data/meetings]
"""

import argparse
import datetime
import hashlib
import json
import math
from collections.abc import Callable
from pathlib import Path

import numpy as np
import soundfile as sf
import torch

from echo_voice.data import meeting_dirs, split_speakers
from echo_voice.model import SAMPLE_RATE, embed, load_base

ScoreFn = Callable[[np.ndarray, np.ndarray], float]

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_HEAD = {"scale": 20.0, "bias": -7.0, "threshold": 0.5}
HEAD_FILE = ROOT.parent.parent / "app" / "web" / "voice" / "voice_head.json"
WINDOW_SECONDS = 3
MAX_CLIP_SECONDS = 8


def eer(scores: np.ndarray, same: np.ndarray) -> float:
    """Equal error rate: where wrongly rejected same-speaker pairs equal wrongly accepted other pairs."""
    scores = np.asarray(scores, dtype=np.float64)
    same = np.asarray(same, dtype=bool)
    positives, negatives = np.sort(scores[same]), np.sort(scores[~same])
    if positives.size == 0 or negatives.size == 0:
        raise ValueError("need both same-speaker and different-speaker pairs")
    thresholds = np.unique(np.concatenate([scores, [np.inf]]))
    frr = np.searchsorted(positives, thresholds, side="left") / positives.size
    far = 1.0 - np.searchsorted(negatives, thresholds, side="left") / negatives.size
    gap = far - frr  # falls from +1 to -1 as the threshold rises
    i = int(np.argmax(gap <= 0))
    if gap[i] == 0 or i == 0:
        return float(far[i])
    weight = gap[i - 1] / (gap[i - 1] - gap[i])
    return float(far[i - 1] + weight * (far[i] - far[i - 1]))


def speaker_probability(cosine: float, head: dict) -> float:
    return 1.0 / (1.0 + math.exp(-(head["scale"] * cosine + head["bias"])))


def meeting_report(score_fn: ScoreFn, archive_dir: Path, head: dict) -> dict:
    labels = json.loads((archive_dir / "labels.json").read_text(encoding="utf-8"))
    enrollment, _ = sf.read(archive_dir / labels["enrollment"], dtype="float32")
    hits = rejects = n_speaker = n_room = 0
    for line in labels["lines"]:
        clip, _ = sf.read(archive_dir / line["file"], dtype="float32")
        labelled_speaker = speaker_probability(score_fn(enrollment, clip), head) >= head["threshold"]
        if line["label"] == "coordinator":
            n_speaker += 1
            hits += labelled_speaker
        else:
            n_room += 1
            rejects += not labelled_speaker
    return {
        "speaker_hit": hits / n_speaker if n_speaker else float("nan"),
        "room_reject": rejects / n_room if n_room else float("nan"),
        "n_speaker": n_speaker,
        "n_room": n_room,
    }


def enrollment_embedding(model: torch.nn.Module, wave: np.ndarray) -> np.ndarray:
    """Mean of the embeddings of 3 s windows, as the presenter page computes it."""
    size = WINDOW_SECONDS * SAMPLE_RATE
    windows = [wave[i : i + size] for i in range(0, wave.size - size + 1, size)] or [wave]
    mean = np.mean([embed(model, w) for w in windows], axis=0)
    return mean / np.linalg.norm(mean)


def make_score_fn(model: torch.nn.Module) -> ScoreFn:
    enrolled: dict[str, np.ndarray] = {}

    def score(enrollment: np.ndarray, clip: np.ndarray) -> float:
        key = hashlib.sha1(enrollment.tobytes()).hexdigest()
        if key not in enrolled:
            enrolled[key] = enrollment_embedding(model, enrollment)
        return float(enrolled[key] @ embed(model, clip[: MAX_CLIP_SECONDS * SAMPLE_RATE]))

    return score


def speaker_trials(root: Path, speakers: list[str], n_trials: int, seed: int = 0) -> list[tuple[Path, Path, bool]]:
    """Balanced same / different pairs of clips from the given speakers."""
    rng = np.random.default_rng(seed)
    files = {s: sorted((root / s).glob("*.wav")) for s in speakers}
    names = sorted(s for s, clips in files.items() if len(clips) >= 2)
    if len(names) < 2:
        raise ValueError("need at least two held-out speakers with two clips each")
    trials = []
    for i in range(n_trials):
        a = names[int(rng.integers(len(names)))]
        if i % 2 == 0:
            x, y = rng.choice(len(files[a]), size=2, replace=False)
            trials.append((files[a][x], files[a][y], True))
        else:
            b = names[int(rng.integers(len(names) - 1))]
            b = b if b != a else names[-1]
            trials.append((files[a][int(rng.integers(len(files[a])))], files[b][int(rng.integers(len(files[b])))], False))
    return trials


def trials_eer(model: torch.nn.Module, trials: list[tuple[Path, Path, bool]]) -> float:
    cache: dict[Path, np.ndarray] = {}

    def vector(path: Path) -> np.ndarray:
        if path not in cache:
            wave, _ = sf.read(path, dtype="float32")
            cache[path] = embed(model, wave[: MAX_CLIP_SECONDS * SAMPLE_RATE])
        return cache[path]

    scores = np.array([float(vector(a) @ vector(b)) for a, b, _ in trials])
    return eer(scores, np.array([same for _, _, same in trials]))


def load_head(path: Path = HEAD_FILE) -> dict:
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else dict(DEFAULT_HEAD)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--candidate", default="base", help="'base' (the pretrained model)")
    parser.add_argument("--speakers", type=Path, default=ROOT / "data" / "speakers")
    parser.add_argument("--meetings", type=Path, default=ROOT / "data" / "meetings")
    parser.add_argument("--trials", type=int, default=4000)
    args = parser.parse_args(argv)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    model = load_base().to(device)
    head = load_head()
    rows = [f"# Evaluare: {args.candidate} ({datetime.date.today().isoformat()})", ""]

    if args.speakers.exists():
        _, test = split_speakers(args.speakers)
        voices = [s for s in test if not s.startswith("meeting-")]
        rows.append(f"EER pe {args.trials} perechi de la {len(voices)} vorbitori ținuți deoparte: "
                    f"**{100 * trials_eer(model, speaker_trials(args.speakers, voices, args.trials)):.2f}%**")
        rows.append("")

    held_out = {line.strip() for line in (ROOT / "heldout_meetings.txt").read_text(encoding="utf-8").splitlines()
                if line.strip()} if (ROOT / "heldout_meetings.txt").exists() else set()
    if args.meetings.exists():
        rows += ["| Meeting | Speaker → „Speaker” | Sală → „Din sală” | Replici speaker / sală |", "|---|---|---|---|"]
        score = make_score_fn(model)
        for folder in meeting_dirs(args.meetings):
            if folder.name not in held_out:
                continue
            r = meeting_report(score, folder, head)
            rows.append(f"| {folder.name} | {100 * r['speaker_hit']:.0f}% | {100 * r['room_reject']:.0f}% "
                        f"| {r['n_speaker']} / {r['n_room']} |")

    report = ROOT / "reports" / f"{datetime.date.today().isoformat()}-eval-{args.candidate}.md"
    report.parent.mkdir(exist_ok=True)
    report.write_text("\n".join(rows) + "\n", encoding="utf-8")
    print("\n".join(rows))
    print(f"\nwrote {report}")


if __name__ == "__main__":
    main()
