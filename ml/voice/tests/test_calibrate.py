import json
import math
import zlib

import numpy as np
import soundfile as sf

from echo_voice.calibrate import fit_head
from echo_voice.evaluate import speaker_probability
from echo_voice.ship import Candidate, ship
from tests.helpers import SR, tone


def test_fit_head_respects_speaker_hit():
    rng = np.random.default_rng(0)
    same = rng.normal(0.70, 0.08, 400)
    diff = rng.normal(0.30, 0.10, 400)
    speaker = rng.normal(0.60, 0.10, 200)
    room = rng.normal(0.25, 0.10, 200)

    head = fit_head(same, diff, speaker, room)

    accepted = np.array([speaker_probability(c, head) >= head["threshold"] for c in speaker])
    rejected = np.array([speaker_probability(c, head) < head["threshold"] for c in room])
    assert accepted.mean() >= 0.95
    assert rejected.mean() > 0.9
    assert speaker_probability(0.70, head) > 0.9
    assert speaker_probability(0.30, head) < 0.2  # the groups overlap, so 0.30 is not certain


def test_fit_head_threshold_is_the_highest_that_keeps_95_percent():
    speaker = np.linspace(0.40, 0.80, 100)  # evenly spaced, so 95% means the lowest 5 may be lost
    head = fit_head(np.array([0.7, 0.8]), np.array([0.2, 0.3]), speaker, np.array([0.1]))

    accepted = [c for c in speaker if speaker_probability(c, head) >= head["threshold"]]
    assert len(accepted) == 95


def test_fit_head_without_meetings_uses_same_speaker_pairs():
    same = np.linspace(0.5, 0.9, 100)
    head = fit_head(same, np.linspace(0.1, 0.4, 100), np.array([]), np.array([]))
    accepted = [c for c in same if speaker_probability(c, head) >= head["threshold"]]
    assert len(accepted) == 95


def fake_candidate(name: str, same: float, different: float, exported: list[str], spread: float = 0.0) -> Candidate:
    def pair_score(a, b) -> float:
        jitter = zlib.crc32(f"{a}|{b}".encode()) % 1000 / 1000 - 0.5  # deterministic, in [-0.5, 0.5)
        return (same if a.parent == b.parent else different) + spread * jitter

    def export(path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(name)
        exported.append(name)

    return Candidate(name=name, model_id=f"model-{name}", pair_score=pair_score, score=lambda e, c: same, export=export)


def test_ship_keeps_base_when_finetune_is_worse(tmp_path):
    speakers = tmp_path / "speakers"
    for s in range(20):
        (speakers / f"vp-{s}").mkdir(parents=True)
        for c in range(3):
            sf.write(speakers / f"vp-{s}" / f"{c}.wav", tone(2), SR)
    exported: list[str] = []
    base = fake_candidate("base", same=0.8, different=0.2, exported=exported)
    worse = fake_candidate("finetune", same=0.5, different=0.48, exported=exported, spread=0.3)
    app_voice = tmp_path / "app" / "voice"
    reports = tmp_path / "reports"

    winner = ship([base, worse], speakers, tmp_path / "no-meetings", app_voice, reports, n_trials=200)

    assert winner == "base"
    assert exported == ["base"]
    assert (app_voice / "speaker.onnx").read_text() == "base"
    head = json.loads((app_voice / "voice_head.json").read_text())
    assert head["model"] == "model-base"
    for key in ("scale", "bias", "threshold", "min_voiced_ms", "enroll_min_voiced_ms", "window_ms"):
        assert isinstance(head[key], (int, float)) and math.isfinite(head[key])
    report = next(reports.glob("*-ship.md")).read_text(encoding="utf-8")
    assert "finetune" in report and "base" in report
