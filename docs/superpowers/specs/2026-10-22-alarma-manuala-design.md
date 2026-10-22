# Alarma dată de un coleg (design)

**Data:** 2026-10-22 · **Stare:** implementat (aprobat de Denis David) · **Pornește de la:** `2026-10-22-sunetul-vizibil-design.md`, `2026-10-22-ecrane-alerta-design.md` (alertele lui Petru), `2026-10-22-conturi-si-baza-de-date-design.md` (conturile)

## Intenție

Detectorul de sunete al lui Petru nu prinde orice: o alarmă prea slabă, una pe care modelul n-o recunoaște, sau o urgență care nu se aude deloc. Atunci un coleg care aude, din firmă, dă alarma de mână din aplicație. Colegii surzi și cu deficiențe de auz aflați în apropiere o primesc exact ca pe o alertă detectată: ecran roșu sau galben, vibrație, notificare, sfat.

Alarma nu e anonimă. Se păstrează cine a dat-o, când și de unde, ca nimeni să n-o dea în glumă și ca cineva să poată fi tras la răspundere.

## Obiective

1. Un coleg autentificat dă o alarmă în cel mult 3 atingeri: butonul, tipul, confirmarea.
2. Cei care au aplicația și sunt la cel mult **500 m** de locul în care s-a dat alarma o primesc în câteva secunde. Cei mai departe (de exemplu cei de acasă) nu o primesc.
3. Fiecare alarmă și fiecare anulare produc o înregistrare cu contul celui care le-a dat, ora și locul, predată prin `AlarmRecorder`. Salvarea ei în baza de date o face Petru. *(2026-10-23: făcut, în baza de date, nu într-un fișier; vezi `2026-10-23-istoric-activitate-design.md`.)*
4. Cel care a dat alarma o poate anula dacă a greșit; anularea închide alerta la ceilalți.

## Non-obiective

- **Push real (APNs / FCM)**: rămâne pentru după demo. Fără el, alarma ajunge doar la telefoanele pe care aplicația e deschisă sau rulează în fundal (ascultarea permanentă a lui Petru o ține pornită în fundal pe iPhone). Cu aplicația închisă de tot nu ajunge nimic.
- **Istoric de alarme în aplicație** (ecran pentru HR sau șefi): după demo.
- **Firme / organizații**: nu există încă; primesc toți cei cu aplicația din rază, indiferent de firmă.
- **Schimbări în codul lui Petru** (`features/alerts/`): nu se fac. Îl folosim cum e.
- **Schimbări în baza de date** (Supabase: tabele, migrații, configurație): nu se fac.

## Anti-obiective

- Să se poată da o alarmă fără cont, adică anonim.
- Să ajungă alarma la oameni care nu sunt în clădire.
- Să se trimită sau să se păstreze poziția celor care **primesc** alarme. Se păstrează doar locul de unde s-a dat alarma.
- Ca numele celui care a dat alarma să apară pe ecranul altora.

## Constrângeri

- Regulile din `CLAUDE.md`: fără audio sau video pe server (aici circulă doar text și coordonate), rolul și nivelul nu doar prin culoare, alerta critică are prioritate absolută, accesibilitate în fiecare ecran, texte doar prin ARB (RO și EN).
- `docs/reguli-frontend.md` pentru ecranul nou (focus, ținte de 48 px, confirmare la acțiuni importante, erori care spun ce urmează).
- Stilul paginii principale (Taste, `EchoPalette`, `EchoButtons`, `Pressable`).
- Demo mâine (2026-10-23); orice alegere favorizează un demo care merge sigur.

## Tipurile de alarmă (decis cu Denis)

| Tip | Nivel | Cum o arată alerta lui Petru |
|---|---|---|
| Incendiu | Critic | `SoundAlert(SoundKind.fireAlarm, label: …)`: iconița și sfatul alarmei de incendiu |
| Evacuare | Critic | `SoundAlert(SoundKind.location, label: …, level: AlertLevel.critical)`: ca un sunet învățat, fără sfat |
| Sirenă / pericol extern | Critic | `SoundAlert(SoundKind.siren, label: …)`: iconița și sfatul sirenei |
| Pericol la un utilaj | Atenție | `SoundAlert(SoundKind.lineSignal, label: …)`: iconița și sfatul semnalului de utilaj |

`label` e numele alarmei urmat de faptul că a dat-o un om, de exemplu „Incendiu · semnalat de un coleg”. `alertLabel` din codul lui Petru afișează deja `label` când există, iar sfatul rămâne cel al tipului. Astfel cel care primește știe că nu e o detecție automată, fără să afle cine a dat-o.

## Cum funcționează

```
Coleg (aude, autentificat)                  Server FastAPI                      Ceilalți (aplicația deschisă / în fundal)
  buton „Alarmă de urgență”
  → alege tipul → confirmă
  → poziția GPS curentă
  → POST /api/alarms  (token Supabase) ──→  verifică tokenul (auth.py)
                                            predă înregistrarea (AlarmRecorder)
                                            trimite pe /ws/alarms ─────────────→  fiecare telefon:
                                                                                  distanța față de alarmă ≤ 500 m ?
                                                                                    da → AlertController.show(...)
                                                                                    nu → ignoră
  „Anulează alarma”
  → POST /api/alarms/{id}/cancel ────────→  doar autorul; AlarmRecorder
                                            trimite anularea ──────────────────→  închide alerta, dacă e aceea
```

### Serverul (`server/app/alarms.py`, rute în `main.py`)

- `POST /api/alarms` cu `{kind, lat, lon, accuracy_m}`. **Cere cont**: fără token sau fără Supabase configurat pe server răspunde 401 / 503 cu un mesaj clar. Validează tipul (unul din cele 4) și coordonatele. Răspunde `{id, at}`.
- `POST /api/alarms/{id}/cancel`: doar contul care a dat alarma (altfel 403).
- Limită anti-abuz: cel mult 3 alarme pe oră per cont, prin `Limiter`-ul existent, cu cheie proprie `alarm:user:<id>` ca să nu se amestece cu limita AI (429 cu `Retry-After`).
- Rutele de alarmă au propria dependență de autentificare, care refuză anonimii (`caller()` existent îi lasă să treacă). `/ws/alarms` se declară înaintea lui `/ws/{code}`.
- `auth.py` primește o metodă mică ce întoarce și `email` din token, lângă `user_id()` (care rămâne neschimbată).
- **Răspunderea** (salvarea o face Petru, în baza de date): serverul construiește pentru fiecare eveniment o înregistrare `{event: "raised" | "cancelled", id, kind, at, lat, lon, accuracy_m, user_id, email, ip}` și o predă unei interfețe `AlarmRecorder` cu o singură metodă, `record(entry)`. Noi livrăm doar interfața și o implementare care scrie înregistrarea în logul serverului (`logging`), ca să se vadă la demo. Petru adaugă implementarea care o salvează în baza de date, fără să schimbe restul. Noi nu creăm fișiere, tabele sau migrații.
- `GET /ws/alarms`: canal doar pentru ascultare, **tot cu cont** (toți utilizatorii au cont, decis cu Denis). Primul mesaj al clientului e `{"type": "auth", "token": …}` (un WebSocket din browser nu poate trimite antetul `Authorization`, iar tokenul nu stă în URL ca să nu apară în loguri); token lipsă sau invalid → închidere cu codul 4401. Astfel nimeni din afară nu vede coordonatele alarmelor. Cine se conectează primește întâi alarmele încă active (date în ultimele 15 minute și neanulate), apoi fiecare alarmă și anulare nouă. Mesaje: `{"type": "alarm", id, kind, at, lat, lon, accuracy_m}` și `{"type": "alarm_cancelled", id}`. Nu conțin numele sau contul autorului.
- Mai multe instanțe: cu `REDIS_URL` setat, alarmele circulă prin canalul Redis `echo:alarms`, iar cele active stau într-o cheie cu expirare de 15 minute; fără Redis, în memoria procesului (la fel ca `LocalHub` / `RedisHub`).

### Aplicația (`app/lib/features/emergency/`, cod nou)

- `alarm_api.dart`: cele două apeluri HTTP, cu tokenul contului curent.
- `alarm_feed.dart`: conexiunea la `/ws/alarms`, cu reconectare automată; pornește când utilizatorul e autentificat. Ignoră alarmele date de pe acest telefon.
- `alarm_logic.dart` (funcții pure): distanța între două coordonate (haversine), regula celor 500 m, traducerea unei alarme în `SoundAlert`.
- **Poziția** prin pachetul `geolocator` (dependință nouă), cu permisiunea „cât timp folosești aplicația”, cerută la pornirea fluxului. Cel care dă alarma trimite poziția curentă. Cel care primește își ia poziția în momentul în care sosește alarma; dacă nu reușește în 5 s sau aplicația e în fundal (iOS nu dă poziție nouă în fundal cu această permisiune), folosește ultima poziție cunoscută, pe care aplicația o reîmprospătează cât e deschisă.
- **Poziție necunoscută** (decis cu Denis): dacă telefonul nu are deloc poziție (locație refuzată, GPS fără răspuns, nicio poziție anterioară), alarma se arată oricum. Siguranța primează: mai bine o alertă și acasă decât un coleg surd care nu află de pericol.
- **Raza ține cont de precizie** (alegerea mea): alarma se arată dacă distanța ≤ 500 m + precizia poziției celui care primește, plafonată la 100 m. Un telefon din clădire cu GPS slab nu e exclus; cineva la 1 km tot nu primește.
- **Ecran blocat** (alegerea mea): alerta lui Petru trimite notificarea doar când se desenează ecranul, iar iOS nu desenează în fundal. De aceea `alarm_feed.dart` cheamă singur `AlertSignals.notify(...)` (serviciul existent din `services.dart`, nemodificat) pentru fiecare alarmă din rază, apoi `AlertController.show(...)` pentru ecranul roșu când se deschide aplicația.
- `emergency_screen.dart`: ecranul pentru cel care dă alarma (vezi mai jos).
- Un punct de intrare pe ecranul principal: „Alarmă de urgență”, vizibil doar pentru cei autentificați.
- `services.dart` și `app.dart` (unde sunt legate alertele): câte o linie, ca să pornească fluxul de alarme.

### Ecranul „Alarmă de urgență”

1. Titlu și o propoziție: alarma ajunge la colegii aflați la cel mult 500 m. Imediat dedesubt, vizibil: „Numele tău se păstrează odată cu alarma.”
2. Cele 4 tipuri, ca rânduri mari: iconiță, nume, nivel scris („Critic” / „Atenție”), nu doar culoare.
3. Confirmare într-un dialog: „Trimiți alarma «Incendiu»?” cu „Trimite alarma” și „Renunță”.
4. După trimitere: „Alarmă trimisă la ora …”, cu butonul „Anulează alarma” (care cere și el confirmare).
5. Erori care spun ce urmează: fără cont („Intră în cont ca să poți da o alarmă.”), fără poziție („Permite accesul la locație din Setări, ca alarma să ajungă la cine e aproape.”), fără server, prea multe alarme.

Ecranul folosește stilul paginii principale și trece de verificările din `docs/reguli-frontend.md`.

## Testare

- **Server** (`server/tests/test_alarms.py`, fără rețea, cu un verificator de tokenuri fals): fără token → 401; tip necunoscut → 422; alarma ajunge la un socket conectat la `/ws/alarms`; `AlarmRecorder`-ul fals primește înregistrarea cu contul; anularea de către altcineva → 403; anularea de către autor ajunge la socket și la `AlarmRecorder`; un client nou primește alarmele active; a 4-a alarmă dintr-o oră → 429; aceleași lucruri prin Redis (`fakeredis`).
- **Aplicație** (`flutter test`, cu servicii false): distanța haversine pe puncte cunoscute; 499 m da, 501 m nu; fiecare tip devine `SoundAlert`-ul din tabel; o alarmă din rază apare pe ecran, una din afara razei nu; anularea închide alerta; alarma proprie e ignorată; fluxul ecranului (tip → confirmare → trimis → anulare); erorile.
- `flutter analyze` și `pytest` trec.
- Manual înainte de demo: două telefoane, ambele autentificate; unul dă alarma, celălalt o primește în câteva secunde, inclusiv cu ecranul blocat și ascultarea pornită.

## Riscuri

- **Supabase trebuie configurat pe serverul și în aplicația de la demo.** Fără conturi nu se poate da nicio alarmă (așa e cerut). Pe laptopul lui Denis nu există încă `.env`.
- Poziția din interiorul clădirilor poate avea o eroare de zeci de metri; raza de 500 m o acoperă.
- Pe iPhone, aplicația primește alarma în fundal doar cât timp rulează ascultarea permanentă; dacă utilizatorul a oprit-o, alarma ajunge când deschide aplicația, dacă e încă activă (cele 15 minute).
- Până când Petru leagă `AlarmRecorder` de baza de date, înregistrările există doar în logul serverului și se pierd la repornire.
