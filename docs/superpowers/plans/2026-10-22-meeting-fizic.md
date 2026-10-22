# Meeting fizic: vocea speakerului, întrebări și „Ți s-a răspuns” — plan de implementare

> **Pentru agenți:** SUB-SKILL OBLIGATORIU: superpowers:subagent-driven-development (recomandat) sau superpowers:executing-plans, task cu task. Pașii au căsuțe (`- [ ]`).

**Scop:** în meetingul fizic, laptopul speakerului ascultă sala, recunoaște vocea speakerului cu un model antrenat de noi și etichetează replicile; persoana surdă pune întrebări din telefon și vede automat răspunsul.

**Arhitectură:** pagina prezentatorului (Flutter web, Chrome) face transcrierea (Web Speech) și, în paralel, amprenta vocii pentru fiecare replică (ReDimNet2 în `onnxruntime-web`, prin `dart:js_interop`). Telefonul păstrează transcrierea și cere serverului (FastAPI + Claude) „e întrebare?” și „s-a răspuns?”. `ml/voice/` (Python + PyTorch, pe RTX 3050) face fine-tuning, calibrare, evaluare și exportul modelului în `app/web/voice/`.

**Stack:** Flutter 3.41+ / Dart, `package:web`, `archive`; Python 3.12, FastAPI, `anthropic`; PyTorch + CUDA, `onnx`, `onnxruntime`; `onnxruntime-web` (WebGPU, altfel WASM).

**Spec:** `docs/superpowers/specs/2026-10-22-meeting-fizic-design.md`. Reguli: `CLAUDE.md`.

## Global Constraints

- Orice text vizibil intră în `app/lib/l10n/app_ro.arb` **și** `app_en.arb`, apoi `cd app && flutter gen-l10n`.
- Rolul nu se transmite doar prin culoare: iconiță + etichetă text + poziție. Ținte de atingere ≥ 48 px, `Semantics` pe tot ce e nou, fără înălțimi fixe care taie textul.
- Audio nu ajunge pe server. Prin rețea circulă doar text. Amprenta vocii se calculează în browser.
- AI: `claude-opus-5-5`, `fallbacks: "default"` (antet `server-side-fallback-2026-07-01`), efort `low` pentru `answer-check` și `questions`; ieșire structurată; `stop_reason == "refusal"` → `AIRefused`. Testele folosesc `FakeAnthropic`, niciodată API-ul real.
- Eticheta replicii: `coordinator` = speakerul (afișat „Speaker”), `public` = din sală (afișat „Din sală”).
- „Ți s-a răspuns”: mai bine niciun card decât unul greșit. Fără cheie API nu există euristică pentru răspuns.
- Datele audio (seturi de date, meetinguri de test) nu intră în git: `ml/voice/data/` e ignorat.
- Commit-uri ca `selimayann`, fără `Co-Authored-By` sau altă atribuire Claude. Nu se face push fără cererea echipei.
- Înainte de fiecare commit: `cd app && flutter analyze && flutter test`; `cd server && .venv/Scripts/python -m pytest`; `cd ml/voice && .venv/Scripts/python -m pytest` (pe Mac: `.venv/bin/`).

## Review Focus

1. **Replici foarte scurte** („da”, „ok”, sub 1 s de vorbire): amprenta e nesigură → replica păstrează eticheta replicii finale anterioare. Test în Task 7.
2. **Vocea sintetizată citește întrebarea**: transcrierea e oprită cât vorbește și repornește și dacă vocea dă eroare. Test în Task 5.
3. **`read` nu ajunge niciodată** (telefonul s-a reconectat, speakerul n-a apăsat): „Caută răspunsul” e disponibil și din starea „Trimisă” și caută în replicile de după trimitere. Test în Task 3.
4. **Server fără cheie API (503)**: întrebările din sală trec pe euristica locală; verificarea răspunsului se oprește în tăcere, întrebarea rămâne „Citită”, nimic nu crapă. Teste în Task 3.
5. **Enrollment cu prea puțină vorbire** (sub 10 s de voce în cele ~20 s): enrollment-ul e respins și speakerul e rugat să repete. Test în Task 7.

## Pas manual (echipa, o singură dată, înainte de Task 10)

- [ ] Pe https://datacollective.mozillafoundation.org: cont, apoi descărcați **TidyVoice** (sau, dacă TidyVoice nu are română, **Common Voice – Romanian**), acceptând termenii (folosire doar pentru verificarea vorbitorului). Dezarhivați în `ml/voice/data/raw/tidyvoice/` (respectiv `ml/voice/data/raw/common_voice_ro/`).

---

### Task 1: Server — mesajele `hand` / `read` și cele două endpointuri AI

**Files:**
- Modify: `server/app/protocol.py`, `server/app/schemas.py`, `server/app/ai.py`, `server/app/main.py`
- Test: `server/tests/test_realtime.py`, `server/tests/test_ai.py`

**Interfaces:**
- Produces (WebSocket): `notify.kind` acceptă `"hand"` (text poate fi gol); mesaj nou `{"type":"read","id":str≤64,"by":"voice"|"speaker"}`, permis doar prezentatorului (`ALLOWED["presenter"] = {"caption","seen","read"}`).
- Produces (REST):
  - `POST /api/ai/answer-check` `AnswerCheckRequest{lang, question: str 1..500, lines: list[Line] 1..200}` → `AnswerCheckResponse{answered: bool, answer: str, line_ids: list[int]}`
  - `POST /api/ai/questions` `QuestionsRequest{lang, lines: list[Line] 1..20}` → `QuestionsResponse{question_ids: list[int]}`
- Produces (Python): `ai.check_answer(client, lang: str, question: str, lines: list[Line]) -> AnswerCheckResponse`, `ai.find_questions(client, lang: str, lines: list[Line]) -> list[int]`

- [ ] **Step 1: Teste care pică** în `server/tests/test_realtime.py`:
  - `test_presenter_can_send_read`: participantul primește `{"type":"read","id":"q1","by":"voice"}` trimis de prezentator.
  - `test_participant_cannot_send_read`: participantul trimite `read` → primește `{"type":"error","message":"participant cannot send read"}`.
  - `test_hand_notify_with_empty_text_is_relayed`: `notify` cu `kind="hand"`, `text=""` ajunge la prezentator.
- [ ] **Step 2: Teste care pică** în `server/tests/test_ai.py`:
  - `test_check_answer_uses_low_effort_and_schema`: `FakeAnthropic(json_response({"answered": True, "answer": "Vineri.", "line_ids": [3]}))`; rezultatul are `answered is True`, `line_ids == [3]`; apelul are `output_config["effort"] == "low"`, `output_config["format"]["type"] == "json_schema"`, întrebarea apare în `messages[0]["content"]`, iar `"[#3] Coordinator:"` apare în același mesaj.
  - `test_check_answer_drops_unknown_line_ids`: modelul întoarce `line_ids: [3, 99]` pentru linii cu id-urile 2 și 3 → `[3]`.
  - `test_find_questions_returns_ids_in_request`: modelul întoarce `{"question_ids": [2, 7]}` pentru liniile 1–2 → `[2]`.
  - `test_answer_check_endpoint_503_without_key` și `test_questions_endpoint_503_without_key`.
  - `test_answer_check_refusal_maps_to_422`.
- [ ] **Step 3: Rulează** `cd server && .venv/Scripts/python -m pytest -q` → testele noi pică (`AttributeError` / 422 / 404).
- [ ] **Step 4: Implementează.** `protocol.py`: `"hand"` în `Notify.kind`, clasa `Read`, `ClientMessage` include `Read`. `schemas.py`: cele patru modele de mai sus. `ai.py`: `check_answer` și `find_questions` cu `create(...)`, `max_tokens=4000`, `output_config={"effort": "low", "format": {"type": "json_schema", "schema": ...}}`, transcriptul randat cu `render_transcript`. Promptul `check_answer` spune: liniile sunt tot ce s-a spus după ce persoana surdă a trimis întrebarea; speakerul poate citi întâi întrebarea cu voce tare, asta nu e răspuns; `answered` e `true` doar dacă speakerul a răspuns chiar la întrebarea asta („revin mai târziu”, „nu știu” contează ca răspuns, iar `answer` spune asta); `answer` e o frază scurtă în limba cerută; `line_ids` sunt replicile din care vine răspunsul. Promptul `find_questions`: întoarce id-urile replicilor care sunt întrebări adresate cuiva din sală (transcrierea poate lipsi de semne de punctuație). Ambele filtrează id-urile la cele din cerere. `main.py`: cele două rute, prin `call_ai(...)` și `require_ai()`.
- [ ] **Step 5: Rulează** `cd server && .venv/Scripts/python -m pytest -q` → totul trece.
- [ ] **Step 6: Commit** `git add server && git commit -m "Add hand/read messages and answer-check/questions AI endpoints"`

---

### Task 2: Aplicația — protocol și ServerApi

**Files:**
- Modify: `app/lib/core/protocol.dart`, `app/lib/core/server_api.dart`
- Test: `app/test/core/transcript_and_protocol_test.dart`, Create: `app/test/core/server_api_test.dart`

**Interfaces:**
- Consumes: mesajele și rutele din Task 1.
- Produces:
  - `enum NotifyKind { question, repeat, slower, custom, hand }`
  - `enum ReadBy { voice, speaker }`; `class ReadMessage { const ReadMessage({required String id, required ReadBy by}); Map<String, Object> toJson(); }` (`{'type':'read','id':…,'by':…}`)
  - `class ReadReceived extends ServerEvent { final String id; final ReadBy by; }`
  - `class AnswerCheck { const AnswerCheck({required bool answered, required String answer, required List<int> lineIds}); }`
  - `ServerApi.checkAnswer(String lang, String question, List<TranscriptLine> lines) -> Future<AnswerCheck>`
  - `ServerApi.findQuestions(String lang, List<TranscriptLine> lines) -> Future<List<int>>`

- [ ] **Step 1: Teste care pică:** `read_message_round_trips` (`ServerEvent.fromJson({'type':'read','id':'q1','by':'speaker'})` e `ReadReceived` cu `by == ReadBy.speaker`; `ReadMessage(...).toJson()` are exact cheile de mai sus); `hand_notify_parses` (`kind: 'hand'`, `text: ''`). În `server_api_test.dart`, cu `MockClient` din `package:http/testing.dart`: `checkAnswer_posts_question_and_lines` (corpul cererii are `question` și `lines`; răspunsul `{"answered":true,"answer":"Vineri.","line_ids":[3]}` devine `AnswerCheck(lineIds: [3])`); `findQuestions_parses_ids`; `checkAnswer_throws_ApiException_on_503`.
- [ ] **Step 2: Rulează** `cd app && flutter test test/core` → pică la compilare.
- [ ] **Step 3: Implementează** în cele două fișiere, după modelul `Notify` / `ask` existent.
- [ ] **Step 4: Rulează** `cd app && flutter test test/core` → trece.
- [ ] **Step 5: Commit** `git commit -am "Add read message, hand notify and AI checks to the app client"` (plus fișierul de test nou cu `git add`).

---

### Task 3: Telefonul — logica întrebării proprii și a întrebărilor din sală

**Files:**
- Create: `app/lib/features/participant/my_question.dart`, `app/lib/features/participant/room_questions.dart`
- Test: Create `app/test/features/my_question_test.dart`, `app/test/features/room_questions_test.dart`

**Interfaces:**
- Consumes: `Transcript`, `TranscriptLine`, `AnswerCheck`, `ApiException` (Task 2).
- Produces:
  - `typedef AnswerChecker = Future<AnswerCheck> Function(String question, List<TranscriptLine> lines);`
  - `enum MyQuestionState { sent, read, answered, notFound }`
  - `class MyQuestion extends ChangeNotifier { MyQuestion({required Transcript transcript, required AnswerChecker check, Duration settle = const Duration(seconds: 3), Duration giveUp = const Duration(minutes: 5)}); String? get id; String? get text; MyQuestionState? get state; AnswerCheck? get result; void asked(String id, String text); void markRead(String id); void retry(); void dismiss(); }`
  - `typedef QuestionFinder = Future<List<int>> Function(List<TranscriptLine> lines);`
  - `class RoomQuestions extends ChangeNotifier { RoomQuestions({required Transcript transcript, required QuestionFinder find, required String lang}); bool isQuestion(String captionId); }`
  - `bool looksLikeQuestion(String text, String lang)` (top-level)

- [ ] **Step 1: Teste care pică** (`fake_async`, `Transcript` real, checker fals care înregistrează apelurile):
  - `only_lines_after_the_question_are_checked`: 2 replici finale, `asked`, apoi `markRead`, apoi 1 replică `coordinator` finală; după 3 s checker-ul primește exact acea linie (numerotată 3).
  - `waits_for_the_speaker_to_pause`: replici la 0 s și 2 s → un singur apel, la 5 s.
  - `one_call_in_flight`: checker-ul răspunde după 10 s; replici noi între timp nu pornesc alt apel; după răspuns `answered:false` se reîncearcă la următoarea replică.
  - `answered_stops_checking`: răspuns `answered:true` → `state == answered`, `result.answer == "Vineri."`, replici noi nu mai cheamă checker-ul.
  - `gives_up_after_five_minutes`: fără răspuns, la 5 min după `markRead` → `state == notFound`; `retry()` → checker-ul e chemat din nou la următoarea replică și pornește alte 5 min.
  - `retry_works_without_read` (Review Focus 3): `asked`, nicio `markRead`, `retry()` → verificarea pornește cu liniile de după trimitere.
  - `new_question_replaces_old`: al doilea `asked` → `id` și `text` noi, `state == sent`, verificarea veche se oprește.
  - `api_error_stops_quietly` (Review Focus 4): checker-ul aruncă `ApiException(503, …)` → `state` rămâne `read`, fără alte apeluri până la `retry()`.
  - `markRead_for_other_id_is_ignored`.
  - Pentru `RoomQuestions`: `batches_up_to_five_lines_per_second` (7 replici `public` finale în 200 ms → apeluri cu 5, apoi 2 linii); `coordinator_lines_are_not_sent`; `marks_returned_ids` (`isQuestion(captionId)` true pentru id-ul întors); `falls_back_to_heuristic_on_api_error` (503 → „când e termenul” e marcat, „mulțumesc” nu).
  - `looksLikeQuestion`: `("Când e termenul", "ro-RO")` → true; `("e gata raportul?", "ro-RO")` → true; `("Mulțumesc mult", "ro-RO")` → false; `("what is the deadline", "en-US")` → true.
- [ ] **Step 2: Rulează** `cd app && flutter test test/features/my_question_test.dart test/features/room_questions_test.dart` → pică.
- [ ] **Step 3: Implementează.** `MyQuestion` ascultă `transcript`, ține minte numărul de linii finale la `asked` și trimite doar liniile de după, renumerotate ca în `finalLines()` (numerele rămân cele globale, ca citările `[#id]` să ducă la replica corectă). Timere prin `Timer` (merg cu `fake_async`). Cuvintele interogative din `looksLikeQuestion` sunt cele din spec, secțiunea 7; comparația e pe primul cuvânt, fără diacritice și fără majuscule, plus textul care se termină cu „?”.
- [ ] **Step 4: Rulează** aceleași teste → trec.
- [ ] **Step 5: Commit** `git add app/lib/features/participant app/test/features && git commit -m "Track the participant's question and questions from the room"`

---

### Task 4: Telefonul — ecranul

**Files:**
- Modify: `app/lib/features/participant/participant_screen.dart`, `app/lib/widgets/caption_tile.dart`, `app/lib/features/home/home_screen.dart`, `app/lib/l10n/app_ro.arb`, `app/lib/l10n/app_en.arb`
- Create: `app/lib/features/participant/ask_panel.dart` (butonul, câmpul, starea, cardul)
- Test: `app/test/features/participant_screen_test.dart`

**Interfaces:**
- Consumes: `MyQuestion`, `RoomQuestions` (Task 3), `ReadReceived`, `NotifyKind.hand` (Task 2).
- Produces: `CaptionTile({..., bool isQuestion = false})`.

- [ ] **Step 1: Teste widget care pică** (cu `TestHarness` din `app/test/fakes.dart`; serverul HTTP fals prin `MockClient` adăugat în `AppServices.httpClient`):
  - `ask_button_sends_hand_then_question`: atingerea „Vreau să întreb” trimite `notify` `kind:'hand'`; câmpul apare; textul + „Trimite” trimite `notify` `kind:'question'` cu textul; starea afișată e „Trimisă”.
  - `read_shows_waiting_state`: serverul trimite `{'type':'read','id':<id>,'by':'voice'}` → apare „Citită, se așteaptă răspunsul”.
  - `answered_card_shows_answer_and_jumps_to_line`: după `read`, o replică `coordinator` finală, 3 s, `answer-check` întoarce `answered:true, answer:'Vineri.', line_ids:[1]` → cardul „Ți s-a răspuns” cu întrebarea și „Vineri.”; are `Semantics(liveRegion: true)`.
  - `room_question_badge`: replică `public` „când e termenul” + `questions` întoarce id-ul ei → pe replică apare „Întrebare din sală”, cu iconiță.
  - `role_labels_are_speaker_and_room`: etichetele sunt „Speaker” și „Din sală”.
  - Textele vechi „Am o întrebare” (quick chip) dispar; „Repetă” și „Mai rar” rămân.
- [ ] **Step 2: Rulează** `cd app && flutter test test/features/participant_screen_test.dart` → pică.
- [ ] **Step 3: Implementează.** ARB nou (RO / EN): `askButton` „Vreau să întreb” / „I want to ask”, `askHint` „Scrie întrebarea”, `askSend` „Trimite”, `askStateSent` „Trimisă, așteaptă să fie citită”, `askStateRead` „Citită, se așteaptă răspunsul”, `askStateNotFound` „Nu am găsit încă un răspuns”, `askRetry` „Caută răspunsul”, `answeredTitle` „Ți s-a răspuns”, `answeredClose` „Închide”, `roomQuestion` „Întrebare din sală”; schimbă valorile `speakerCoordinator` → „Speaker” / „Speaker”, `speakerPublic` → „Din sală” / „Room”, `homeJoin` → „Conectează-te la speaker” / „Connect to the speaker”, `joinTitle` la fel. Butonul „Vreau să întreb” e mereu vizibil deasupra barei de mesaje, minim 48 px înălțime, cu iconița `front_hand`. Cardul e fixat sus, sub banner, până la „Închide”; la apariție: `HapticFeedback.heavyImpact()` și `SemanticsService.announce`. Atingerea unei citări derulează lista la replica `#id`.
- [ ] **Step 4: Rulează** `cd app && flutter gen-l10n && flutter analyze && flutter test` → trece.
- [ ] **Step 5: Commit** `git add app && git commit -m "Participant: ask the speaker, see when the question is answered, room questions"`

---

### Task 5: Laptopul — alerta, întrebarea, vocea sintetizată, „Vorbesc eu”

**Files:**
- Create: `app/lib/core/tts/tts_service.dart` (interfață + `createTtsService()` prin import condiționat), `app/lib/core/tts/tts_web.dart`, `app/lib/core/tts/tts_stub.dart`
- Modify: `app/lib/core/services.dart` (`AppServices.tts`), `app/lib/main.dart`, `app/lib/features/presenter/presenter_screen.dart`, ARB-urile, `app/pubspec.yaml` (`web`)
- Test: `app/test/features/presenter_and_settings_test.dart`, `app/test/fakes.dart` (`FakeTts`)

**Interfaces:**
- Produces:
  - `abstract class TtsService { bool canSpeak(String localeId); Future<bool> speak(String text, String localeId); void cancel(); }` (`speak` se termină când vocea a terminat; `false` la eroare sau fără voce)
  - `PresenterScreen` trimite `ReadMessage` și etichetează replicile prin `Speaker Function() currentSpeaker` (în acest task: `forceSpeaker` sau `coordinator`; Task 8 conectează amprenta).

- [ ] **Step 1: Teste widget care pică:**
  - `hand_alert_is_big_and_silent`: `notify kind:'hand'` → text „Persoana care folosește Echo vrea să pună o întrebare”, cu iconiță, în zona de alerte, în `liveRegion`.
  - `question_card_reads_aloud_and_sends_read`: `notify kind:'question'` → textul întrebării + „Citește cu voce tare” + „Am citit-o eu”; „Citește cu voce tare” → `FakeTts.spoken == [text]`, apoi se trimite `{'type':'read','id':…,'by':'voice'}`.
  - `read_by_speaker_sends_read`: „Am citit-o eu” → `by:'speaker'`.
  - `listening_pauses_while_tts_speaks` (Review Focus 2): cu transcrierea pornită, în timpul `speak` `FakeSpeech` e oprit; după `speak` repornește; la fel când `speak` întoarce `false`.
  - `read_aloud_disabled_without_voice`: `FakeTts.canSpeak → false` → butonul e dezactivat și apare „Nu există voce în limba asta pe laptop; citește-o tu”.
  - `force_speaker_toggle`: „Vorbesc eu” e un buton comutator (`Semantics(toggled: …)`).
- [ ] **Step 2: Rulează** → pică.
- [ ] **Step 3: Implementează.** `tts_web.dart` folosește `window.speechSynthesis` din `package:web` (vocea = prima cu `lang` care începe cu limba cerută; `speak` așteaptă evenimentul `end` sau `error`). ARB: `presenterHand`, `presenterReadAloud` „Citește cu voce tare”, `presenterReadMyself` „Am citit-o eu”, `presenterNoVoice`, `presenterForceSpeaker` „Vorbesc eu”.
- [ ] **Step 4: Rulează** `cd app && flutter gen-l10n && flutter analyze && flutter test` → trece.
- [ ] **Step 5: Verificare în Chrome:** `cd app && flutter run -d chrome`, telefonul simulat dintr-un al doilea tab (participant, același cod): mâna apare pe laptop, „Citește cu voce tare” vorbește în română, iar tab-ul participantului trece pe „Citită”.
- [ ] **Step 6: Commit** `git add app && git commit -m "Presenter: hand alert, question card, read aloud, force-speaker toggle"`

---

### Task 6: `ml/voice` — modelul de bază, exportul ONNX și paritatea

**Files:**
- Create: `ml/voice/requirements.txt`, `ml/voice/pytest.ini`, `ml/voice/echo_voice/__init__.py`, `ml/voice/echo_voice/model.py`, `ml/voice/echo_voice/export.py`, `ml/voice/tests/test_export.py`, `ml/voice/README.md`
- Create (output): `app/web/voice/speaker.onnx`, `app/web/voice/fixtures/parity.json`
- Modify: `.gitignore` (`ml/voice/data/`, `ml/voice/runs/`, `ml/voice/.venv/`; excepție `!app/web/voice/speaker.onnx`)

**Interfaces:**
- Produces:
  - `load_base(size: str = "b6", dataset: str = "vb2+vox2_v0", train_type: str = "lm") -> torch.nn.Module` (prin `torch.hub.load("PalabraAI/redimnet2:<commit fixat>", "redimnet2", ...)`, `trust_repo=True`, `eval()`)
  - `embed(model, wave: np.ndarray) -> np.ndarray` (16 kHz mono float32 → vector 192, normalizat L2)
  - `export_onnx(model, path: Path) -> None`: intrare `audio` `[1, samples]` cu `samples` dinamic, ieșire `embedding` `[1, 192]` normalizată L2; opset 18
  - `python -m echo_voice.export --out ../../app/web/voice/speaker.onnx` scrie modelul și `fixtures/parity.json` (`{"sample_rate":16000,"audio_b64":<3 s float32 LE>,"embedding":[192 numere]}`)

- [ ] **Step 1:** `cd ml/voice && python -m venv .venv && .venv/Scripts/pip install torch torchaudio --index-url https://download.pytorch.org/whl/cu128 && .venv/Scripts/pip install onnx onnxruntime numpy soundfile pytest`, apoi `pip freeze > requirements.txt` (versiuni fixate). Verifică: `.venv/Scripts/python -c "import torch; print(torch.cuda.is_available())"` → `True`.
- [ ] **Step 2: Teste care pică** (`ml/voice/tests/test_export.py`, marcate `@pytest.mark.slow` pentru cele care descarcă modelul):
  - `test_embedding_is_unit_length_192`
  - `test_onnx_matches_torch_for_several_lengths`: pentru 1,5 s, 3 s, 8 s (zgomot filtrat, seed fix) cosinusul dintre torch și `onnxruntime` ≥ 0,9999.
  - `test_same_speaker_scores_higher_than_different`: pe 3 clipuri incluse în `ml/voice/tests/fixtures/` (2 cu aceeași voce, 1 cu altă voce, ~3 s fiecare, înregistrate de echipă sau din LibriSpeech dev-clean), cos(același) > cos(diferit) + 0,2.
- [ ] **Step 3: Rulează** `.venv/Scripts/python -m pytest -q` → pică.
- [ ] **Step 4: Implementează** `model.py` și `export.py`. Dacă exportul dinamic eșuează la STFT, exportă fereastră fixă de 3 s și documentează în `README.md` că browserul împarte replicile în ferestre de 3 s (repetate până la 3 s dacă sunt mai scurte) și face media; testul de paritate verifică atunci doar 3 s.
- [ ] **Step 5: Rulează** testele → trec; rulează exportul → `app/web/voice/speaker.onnx` (~50 MB) și `parity.json` există.
- [ ] **Step 6: Commit** `git add .gitignore ml/voice app/web/voice && git commit -m "Add ReDimNet2 base model, ONNX export and parity tests"`

---

### Task 7: Browserul — captura, modelul și eticheta fiecărei replici

**Files:**
- Create: `app/web/voice/echo_voice.js`, `app/web/voice/capture_worklet.js`, `app/web/voice/check.html`, `app/web/voice/voice_head.json`, `app/web/voice/ort/` (fișierele `onnxruntime-web` fixate, copiate din pachetul npm, cu excepție în `.gitignore` dacă depășesc regula `*.onnx`)
- Create: `app/lib/core/voice/voice_engine.dart` (interfață + `createVoiceEngine()` prin import condiționat), `voice_engine_web.dart`, `voice_engine_stub.dart`, `voice_head.dart`, `speaker_labeler.dart`
- Modify: `app/web/index.html` (`<script src="voice/echo_voice.js" defer>`), `app/lib/core/services.dart` (`AppServices.voice`), `app/lib/main.dart`, `app/test/fakes.dart` (`FakeVoiceEngine`)
- Test: Create `app/test/core/speaker_labeler_test.dart`, `app/test/core/voice_head_test.dart`

**Interfaces:**
- Produces (JS, `window.echoVoice`): `start(): Promise<boolean>` (microfon + worklet la 16 kHz + sesiune ORT pe `['webgpu','wasm']`), `recent(seconds: number): Float32Array`, `embed(samples: Float32Array): Promise<Float32Array>`, `stop()`, `provider: string`.
- Produces (Dart):
  - `abstract class VoiceEngine { Future<bool> start(); Future<void> stop(); Float32List recent(Duration length); Future<Float32List> embed(Float32List samples); Future<VoiceHead> loadHead(); }`
  - `class VoiceHead { const VoiceHead({required double scale, required double bias, required double threshold, int minVoicedMs = 1000, int enrollMinVoicedMs = 10000, int windowMs = 3000}); static VoiceHead fromJson(Map<String, dynamic>); double probability(double cosine); bool isSpeaker(double cosine); }` (`probability = 1 / (1 + exp(-(scale * cosine + bias)))`, `isSpeaker = probability >= threshold`)
  - `enum EnrollResult { ok, tooLittleSpeech, failed }`
  - `class SpeakerLabeler { SpeakerLabeler(VoiceEngine engine, VoiceHead head); bool get enrolled; bool forceSpeaker; Speaker get current; Future<EnrollResult> enroll(Float32List samples); Future<Speaker> labelFinal(DateTime now); double? get lastScore; Float32List? get lastClip; }`
  - `Float32List trimSilence(Float32List samples, {int frameMs = 30, double relativeDb = -35})` (top-level)
  - `double cosine(Float32List a, Float32List b)` (top-level)
- `voice_head.json` inițial (înainte de calibrare): `{"model":"redimnet2-b6-vb2+vox2_v0-lm","scale":20.0,"bias":-7.0,"threshold":0.5,"min_voiced_ms":1000,"enroll_min_voiced_ms":10000,"window_ms":3000}`.

- [ ] **Step 1: Teste care pică** (`FakeVoiceEngine`: `recent` întoarce buffer-ul setat de test, `embed` întoarce un vector ales de test după conținut):
  - `voice_head_probability_and_threshold`: cu `scale 20, bias -7`, `probability(0.35) == 0.5` (±1e-9), `isSpeaker(0.36)` true, `isSpeaker(0.34)` false.
  - `enroll_rejects_too_little_speech` (Review Focus 5): 20 s cu doar 6 s de voce → `tooLittleSpeech`, `enrolled == false`.
  - `enroll_averages_three_second_windows`: 12 s de voce → `embed` chemat de 4 ori cu câte 48.000 de eșantioane; amprenta salvată e media normalizată.
  - `label_uses_audio_since_previous_final`: finală la t=10 s, apoi la t=14 s → `recent` cerut pentru 4 s; prima finală după pornire cere 8 s; la 20 s distanță tot 8 s.
  - `short_utterance_keeps_previous_label` (Review Focus 1): sub 1 s de voce după `trimSilence` → aceeași etichetă ca înainte, `embed` nu e chemat.
  - `force_speaker_wins`: `forceSpeaker = true` → `coordinator` fără `embed`.
  - `not_enrolled_means_coordinator`.
  - `trimSilence_removes_quiet_edges`: 1 s liniște + 2 s ton + 1 s liniște → ~2 s (±60 ms).
- [ ] **Step 2: Rulează** `cd app && flutter test test/core` → pică.
- [ ] **Step 3: Implementează** partea Dart, apoi JS: worklet-ul reeșantionează la 16 kHz și scrie într-un buffer circular de 15 s; `embed` rulează sesiunea ORT (intrarea `audio`, `[1, n]`) și întoarce `embedding`. Fișierele ORT: din pachetul npm `onnxruntime-web` (o versiune publicată de cel puțin două săptămâni, fixată în `app/web/voice/ort/VERSION`).
- [ ] **Step 4: Rulează** `cd app && flutter analyze && flutter test` → trece.
- [ ] **Step 5: Verificare în Chrome:** `cd app && flutter build web` și `docker compose up --build -d`, apoi `http://localhost:8000/voice/check.html`: pagina încarcă `fixtures/parity.json`, rulează modelul și afișează cosinusul cu amprenta din Python (trebuie ≥ 0,999), providerul (`webgpu` / `wasm`) și durata pentru 3 s și 8 s. **Criteriu:** p95 ≤ 1,5 s pentru 8 s. Dacă nu: activează firele WASM (antete `Cross-Origin-Opener-Policy: same-origin` și `Cross-Origin-Embedder-Policy: require-corp` pe server, cu test în `server/tests`), apoi, dacă tot nu, B3 (`load_base("b3", "vb2+vox2+cnc2_v0")`) prin Task 6.
- [ ] **Step 6: Commit** `git add app && git commit -m "Run ReDimNet2 in Chrome and label each caption by voice"`

---

### Task 8: Laptopul — enrollment și etichetele din amprentă

**Files:**
- Create: `app/lib/features/presenter/enroll_view.dart`
- Modify: `app/lib/features/presenter/presenter_screen.dart`, ARB-urile
- Test: `app/test/features/presenter_and_settings_test.dart`

**Interfaces:**
- Consumes: `VoiceEngine`, `SpeakerLabeler`, `VoiceHead` (Task 7); `currentSpeaker` din Task 5.

- [ ] **Step 1: Teste widget care pică:**
  - `presenter_starts_with_enrollment`: pagina arată textul de citit, „Începe” și o bară de progres; după 20 s (`fake_async`) și `EnrollResult.ok` → „Vocea ta e învățată”, apoi QR-ul.
  - `enrollment_too_short_asks_again`: `tooLittleSpeech` → mesaj „Am auzit prea puțin. Citește din nou textul, cu voce normală.” și „Începe” din nou.
  - `final_captions_carry_voice_label`: `FakeVoiceEngine` dă o amprentă diferită de cea învățată → `caption` trimis cu `speaker:'public'`; amprenta învățată → `coordinator`. Replicile parțiale pleacă cu eticheta ultimei finale.
  - `relearn_voice_returns_to_enrollment`.
  - `voice_unavailable_falls_back_to_coordinator`: `start()` întoarce `false` → mesaj „Recunoașterea vocii nu merge în acest browser; toate replicile sunt «Speaker»”, iar pagina merge mai departe la QR.
- [ ] **Step 2: Rulează** → pică.
- [ ] **Step 3: Implementează.** Textul de enrollment (RO și EN, în ARB): un paragraf de ~60 de cuvinte, neutru, cu sunete variate. Amprenta învățată se salvează în `SharedPreferences` (`voiceEnrollment`, listă de 192 de numere) și se încarcă la reîncărcarea paginii; „Reînvață vocea” o șterge.
- [ ] **Step 4: Rulează** `cd app && flutter gen-l10n && flutter analyze && flutter test` → trece.
- [ ] **Step 5: Verificare în Chrome, cu două persoane:** enrollment, apoi 10 replici fiecare, la 1–2 m de laptop; numără etichetele corecte pe ecranul participantului (al doilea tab).
- [ ] **Step 6: Commit** `git add app && git commit -m "Presenter: learn the speaker's voice and label captions with it"`

---

### Task 9: Meetingul de test — înregistrare, verificare, arhivă

**Files:**
- Create: `app/lib/features/presenter/test_meeting.dart` (`TestMeetingRecorder`, `encodeWav`), `app/lib/features/presenter/test_meeting_review.dart` (ecranul), `app/lib/core/download/download.dart` + `download_web.dart` + `download_stub.dart`
- Modify: `app/lib/features/presenter/presenter_screen.dart`, `app/pubspec.yaml` (`archive`), ARB-urile
- Test: Create `app/test/features/test_meeting_test.dart`

**Interfaces:**
- Consumes: `SpeakerLabeler.lastClip`, `lastScore` (Task 7).
- Produces:
  - `Uint8List encodeWav(Float32List samples, {int sampleRate = 16000})` (PCM 16 biți, mono)
  - `class TestMeetingRecorder extends ChangeNotifier { void setEnrollment(Float32List samples); void add({required String id, required String text, required Speaker predicted, required double? score, required Float32List clip}); void setLabel(String id, Speaker label); List<RecordedLine> get lines; Uint8List buildArchive(); }`
  - Arhiva `echo-test-meeting-<yyyyMMdd-HHmm>.zip`: `enrollment.wav`, `clips/001.wav`…, `labels.json` = `{"version":1,"sample_rate":16000,"model":<din voice_head.json>,"enrollment":"enrollment.wav","lines":[{"id":…,"file":"clips/001.wav","text":…,"predicted":"coordinator","score":0.83,"label":"coordinator"}]}`. `label` pornește egal cu `predicted`.
  - `void downloadBytes(Uint8List bytes, String fileName)`

- [ ] **Step 1: Teste care pică:** `encodeWav_header_and_samples` (antet RIFF/WAVE, `fmt` PCM 1 canal 16000 Hz, 16 biți; `1.0` → 32767, `-1.0` → -32768, `2.0` limitat la 32767); `archive_contains_labels_and_clips` (2 replici → 4 fișiere, `labels.json` cu `label` schimbat de `setLabel`); `review_screen_lets_team_fix_labels` (widget: comutatorul Speaker / Din sală de pe o replică schimbă `label`; „Descarcă” cheamă `downloadBytes` falsificat cu un `.zip`).
- [ ] **Step 2: Rulează** → pică.
- [ ] **Step 3: Implementează.** „Meeting de test” e un comutator pe pagina prezentatorului, înainte de pornirea transcrierii, cu textul „Înregistrează clipurile pe acest laptop, pentru antrenare. Toți cei din sală trebuie să fie de acord.” La oprirea transcrierii, dacă modul e activ, se deschide ecranul de verificare.
- [ ] **Step 4: Rulează** `cd app && flutter gen-l10n && flutter analyze && flutter test` → trece.
- [ ] **Step 5: Commit** `git add app && git commit -m "Add test meeting recording, review and archive download"`

---

### Task 10: `ml/voice` — date, sală simulată, evaluare

**Files:**
- Create: `ml/voice/echo_voice/data.py`, `augment.py`, `evaluate.py`, `ml/voice/tests/test_data.py`, `test_augment.py`, `test_evaluate.py`

**Interfaces:**
- Consumes: `embed`, `load_base` (Task 6); arhivele din Task 9.
- Produces:
  - `prepare(source: str, src: Path, out: Path, lang: str = "ro") -> int` (CLI `python -m echo_voice.data --source common_voice|tidyvoice|meetings --src … --out data/speakers`): scrie `<out>/<vorbitor>/<clip>.wav`, 16 kHz mono; întoarce numărul de vorbitori. Pentru meetinguri: `meeting-<arhivă>-speaker/` cu enrollment-ul și clipurile etichetate `coordinator`; clipurile `public` merg în `<out>/_room/<arhivă>/` (identitate necunoscută: doar la evaluare și calibrare).
  - `split_speakers(root: Path, held_out: float = 0.1, seed: int = 0) -> tuple[list[str], list[str]]` (determinist; meetingurile listate în `ml/voice/heldout_meetings.txt` merg mereu la test)
  - `synthetic_rir(rt60: float, sr: int, rng) -> np.ndarray`; `apply_room(wave: np.ndarray, rng, noise_pool: list[np.ndarray]) -> np.ndarray` (reverb RT60 0,2–0,8 s, atenuare de distanță 1–4 m, zgomot sau altă voce la SNR 5–20 dB)
  - `eer(scores: np.ndarray, same: np.ndarray) -> float`
  - `meeting_report(score_fn, archive_dir: Path, head: dict) -> dict` cu `speaker_hit`, `room_reject`, `n_speaker`, `n_room`
  - CLI `python -m echo_voice.evaluate --candidate base|<checkpoint> ...` → tabel: EER pe perechile de test în română, `speaker_hit` și `room_reject` pe fiecare meeting ținut deoparte

- [ ] **Step 1: Teste care pică** (date sintetice mici, generate în `tmp_path`):
  - `test_prepare_common_voice_groups_by_client_id` (un `validated.tsv` mic cu 2 `client_id` → 2 foldere).
  - `test_prepare_meetings_splits_speaker_and_room`.
  - `test_split_is_deterministic_and_disjoint`.
  - `test_apply_room_keeps_length_and_is_seeded` (aceeași lungime; același seed → același rezultat; RMS finit, nenul).
  - `test_eer_perfect_and_random` (separare perfectă → 0; scoruri identice → 0,5).
  - `test_meeting_report_counts` (scoruri false fixe → `speaker_hit == 0.75` pentru 3/4).
- [ ] **Step 2: Rulează** → pică. **Step 3: Implementează** (fără dependențe noi: `numpy`, `soundfile`, `torchaudio` pentru reeșantionare/mp3). **Step 4: Rulează** → trece.
- [ ] **Step 5:** pe datele reale (după pasul manual): `prepare` pentru sursa descărcată și pentru meetingurile din `ml/voice/data/meetings/`; `evaluate --candidate base` scrie primul raport în `ml/voice/reports/`.
- [ ] **Step 6: Commit** `git add ml/voice && git commit -m "Add voice data preparation, room simulation and evaluation"` (rapoartele sunt text și intră în git; datele nu).

---

### Task 11: `ml/voice` — fine-tuning, calibrare, livrare

**Files:**
- Create: `ml/voice/echo_voice/train.py`, `calibrate.py`, `ship.py`, `ml/voice/tests/test_train.py`, `test_calibrate.py`

**Interfaces:**
- Consumes: Task 6 (`load_base`, `export_onnx`), Task 10 (`split_speakers`, `apply_room`, `eer`, `meeting_report`).
- Produces:
  - `python -m echo_voice.train --data data/speakers --out runs/<nume> [--epochs 5] [--smoke]`: AAM-softmax (marjă 0,2, scală 32) peste vorbitorii de antrenare, tăieturi de 3 s, sală simulată cu probabilitate 0,6, AdamW (backbone 1e-5, capul 1e-3), AMP pe CUDA; salvează `best.pt` după EER pe vorbitorii ținuți deoparte. `--smoke`: 2 pași pe CPU.
  - `fit_head(same: np.ndarray, diff: np.ndarray, speaker_scores: np.ndarray, room_scores: np.ndarray, min_speaker_hit: float = 0.95) -> dict` → `scale`, `bias` (regresie logistică pe cosinus) și `threshold` = cel mai mare prag de probabilitate cu `speaker_hit ≥ 0.95` pe datele de calibrare.
  - `python -m echo_voice.ship`: evaluează `base`, ultimul `best.pt` și ReDimNet2+ (dacă există `runs/redimnet2plus/`) pe setul ținut deoparte; câștigă candidatul cu `speaker_hit ≥ 0.95` și cel mai mare `room_reject` (la egalitate, EER mai mic); exportă câștigătorul în `app/web/voice/speaker.onnx`, scrie `voice_head.json` și `ml/voice/reports/<data>-ship.md` cu tabelul tuturor candidaților; raportul marchează „sub criteriu” orice meeting ținut deoparte cu `speaker_hit < 0.95` sau `room_reject < 0.85` (criteriul din spec, 5bis).

- [ ] **Step 1: Teste care pică:** `test_train_smoke_runs_two_steps` (date sintetice: 3 vorbitori × 3 clipuri de ton modulat; `--smoke` produce `best.pt`); `test_fit_head_respects_speaker_hit` (scoruri sintetice → pragul ales lasă ≥ 95% din `speaker_scores` deasupra); `test_ship_keeps_base_when_finetune_is_worse` (`score_fn`-uri false: fine-tune mai slab → raportul spune „base” și `voice_head.json` are `model` de bază).
- [ ] **Step 2: Rulează** → pică. **Step 3: Implementează.** **Step 4: Rulează** → trece.
- [ ] **Step 5: Antrenarea reală:** `train --epochs 5` pe RTX 3050, apoi `ship`. Rulează `cd app && flutter build web` și refă verificarea din Task 7, Step 5 (paritate + viteză) cu modelul livrat.
- [ ] **Step 6: Commit** `git add ml/voice app/web/voice && git commit -m "Fine-tune and calibrate the speaker model; ship the best candidate"`

---

### Task 12: Documentație și verificarea cap-coadă

**Files:**
- Modify: `README.md`, `ml/voice/README.md`, `CLAUDE.md` (secțiunea „Comenzi”), `docs/superpowers/plans/2026-10-22-demo.md` (trimitere la acest plan pentru partea de meeting)

- [ ] **Step 1:** `ml/voice/README.md`: descărcarea datelor (pasul manual), `prepare`, un meeting de test (cine, cât, consimțământ, unde se copiază arhiva), `train`, `evaluate`, `ship`, ce înseamnă coloanele din raport.
- [ ] **Step 2:** `CLAUDE.md`, „Comenzi”: `cd ml/voice && .venv/Scripts/python -m pytest` și `python -m echo_voice.ship`.
- [ ] **Step 3: Verificare cap-coadă** pe laptop + iPhone (sau al doilea tab): enrollment, 5 replici speaker + 5 din sală, o întrebare din sală marcată, „Vreau să întreb” → alertă → întrebare citită cu voce tare → răspunsul speakerului → cardul „Ți s-a răspuns” cu răspunsul corect. Notează rezultatul în `ml/voice/reports/`.
- [ ] **Step 4:** toate testele (app, server, ml/voice) trec; `flutter analyze` curat.
- [ ] **Step 5: Commit** `git add -A && git commit -m "Document voice training, test meetings and the physical meeting flow"`
