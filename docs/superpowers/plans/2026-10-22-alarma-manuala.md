# Alarma dată de un coleg: plan de implementare

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un coleg autentificat dă de mână o alarmă (4 tipuri); toți cei autentificați aflați la cel mult 500 m o primesc prin alerta existentă a lui Petru; serverul predă cine a dat-o unui `AlarmRecorder`.

**Architecture:** Serverul FastAPI primește alarma (`POST /api/alarms`), cere cont, o predă lui `AlarmRecorder` și o difuzează pe `/ws/alarms` (în memorie sau prin Redis). Fiecare telefon autentificat ascultă canalul, își compară poziția cu a alarmei și, dacă e în rază, trimite notificarea prin `AlertSignals` și arată ecranul prin `AlertController`. Codul lui Petru (`app/lib/features/alerts/`) și baza de date nu se modifică.

**Tech Stack:** FastAPI, pytest, fakeredis; Flutter, `web_socket_channel`, `http`, `geolocator` (nou).

**Spec:** `docs/superpowers/specs/2026-10-22-alarma-manuala-design.md`

## Global Constraints

- Nu se modifică nimic în `app/lib/features/alerts/`, `supabase/` sau în schema bazei de date.
- Raza: arată dacă `distanța ≤ 500 m + min(precizia celui care primește, 100 m)`; poziție necunoscută → arată oricum.
- Alarme active: 15 minute de la `at`, dacă nu sunt anulate.
- Limită: 3 alarme pe oră per cont, cheia `alarm:user:<id>`; peste ea 429 cu `Retry-After`.
- Tipuri pe fir: `fire`, `evacuation`, `siren`, `machine`.
- Mesajele de pe `/ws/alarms` nu conțin niciodată `user_id`, `email` sau `ip`.
- Orice text vizibil prin `app_ro.arb` și `app_en.arb` (după editare: `flutter gen-l10n`).
- Accesibilitate (CLAUDE.md, regula 4) și `docs/reguli-frontend.md` pe ecranul nou; stilul paginii principale (`EchoPalette`, `EchoButtons`, `Pressable`).
- Commituri ca Denis David, fără atribuire Claude.

## Review Focus

- **Aceeași alarmă primită de două ori** (o dată din lista alarmelor active la reconectare, o dată live): se arată o singură dată. Test în Task 5.
- **Tokenul expiră cât e deschis canalul** (serverul închide cu 4401): aplicația se reconectează cu tokenul nou, nu se oprește. Test în Task 5.
- **Utilizatorul se deconectează din cont**: fluxul se oprește și nu mai arată alarme. Test în Task 6.
- **Anularea unei alarme care nu se vede** (altă alertă pe ecran sau alarma în afara razei): nu închide alerta altcuiva. Test în Task 5.
- **Telefonul care a dat alarma o primește înapoi** din lista alarmelor active, după repornire: o ignoră. Test în Task 5.

---

### Task 1: Server: cine e contul (email) și ruta care cere cont

**Files:**
- Modify: `server/app/auth.py`
- Modify: `server/app/main.py` (dependența nouă, lângă `caller`)
- Test: `server/tests/test_alarms.py` (nou)

**Interfaces:**
- Produces: `TokenVerifier.identity(token: str) -> Identity`, cu `@dataclass(frozen=True) class Identity: user_id: str; email: str | None`. `user_id()` rămâne și se sprijină pe `identity()`.
- Produces (în `create_app`): dependența `account_caller(request) -> AccountCaller` (`user_id`, `email`, `ip`); `verifier is None` → 503 „Accounts are not configured on this server”; fără `Bearer` → 401; token invalid → 401.

- [ ] **Step 1: Write the failing tests** în `test_alarms.py`, refolosind `token()` și `SECRET` din `tests/test_accounts.py` (tokenul primește opțional `email`):
  - `test_identity_reads_the_email`: `identity(token(email="ana@firma.ro"))` → `Identity("user-1", "ana@firma.ro")`.
  - `test_raising_an_alarm_needs_an_account`: `POST /api/alarms` fără antet → 401.
  - `test_alarms_need_accounts_configured`: `create_app(ai_client=None, verifier=None)`, cu token → 503.
- [ ] **Step 2:** `cd server && .venv/bin/python -m pytest tests/test_alarms.py -v` → FAIL (`identity` nu există; ruta lipsește → 404/405).
- [ ] **Step 3:** Implementează `Identity` și `identity()` în `auth.py` (același `jwt.decode`; `email = claims.get("email")`). Adaugă `account_caller` în `main.py`. Ruta `POST /api/alarms` vine în Task 3; ca testele să treacă acum, înregistreaz-o deja cu corpul `raise NotImplementedError`, iar Task 3 o completează.
- [ ] **Step 4:** pytest pe tot serverul → PASS (inclusiv `test_accounts.py`).
- [ ] **Step 5: Commit** `git add server && git commit -m "Server: read the account email and require an account for alarms"`

### Task 2: Server: fluxul de alarme (`alarms.py`)

**Files:**
- Create: `server/app/alarms.py`
- Test: `server/tests/test_alarms.py`

**Interfaces:**
- Produces:
  - `AlarmKind = Literal["fire", "evacuation", "siren", "machine"]`
  - `class AlarmIn(BaseModel)`: `kind: AlarmKind`, `lat: float` (−90…90), `lon: float` (−180…180), `accuracy_m: float` (≥ 0).
  - `@dataclass Alarm`: `id: str` (`secrets.token_urlsafe(8)`), `kind`, `at: float` (epoch s), `lat`, `lon`, `accuracy_m`, `cancelled: bool = False`; `public() -> dict` = `{"type": "alarm", id, kind, at, lat, lon, accuracy_m}`.
  - `class AlarmRecorder(Protocol)`: `async def record(self, entry: dict) -> None`. `entry` = `{event: "raised" | "cancelled", id, kind, at, lat, lon, accuracy_m, user_id, email, ip}`.
  - `class LogRecorder`: scrie `entry` ca JSON într-un `logging.getLogger("echo.alarms")` la nivel WARNING (să se vadă în `docker compose logs`). E cel implicit; Petru îl înlocuiește cu salvarea în baza de date.
  - `class AlarmFeed(Protocol)`: `start()`, `close()`, `async add(alarm, owner: str)`, `async cancel(id: str, owner: str) -> Literal["ok", "missing", "forbidden"]`, `async active(now: float) -> list[Alarm]`, `subscribe(socket)`, `unsubscribe(socket)`.
  - `LocalAlarmFeed(send=send_json, clock=time.time)` și `RedisAlarmFeed(redis, send=send_json, clock=time.time)`. Redis: `echo:alarms:active` (hash id → JSON, cu `owner`), expirare 900 s după ultima scriere, curățat de cele mai vechi de 900 s la citire; canalul pub/sub `echo:alarms`. Livrarea către socketurile locale, ca în `RedisHub._listen`.
  - `ACTIVE_SECONDS = 900`.

- [ ] **Step 1: Write the failing tests**, pentru ambele feeduri (parametrizat; Redis prin `fakeredis.aioredis.FakeRedis(decode_responses=True)`, ca în `test_redis.py`), cu un `send` care adună în listă și un ceas fals:
  - `test_new_alarm_reaches_subscribers`: `subscribe(s)`, `add(a, "u1")` → `s` primește `a.public()`.
  - `test_cancel_by_someone_else_is_forbidden`: `cancel(a.id, "u2")` → `"forbidden"`, nimic trimis.
  - `test_cancel_by_owner_reaches_subscribers`: → `"ok"`, `s` primește `{"type": "alarm_cancelled", "id": a.id}`; `active()` nu mai conține `a`.
  - `test_unknown_alarm_is_missing`: `cancel("nope", "u1")` → `"missing"`.
  - `test_alarms_stop_being_active_after_15_minutes`: ceas +899 s → în `active()`; +901 s → nu.
  - `test_public_message_has_no_identity`: cheile din `a.public()` nu includ `user_id`, `email`, `ip`, `owner`.
- [ ] **Step 2:** pytest → FAIL (modulul lipsește).
- [ ] **Step 3:** Implementează `server/app/alarms.py` după interfețe.
- [ ] **Step 4:** pytest → PASS.
- [ ] **Step 5: Commit** `git commit -m "Server: alarm feed in memory and through Redis"`

### Task 3: Server: rutele de alarmă

**Files:**
- Modify: `server/app/main.py` (`create_app` primește `alarm_feed: AlarmFeed | None = None`, `recorder: AlarmRecorder | None = None`; Redis → `RedisAlarmFeed`, altfel `LocalAlarmFeed`; `start/close` în `lifespan`)
- Test: `server/tests/test_alarms.py`

**Interfaces:**
- Consumes: `account_caller` (Task 1), `AlarmIn`, `Alarm`, `AlarmFeed`, `AlarmRecorder` (Task 2), `Limiter.hit`.
- Produces:
  - `POST /api/alarms` (corp `AlarmIn`) → 201 `{"id", "at"}`.
  - `POST /api/alarms/{id}/cancel` → 200 `{"id"}`; 403 dacă nu e autorul, 404 dacă nu există.
  - `WS /ws/alarms`, **declarat înaintea** `/ws/{code}`: acceptă, așteaptă max 10 s primul mesaj `{"type": "auth", "token"}`; token lipsă sau invalid → închide cu 4401; conturi neconfigurate → 4503. Apoi trimite `{"type": "auth_ok"}`, fiecare alarmă activă (`public()`), apoi live. Mesajele ulterioare ale clientului se ignoră.

- [ ] **Step 1: Write the failing tests** (`TestClient`, `verifier=TokenVerifier(secret=SECRET)`, un `FakeRecorder` care adună `entry`):
  - `test_alarm_reaches_a_listening_phone`: WS `/ws/alarms`, trimite auth, primește `auth_ok`; `POST /api/alarms` cu `{"kind": "fire", "lat": 44.43, "lon": 26.10, "accuracy_m": 12}` → 201; WS primește `{"type": "alarm", "kind": "fire", …}` fără chei de identitate.
  - `test_alarm_is_recorded_with_the_account`: `FakeRecorder` primește `event="raised"`, `user_id="user-1"`, `email="ana@firma.ro"`, `ip` nevid.
  - `test_unknown_kind_is_rejected`: `kind="flood"` → 422; `lat=91` → 422.
  - `test_only_the_author_can_cancel`: alt cont → 403; autorul → 200, WS primește `alarm_cancelled`, recorder primește `event="cancelled"` cu contul autorului.
  - `test_new_listener_gets_active_alarms`: alarmă dată, apoi WS nou → după `auth_ok` primește alarma.
  - `test_listening_needs_an_account`: WS cu token greșit → închis cu 4401.
  - `test_fourth_alarm_in_an_hour_is_refused`: a 4-a → 429 cu `Retry-After`; limita AI a aceluiași cont nu e atinsă (un apel `/api/ai/simplify` merge).
  - `test_meeting_sockets_still_work`: `/ws/{code}` cu o sesiune creată merge ca înainte.
- [ ] **Step 2:** pytest → FAIL.
- [ ] **Step 3:** Implementează rutele în `main.py`. Limita: `limiter.hit(f"alarm:user:{who.user_id}", 3)`.
- [ ] **Step 4:** pytest pe tot serverul → PASS.
- [ ] **Step 5:** Adaugă în `docker-compose.yml` nimic; în `README.md` (secțiunea serverului) o linie: rutele de alarmă și că `AlarmRecorder` doar loghează până îl leagă Petru de baza de date.
- [ ] **Step 6: Commit** `git commit -m "Server: raise, cancel and listen to colleague alarms"`

### Task 4: Aplicație: logica pură și textele

**Files:**
- Create: `app/lib/features/emergency/alarm_logic.dart`
- Modify: `app/lib/l10n/app_ro.arb`, `app/lib/l10n/app_en.arb` (+ `flutter gen-l10n`)
- Test: `app/test/features/alarm_logic_test.dart`

**Interfaces:**
- Produces:
  - `enum AlarmKind { fire, evacuation, siren, machine }` cu `String get wire` (`fire`, `evacuation`, `siren`, `machine`), `static AlarmKind? fromWire(String)`, `AlertLevel get level` (machine = warning, restul critical), `SoundKind get sound` (fire→fireAlarm, evacuation→location, siren→siren, machine→lineSignal), `IconData get icon` (fire/siren/machine: `soundIcon(sound)` din codul lui Petru; evacuation: `Icons.directions_run`).
  - `class Alarm { id, kind, at (DateTime), lat, lon, accuracyM; static Alarm? fromJson(Map) }`.
  - `class Position { lat, lon, accuracyM }`.
  - `double distanceMeters(double lat1, double lon1, double lat2, double lon2)` (haversine, R = 6 371 000 m).
  - `bool inRange(Alarm alarm, Position? here)`: `here == null` → true; altfel `distance ≤ 500 + min(here.accuracyM, 100)`.
  - `String alarmName(AppLocalizations l10n, AlarmKind kind)`.
  - `SoundAlert toSoundAlert(AppLocalizations l10n, Alarm alarm)` = `SoundAlert(kind.sound, at: alarm.at, label: l10n.alarmFromColleague(alarmName(l10n, kind)), level: kind.level)`.
  - Chei ARB noi (RO / EN): `alarmFire` „Incendiu” / „Fire”; `alarmEvacuation` „Evacuare” / „Evacuation”; `alarmSiren` „Sirenă sau pericol afară” / „Siren or danger outside”; `alarmMachine` „Pericol la un utilaj” / „Machine hazard”; `alarmFromColleague` „{name} · semnalat de un coleg” / „{name} · raised by a colleague”. Textele ecranului vin în Task 7.

- [ ] **Step 1: Write the failing tests:**
  - `distanceMeters(44.4268, 26.1025, 44.4268, 26.1025)` = 0; București–Ploiești (44.4268, 26.1025 → 44.9419, 26.0225) în 57 000 ± 1 000 m.
  - Pe aceeași longitudine, 1° latitudine = 111 195 m: puncte la 499 m → `inRange` true cu precizie 0; 501 m → false cu precizie 0; 590 m cu precizie 90 → true; 650 m cu precizie 400 → false (plafon 100).
  - `inRange(alarm, null)` → true.
  - Fiecare tip → `SoundKind` și `AlertLevel` din tabelul specului; `toSoundAlert` pe `fire` în RO are `label == "Incendiu · semnalat de un coleg"`.
  - `Alarm.fromJson` cu `kind: "flood"` → null.
- [ ] **Step 2:** `cd app && flutter test test/features/alarm_logic_test.dart` → FAIL.
- [ ] **Step 3:** Implementează; adaugă cheile ARB; `flutter gen-l10n`.
- [ ] **Step 4:** test → PASS; `flutter analyze` → No issues.
- [ ] **Step 5: Commit** `git commit -m "App: alarm kinds, 500 m range and mapping onto sound alerts"`

### Task 5: Aplicație: API-ul și fluxul de alarme

**Files:**
- Create: `app/lib/features/emergency/alarm_api.dart`, `app/lib/features/emergency/alarm_feed.dart`, `app/lib/features/emergency/position_source.dart`
- Modify: `app/pubspec.yaml` (`geolocator`), `app/ios/Runner/Info.plist` (`NSLocationWhenInUseUsageDescription`, text RO despre raza de 500 m), `app/android/app/src/main/AndroidManifest.xml` (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`)
- Test: `app/test/features/alarm_feed_test.dart`

**Interfaces:**
- Consumes: `Alarm`, `Position`, `inRange`, `toSoundAlert` (Task 4); `AccountService.accessToken`, `AccountService.user`; `ChannelFactory`; `AlertSignals.notify`; `AlertController.show/dismiss/current`.
- Produces:
  - `abstract class PositionSource { Future<Position?> current({Duration timeout}); Future<Position?> lastKnown(); }` + `GeolocatorPositionSource` (cere permisiunea „cât timp folosești aplicația”; orice eroare → null).
  - `class AlarmApi(Uri server, {http.Client? client, required String? Function() token})`: `Future<RaisedAlarm> raise(AlarmKind kind, Position at)` (`RaisedAlarm {id, at}`), `Future<void> cancel(String id)`; aruncă `AlarmError(AlarmProblem problem, {int? retryAfterSeconds})` cu `enum AlarmProblem { signedOut, notConfigured, tooMany, offline, failed }` (401 → signedOut, 503 → notConfigured, 429 → tooMany, excepție de rețea → offline, altfel failed).
  - `class AlarmFeed(Uri server, {required AccountService account, required PositionSource positions, required void Function(Alarm alarm) onAlarm, required void Function(String id) onCancelled, ChannelFactory? channelFactory})`: `start()`, `stop()`, `void markOwn(String id)`. Socket la `ws(s)://…/ws/alarms`; primul mesaj auth cu `account.accessToken`; reconectare cu întârziere crescătoare (1, 2, 4… max 30 s), inclusiv după 4401, cu tokenul curent. Fiecare `id` produce cel mult un `onAlarm`; idurile marcate cu `markOwn` nu produc nimic. Poziția: `current(timeout: 5 s)`, altfel `lastKnown()`; `onAlarm` doar dacă `inRange`.
  - `class AlarmPresenter(AlertController alerts, AlertSignals signals, AppLocalizations Function() l10n)`: `show(Alarm)` → `signals.notify(sa, sa.label!, l10n.alertOpenApp)` apoi `alerts.show(sa)`, ține minte ce `SoundAlert` a arătat pentru id; `cancelled(id)` → `alerts.dismiss()` doar dacă `identical(alerts.current, cel arătat pentru id)`, și `signals.clear()` tot atunci.

- [ ] **Step 1: Write the failing tests** (`FakeChannel` din `test/fakes.dart`, un `PositionSource` fals, un `AccountService` fals cu token schimbabil, un `AlertSignals` fals care adună apelurile):
  - `sends the token first`: primul mesaj trimis = `{"type": "auth", "token": "t1"}`.
  - `an alarm in range is shown once`: aceeași alarmă primită de două ori → un singur `onAlarm`.
  - `an alarm out of range is ignored`: poziție la 2 km → niciun `onAlarm`.
  - `no position at all still shows the alarm`: `current` și `lastKnown` → null → `onAlarm`.
  - `own alarms are ignored`: `markOwn(id)` apoi alarma cu acel id → nimic.
  - `reconnects with the new token after 4401`: închidere 4401, tokenul devine `t2`, după retry primul mesaj pe noul canal are `t2`.
  - `AlarmPresenter`: `show` cheamă `notify` și `alerts.current` devine alerta cu labelul colegului; `cancelled(id)` o închide; `cancelled(id)` când pe ecran e altă alertă (dată cu `alerts.show` direct) nu o închide.
  - `AlarmApi`: cu un `http.Client` fals (`MockClient`), 201 → `RaisedAlarm`; 401/503/429 → `AlarmProblem`-ul potrivit, 429 cu `retryAfterSeconds` din antet; antetul `Authorization: Bearer t1` e trimis.
- [ ] **Step 2:** `flutter test test/features/alarm_feed_test.dart` → FAIL.
- [ ] **Step 3:** `flutter pub add geolocator`; implementează cele trei fișiere; Info.plist și AndroidManifest.
- [ ] **Step 4:** test → PASS; `flutter analyze` → No issues.
- [ ] **Step 5: Commit** `git commit -m "App: listen for colleague alarms and show those within 500 m"`

### Task 6: Aplicație: legarea în `services.dart` și `app.dart`

**Files:**
- Modify: `app/lib/core/services.dart` (`AppServices` primește opțional `PositionSource? positions`; implicit `GeolocatorPositionSource()`)
- Modify: `app/lib/app.dart` (`_EchoAppState`: un `AlarmFeed` creat când `account` există; pornit la autentificare, oprit la deconectare, prin `account.addListener`; `onAlarm` → `AlarmPresenter.show`, `onCancelled` → `AlarmPresenter.cancelled`)
- Test: `app/test/features/alarm_wiring_test.dart`

**Interfaces:**
- Consumes: `AlarmFeed`, `AlarmPresenter` (Task 5), `defaultServer(settings)`.
- Produces: `AppServices.positions`. `AlarmPresenter` primește l10n prin `lookupAppLocalizations(widget.settings.locale ?? const Locale('ro'))`.

- [ ] **Step 1: Write the failing tests** (`EchoApp` cu servicii false, `channelFactory` fals):
  - `signed in: a colleague alarm covers the screen`: canalul primește o alarmă `fire` în rază → pe ecran „Incendiu · semnalat de un coleg” și sfatul alarmei de incendiu.
  - `signed out: no socket is opened`: fără utilizator, `channelFactory` nu e chemat.
  - `signing out stops the feed`: după deconectare, o alarmă pe vechiul canal nu mai apare.
- [ ] **Step 2:** test → FAIL.
- [ ] **Step 3:** Implementează legarea.
- [ ] **Step 4:** `flutter test` (toate) → PASS; `flutter analyze` → No issues.
- [ ] **Step 5: Commit** `git commit -m "App: start the alarm feed while signed in"`

### Task 7: Aplicație: ecranul „Alarmă de urgență” și intrarea de pe ecranul principal

**Files:**
- Create: `app/lib/features/emergency/emergency_screen.dart`
- Modify: `app/lib/features/home/home_screen.dart` (un `_ToolRow` în panoul „În afara meetingurilor”, doar când `account?.isSignedIn == true`, iconița `Icons.emergency_share`)
- Modify: ARB-urile (+ `flutter gen-l10n`)
- Test: `app/test/features/emergency_screen_test.dart`

**Interfaces:**
- Consumes: `AlarmApi`, `AlarmError`, `AlarmProblem`, `PositionSource` (Task 5); `AlarmKind` (Task 4); `AlarmFeed.markOwn` (prin `EchoApp`; ecranul primește un `void Function(String id) onRaised`).
- Produces: `EmergencyScreen({required AlarmApi api, required PositionSource positions, required void Function(String id) onRaised})`.
- Chei ARB (RO / EN): `emergencyTitle` „Alarmă de urgență” / „Emergency alarm”; `emergencyHomeHint` „Când aplicația nu aude pericolul” / „When the app can't hear the danger”; `emergencyIntro` „Alarma ajunge la colegii aflați la cel mult 500 m.” / „The alarm reaches colleagues within 500 m.”; `emergencyAccountable` „Numele tău se păstrează odată cu alarma.” / „Your name is kept with the alarm.”; `alarmLevelCritical` „Critic” / „Critical”; `alarmLevelWarning` „Atenție” / „Warning”; `emergencyConfirm` „Trimiți alarma „{name}”?” / „Send the „{name}” alarm?”; `emergencySend` „Trimite alarma” / „Send alarm”; `emergencyCancelDialog` „Renunță” / „Cancel”; `emergencySent` „Alarmă trimisă la {time}” / „Alarm sent at {time}”; `emergencyCancelAlarm` „Anulează alarma” / „Cancel the alarm”; `emergencyCancelConfirm` „Anulezi alarma pentru toți colegii?” / „Cancel the alarm for everyone?”; `emergencyCancelled` „Alarmă anulată” / „Alarm cancelled”; `emergencySending` „Se trimite…” / „Sending…”; `emergencyErrorSignedOut` „Intră în cont ca să poți da o alarmă.” / „Sign in to raise an alarm.”; `emergencyErrorLocation` „Permite accesul la locație din Setări, ca alarma să ajungă la cine e aproape.” / „Allow location access in Settings so the alarm reaches people nearby.”; `emergencyErrorTooMany` „Ai dat deja 3 alarme în ultima oră. Încearcă din nou peste {minutes} min.” / „You've raised 3 alarms in the last hour. Try again in {minutes} min.”; `emergencyErrorOffline` „Nu ajungem la server. Verifică internetul și încearcă din nou.” / „Can't reach the server. Check the internet and try again.”; `emergencyErrorFailed` „Alarma nu a plecat. Încearcă din nou.” / „The alarm didn't go out. Try again.”; `emergencyErrorNotConfigured` „Serverul nu are conturi pornite. Anunță administratorul.” / „The server has no accounts set up. Tell the administrator.”

- [ ] **Step 1: Write the failing tests** (`AlarmApi` cu `MockClient`, `PositionSource` fals):
  - `four kinds with their level in words`: 4 rânduri, fiecare cu nume, iconiță și „Critic” sau „Atenție”; textul despre răspundere e vizibil.
  - `raise flow`: atinge „Incendiu” → dialog cu „Trimiți alarma „Incendiu”?” → „Trimite alarma” → cererea are `kind: "fire"` și poziția falsă; apare „Alarmă trimisă la …”; `onRaised` primește idul.
  - `cancelling the dialog sends nothing`.
  - `cancel flow`: „Anulează alarma” → confirmare → cerere la `/api/alarms/{id}/cancel` → „Alarmă anulată”.
  - `no position: explains how to fix it`: `current` și `lastKnown` → null → `emergencyErrorLocation`, nicio cerere.
  - `429: tells when to try again`: `Retry-After: 1200` → „… peste 20 min.”.
  - `semantics`: fiecare rând e buton cu eticheta „Incendiu, Critic”; ținte ≥ 48 px la scalare de text 2,0, fără overflow.
  - `home: the row appears only when signed in` (în `home_screen_test.dart`).
- [ ] **Step 2:** test → FAIL.
- [ ] **Step 3:** Implementează ecranul (stilul paginii principale, `Pressable`, `EchoButtons.primary` pentru „Trimite alarma”, butonul de anulare ca link) și rândul de pe ecranul principal. Butonul de trimitere arată „Se trimite…” și rămâne de aceeași lățime cât pleacă cererea.
- [ ] **Step 4:** `flutter test` → PASS; `flutter analyze` → No issues; `flutter build web` → reușește (fără a deschide browserul).
- [ ] **Step 5:** În specul alarmei, „Stare: implementat”; în `docs/superpowers/plans/2026-10-22-demo.md`, pasul de verificare manuală cu două telefoane.
- [ ] **Step 6: Commit** `git commit -m "App: emergency alarm screen and home entry"`
