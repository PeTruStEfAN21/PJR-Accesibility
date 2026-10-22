# Antrenorul de claritate — plan de implementare

> **Pentru agenți:** SUB-SKILL OBLIGATORIU: superpowers:executing-plans (sau subagent-driven-development), task cu task, TDD.

**Scop:** colegul auzitor deschide Echo în Chrome în timpul unui meeting online și primește alerte personale, discrete, ca persoana surdă să poată citi clar subtitrarea.

**Arhitectură:** sunetul microfonului (16 kHz, din captura existentă `echo_voice.js`) intră într-un analizor Dart pe cadre de 30 ms (voce / zgomot, silabe, pauze), plus YAMNet pentru zgomot și, opțional, modelul de voce ca să conteze doar vocea colegului. Regulile de alertă și programarea lor (prioritate, pauză între repetări) sunt Dart pur, testat cu timp fals. Suprapunerea vine din mesaje `speaking` prin serverul existent. Alertele apar pe pagină și într-o fereastră Document Picture-in-Picture.

**Spec:** `docs/superpowers/specs/2026-10-22-antrenor-claritate-design.md`. Reguli: `CLAUDE.md`.

## Global Constraints

- Meetingul fizic nu se schimbă: niciun comportament existent din `features/presenter`, `features/participant`, `core/voice` nu se modifică (doar se refolosește).
- Audio și video nu pleacă de pe calculator; prin rețea doar `speaking` `{id, active, ts}`.
- Orice text vizibil în `app_ro.arb` + `app_en.arb`; iconiță + text la fiecare alertă; `Semantics(liveRegion)`; ținte ≥ 48 px.
- Commit-uri ca `selimayann`, fără atribuire Claude. Push pe `main` la final (cerut de echipă).
- Teste: `cd app && flutter analyze && flutter test`; `cd server && .venv/Scripts/python -m pytest -q`; `cd ml/voice && .venv/Scripts/python -m pytest -q -m "not slow"`.

## Review Focus

1. Fila Echo în fundal: analiza trebuie să meargă (pornită de sunet, nu de cronometre).
2. Colegul tace mult: nicio alertă de ritm / pauze pe date vechi; ferestrele se golesc.
3. Microfonul aude difuzoarele: fără vocea învățată, alertele sunt marcate ca aproximative; cu vocea învățată, segmentele altora nu contează.
4. Conexiunea cade: `speaking` nu rămâne „true” la ceilalți (la `peer connected:false` se șterge).
5. Fără Document Picture-in-Picture: pagina merge, butonul spune de ce nu se poate.

---

### Task 1: Server — rolul `colleague` și mesajul `speaking`
**Files:** `server/app/protocol.py`, `server/app/main.py` (mesajul de eroare pentru rol), `server/tests/test_realtime.py`
- [ ] Teste: `colleague` se poate conecta; `speaking` de la `colleague` ajunge la ceilalți colegi; `participant` / `presenter` nu pot trimite `speaking`; `speaking` cu `active` lipsă → `invalid message`.
- [ ] `ROLES += ("colleague",)`, `class Speaking(type="speaking", id≤64, active: bool, ts: int)`, `ALLOWED["colleague"] = {"speaking"}`.
- [ ] Commit „Add the colleague role and speaking messages”.

### Task 2: Aplicația — protocolul `speaking`
**Files:** `app/lib/core/protocol.dart`, `app/test/core/transcript_and_protocol_test.dart`
- [ ] `SpeakingMessage({id, active, ts}).toJson()`; `SpeakingReceived(id, active)` în `ServerEvent.fromJson`.
- [ ] Commit.

### Task 3: Analizorul de voce pe cadre (Dart pur)
**Files:** `app/lib/features/coach/voice_activity.dart`, `app/test/features/coach/voice_activity_test.dart`
- **Produce:** `class FrameAnalyzer { void add(Float32List samples); Stream/List<VoiceFrame> }` cu `VoiceFrame {double time, double db, bool voiced, bool syllable}`; prag de zgomot continuu = cea mai liniștită cincime din ultimele 10 s + 12 dB (și cel mult 6 dB sub cel mai tare cadru, cel puțin -60 dBFS); nucleu de silabă = vârf de energie în cadre cu voce, ≥ 2 dB peste minimele vecine, la ≥ 100 ms de vârful anterior.
- [ ] Teste: zgomot modulat la 4 Hz → ~4 silabe/s (±15%); liniște → nicio voce; zgomot de fond constant + voce → doar vocea e „voiced”; cadrele se pot da în bucăți de orice mărime cu același rezultat.
- [ ] Commit.

### Task 4: Măsurătorile și regulile alertelor (Dart pur, timp fals)
**Files:** `app/lib/features/coach/coach_metrics.dart`, `coach_alerts.dart`, `coach_thresholds.dart`, teste în `app/test/features/coach/`
- **Produce:** `enum CoachAlert { overlap, weakMic, tooFast, noPauses, longTalk, noise }` (ordinea = prioritatea); `class ClarityCoach extends ChangeNotifier { void onFrame(VoiceFrame f, {required bool own}); void onNoise(double score, DateTime t); void onOthersSpeaking(bool any, DateTime t); CoachAlert? get current; }`.
- Reguli (praguri în `coach_thresholds.dart`): prea repede = silabe/s pe ultimele 20 s de vorbire proprie > prag calibrat (Task 5); fraze fără pauză = ≥ 12 s de vorbire fără pauză de 0,4 s, de 2 ori în 2 min; 5 minute = vorbire continuă (pauze < 3 s) ≥ 5 min; microfon slab = SNR mediu al vorbirii proprii < 15 dB pe ultimele 10 s de vorbire; zgomot = scor YAMNet de zgomot ≥ 0,3 timp de 5 s cât nu vorbești; suprapunere = tu și altcineva vorbiți ≥ 1,5 s simultan.
- Programare: o alertă odată (cea mai prioritară activă), minim 6 s pe ecran, aceeași nu revine mai devreme de 3 min, se stinge când condiția dispare.
- [ ] Teste pentru fiecare regulă (inclusiv „tăcere lungă golește ferestrele”), prioritate, 6 s, 3 min.
- [ ] Commit.

### Task 5: Calibrarea pragului de ritm pe română (Python)
**Files:** `ml/voice/echo_voice/speech_rate.py`, `ml/voice/tests/test_speech_rate.py`, `ml/voice/reports/<data>-ritm.md`, `app/lib/features/coach/coach_thresholds.dart`
- [ ] Același algoritm ca Task 3; test de paritate: același semnal sintetic dă același număr de silabe ca în testul Dart (valoare literală în ambele teste).
- [ ] Pe VoxPopuli RO (transcriere = cuvinte): regresie silabe detectate / cuvinte → pragul în silabe/s pentru 170 cuvinte/min; raport cu distribuția.
- [ ] Commit.

### Task 6: Browserul — captura fără model, YAMNet, fereastra mereu deasupra
**Files:** `app/web/voice/echo_voice.js` (adaugă `startCapture()` și `onChunk(cb)`, fără a schimba `start()`), `app/web/coach/pip.js` (+ `index.html`), `app/lib/features/coach/coach_audio*.dart` (interfață + web + stub), `app/lib/features/coach/alert_window*.dart`, fakes în `app/test/fakes.dart`
- [ ] `CoachAudio { Future<bool> start(); Stream<Float32List> get chunks; Future<List<double>?> yamnetScores(Float32List window); void stop(); }`; `AlertWindow { bool get supported; Future<bool> open(); void show(String text, String icon); void close(); }`.
- [ ] Verificare manuală în Chrome (fila în fundal, fereastra deasupra).
- [ ] Commit.

### Task 7: Doar vocea colegului
**Files:** `app/lib/features/coach/own_voice.dart`, test
- [ ] `OwnVoiceGate(SpeakerLabeler)`: segmentele de voce ≥ 1 s sunt judecate cu amprenta; cadrele unui segment judecat „altcineva” nu contează; fără voce învățată totul contează.
- [ ] Commit.

### Task 8: Ecranul colegului
**Files:** `app/lib/features/coach/coach_screen.dart`, `app/lib/features/home/home_screen.dart` (o intrare nouă), ARB, `app/test/features/coach_screen_test.dart`
- [ ] Flux: „Sunt coleg într-un meeting online” → creează / intră cu cod → (opțional) învață vocea (refolosește `EnrollView`) → ascultă → alerta curentă mare, cu iconiță + text, în `liveRegion` → „Arată alertele peste meeting”.
- [ ] Teste widget cu fakes: alerta apare, `speaking` se trimite la schimbare, suprapunerea vine din `SpeakingReceived`.
- [ ] Commit.

### Task 9: Documentație, verificare, push
- [ ] `CLAUDE.md` (componenta nouă), README-ul din `ml/voice` (calibrarea ritmului).
- [ ] Toate testele; build web; verificare în Chrome; push pe `main`.
