# Deciziile luate la implementarea meetingului fizic

Extrase din registrul de execuție al planului `docs/superpowers/plans/2026-10-22-meeting-fizic.md` (în engleză, cum au fost notate). Fiecare decizie are motivul și ce costă dacă e greșită.

## Decizii

- Setup: Ruling: feature branch `meeting-fizic` in this checkout instead of a git worktree — the team's dataset path (ml/voice/data/raw) and venvs live in this checkout; the branch keeps main untouched — cost if wrong: none, commits are isolated from main.
- Setup: Ruling: execution order 6, 10, 11, 1, 2, 3, 4, 5, 7, 8, 9, 12 — the user asked to start with training ("haide sa il antrenam"); 10 and 11 consume only Task 6 and the archive format fixed in Task 9's text — cost if wrong: none, tasks are independent in code.
- Setup: Ruling: steps that need the real dataset (Task 10 Step 5, Task 11 Step 5) wait for the team's manual download; code + tests are completed and the step is ledgered as pending — cost if wrong: training numbers arrive later.
- - T11→T7: Ruling: `ship` must write every key VoiceHead.fromJson reads (model, scale, bias, threshold, min_voiced_ms, enroll_min_voiced_ms, window_ms) — the plan lists only threshold/scale/bias for fit_head — cost if wrong: browser falls back to defaults silently.
- Task 6: Ruling: paused at Step 1 (torch download running) to run Task 1 meanwhile; Task 6 resumes with BASE = HEAD after Task 1 — no shared files — cost if wrong: none
- Task 6: Ruling: Python 3.14.2 (official CPython) + torch 2.11.0/torchaudio 2.11.0 from the cu130 index instead of cu128 — the default `python` is MSYS2 (no torch wheels), the driver supports CUDA 13.1, and torchaudio's last release is 2.11 — cost if wrong: none, README documents the install.
- Task 6: Ruling: scipy and pyarrow added as dependencies — the ReDimNet2 repo imports scipy; VoxPopuli ships as parquet — cost if wrong: two extra wheels.
- Task 6: Ruling: test fixtures from VoxPopuli RO (CC0, Romanian, two male speakers, cross-session) instead of LibriSpeech — the LibriSpeech dummy has one speaker, and Romanian clips test the real language — cost if wrong: none.
- Task 6: Ruling: VoxPopuli RO (facebook/voxpopuli `ro`, CC0, not gated, ~16 GB) becomes the default Romanian training source; TidyVoice / Common Voice stay optional additions — it needs no account, so training can start without the manual step — cost if wrong: parliament audio is cleaner than a meeting room; room simulation and test meetings cover that.
- Task 10: Ruling: added a `voxpopuli` source and dropped `tidyvoice` (format unknown until downloaded) and the unused `lang` parameter of prepare — VoxPopuli RO is the source we have; a TidyVoice adapter is a small addition when its files exist — cost if wrong: one adapter later.
- Task 10: Ruling: split_speakers takes `heldout_meetings` as a keyword (default ml/voice/heldout_meetings.txt) so the test can pin a file — cost if wrong: none.
- Task 10: Ruling: distance is simulated through the direct-to-reverberant ratio (about +10 dB at 1 m, -6 dB per doubling) rather than level, because ReDimNet2 normalizes the signal level itself — cost if wrong: weaker far-field augmentation.
- Task 10: Ruling: the evaluate CLI handles `--candidate base`; loading fine-tuned checkpoints arrives with Task 11, whose tests produce one — cost if wrong: none.
- Task 11: Ruling: ship's candidates are the base and every runs/*/best.pt; ReDimNet2+ is left out for now — it needs its own loader (separate repo, state_dict with `_orig_mod.` keys, log-mel front-end outside the checkpoint) — cost if wrong: one candidate fewer in the comparison; can be added as another Candidate.
- Task 11: Ruling: without held-out test meetings, ship calibrates and scores on Romanian speaker pairs and says so in the report ("proxy") — test meetings do not exist until Task 9 — cost if wrong: the first threshold is tuned to parliament audio, not the meeting room; rerun ship after test meetings.
- Task 11: Ruling: bf16 autocast instead of fp16 + GradScaler on the RTX 3050 — Ampere supports bf16 and it needs no loss scaling — cost if wrong: none.
- Task 11: Ruling: the AAM-softmax class weights start at each speaker's mean base embedding — avoids large early gradients into the pretrained backbone — cost if wrong: a minute of extra start-up.
- Task 11: Ruling: paused before Step 5 (VoxPopuli shard 5 still downloading); Task 2 runs meanwhile — no shared files — cost if wrong: none
- Task 3: Ruling: retry() checks right away over the lines since the question (then on new lines for 5 more minutes), instead of waiting for the next line as the brief's give-up case says — the participant presses it because they think the answer was already given — cost if wrong: one extra AI call per press.
- Task 4: Ruling: new ARB keys are named myQuestion* / answered* / roomQuestion (not askHint/askSend/...) — `askHint` already exists for „Întreabă meetingul” — cost if wrong: none.
- Task 4: Ruling: the answer card quotes the cited lines inline ("#3 text") instead of jumping the list to them — the lines are read directly (also by VoiceOver) and a lazy ListView cannot scroll reliably to an unbuilt item — cost if wrong: one tap less convenient for long meetings.
- Task 4: Ruling: a hand notify shows a short confirmation snack („Speakerul știe că vrei să întrebi”) — the participant gets feedback that the alert left — cost if wrong: none.
- Task 4: Ruling: questions from the room go to the AI in the spoken language (speech locale), the answer card is written in the interface language — matches who reads each — cost if wrong: none.
- Task 5: Ruling: speech synthesis through `dart:js_interop` directly instead of adding `package:web` — no new dependency, so pubspec.lock (resolved for Flutter 3.47 on the Mac) is not re-resolved here with 3.41 — cost if wrong: slightly more interop code.
- Task 5: Ruling: AppServices.tts defaults to createTtsService(), so main.dart needs no change — cost if wrong: none.
- Task 5: Ruling: if the laptop's voice fails, no `read` is sent and the speaker sees „Nu am putut citi întrebarea; citește-o tu”; „Am citit-o eu” stays available — cost if wrong: none.
- Task 5: Ruling: the manual Chrome check (Step 5) moves to Task 12's end-to-end check with the team — it needs a microphone, a second person and someone looking at two screens — cost if wrong: UI issues found later.
- Task 11: Ruling: training batch 6 instead of 24 — B6 needs ~0.72 GiB per 3 s clip; above 6 GiB Windows spills GPU memory into system RAM (first run OOM at 24) — cost if wrong: noisier gradients, more steps per epoch.
- Task 7: Ruling: the microphone buffer holds 30 s, not 15 s — enrollment reads ~20 s from it — cost if wrong: 1 MB of memory.
- Task 7: Ruling: only ort.webgpu.min.js + the asyncify wasm build (26.8 MB, also runs the WASM CPU fallback) are shipped, committed in app/web/voice/ort/ with onnxruntime-web 1.30.0 (2026-09-14) — the demo Mac gets everything from git — cost if wrong: repository grows by ~27 MB.
- Task 7: Ruling: AudioContext at 16 kHz lets Chrome resample the microphone, so the worklet only forwards chunks; capture runs without echo cancellation, noise suppression and gain control — call processing alters the voice the model hears — cost if wrong: noisier input in loud rooms.
- Task 7: Ruling: SpeakerLabeler keeps the clip it judged (lastClip) even under „Vorbesc eu”, for test meetings; nothing is judged before enrollment — cost if wrong: none.
- Task 8: Ruling: the learned voice is kept in AppSettings (`voiceEnrollment`, JSON list) rather than a separate SharedPreferences call — same storage, one place for saved state — cost if wrong: none.
- Task 8: Ruling: tests advance 21 s for the 20 s recording — the AnimationController completes on the first frame after its duration — cost if wrong: none (test timing only).
- Task 8: Ruling: Step 5 (two people, ten lines each, at 1–2 m) moves to Task 12's end-to-end check — it needs two people at the laptop — cost if wrong: labelling issues found later.
- Task 9: Ruling: the archive is a stored (uncompressed) zip written by our own ~60 lines with CRC-32, instead of adding the `archive` package — WAV barely compresses, and no new dependency keeps pubspec.lock as the Mac resolved it — cost if wrong: larger downloads (~32 KB per second of audio).
- Task 9: Ruling: turning on „Meeting de test” without an enrollment recording from this session asks the speaker to read the text again — the archive must start with the enrollment audio, and a saved voiceprint has no audio — cost if wrong: 20 s of reading.
- Task 9: Ruling: VoiceEngine gains play() for „Ascultă” in the review (AudioContext at 16 kHz in echo_voice.js) — the brief's review needs it — cost if wrong: none.
- Task 9: Ruling: stopping captioning no longer awaits the stream subscription's cancel() — it completes on the root zone, which never ran under widget-test fake time, so the stop path hung in tests; nothing depends on it — cost if wrong: none.
- Task 12: Ruling: Step 3 (end-to-end on laptop + iPhone with real voices) is left to the team, as a checklist in the final message — it needs people, microphones and the room — cost if wrong: integration issues surface at the rehearsal.
- Final: Ruling: Important 10 (unstable train/test split when speakers are added) deferred — the dataset has not changed since vp-ro-1 started and vp-ro-2-far uses the same 84 speakers; fix before adding Common Voice or other data — cost if wrong: a contaminated comparison after adding data.
- Final: Ruling: Important 11 (Python calibration not mirroring the page: raw vs voiced-only enrollment, short clips) deferred until test meetings exist — calibration runs on Romanian pairs now, which the page-mirroring does not change — cost if wrong: threshold slightly off until recalibrated.

## Observații minore amânate

- presenter page — the code is the large element, QR 220 px; join hint still says „introduc codul în aplicație”.
- retry() from „Trimisă” shows „Citită…” although nothing was read.
- „Reînvață vocea” stays available while captioning runs (enrollment text gets captioned).
- partial lines keep the pre-switch label after „Vorbesc eu” is turned off, until the next final.
- the answer card is a live region and also announced assertively (VoiceOver may say it twice).
- with „Ascultă și sala” on, the phone captions the laptop's synthetic voice as a room line.
- no way to cancel the question field once the hand was sent.
- no „skip enrollment” path; no progress indicator while enrollment embeddings are computed.
- evaluate --candidate X evaluates the base model but titles the report X.
- ml/voice README Mac install fails on the +cu130 pins in requirements.txt.
- root README.md not updated (Task 12 listed it).
- BatchNorm statistics train at batch size 6; consider freezing them.
- 51 MB speaker.onnx + 27 MB wasm in git, each ship adds 51 MB; consider Git LFS.
- check.html times fixed lengths only; real clips vary.
- download_web revokes the object URL right after click().
- find_questions parses JSON by hand instead of a Pydantic model.

## Reparații după recenzia finală

- answer said during an in-flight check never checked — "an answer said while a check runs is checked after the speaker pauses" RED→GREEN
- any error stopping the answer search for good (only 503 stops now; 20 s timeout; retry resets a hung check; last 200 lines) — four tests RED→GREEN; room questions time out after 20 s to the local rule — RED→GREEN
- answer card hiding the live captions on small iPhones (card ≤25% and bottom bar ≤30% of the space left, quick messages hidden while typing, pinned line hidden under 220 px, close button in the card header) — 'on a small iPhone the answer card leaves room for the live captions' RED→GREEN, suite 111/111
- read-aloud hang (time limit 5 s + 120 ms/char, try/finally restart, utterance kept alive, cancel before speaking) — "a voice that never finishes gives up…" RED→GREEN
- first line after read-aloud judged on the synthetic voice (window restarts when the voice ends and when captioning starts) — "after the laptop reads a question…" RED→GREEN
- unserialized labelling, shared lastClip/lastScore and dropped lines on model errors (judgeFinal returns its own judgement, queued; errors keep the previous label) — two labeller tests RED→GREEN
- silence guards fooled by room noise (noise floor = quietest fifth + 12 dB; voiced-frame count for the short-line check) — two noise tests RED→GREEN
- saved voiceprint not tied to the model (saved as {model, vector}; another model's voice is learned again) — 'a voice learned with an older model is learned again' RED→GREEN, suite 122/122
- the phone confirming a hand it could not deliver („Vreau să întreb” off with the reason while the speaker's laptop is not connected; the snack now says „trimis”, and the presenter's seen shows „Speakerul a văzut că vrei să întrebi”) — two tests RED→GREEN, suite 124/124
