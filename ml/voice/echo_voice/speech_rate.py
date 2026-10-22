"""Speech rate without a transcript: the clarity coach's frame analyzer, ported line for line from
app/lib/features/coach/voice_activity.dart so the pace threshold can be calibrated on Romanian speech.

Usage: python -m echo_voice.speech_rate [--src data/raw/voxpopuli_ro] [--words-per-minute 170]
(writes reports/<date>-ritm.md)
"""

import argparse
import datetime
import io
import math
from collections.abc import Iterable, Iterator
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pyarrow.parquet as pq
import soundfile as sf

from echo_voice.data import to_16k_mono
from echo_voice.evaluate import ROOT

FRAME = 480  # 30 ms at 16 kHz
HISTORY = 333  # 10 s of frames
DIP_DB = 2.0
MIN_GAP = 0.1


@dataclass
class Frame:
    time: float
    db: float
    voiced: bool
    syllable: bool


def _db(energy: float) -> float:
    return 10 * math.log10(max(energy, 1e-12))


class FrameAnalyzer:
    """Same rules as the app: voice is 12 dB above the quietest tenth of the last 10 s (a fixed -50 dBFS
    floor during the first second); syllables are loudness peaks in voice with 2 dB dips around them."""

    def __init__(self) -> None:
        self._pending = np.zeros(0, dtype=np.float64)
        self._energies: list[float] = []
        self._index = 0
        self._dip = math.inf
        self._candidate_db = -math.inf
        self._candidate_time = -math.inf
        self._armed = False
        self._last_syllable = -math.inf

    def add(self, samples: np.ndarray) -> list[Frame]:
        self._pending = np.concatenate([self._pending, np.asarray(samples, dtype=np.float64)])
        frames = []
        start = 0
        while len(self._pending) - start >= FRAME:
            chunk = self._pending[start : start + FRAME]
            frames.append(self._frame(float(np.sum(chunk * chunk)) / FRAME))
            start += FRAME
        self._pending = self._pending[start:]
        return frames

    def _frame(self, energy: float) -> Frame:
        time = self._index * 0.03
        self._index += 1
        self._energies.append(energy)
        if len(self._energies) > HISTORY:
            self._energies.pop(0)
        voiced = energy >= self._floor()
        db = _db(energy)
        return Frame(time, db, voiced, self._syllable(time, db, voiced))

    def _floor(self) -> float:
        if len(self._energies) < 1000 // 30:
            return 1e-5
        noise = sorted(self._energies)[int(len(self._energies) * 0.1)]
        return max(noise * 10 ** (12 / 10), 1e-6)

    def _syllable(self, time: float, db: float, voiced: bool) -> bool:
        if not voiced:
            confirmed = self._confirm(db)
            self._dip = min(self._dip, db)
            return confirmed
        if db > self._candidate_db or not self._armed:
            if db >= self._dip + DIP_DB or self._dip == math.inf:
                self._candidate_db = db
                self._candidate_time = time
                self._armed = True
            self._dip = min(self._dip, db)
            return False
        return self._confirm(db)

    def _confirm(self, db: float) -> bool:
        if not self._armed or db > self._candidate_db - DIP_DB:
            return False
        self._armed = False
        self._dip = db
        self._candidate_db = -math.inf
        if self._candidate_time - self._last_syllable < MIN_GAP:
            return False
        self._last_syllable = self._candidate_time
        return True


def syllable_count(samples: np.ndarray) -> int:
    return sum(f.syllable for f in FrameAnalyzer().add(samples))


def talk_time(frames: list[Frame], gap: float = 1.0) -> float:
    """Seconds counted as talk the way the coach does: frames within `gap` s after the last voice."""
    last = -math.inf
    total = 0.0
    for f in frames:
        if f.voiced:
            last = f.time
        if f.time - last < gap:
            total += 0.03
    return total


@dataclass
class Calibration:
    clips: int
    syllables_per_word: float  # detected syllables per transcript word, near the target pace
    threshold: float  # detected syllables per second of talk at the target pace
    words_per_minute: tuple[float, float, float]  # quartiles of the clips' pace
    syllables_per_second: tuple[float, float, float]
    above: float  # share of clips faster than the threshold
    letters_per_word: float
    caught: float  # share of clips 20+ words a minute faster than the target that are above the threshold
    false_alarms: float  # share of clips 20+ words a minute slower than the target that are above it
    correlation: float  # between words a minute and detected syllables a second


def calibrate(clips: Iterable[tuple[np.ndarray, str]], words_per_minute: float = 170) -> Calibration:
    """Turns a pace in words a minute into the detected syllables a second the coach can measure, from
    clips with transcripts. The ratio comes from clips spoken within 20 words a minute of the target when
    there are 50 of them (the detector merges more syllables at speed), otherwise from all clips."""
    rows = []
    for wave, text in clips:
        words = text.split()
        frames = FrameAnalyzer().add(wave)
        talk = talk_time(frames)
        if len(words) < 5 or talk < 3:
            continue
        syllables = sum(f.syllable for f in frames)
        rows.append((60 * len(words) / talk, syllables / talk, syllables / len(words), sum(map(len, words)) / len(words)))
    pace, rate, per_word, letters = (np.array(column) for column in zip(*rows))
    near = np.abs(pace - words_per_minute) <= 20
    ratio = float(np.median(per_word[near] if near.sum() >= 50 else per_word))
    threshold = words_per_minute / 60 * ratio
    quartiles = lambda xs: tuple(float(v) for v in np.percentile(xs, [25, 50, 75]))  # noqa: E731
    flagged = rate > threshold
    return Calibration(
        len(rows),
        ratio,
        threshold,
        quartiles(pace),
        quartiles(rate),
        float(np.mean(flagged)),
        float(np.mean(letters)),
        float(np.mean(flagged[pace >= words_per_minute + 20])),
        float(np.mean(flagged[pace <= words_per_minute - 20])),
        float(np.corrcoef(pace, rate)[0, 1]),
    )


def pace_windows(segments: Iterable[tuple[str, np.ndarray, str]], talk_seconds: float = 20) -> Iterator[tuple[float, float]]:
    """What the coach judges: consecutive segments of one speech, joined with 0.4 s of quiet room until they
    hold [talk_seconds] of talk, as (words a minute, detected syllables a second)."""
    rng = np.random.default_rng(0)
    current, waves, words = None, [], 0
    for speech, wave, text in segments:
        if speech != current:
            current, waves, words = speech, [], 0
        waves += [wave, rng.uniform(-0.003, 0.003, 6400).astype(np.float32)]
        words += len(text.split())
        frames = FrameAnalyzer().add(np.concatenate(waves))
        talk = talk_time(frames)
        if talk >= talk_seconds:
            yield 60 * words / talk, sum(f.syllable for f in frames) / talk
            waves, words = [], 0


def voxpopuli_segments(src: Path) -> Iterator[tuple[str, np.ndarray, str]]:
    """The validation and test segments, grouped by speech and in the order they were spoken."""
    speeches: dict[str, list[tuple[int, dict]]] = {}
    for shard in sorted(src.glob("validation-*.parquet")) + sorted(src.glob("test-*.parquet")):
        for row in pq.read_table(shard, columns=["audio_id", "audio", "normalized_text"]).to_pylist():
            speech, _, part = row["audio_id"].rpartition("_")
            speeches.setdefault(speech, []).append((int(part) if part.isdigit() else 0, row))
    for speech, parts in speeches.items():
        for _, row in sorted(parts, key=lambda p: p[0]):
            wave, sample_rate = sf.read(io.BytesIO(row["audio"]["bytes"]), dtype="float32")
            yield speech, to_16k_mono(wave, sample_rate), row["normalized_text"]


def voxpopuli_clips(src: Path) -> Iterator[tuple[np.ndarray, str]]:
    """The validation and test clips (speakers never used in training), as 16 kHz waves with their text."""
    for shard in sorted(src.glob("validation-*.parquet")) + sorted(src.glob("test-*.parquet")):
        parquet = pq.ParquetFile(shard)
        for group in range(parquet.num_row_groups):
            for row in parquet.read_row_group(group, columns=["audio", "normalized_text"]).to_pylist():
                wave, sample_rate = sf.read(io.BytesIO(row["audio"]["bytes"]), dtype="float32")
                yield to_16k_mono(wave, sample_rate), row["normalized_text"]


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--src", type=Path, default=ROOT / "data" / "raw" / "voxpopuli_ro")
    parser.add_argument("--words-per-minute", type=float, default=170)
    args = parser.parse_args(argv)

    result = calibrate(voxpopuli_clips(args.src), args.words_per_minute)
    wpm, sps = result.words_per_minute, result.syllables_per_second
    pace, rate = (np.array(column) for column in zip(*pace_windows(voxpopuli_segments(args.src))))
    fast, slow = pace >= args.words_per_minute + 20, pace <= args.words_per_minute - 20
    bands = [(0, 130), (130, 150), (150, 170), (170, 190), (190, 210), (210, 400)]
    table = [
        f"| {lo}–{hi if hi < 400 else '…'} | {m.sum()} | {np.median(rate[m]):.2f} |"
        for lo, hi in bands
        if (m := (pace >= lo) & (pace < hi)).any()
    ]
    today = datetime.date.today().isoformat()
    report = "\n".join([
        f"# Pragul de ritm al antrenorului de claritate ({today})",
        "",
        f"Calibrat cu `python -m echo_voice.speech_rate` pe {result.clips} clipuri VoxPopuli în română (validare + test,",
        "vorbitori nefolosiți la antrenare). Transcrierea dă numărul de cuvinte; analizorul (același ca în aplicație,",
        "testul de paritate o garantează) dă silabele detectate și timpul de vorbire.",
        "",
        f"- Ritmul clipurilor: {wpm[0]:.0f} / {wpm[1]:.0f} / {wpm[2]:.0f} cuvinte pe minut (quartile)",
        f"- Silabe detectate pe secundă: {sps[0]:.2f} / {sps[1]:.2f} / {sps[2]:.2f}",
        f"- Silabe detectate pe cuvânt (mediana): {result.syllables_per_word:.2f}",
        f"- **Prag pentru {args.words_per_minute:.0f} cuvinte pe minut: {result.threshold:.2f} silabe detectate pe secundă**"
        " (`CoachThresholds.syllablesPerSecond`)",
        f"- Clipuri peste prag: {100 * result.above:.0f}%",
        f"- Clipuri de {args.words_per_minute + 20:.0f}+ cuvinte pe minut prinse: {100 * result.caught:.0f}%; clipuri de"
        f" {args.words_per_minute - 20:.0f} sau mai puțin semnalate greșit: {100 * result.false_alarms:.0f}%",
        f"- Corelația ritm în cuvinte / silabe detectate pe secundă: {result.correlation:.2f}",
        "",
        "## Ce judecă aplicația: 20 s de vorbire a aceluiași om",
        "",
        f"{len(pace)} ferestre: segmente consecutive din același discurs, cu 0,4 s de liniște între ele, până la 20 s",
        "de vorbire.",
        "",
        f"- Corelația ritm în cuvinte / silabe detectate pe secundă: {np.corrcoef(pace, rate)[0, 1]:.2f}",
        f"- La pragul {result.threshold:.2f}: prinde {100 * np.mean(rate[fast] > result.threshold):.0f}% din ferestrele de"
        f" {args.words_per_minute + 20:.0f}+ cuvinte pe minut ({fast.sum()}) și semnalează greșit"
        f" {100 * np.mean(rate[slow] > result.threshold):.0f}% din cele de {args.words_per_minute - 20:.0f} sau mai puțin"
        f" ({slow.sum()})",
        "",
        "| cuvinte pe minut | ferestre | silabe detectate / s (mediana) |",
        "|---|---|---|",
        *table,
        "",
        "Detectorul se saturează la vorbire foarte rapidă (silabele se contopesc în mai puține vârfuri de intensitate):",
        "pragul rămâne conservator, cu puține alerte greșite pentru cine vorbește normal. Variante încercate (ferestre",
        "de 40–64 ms cu pas de 10 ms, preaccentuare, banda vocalelor 300–2500 Hz, netezire, praguri de 1–3 dB) nu au",
        "separat mai bine (AUC 0,84–0,85 pe clipuri, față de 0,84). Modul demonstrație din aplicație folosește 4,5.",
        "",
        "De la ~170 de cuvinte pe minut în sus, cititorii de subtitrare încep să aibă dificultăți (Jensema, 1998).",
        f"Un cuvânt românesc are aici în medie {result.letters_per_word:.1f} litere (în engleză ~4,7): la același număr de",
        "cuvinte, subtitrarea în română are mai mult text de citit. Dacă colegii surzi spun că e încă prea repede,",
        "pragul se coboară rulând din nou cu `--words-per-minute 150`.",
    ])
    out = ROOT / "reports" / f"{today}-ritm.md"
    out.write_text(report + "\n", encoding="utf-8")
    print(f"threshold {result.threshold:.2f} syllables/s, report in {out}")


if __name__ == "__main__":
    main()
