"""Small synthetic audio and test-meeting archives for the data and evaluation tests."""

import json
from pathlib import Path

import numpy as np
import soundfile as sf

SR = 16000


def tone(seconds: float, freq: float = 220.0, sr: int = SR) -> np.ndarray:
    t = np.arange(int(seconds * sr)) / sr
    return (0.2 * np.sin(2 * np.pi * freq * t)).astype(np.float32)


def write_meeting(folder: Path, clips: list[tuple[str, float]], enrollment_seconds: float = 20) -> Path:
    """A test-meeting archive as the presenter page downloads it: (label, seconds) per clip."""
    (folder / "clips").mkdir(parents=True)
    sf.write(folder / "enrollment.wav", tone(enrollment_seconds), SR)
    lines = []
    for i, (label, seconds) in enumerate(clips, 1):
        name = f"clips/{i:03d}.wav"
        sf.write(folder / name, tone(seconds), SR)
        lines.append(
            {"id": f"c{i}", "file": name, "text": "x", "predicted": "coordinator", "score": 0.5, "label": label}
        )
    labels = {"version": 1, "sample_rate": SR, "model": "test", "enrollment": "enrollment.wav", "lines": lines}
    (folder / "labels.json").write_text(json.dumps(labels))
    return folder
