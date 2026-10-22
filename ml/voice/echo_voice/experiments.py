"""Measures what lowers the error in the app's own situation: a reply (1.5–8 s, maybe heard across a room)
compared with ~20 s of learned voice. Prints EER for each variant on the held-out speakers.

Usage: python -m echo_voice.experiments [--trials 2000]
"""

import argparse
from pathlib import Path

import numpy as np
import soundfile as sf
import torch

from echo_voice.augment import apply_room
from echo_voice.data import split_speakers
from echo_voice.evaluate import ROOT, eer
from echo_voice.model import SAMPLE_RATE, embed, load_base, load_candidate

ENROLL_SECONDS = 20


def _clips(root: Path, speaker: str) -> list[np.ndarray]:
    return [sf.read(p, dtype="float32")[0] for p in sorted((root / speaker).glob("*.wav"))]


def _crop(wave: np.ndarray, seconds: float, rng: np.random.Generator) -> np.ndarray:
    n = int(seconds * SAMPLE_RATE)
    if wave.size <= n:
        return wave
    start = int(rng.integers(wave.size - n + 1))
    return wave[start : start + n]


def _normalize(v: np.ndarray) -> np.ndarray:
    return v / np.linalg.norm(v)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--speakers", type=Path, default=ROOT / "data" / "speakers")
    parser.add_argument("--run", type=Path, default=ROOT / "runs" / "vp-ro-1" / "best.pt")
    parser.add_argument("--trials", type=int, default=2000)
    args = parser.parse_args(argv)

    rng = np.random.default_rng(0)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    train, test = split_speakers(args.speakers)
    voices = [s for s in test if not s.startswith("meeting-")]
    clips = {s: _clips(args.speakers, s) for s in voices}
    cohort_speakers = [s for s in train if not s.startswith("meeting-")][:60]

    models = {"base": load_base().to(device)}
    if args.run.exists():
        models["fine-tuned"] = load_candidate(str(args.run)).to(device)

    # Enrollment: ~20 s of one speaker's clips, never the test clip; trials: a test clip of the same or
    # another held-out speaker, at several lengths, clean or heard across a simulated room.
    noise_pool = [c for s in voices for c in clips[s][:3]]
    trials = []
    for i in range(args.trials):
        target = voices[int(rng.integers(len(voices)))]
        same = i % 2 == 0
        other = target if same else voices[(voices.index(target) + 1 + int(rng.integers(len(voices) - 1))) % len(voices)]
        pool = list(range(len(clips[target])))
        rng.shuffle(pool)
        enroll_idx, seconds = [], 0.0
        for j in pool[1:]:
            enroll_idx.append(j)
            seconds += clips[target][j].size / SAMPLE_RATE
            if seconds >= ENROLL_SECONDS:
                break
        test_clip = clips[target][pool[0]] if same else clips[other][int(rng.integers(len(clips[other])))]
        trials.append((target, tuple(enroll_idx), test_clip, same))

    results = {}
    for name, model in models.items():
        cache: dict[tuple, np.ndarray] = {}

        def vec(key, wave):
            if key not in cache:
                cache[key] = embed(model, wave)
            return cache[key]

        cohort = np.stack([
            _normalize(np.mean([vec(("c", s, k), c[: 8 * SAMPLE_RATE]) for k, c in enumerate(_clips(args.speakers, s)[:3])], axis=0))
            for s in cohort_speakers
        ])

        def enrollment(target, idx):
            key = ("e", target, idx)
            if key not in cache:
                windows = [vec(("w", target, j), clips[target][j][: 8 * SAMPLE_RATE]) for j in idx]
                cache[key] = _normalize(np.mean(windows, axis=0))
            return cache[key]

        for condition in ("curat", "sală 5-10 m"):
            for seconds in (1.5, 3.0, 8.0):
                plain, normed, labels = [], [], []
                trial_rng = np.random.default_rng(1)
                for t, (target, idx, wave, same) in enumerate(trials):
                    clip = _crop(wave, seconds, trial_rng)
                    if condition != "curat":
                        clip = apply_room(clip, trial_rng, noise_pool, distance=(5.0, 10.0))
                    e = enrollment(target, idx)
                    v = embed(model, clip)
                    s = float(e @ v)
                    # Adaptive score normalisation against the 60-speaker cohort (top 20 on each side).
                    ce, cv = np.sort(cohort @ e)[-20:], np.sort(cohort @ v)[-20:]
                    normed.append(0.5 * ((s - ce.mean()) / ce.std() + (s - cv.mean()) / cv.std()))
                    plain.append(s)
                    labels.append(same)
                key = (name, condition, seconds)
                results[key] = (eer(np.array(plain), np.array(labels)), eer(np.array(normed), np.array(labels)), np.array(plain), np.array(labels))
                print(f"{name:11s} {condition:14s} {seconds:4.1f} s   EER {100 * results[key][0]:5.2f}%   cu AS-norm {100 * results[key][1]:5.2f}%", flush=True)

    if "fine-tuned" in models:
        for condition in ("curat", "sală 5-10 m"):
            for seconds in (1.5, 3.0, 8.0):
                b, f = results[("base", condition, seconds)], results[("fine-tuned", condition, seconds)]
                fused = eer((b[2] + f[2]) / 2, b[3])
                print(f"fuziune     {condition:14s} {seconds:4.1f} s   EER {100 * fused:5.2f}%", flush=True)


if __name__ == "__main__":
    main()
