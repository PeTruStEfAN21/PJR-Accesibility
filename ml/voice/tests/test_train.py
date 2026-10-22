import numpy as np
import pytest
import soundfile as sf
import torch

from echo_voice import train
from echo_voice.model import load_base, load_candidate
from tests.helpers import SR


def modulated_tone(seconds: float, freq: float, rate: float) -> np.ndarray:
    t = np.arange(int(seconds * SR)) / SR
    return (0.3 * np.sin(2 * np.pi * freq * t) * (0.5 + 0.5 * np.sin(2 * np.pi * rate * t))).astype(np.float32)


@pytest.mark.slow
def test_train_smoke_runs_two_steps(tmp_path):
    data = tmp_path / "speakers"
    for s, freq in enumerate((150.0, 220.0, 310.0)):
        (data / f"vp-{s}").mkdir(parents=True)
        for c in range(3):
            sf.write(data / f"vp-{s}" / f"{c}.wav", modulated_tone(2.0, freq, 3 + c), SR)

    out = tmp_path / "runs" / "smoke"
    train.main(["--data", str(data), "--out", str(out), "--smoke"])

    best = out / "best.pt"
    assert best.exists()
    tuned = load_candidate(str(best))
    base = load_base()
    # Two optimizer steps move the backbone, however little.
    changed = [
        name
        for (name, p), (_, q) in zip(tuned.named_parameters(), base.named_parameters(), strict=True)
        if not torch.equal(p, q)
    ]
    assert changed
    with torch.no_grad():
        assert tuned(torch.zeros(1, SR)).shape == (1, 192)
