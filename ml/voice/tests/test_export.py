import base64
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
import pytest
import soundfile as sf

from echo_voice import export
from echo_voice.model import SAMPLE_RATE, embed, load_base

FIXTURES = Path(__file__).parent / "fixtures"


@pytest.fixture(scope="module")
def model():
    return load_base()


def speechlike(seconds: float, seed: int = 0) -> np.ndarray:
    """Noise shaped into the voice band and modulated at a syllable rate."""
    rng = np.random.default_rng(seed)
    noise = rng.standard_normal(int(seconds * SAMPLE_RATE)).astype(np.float32)
    wave = np.convolve(noise, np.ones(8, dtype=np.float32) / 8, mode="same")
    t = np.arange(wave.size) / SAMPLE_RATE
    wave *= 0.5 * (1 + np.sin(2 * np.pi * 4 * t))
    return (0.3 * wave / np.abs(wave).max()).astype(np.float32)


def read(name: str) -> np.ndarray:
    wave, sr = sf.read(FIXTURES / name, dtype="float32")
    assert sr == SAMPLE_RATE
    return wave


def onnx_embed(session: ort.InferenceSession, wave: np.ndarray) -> np.ndarray:
    (out,) = session.run(["embedding"], {"audio": wave[None, :]})
    return out[0]


@pytest.mark.slow
def test_embedding_is_unit_length_192(model):
    vector = embed(model, speechlike(3))
    assert vector.shape == (192,)
    assert abs(np.linalg.norm(vector) - 1) < 1e-5


@pytest.mark.slow
def test_onnx_matches_torch_for_several_lengths(model, tmp_path):
    path = tmp_path / "speaker.onnx"
    export.export_onnx(model, path)
    session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
    for seconds in (1.5, 3, 8):
        wave = speechlike(seconds, seed=int(seconds * 10))
        from_onnx = onnx_embed(session, wave)
        assert abs(np.linalg.norm(from_onnx) - 1) < 1e-4
        cosine = float(from_onnx @ embed(model, wave))
        assert cosine >= 0.9999, (seconds, cosine)


@pytest.mark.slow
def test_same_speaker_scores_higher_than_different(model):
    a, b, other = (embed(model, read(name)) for name in ("spk1_a.wav", "spk1_b.wav", "spk2_a.wav"))
    same = float(a @ b)
    different = max(float(a @ other), float(b @ other))
    assert same > different + 0.2, (same, different)


@pytest.mark.slow
def test_export_cli_writes_model_and_parity_fixture(tmp_path):
    out = tmp_path / "voice" / "speaker.onnx"
    export.main(["--out", str(out)])

    parity = json.loads((out.parent / "fixtures" / "parity.json").read_text())
    assert parity["sample_rate"] == 16000
    audio = np.frombuffer(base64.b64decode(parity["audio_b64"]), dtype="<f4")
    assert audio.size == 3 * 16000
    session = ort.InferenceSession(str(out), providers=["CPUExecutionProvider"])
    expected = np.asarray(parity["embedding"], dtype=np.float32)
    assert expected.shape == (192,)
    assert float(onnx_embed(session, audio) @ expected) >= 0.9999
