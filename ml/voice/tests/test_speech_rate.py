import numpy as np
import pytest

from echo_voice.speech_rate import FrameAnalyzer, calibrate, pace_windows, syllable_count, talk_time

RATE = 16000


def syllables(seconds: float, per_second: float, amplitude: float = 0.3) -> np.ndarray:
    """Same signal as app/test/features/coach/voice_activity_test.dart: a three-tone carrier whose
    loudness rises and falls `per_second` times a second."""
    t = np.arange(round(seconds * RATE)) / RATE
    carrier = np.sin(2 * np.pi * 220 * t) + 0.5 * np.sin(2 * np.pi * 440 * t + 1) + 0.3 * np.sin(2 * np.pi * 880 * t + 2)
    hump = np.maximum(0.0, np.sin(2 * np.pi * per_second * t))
    return (amplitude * (0.05 + hump) * carrier / 1.8).astype(np.float32)


def test_parity_signal_counts_the_same_as_the_app():
    # The Dart test expects exactly 27 for this signal too.
    assert syllable_count(syllables(6, 4.5)) == 27


def test_four_syllables_a_second():
    assert 34 <= syllable_count(syllables(10, 4)) <= 46


def test_silence_is_not_voice():
    frames = FrameAnalyzer().add(np.zeros(3 * RATE, dtype=np.float32))
    assert not any(f.voiced for f in frames)


def test_chunking_does_not_matter():
    signal = syllables(4, 5)
    a, b = FrameAnalyzer(), FrameAnalyzer()
    big = [f for i in range(0, len(signal), 4096) for f in a.add(signal[i : i + 4096])]
    small = [f for i in range(0, len(signal), 333) for f in b.add(signal[i : i + 333])]
    assert [(f.voiced, f.syllable) for f in big] == [(f.voiced, f.syllable) for f in small]


def test_talk_lasts_one_second_after_the_voice_like_in_the_coach():
    frames = FrameAnalyzer().add(np.concatenate([syllables(3, 4), np.zeros(3 * RATE, dtype=np.float32)]))
    assert talk_time(frames) == pytest.approx(3.9, abs=0.2)


def test_calibration_turns_words_a_minute_into_syllables_a_second():
    # Two pulses a word: 170 words a minute are 170 / 60 * 2 = 5.67 pulses a second.
    clips = [(syllables(10, rate), " ".join(["cuvânt"] * round(rate * 5))) for rate in (3, 3.5, 4, 4.5, 5, 5.5, 6, 7)]
    result = calibrate(clips, words_per_minute=170)
    assert result.clips == 8
    assert result.syllables_per_word == pytest.approx(2, rel=0.15)
    assert result.threshold == pytest.approx(170 / 60 * 2, rel=0.15)
    assert result.letters_per_word == 6
    # 210 words a minute is caught; 150 and slower never are.
    assert result.caught == 1
    assert result.false_alarms == 0


def test_windows_join_one_speech_until_twenty_seconds_of_talk():
    words = " ".join(["cuvânt"] * 20)
    segments = [("a", syllables(8, 4), words)] * 3 + [("b", syllables(8, 4), words)]
    windows = list(pace_windows(segments, talk_seconds=20))
    # Speech a holds 24 s of voice; speech b alone is too short.
    assert len(windows) == 1
    words_per_minute, syllables_per_second = windows[0]
    assert words_per_minute == pytest.approx(60 * 60 / 25.2, rel=0.1)
    assert syllables_per_second == pytest.approx(4 * 24 / 25.2, rel=0.15)
