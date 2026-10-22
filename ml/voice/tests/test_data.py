import csv
import io
import shutil

import pyarrow as pa
import pyarrow.parquet as pq
import pytest
import soundfile as sf

from echo_voice.data import prepare, split_speakers
from tests.helpers import SR, tone, write_meeting


def wav_bytes(wave) -> bytes:
    buffer = io.BytesIO()
    sf.write(buffer, wave, SR, format="WAV")
    return buffer.getvalue()


def test_prepare_voxpopuli_groups_by_speaker_id(tmp_path):
    src = tmp_path / "voxpopuli"
    src.mkdir()
    rows = [
        ("20160525-ro_16:38:35_1", "11", tone(2)),
        ("20160525-ro_16:38:35_2", "11", tone(3)),
        ("20171113-ro_23:03:42_3", "22", tone(2)),
        ("20171113-ro_23:03:42_4", "22", tone(1.0)),  # too short to learn a voice from
        ("20171113-ro_23:03:42_5", None, tone(2)),  # unknown speaker
    ]
    table = pa.table(
        {
            "audio_id": [r[0] for r in rows],
            "audio": [{"bytes": wav_bytes(r[2]), "path": None} for r in rows],
            "speaker_id": [r[1] for r in rows],
        }
    )
    pq.write_table(table, src / "train-00000-of-00001.parquet")

    out = tmp_path / "speakers"
    assert prepare("voxpopuli", src, out) == 2
    assert sorted(p.name for p in out.iterdir()) == ["vp-11", "vp-22"]
    assert len(list((out / "vp-11").glob("*.wav"))) == 2
    assert len(list((out / "vp-22").glob("*.wav"))) == 1


def test_prepare_common_voice_groups_by_client_id(tmp_path):
    src = tmp_path / "cv"
    (src / "clips").mkdir(parents=True)
    rows = [("a" * 128, "one.wav"), ("a" * 128, "two.wav"), ("b" * 128, "three.wav")]
    for _, name in rows:
        sf.write(src / "clips" / name, tone(2, sr=48000), 48000)
    with open(src / "validated.tsv", "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter="\t")
        writer.writerow(["client_id", "path", "sentence"])
        for client_id, name in rows:
            writer.writerow([client_id, name, "text"])

    out = tmp_path / "speakers"
    assert prepare("common_voice", src, out) == 2
    files = sorted(out.glob("*/*.wav"))
    assert len(files) == 3
    wave, sr = sf.read(files[0])
    assert sr == 16000
    assert abs(len(wave) - 2 * 16000) <= 1


@pytest.mark.parametrize("zipped", [False, True])
def test_prepare_meetings_splits_speaker_and_room(tmp_path, zipped):
    meetings = tmp_path / "meetings"
    name = "echo-test-meeting-20261022-1700"
    folder = write_meeting(meetings / name, [("coordinator", 2), ("public", 2), ("coordinator", 3)])
    if zipped:
        shutil.make_archive(str(meetings / name), "zip", folder)
        shutil.rmtree(folder)

    out = tmp_path / "speakers"
    assert prepare("meetings", meetings, out) == 1
    speaker = out / f"meeting-{name}-speaker"
    assert len(list(speaker.glob("*.wav"))) == 3  # enrollment + the two coordinator clips
    assert len(list((out / "_room" / name).glob("*.wav"))) == 1


def test_split_is_deterministic_and_disjoint(tmp_path):
    for name in [f"vp-{i}" for i in range(20)] + ["meeting-a-speaker", "meeting-b-speaker", "_room"]:
        (tmp_path / name).mkdir()
    heldout = tmp_path / "heldout_meetings.txt"
    heldout.write_text("b\n")

    train, test = split_speakers(tmp_path, held_out=0.1, seed=0, heldout_meetings=heldout)

    assert (train, test) == split_speakers(tmp_path, held_out=0.1, seed=0, heldout_meetings=heldout)
    assert not set(train) & set(test)
    assert "_room" not in train + test
    assert "meeting-b-speaker" in test
    assert "meeting-a-speaker" in train
    assert len(train) + len(test) == 22
    assert len([s for s in test if s.startswith("vp-")]) == 2
