"""Pick the speaker model that goes into the app, calibrate it, export it and write a report.

Candidates: the pretrained base and every fine-tuned run in runs/*/best.pt. The winner labels at least 95% of
the speaker's lines "Speaker" on held-out data and, among those, rejects the most room lines (then lowest EER).

Usage: python -m echo_voice.ship [--speakers data/speakers] [--meetings data/meetings]
"""

import argparse
import datetime
import json
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import soundfile as sf
import torch

from echo_voice.calibrate import fit_head
from echo_voice.data import DEFAULT_HELDOUT, meeting_dirs, split_speakers
from echo_voice.evaluate import (
    MAX_CLIP_SECONDS,
    ROOT,
    ScoreFn,
    eer,
    far_version,
    make_score_fn,
    speaker_probability,
    speaker_trials,
)
from echo_voice.export import export_onnx, write_parity_fixture
from echo_voice.model import SAMPLE_RATE, embed, load_base, load_candidate

MIN_SPEAKER_HIT = 0.95
MIN_ROOM_REJECT = 0.85
# Read by the presenter page (app/lib/core/voice/voice_head.dart).
PAGE_SETTINGS = {"min_voiced_ms": 500, "enroll_min_voiced_ms": 10000, "window_ms": 3000}
APP_VOICE = ROOT.parent.parent / "app" / "web" / "voice"
BASE_ID = "redimnet2-b6-vb2+vox2_v0-lm"


@dataclass
class Candidate:
    name: str
    model_id: str
    pair_score: Callable[[Path, Path], float]
    score: ScoreFn
    export: Callable[[Path], None]


def _meeting_scores(score: ScoreFn, folder: Path) -> tuple[list[float], list[float]]:
    labels = json.loads((folder / "labels.json").read_text(encoding="utf-8"))
    enrollment, _ = sf.read(folder / labels["enrollment"], dtype="float32")
    speaker, room = [], []
    for line in labels["lines"]:
        clip, _ = sf.read(folder / line["file"], dtype="float32")
        (speaker if line["label"] == "coordinator" else room).append(score(enrollment, clip))
    return speaker, room


def _rates(head: dict, speaker: np.ndarray, room: np.ndarray) -> tuple[float, float]:
    accepted = [speaker_probability(c, head) >= head["threshold"] for c in speaker]
    rejected = [speaker_probability(c, head) < head["threshold"] for c in room]
    return float(np.mean(accepted)) if accepted else float("nan"), float(np.mean(rejected)) if rejected else float("nan")


def evaluate_candidate(
    candidate: Candidate, speakers: Path, meetings: Path, heldout_meetings: Path, n_trials: int
) -> dict:
    _, test = split_speakers(speakers, heldout_meetings=heldout_meetings)
    trials = speaker_trials(speakers, [s for s in test if not s.startswith("meeting-")], n_trials)
    pair = np.array([candidate.pair_score(a, b) for a, b, _ in trials])
    same = np.array([s for _, _, s in trials])

    held_out = set()
    if heldout_meetings.exists():
        held_out = {line.strip() for line in heldout_meetings.read_text(encoding="utf-8").splitlines() if line.strip()}
    folders = meeting_dirs(meetings) if meetings.exists() else []
    calibration = [f for f in folders if f.name not in held_out]
    evaluation = [f for f in folders if f.name in held_out]

    speaker_cal, room_cal = [], []
    for folder in calibration:
        s, r = _meeting_scores(candidate.score, folder)
        speaker_cal += s
        room_cal += r
    head = fit_head(pair[same], pair[~same], np.array(speaker_cal), np.array(room_cal))

    per_meeting = []
    for folder in evaluation:
        s, r = _meeting_scores(candidate.score, folder)
        hit, reject = _rates(head, np.array(s), np.array(r))
        per_meeting.append({"meeting": folder.name, "speaker_hit": hit, "room_reject": reject, "n": (len(s), len(r))})
    if per_meeting:
        hit = float(np.nanmean([m["speaker_hit"] for m in per_meeting]))
        reject = float(np.nanmean([m["room_reject"] for m in per_meeting]))
    else:
        # No held-out meeting yet: Romanian speaker pairs stand in for "speaker" and "room" lines.
        hit, reject = _rates(head, pair[same], pair[~same])
    return {
        "candidate": candidate,
        "eer": eer(pair, same),
        "speaker_hit": hit,
        "room_reject": reject,
        "head": head,
        "per_meeting": per_meeting,
    }


def choose(results: list[dict]) -> dict:
    good = [r for r in results if r["speaker_hit"] >= MIN_SPEAKER_HIT]
    if good:
        return min(good, key=lambda r: (-r["room_reject"], r["eer"]))
    return min(results, key=lambda r: (-r["speaker_hit"], r["eer"]))


def _report(results: list[dict], winner: dict, proxy: bool) -> str:
    rows = [
        f"# Alegerea modelului de voce ({datetime.date.today().isoformat()})",
        "",
        "Cifre pe perechi de vorbitori din română (fără meetinguri de test ținute deoparte)."
        if proxy
        else "Cifre pe meetingurile de test ținute deoparte.",
        "",
        "| Candidat | EER | Speaker → „Speaker” | Sală → „Din sală” | Prag |",
        "|---|---|---|---|---|",
    ]
    for r in results:
        rows.append(
            f"| {r['candidate'].name} | {100 * r['eer']:.2f}% | {100 * r['speaker_hit']:.1f}% "
            f"| {100 * r['room_reject']:.1f}% | {r['head']['threshold']:.3f} |"
        )
    rows += ["", f"**Câștigător: {winner['candidate'].name}** (`{winner['candidate'].model_id}`)"]
    for m in winner["per_meeting"]:
        if m["speaker_hit"] < MIN_SPEAKER_HIT or m["room_reject"] < MIN_ROOM_REJECT:
            rows.append(f"- sub criteriu: {m['meeting']} ({100 * m['speaker_hit']:.0f}% / {100 * m['room_reject']:.0f}%)")
    return "\n".join(rows) + "\n"


def ship(
    candidates: list[Candidate],
    speakers: Path,
    meetings: Path,
    app_voice: Path,
    reports: Path,
    n_trials: int = 4000,
    heldout_meetings: Path = DEFAULT_HELDOUT,
) -> str:
    results = [evaluate_candidate(c, speakers, meetings, heldout_meetings, n_trials) for c in candidates]
    winner = choose(results)
    winner["candidate"].export(app_voice / "speaker.onnx")
    head = {"model": winner["candidate"].model_id, **winner["head"], **PAGE_SETTINGS}
    (app_voice / "voice_head.json").write_text(json.dumps(head, indent=2) + "\n", encoding="utf-8")
    reports.mkdir(parents=True, exist_ok=True)
    report = reports / f"{datetime.date.today().isoformat()}-ship.md"
    report.write_text(_report(results, winner, proxy=not winner["per_meeting"]), encoding="utf-8")
    return winner["candidate"].name


def model_candidate(name: str, model_id: str, model: torch.nn.Module, far: bool = True) -> Candidate:
    """Pairs compare a clean clip (standing for enrollment) with one heard 5–10 m away, unless not [far]."""
    vectors: dict[tuple[Path, bool], np.ndarray] = {}

    def vector(path: Path, distant: bool = False) -> np.ndarray:
        if (path, distant) not in vectors:
            wave, _ = sf.read(path, dtype="float32")
            wave = wave[: MAX_CLIP_SECONDS * SAMPLE_RATE]
            vectors[(path, distant)] = embed(model, far_version(path, wave) if distant else wave)
        return vectors[(path, distant)]

    def export(path: Path) -> None:
        export_onnx(model, path)
        write_parity_fixture(path)

    return Candidate(name, model_id, lambda a, b: float(vector(a) @ vector(b, far)), make_score_fn(model), export)


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--speakers", type=Path, default=ROOT / "data" / "speakers")
    parser.add_argument("--meetings", type=Path, default=ROOT / "data" / "meetings")
    parser.add_argument("--trials", type=int, default=4000)
    parser.add_argument("--clean", action="store_true", help="compare on clean pairs instead of 5–10 m away")
    args = parser.parse_args(argv)

    device = "cuda" if torch.cuda.is_available() else "cpu"
    far = not args.clean
    candidates = [model_candidate("base", BASE_ID, load_base().to(device), far)]
    for run in sorted((ROOT / "runs").glob("*/best.pt")):
        model = load_candidate(str(run)).to(device)
        candidates.append(model_candidate(run.parent.name, f"{BASE_ID}+{run.parent.name}", model, far))
    winner = ship(candidates, args.speakers, args.meetings, APP_VOICE, ROOT / "reports", args.trials)
    print(f"winner: {winner}")
    print((ROOT / "reports" / f"{datetime.date.today().isoformat()}-ship.md").read_text(encoding="utf-8"))


if __name__ == "__main__":
    main()
