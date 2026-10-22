# Vibrația aleasă pe nivel de alertă — plan de implementare

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cardul „Sunete” pe ecranul principal în locul pastilei, iar pe ecranul Sunete alegerea vibrației (unice) pentru fiecare nivel de alertă, cu previzualizare la atingere.

**Architecture:** Alegerea stă în `AppSettings` (`alertHaptics`, cu schimb între niveluri). `AlertController` cere vibrația nivelului printr-o funcție primită din `app.dart`. Ecranul Sunete redă vibrația prin `AlertSignals.vibrate`, aceeași funcție ca alerta reală.

**Tech Stack:** Flutter (Dart), SharedPreferences, `vibration`, flutter_test + fake_async.

**Spec:** `docs/superpowers/specs/2026-10-22-vibratii-alerte-design.md`

## Global Constraints

- Orice text vizibil în `app/lib/l10n/app_ro.arb` și `app_en.arb`; după editare `flutter gen-l10n` (fișierele generate sunt în git).
- `Semantics` pe fiecare rând interactiv; ținte ≥ 48 px; fără înălțimi fixe pentru text; nivelul arătat prin iconiță + etichetă, nu doar culoare.
- Implicit: critical → `Haptic.long`, warning → `Haptic.strong`, info → `Haptic.light`. Cheie `alertHaptics`, JSON `{"critical":"long","warning":"strong","info":"light"}`.
- Durate tipare: long 450 ms, strong 1500 ms, light 150 ms; repetarea la critic = durată + 50 ms.
- Alerta critică nu se închide singură și nu e înlocuită de niveluri mai mici (neschimbat).
- Pe laptop (`presenterFirst`) nimic din toate acestea nu apare.
- Verificare: `cd app && flutter analyze` fără probleme, `flutter test` verde. Flutter: `C:\Users\iulia\dev\flutter\bin`.
- Commit-uri ca `selimayann`, fără atribuire Claude (CLAUDE.md regula 8).

## Review Focus

- Salvare cu două niveluri pe aceeași vibrație (editată manual / versiune veche) → toate revin la implicit. Test în Task 1.
- Alegerea vibrației deja aleasă pentru același nivel → nimic nu se schimbă, fără mesaj de schimb, dar vibrația tot se redă. Test în Task 4.
- Schimbarea vibrației în timp ce o alertă critică e pe ecran → următoarea repetare folosește noua vibrație. Test în Task 2.
- Text 200% pe telefon mic, ecranul Sunete și ecranul de alegere → fără overflow. Test în Task 4.
- Detector indisponibil (web) → cardul spune „Indisponibil…”, comutatorul e dezactivat, alegerea vibrațiilor merge în continuare. Teste în Task 3 și 4.

---

### Task 1: Vibrațiile alese în setări

**Files:**
- Modify: `app/lib/features/alerts/alert_controller.dart` (enum `Haptic`)
- Modify: `app/lib/settings/app_settings.dart`
- Test: `app/test/settings/alert_haptics_test.dart` (nou)

**Interfaces:**
- Produces: `extension HapticTiming on Haptic { Duration get duration; }` (450/1500/150 ms) în `alert_controller.dart`.
- Produces: în `AppSettings`: `static const defaultAlertHaptics = {AlertLevel.critical: Haptic.long, AlertLevel.warning: Haptic.strong, AlertLevel.info: Haptic.light};`, `Map<AlertLevel, Haptic> alertHaptics` (copie a implicitului), `Haptic hapticFor(AlertLevel level)`, `AlertLevel? chooseHaptic(AlertLevel level, Haptic haptic)` — salvează și notifică; dacă altă treaptă folosea `haptic`, îi dă vechea vibrație a lui `level` și întoarce acea treaptă; altfel `null`.

- [ ] **Step 1: Teste care pică** (`SharedPreferences.setMockInitialValues`):
  - `defaults are today's vibrations`: `hapticFor(critical) == long`, `warning == strong`, `info == light`.
  - `choosing another level's vibration swaps the two`: `chooseHaptic(info, Haptic.long)` întoarce `AlertLevel.critical`; apoi `hapticFor(info) == long`, `hapticFor(critical) == light`.
  - `choosing the current vibration changes nothing`: `chooseHaptic(warning, Haptic.strong)` întoarce `null`, harta neschimbată.
  - `the choice survives a restart`: după swap, `AppSettings(prefs)` nou are aceleași valori.
  - `a broken save falls back to the defaults`: prefs `alertHaptics` = `'{"critical":"light","warning":"light","info":"long"}'` → implicitul; la fel `'nu e json'` și `'{"critical":"buzz"}'`.
- [ ] **Step 2:** `flutter test test/settings/alert_haptics_test.dart` → pică (nu compilează).
- [ ] **Step 3: Implementează** în `_load` / `_save` (JSON cu `AlertLevel.name` → `Haptic.name`; valid doar dacă are toate trei nivelurile și trei vibrații distincte).
- [ ] **Step 4:** testul trece; `flutter test` verde.
- [ ] **Step 5: Commit** `Remember the vibration chosen for each alert level`

### Task 2: Alerta folosește vibrația aleasă

**Files:**
- Modify: `app/lib/features/alerts/alert_controller.dart`
- Modify: `app/lib/app.dart:29`
- Test: `app/test/features/alert_controller_test.dart`

**Interfaces:**
- Consumes: `Haptic.duration`, `AppSettings.hapticFor` (Task 1).
- Produces: `AlertController({void Function(Haptic)? haptic, Haptic Function(AlertLevel)? hapticFor})`; fără `hapticFor` → implicitul din `AppSettings.defaultAlertHaptics`. `app.dart` trece `hapticFor: widget.settings.hapticFor`.

- [ ] **Step 1: Teste care pică:**
  - `each level vibrates with the chosen vibration`: `hapticFor` întoarce `{critical: light, warning: long, info: strong}`; `show(horn)` → primul haptic `long`; `show(name)` după dismiss → `strong`.
  - `critical repeats when the chosen pattern ends`: critic = `strong`; `fakeAsync`: după `show(fireAlarm)` și `elapse(1549 ms)` → 1 haptic; după încă 2 ms → 2; după alte 1550 ms → 3.
  - `a new choice applies from the next repeat`: critic = `long` apoi schimbat în `light` după primul haptic; după 500 ms următorul haptic e `light`.
  - Testul existent `critical alerts stay and keep vibrating until dismissed` rămâne verde (implicit long → la 500 ms).
- [ ] **Step 2:** rulează → pică.
- [ ] **Step 3: Implementează:** la critic un `Timer` care, la fiecare tick, citește din nou `hapticFor(critical)`, vibrează și se reprogramează la `duration + 50 ms` (nu `Timer.periodic`). Warning/info: neschimbate în afară de vibrație.
- [ ] **Step 4:** `flutter test` verde.
- [ ] **Step 5: Commit** `Vibrate each alert with the pattern chosen for its level`

### Task 3: Cardul „Sunete” în locul pastilei

**Files:**
- Modify: `app/lib/features/home/home_screen.dart` (bara: linia cu `SoundsPill`; lista: sub `mainAction()`)
- Delete: `app/lib/features/sounds/sounds_pill.dart`
- Modify: ARB-uri (șterge cheile `soundsPill*`; adaugă `homeSounds`, `homeSoundsOn`, `homeSoundsOff`, `homeSoundsPaused`, `homeSoundsUnavailable`)
- Test: `app/test/features/home_screen_test.dart`, `app/test/features/sounds_screen_test.dart` (șterge cele două teste ale pastilei)

**Interfaces:**
- Consumes: `services.soundListening` (`wanted`, `paused`), `services.sounds.isAvailable`.
- Produces: cardul e un `_MainAction(icon: Icons.hearing / Icons.hearing_disabled, title: l10n.homeSounds, hint: <starea>, onTap: open(SoundsScreen()))`, reconstruit cu `ListenableBuilder(listenable: services.soundListening)`.

Texte (RO / EN):
- `homeSounds`: „Sunete” / „Sounds”
- `homeSoundsOn`: „Pornit: telefonul te alertează la alarme, claxoane și numele tău.” / „On: your phone alerts you to alarms, horns and your name.”
- `homeSoundsOff`: „Oprit: atinge ca să pornești alertele de sunet.” / „Off: tap to turn sound alerts on.”
- `homeSoundsPaused`: „Pe pauză cât rulează subtitrările.” / „Paused while captions run.”
- `homeSoundsUnavailable`: „Indisponibil pe acest dispozitiv: atinge pentru detalii.” / „Not available on this device: tap for details.”

- [ ] **Step 1: Teste care pică** (în `home_screen_test.dart`):
  - `phone: the Sounds card says the state and opens the Sounds screen`: cu detector disponibil și ascultare oprită, `find.text(l10n.homeSoundsOff)`; `enable()` → `homeSoundsOn`; tap pe `l10n.homeSounds` → `SoundsScreen` găsit.
  - `phone: without a detector the card says it is unavailable` → `homeSoundsUnavailable`.
  - În `phone: one main action...` și `laptop: ...`: nu există `find.byType(SoundsPill)` (se scoate referința); pe laptop `find.text(l10n.homeSounds)` → `findsNothing`.
- [ ] **Step 2:** rulează → pică.
- [ ] **Step 3: Implementează;** șterge pastila și testele ei.
- [ ] **Step 4:** `flutter gen-l10n`, `flutter analyze`, `flutter test` verde.
- [ ] **Step 5: Commit** `Replace the Sounds pill with a Sounds card on the home screen`

### Task 4: Ecranul Sunete: explicație, comutator, alegerea vibrațiilor

**Files:**
- Modify: `app/lib/features/sounds/sounds_screen.dart`
- Create: `app/lib/features/sounds/vibration_picker.dart` (ecranul de alegere pentru un nivel)
- Modify: ARB-uri
- Test: `app/test/features/sounds_screen_test.dart`

**Interfaces:**
- Consumes: `AppSettings.hapticFor/chooseHaptic` (Task 1), `services.alertSignals.vibrate(Haptic)`, `levelIcon`/`levelLabel` dacă există în `alert_overlay.dart`, altfel definite aici.
- Produces: `VibrationPicker({required AlertLevel level})` (pagină `MaterialPageRoute`); `String hapticName(AppLocalizations, Haptic)`, `String hapticDescription(AppLocalizations, Haptic)`.

Structura ecranului Sunete (listă grupată, stil iOS, după `EchoPalette`): explicația (`soundsExplain`), `SwitchListTile` „Alerte de sunet” (`soundsSwitch`) cu starea de azi ca live region și dezactivat fără detector (+ `soundsDetectorMissing`), secțiunea `soundsVibrations` cu 3 rânduri (iconiță + `levelLabel` + exemple `soundsLevelExamples{Critical,Warning,Info}` + în dreapta `hapticName` + chevron), secțiunea `soundsTest` cu butoanele de azi.

Ecranul de alegere: titlu = nivelul; 3 rânduri (`hapticName`, `hapticDescription`, „Folosită la {nivel}” dacă e a altui nivel, bifă la cea aleasă, `Semantics(selected:, button: true)`); atingere → `alertSignals.vibrate(h)` apoi `chooseHaptic`; dacă întoarce un nivel → SnackBar `vibrationSwapped(level, haptic)` + `SemanticsService.announce`. Notă sub listă la critic: `vibrationCriticalRepeats`.

Texte (RO / EN): `hapticLong` „Lungă” / „Long” — `hapticLongHint` „Un buzz lung și puternic” / „One long, strong buzz”; `hapticStrong` „Triplă” / „Triple” — „Trei buzz-uri puternice la rând” / „Three strong buzzes in a row”; `hapticLight` „Scurtă” / „Short” — „Un buzz scurt și ușor” / „One short, light buzz”; `soundsExplain` „Telefonul ascultă sunetele din jur, direct pe dispozitiv: nimic nu pleacă pe internet. Când recunoaște un sunet, ecranul se schimbă și telefonul vibrează. Alertele critice acoperă orice ecran până le închizi.” / EN echivalent; `soundsSwitch` „Alerte de sunet” / „Sound alerts”; `soundsVibrations` „Vibrații” / „Vibrations”; exemple: „Alarmă de incendiu, sirenă” / „Claxon, sticlă spartă” / „Numele tău, telefon, ușă” (EN echivalent); `vibrationUsedBy` „Folosită la {level}”; `vibrationSwapped` „{level} folosește acum {haptic}”; `vibrationCriticalRepeats` „La alertele critice vibrația se repetă până închizi alerta.”

- [ ] **Step 1: Teste care pică** (cu `AlertSignals` fals care înregistrează `vibrate`):
  - `the Sounds screen explains itself and switches listening`: `find.text(l10n.soundsExplain)`; tap pe switch → `soundListening.wanted == true`; încă un tap → `false`.
  - `each level shows its chosen vibration`: rândurile Critic/Important/Informativ arată „Lungă”/„Triplă”/„Scurtă”.
  - `tapping a vibration plays it and chooses it`: deschide Informativ, tap „Triplă” → fals a primit `[Haptic.strong]`; `settings.hapticFor(info) == strong`, `hapticFor(warning) == light`; SnackBar cu `vibrationSwapped(...)`; rândul „Triplă” are `Semantics` selectat.
  - `tapping the current vibration only plays it`: Critic, tap „Lungă” → vibrate `[long]`, fără SnackBar, harta neschimbată.
  - `without a detector the switch is off but vibrations can be chosen`: switch dezactivat, `soundsDetectorMissing` vizibil, alegerea merge.
  - `200% text on a small phone does not overflow` pentru ambele ecrane (`tester.view.physicalSize = Size(320*3, 568*3)`, `devicePixelRatio = 3`, `textScale = 2`).
- [ ] **Step 2:** rulează → pică.
- [ ] **Step 3: Implementează** (direcție vizuală cu `taste-skill:design-taste-frontend` / `apple-design`; regulile de accesibilitate au prioritate).
- [ ] **Step 4:** `flutter gen-l10n`, `flutter analyze`, `flutter test` verde; `flutter build web --dart-define=ECHO_PHONE_PREVIEW=true -o build/web-phone`, verificare vizuală în Chrome (Playwright) a cardului, ecranului Sunete și alegerii.
- [ ] **Step 5: Commit** `Explain sound alerts and let each level pick its vibration, felt on tap`
