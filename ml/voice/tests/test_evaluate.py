import numpy as np
import pytest

from echo_voice.evaluate import eer, meeting_report
from tests.helpers import SR, write_meeting


def test_eer_perfect_and_random():
    same = np.array([True, True, False, False])
    assert eer(np.array([0.9, 0.8, 0.1, 0.2]), same) == 0.0
    assert eer(np.array([0.5, 0.5, 0.5, 0.5]), same) == pytest.approx(0.5)


def test_eer_with_overlap():
    scores = np.array([0.9, 0.8, 0.4, 0.5, 0.3, 0.2])
    same = np.array([True, True, True, False, False, False])
    # Between 0.4 and 0.5 one same-speaker pair is rejected and one other-speaker pair accepted.
    assert eer(scores, same) == pytest.approx(1 / 3)


def test_meeting_report_counts(tmp_path):
    # Clip lengths stand in for voices: the fake scorer maps each length to a cosine.
    speaker = [("coordinator", 2.0), ("coordinator", 2.1), ("coordinator", 2.2), ("coordinator", 2.3)]
    room = [("public", 2.4), ("public", 2.5)]
    folder = write_meeting(tmp_path / "m1", speaker + room)
    cosine_by_length = {
        int(2.0 * SR): 0.6,
        int(2.1 * SR): 0.5,
        int(2.2 * SR): 0.4,
        int(2.3 * SR): 0.2,  # missed: the speaker labelled as room
        int(2.4 * SR): 0.1,
        int(2.5 * SR): 0.5,  # missed: someone in the room labelled as the speaker
    }
    head = {"scale": 20.0, "bias": -7.0, "threshold": 0.5}  # speaker when cosine >= 0.35

    report = meeting_report(lambda enrollment, clip: cosine_by_length[len(clip)], folder, head)

    assert report == {"speaker_hit": 0.75, "room_reject": 0.5, "n_speaker": 4, "n_room": 2}
