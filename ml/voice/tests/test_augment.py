import numpy as np

from echo_voice.augment import apply_room, synthetic_rir
from tests.helpers import SR, tone


def test_apply_room_keeps_length_and_is_seeded():
    wave = tone(3)
    pool = [tone(2, freq=330)]

    first = apply_room(wave, np.random.default_rng(7), pool)
    again = apply_room(wave, np.random.default_rng(7), pool)

    assert first.shape == wave.shape
    assert first.dtype == np.float32
    np.testing.assert_array_equal(first, again)
    rms = float(np.sqrt(np.mean(first**2)))
    assert np.isfinite(rms) and rms > 0
    assert np.abs(first).max() <= 1.0
    assert not np.allclose(first, wave, atol=1e-3)


def test_apply_room_works_without_a_noise_pool():
    out = apply_room(tone(2), np.random.default_rng(1), [])
    assert out.shape == (2 * SR,)
    assert np.isfinite(out).all()


def test_synthetic_rir_decays_by_60_db_at_rt60():
    rir = synthetic_rir(0.5, SR, np.random.default_rng(0))

    def energy(seconds: float) -> float:
        start = int(seconds * SR)
        return float(np.mean(rir[start : start + 160] ** 2))

    drop_db = 10 * np.log10(energy(0.005) / energy(0.5))
    assert 50 < drop_db < 70
