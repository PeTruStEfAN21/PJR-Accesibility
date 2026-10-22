"""A simulated meeting room for training: reverb, distance, and background voices or noise."""

import numpy as np
from scipy.signal import fftconvolve

from echo_voice.model import SAMPLE_RATE

# Amplitude falls by 60 dB (a factor of 1000) over RT60: exp(-ln(1000) * t / rt60).
LN_1000 = float(np.log(1000.0))


def synthetic_rir(rt60: float, sr: int, rng: np.random.Generator) -> np.ndarray:
    """Room impulse response: a direct path, then an exponentially decaying noise tail."""
    n = int(1.5 * rt60 * sr)
    t = np.arange(n) / sr
    rir = rng.standard_normal(n) * np.exp(-LN_1000 * t / rt60)
    rir[0] = 1.0
    return rir


def _pink_noise(n: int, rng: np.random.Generator) -> np.ndarray:
    spectrum = np.fft.rfft(rng.standard_normal(n))
    freqs = np.arange(spectrum.size, dtype=np.float64)
    freqs[0] = 1.0
    return np.fft.irfft(spectrum / np.sqrt(freqs), n)


def _in_room(wave: np.ndarray, rng: np.random.Generator, distance: tuple[float, float]) -> np.ndarray:
    rir = synthetic_rir(rng.uniform(0.2, 0.8), SAMPLE_RATE, rng)
    # Direct-to-reverberant ratio: about +10 dB at 1 m, falling ~6 dB per doubling of distance.
    drr_db = 10.0 - 6.0 * np.log2(rng.uniform(*distance))
    tail_energy = max(float(np.sum(rir[1:] ** 2)), 1e-12)
    rir[1:] *= np.sqrt(10 ** (-drr_db / 10) / tail_energy)
    return fftconvolve(wave, rir)[: wave.size]


def apply_room(
    wave: np.ndarray,
    rng: np.random.Generator,
    noise_pool: list[np.ndarray],
    distance: tuple[float, float] = (1.0, 10.0),
) -> np.ndarray:
    """The clip as a laptop [distance] metres away would hear it, with another voice or noise at 5–20 dB SNR."""
    n = wave.size
    wet = _in_room(np.asarray(wave, dtype=np.float64), rng, distance)
    if noise_pool and rng.random() < 0.5:
        other = noise_pool[int(rng.integers(len(noise_pool)))]
        start = int(rng.integers(max(other.size, 1)))
        noise = _in_room(np.resize(np.roll(other, -start), n).astype(np.float64), rng, distance)
    else:
        noise = _pink_noise(n, rng)
    snr_db = rng.uniform(5.0, 20.0)
    signal_power = float(np.mean(wet**2))
    noise_power = max(float(np.mean(noise**2)), 1e-12)
    out = wet + noise * np.sqrt(signal_power / (noise_power * 10 ** (snr_db / 10)))
    peak = float(np.abs(out).max())
    if peak > 1.0:
        out /= peak
    return out.astype(np.float32)
