"""Turn downloaded speech datasets and test-meeting archives into `<speaker>/<clip>.wav` folders.

Usage: python -m echo_voice.data --source voxpopuli|common_voice|meetings --src <folder> --out data/speakers
"""

import argparse
import csv
import io
import json
import re
import zipfile
from pathlib import Path

import numpy as np
import pyarrow.parquet as pq
import soundfile as sf
import torch
import torchaudio

from echo_voice.model import SAMPLE_RATE

# Shorter clips say too little about a voice to train on.
MIN_SECONDS = 1.5
# Clips said by someone in the room during a test meeting: identity unknown, used only to evaluate and calibrate.
ROOM_DIR = "_room"
DEFAULT_HELDOUT = Path(__file__).resolve().parent.parent / "heldout_meetings.txt"


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]", "_", name)


def to_16k_mono(wave: np.ndarray, sample_rate: int) -> np.ndarray:
    wave = np.asarray(wave, dtype=np.float32)
    if wave.ndim == 2:
        wave = wave.mean(axis=1)
    if sample_rate != SAMPLE_RATE:
        wave = torchaudio.functional.resample(torch.from_numpy(wave), sample_rate, SAMPLE_RATE).numpy()
    return wave


def write_clip(folder: Path, name: str, wave: np.ndarray) -> None:
    folder.mkdir(parents=True, exist_ok=True)
    sf.write(folder / f"{safe_name(name)}.wav", wave, SAMPLE_RATE, subtype="PCM_16")


def long_enough(wave: np.ndarray) -> bool:
    return wave.size >= MIN_SECONDS * SAMPLE_RATE


def _voxpopuli(src: Path, out: Path) -> set[str]:
    speakers = set()
    for shard in sorted(src.glob("*.parquet")):
        parquet = pq.ParquetFile(shard)
        for group in range(parquet.num_row_groups):
            rows = parquet.read_row_group(group, columns=["audio_id", "audio", "speaker_id"]).to_pylist()
            for row in rows:
                if not row["speaker_id"] or row["speaker_id"] == "None":
                    continue
                folder = f"vp-{safe_name(row['speaker_id'])}"
                if (out / folder / f"{safe_name(row['audio_id'])}.wav").exists():
                    speakers.add(folder)  # already converted by an earlier run
                    continue
                wave = to_16k_mono(*sf.read(io.BytesIO(row["audio"]["bytes"]), dtype="float32"))
                if long_enough(wave):
                    write_clip(out / folder, row["audio_id"], wave)
                    speakers.add(folder)
    return speakers


def _common_voice(src: Path, out: Path) -> set[str]:
    speakers = set()
    with open(src / "validated.tsv", newline="", encoding="utf-8") as tsv:
        for row in csv.DictReader(tsv, delimiter="\t", quoting=csv.QUOTE_NONE):
            # client_id is 128 hex characters; a prefix keeps paths under the Windows limit.
            folder = f"cv-{row['client_id'][:16]}"
            wave = to_16k_mono(*sf.read(src / "clips" / row["path"], dtype="float32"))
            if long_enough(wave):
                write_clip(out / folder, Path(row["path"]).stem, wave)
                speakers.add(folder)
    return speakers


def meeting_dirs(src: Path) -> list[Path]:
    """Test-meeting archive folders under src; a downloaded .zip is unpacked next to itself once."""
    for archive in sorted(src.glob("*.zip")):
        target = archive.with_suffix("")
        if not target.exists():
            with zipfile.ZipFile(archive) as z:
                z.extractall(target)
    return sorted(labels.parent for labels in src.glob("*/labels.json"))


def _meetings(src: Path, out: Path) -> set[str]:
    speakers = set()
    for folder in meeting_dirs(src):
        labels = json.loads((folder / "labels.json").read_text(encoding="utf-8"))
        speaker = f"meeting-{folder.name}-speaker"
        write_clip(out / speaker, "enrollment", to_16k_mono(*sf.read(folder / labels["enrollment"], dtype="float32")))
        for line in labels["lines"]:
            wave = to_16k_mono(*sf.read(folder / line["file"], dtype="float32"))
            target = out / speaker if line["label"] == "coordinator" else out / ROOM_DIR / folder.name
            write_clip(target, Path(line["file"]).stem, wave)
        speakers.add(speaker)
    return speakers


SOURCES = {"voxpopuli": _voxpopuli, "common_voice": _common_voice, "meetings": _meetings}


def prepare(source: str, src: Path, out: Path) -> int:
    """Writes 16 kHz mono clips grouped by speaker; returns how many speakers were written."""
    if source not in SOURCES:
        raise ValueError(f"unknown source {source!r}; expected one of {sorted(SOURCES)}")
    return len(SOURCES[source](Path(src), Path(out)))


def split_speakers(
    root: Path, held_out: float = 0.1, seed: int = 0, heldout_meetings: Path | None = DEFAULT_HELDOUT
) -> tuple[list[str], list[str]]:
    """Deterministic train / test split by speaker. Meetings named in heldout_meetings always go to test."""
    names = sorted(p.name for p in Path(root).iterdir() if p.is_dir() and not p.name.startswith("_"))
    pinned = set()
    if heldout_meetings is not None and heldout_meetings.exists():
        lines = heldout_meetings.read_text(encoding="utf-8").splitlines()
        pinned = {f"meeting-{line.strip()}-speaker" for line in lines if line.strip()}
    meetings = [n for n in names if n.startswith("meeting-")]
    others = [n for n in names if not n.startswith("meeting-")]
    order = [others[i] for i in np.random.default_rng(seed).permutation(len(others))]
    n_test = round(held_out * len(others))
    test = sorted(order[:n_test]) + [m for m in meetings if m in pinned]
    train = sorted(order[n_test:]) + [m for m in meetings if m not in pinned]
    return train, test


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", required=True, choices=sorted(SOURCES))
    parser.add_argument("--src", type=Path, required=True)
    parser.add_argument("--out", type=Path, default=Path("data/speakers"))
    args = parser.parse_args(argv)
    print(f"{prepare(args.source, args.src, args.out)} speakers in {args.out}")


if __name__ == "__main__":
    main()
