# Sunetul vizibil: detectorul YAMNet și sunetele locației (design)

**Data:** 2026-10-22 · **Stare:** aprobat, extins la cererea echipei: toate dispozitivele și alertă ca o alarmă reală (vezi „Pe fiecare dispozitiv”) · **Pornește de la:** `docs/prezentare-generala.tex` (Funcție bonus 2) și planul demo, „Persoana 3”.

## Scop

Butonul „Sunetul vizibil” ascultă de-adevăratelea. Telefonul recunoaște local alarmele, sirenele, claxoanele, telefonul și ușa și le transformă în alertele care există deja (3 niveluri, ecran roșu, vibrație). În plus, ca prototip, utilizatorul poate învăța telefonul un sunet al locației (alarma lor, semnalul liniei) din 3–5 mostre.

**Criterii de reușită (verificabile):**
1. Pe iPhone, o alarmă de incendiu dintr-un difuzor produce ecranul roșu în cel mult ~3 s, peste orice ecran.
2. Un sunet învățat din 3 mostre e recunoscut când e redat din nou și produce alerta cu numele și nivelul alese.
3. Niciun eșantion audio și niciun vector derivat din audio nu iese de pe telefon.
4. Ascultarea merge și în browser (laptop: Chrome / Edge), cu YAMNet în TensorFlow.js; pagina prezentatorului merge ca înainte.
5. Testele pure (mapare clase, prag, ferestre, potrivire sunete învățate) trec în `flutter test`.
6. Alerta se simte ca o alarmă reală, după gravitate, pe telefon, ceas și laptop (vezi „Pe fiecare dispozitiv”).

**Non-obiective:** „Numele strigat” (YAMNet știe doar „vorbire”, nu un nume; ar cere recunoașterea vorbirii pe același microfon), pornirea automată a subtitrării când cineva vorbește, trimiterea sunetelor învățate către colegi sau în cont, panoul HR, antrenarea unui model cu gradient. Rămân în roadmap.

## Confidențialitate

Tot ce ține de sunet rulează pe telefon: microfonul, modelul, vectorii învățați. Sunetele învățate se păstrează doar local (`shared_preferences`), nu într-un cont și nu pe server. Serverul nu se schimbă.

## Modelul

- Pornim de la YAMNet TFLite oficial (MediaPipe, Apache 2.0): intrare 15.600 eșantioane float (0,975 s la 16 kHz), ieșire 521 de scoruri AudioSet.
- Modelul oficial nu expune vectorul de 1.024 de valori (embedding) de care avem nevoie pentru sunetele locației. Scriptul `tools/yamnet_embeddings.py` adaugă tensorul intern `layer28/reduce_mean` ca a doua ieșire (printr-o operație DEQUANTIZE). Scorurile rămân identice; verificat pe liniște, bip, zgomot.
- Rezultatul, `app/assets/models/yamnet.tflite` (~4 MB), intră în git (excepția din `.gitignore` există deja), împreună cu `yamnet_class_map.csv`. Scriptul rămâne ca modelul să poată fi refăcut.

## Pe fiecare dispozitiv

| Dispozitiv | Recunoaștere | Cum te atenționează |
|---|---|---|
| iPhone | YAMNet TFLite | Critic: ecran roșu care pulsează lent, vibrație aproape continuă până confirmi, notificare *time-sensitive*. Atenție: banner + 3 vibrații puternice. Informativ: notificare + vibrație scurtă. Ascultă și cu ecranul blocat (mod audio în fundal). |
| Android | YAMNet TFLite | La fel; critic = notificare de tip alarmă, pe tot ecranul peste ecranul blocat, cu tipar lung de vibrație. Ascultarea merge cât timp aplicația e deschisă. |
| Apple Watch / Wear OS | prin telefon | Notificarea telefonului (cu vibrația ceasului) când telefonul e blocat sau în buzunar. Fără aplicație separată pe ceas. |
| Laptop (Chrome / Edge) | YAMNet TensorFlow.js, local în pagină | Ecranul roșu, notificare de sistem care rămâne până o închizi (și cu fila în fundal), titlul filei clipește „⚠ ALARMĂ…” o dată pe secundă. |
| Telefon în browser | YAMNet TensorFlow.js | Ca laptopul; vibrație în Chrome pe Android (Safari pe iPhone nu permite vibrația din pagină). |

- Pulsul și clipirea au cel mult o schimbare pe secundă (sub limita de 3/s pentru epilepsie fotosensibilă) și se opresc dacă sistemul cere animații reduse.
- Pe iPhone, `allowHapticsAndSystemSoundsDuringRecording` e obligatoriu: altfel iOS oprește vibrația cât timp microfonul înregistrează.
- Notificările pornesc doar după permisiunea dată la „Pornește ascultarea” (browserul o cere dintr-o acțiune a utilizatorului).
- Alertele critice de iOS care trec de modul silențios cer aprobare specială de la Apple; nu le avem. *Time-sensitive* cere capabilitatea „Time Sensitive Notifications” adăugată în Xcode.

## Cum ascultă

```
microfon (record, PCM16 16 kHz mono)
  → ferestre de 15.600 eșantioane, pas 0,5 s, convertite în [-1, 1]
  → YAMNet → 521 scoruri + embedding 1.024
  → (a) clase cunoscute: scor ≥ 0,3 în 2 ferestre la rând
    (b) sunete învățate: similaritate cosinus ≥ 0,80 față de media mostrelor, în 2 ferestre la rând
  → aceeași alertă cel mult o dată la 10 s
  → AlertController.show(...)   (existent: prioritate, vibrație, ecran roșu)
```

- Maparea claselor se face după `display_name`, ca în plan: „Fire alarm”, „Smoke detector, smoke alarm” → `fireAlarm`; „Siren”, „Civil defense siren” → `siren`; „Vehicle horn, car horn, honking”, „Air horn, truck horn” → `horn`; „Telephone bell ringing”, „Ringtone” → `phone`; „Doorbell”, „Ding-dong”, „Knock” → `door`.
- Pasul de 0,5 s (ferestre care se suprapun) ține întârzierea la ~1,5 s pentru „2 ferestre la rând”.
- Pragul 0,80 vine dintr-un test cu sunete sintetice (aceeași sursă 0,89–0,97, altele sub 0,6). Se reglează pe iPhone, cu sunete reale; e o constantă.

## Sunetele locației (prototip)

- În ecranul Sunete, secțiunea „Sunetele locației”: lista sunetelor învățate (nume, nivel cu iconiță + text, buton Șterge) și „Învață un sunet nou”.
- Fluxul de învățare: nume (ex. „Alarma halei 2”) → nivel (Critic / Atenție / Informativ, fiecare cu iconiță și text, nu doar culoare) → „Înregistrează mostra” de 3–5 ori, câte 2 s. Progresul se vede ca text („Mostra 2 din 3”) și se anunță pentru VoiceOver. „Salvează” devine activ după 3 mostre.
- Din fiecare mostră se păstrează media embeddingurilor ferestrelor ei; sunetul învățat = media normalizată a mostrelor. Nu se păstrează audio.
- Cât timp se înregistrează o mostră, detectorul nu ascultă (un singur microfon); după aceea revine la starea de dinainte.
- Alerta unui sunet învățat folosește nivelul ales: un sunet critic învățat acoperă ecranul ca alarma de incendiu.

## Ce se schimbă în cod

| Fișier | Schimbare |
|---|---|
| `features/alerts/sound_alert.dart` | `SoundKind.location` (iconiță proprie); `SoundAlert` primește opțional `label` și `level` pentru sunetele învățate |
| `features/alerts/alert_overlay.dart` | eticheta vine din alertă (numele sunetului învățat), nu doar din tip |
| `features/alerts/yamnet_logic.dart` (nou) | funcții pure: ferestre PCM, mapare clase, poartă prag + 2 ferestre + 10 s, cosinus și media mostrelor |
| `features/alerts/location_sounds.dart` (nou) | modelul `LocationSound` + salvarea locală (JSON în `shared_preferences`) |
| `features/alerts/yamnet_detector.dart` (nou) | `YamnetSoundDetector implements SoundDetector`: `record` + `tflite_flutter`, plus înregistrarea unei mostre |
| `features/alerts/yamnet_model*.dart` (nou) | import condiționat: TFLite pe iOS / Android (`dart:ffi`), TensorFlow.js pe web (`web/js/yamnet.js`, model în `web/models/yamnet/`) |
| `features/alerts/alert_signals*.dart` (nou), `web/js/alerts.js` | vibrații pe niveluri și notificări de sistem, pe fiecare platformă |
| `ios/Runner/Info.plist`, `AppDelegate.swift`, `android/...` | ascultare în fundal (iOS), notificări cu aplicația deschisă, permisiuni de notificare / ecran complet (Android) |
| `features/sounds/sounds_screen.dart` + ecran nou de învățare | secțiunea „Sunetele locației” |
| `main.dart` | o linie: detectorul din factory |
| `l10n/app_ro.arb`, `app_en.arb` | textele noi, în ambele limbi |
| `tools/yamnet_embeddings.py` (nou) | refacerea modelului cu ieșirea de embedding |
| `pubspec.yaml` | `tflite_flutter`, `record`, `vibration`, `flutter_local_notifications`; asseturile modelului |

## Testare

- `app/test/features/yamnet_mapping_test.dart` (din plan) + teste pentru ferestre, poartă și sunetele învățate: funcții pure, fără model și fără microfon.
- Test de widget pentru fluxul de învățare, cu un detector fals (mostre fixe): „Salvează” activ abia după 3 mostre, sunetul apare în listă, ștergerea merge.
- Cap-coadă în Chrome, automat (Playwright, microfon fals dintr-un WAV): alarmă de fum T3 → ecran roșu în ~5 s, notificare, titlul clipește; un sunet necunoscut nu dă nimic în 15 s; același sunet învățat din 3 mostre → bannerul cu numele lui în ~1,5 s.
- Pe telefon (Mac + iPhone, Android): alarmă de pe YouTube → ecran roșu + vibrație; ecran blocat → notificare și pe ceas.

## Riscuri

- `tflite_flutter` pe iOS cere pod-ul TensorFlowLiteC (`pod install` pe Mac). Dacă nu merge la timp, detectorul rămâne `Unavailable` și butoanele de test acoperă demo-ul.
- Microfonul e comun cu recunoașterea vorbirii: în demo, ascultarea sunetelor rulează pe ecranul ei (ca în designul principal).
- Pragul de 0,80 e ales pe sunete sintetice; în sală poate trebui coborât.

## Actualizare (22 oct., seara): fără UI, detector antrenat de noi

**Fără UI.** Interfața o face altcineva din echipă, așa că ecranul de învățare, secțiunea „Sunetele locației” din ecranul Sunete și pulsul ecranului roșu au fost scoase (backup în istoricul conversației, nu în repo). Rămâne logica, gata de legat:

| Pentru UI | API |
|---|---|
| Pornește / oprește ascultarea | `ServicesScope.of(context).sounds.start()` / `.stop()` (cere singur microfonul și permisiunea de notificări) |
| Învață un sunet | `sounds.recordSample(Duration(seconds: 2))` de 3–5 ori → `fingerprint(mostre)` → `services.locationSounds!.add(nume, nivel, amprentă)` |
| Lista sunetelor învățate | `services.locationSounds` (`ChangeNotifier`): `.sounds`, `.remove(id)` |
| Alerta | existentă (`AlertOverlay`); un sunet învățat are `alert.label` și `alert.level` proprii, `alertLabel(l10n, alert)` dă textul |

Ecranele existente merg cu detectorul nou fără schimbări. În `alert_overlay.dart` s-au adăugat doar legăturile necesare (eticheta sunetelor învățate, notificările de sistem, tipurile noi în `switch`), fără schimbări vizuale.

**Detectorul antrenat** (`tools/train_danger_sounds.py`, rezultat în `app/assets/models/danger_head*.json`):

- Problema găsită: pe alarme reale de incendiu YAMNet răspunde „Alarm” (clasă generică), nu „Fire alarm”, deci maparea după nume le rata.
- Un strat softmax (1024 → 5: fundal, alarmă de incendiu, sirenă, claxon, geam spart) peste embeddingul YAMNet pe care telefonul îl calculează oricum. Aplicația alertează când **fie** stratul nostru, **fie** numele YAMNet o cer (`SoundAnalyzer`).
- Date: ESC-50 (CC BY-NC 3.0; fold 5 ținut deoparte), Mini LibriSpeech (CC BY 4.0; vorbirea e fundal, împărțită pe vorbitori), alarme de incendiu sintetizate după tiparele standard (ISO 8201 T3/T4, sonerii, hupe, whoop) cu reverberație și zgomot real, și 10 înregistrări reale de pe Wikimedia Commons doar pentru test.
- Pragurile se aleg cu validare încrucișată pe datele de antrenare: cel mult 0,2 % alarme false pe clip de fundal, pe clasă.
- Rezultate pe setul de test (ESC-50 fold 5 + alarme sintetice noi + vorbitori noi), aplicația (model + nume) față de doar nume: alarmă de incendiu 53 % față de 11 %, sirenă 100 % față de 87,5 %, claxon 87,5 % față de 12,5 %, geam spart 37,5 % față de 0 %; alarme false 0,8 % (foc care trosnește, clopote, ceasuri cu alarmă) față de 0 %; vorbire: nicio alarmă falsă.
- Pe cele 8 înregistrări reale (5 alarme de incendiu, 3 sirene) aplicația dă 5/8 alerte critice, la fel ca maparea după nume; două alarme NFPA și o sonerie mecanică nu sunt prinse de niciuna. Setul real e mic: rezultatele lui sunt un semnal, nu o măsurătoare.
- Încercate și respinse: MLP (rezultate instabile de la o inițializare la alta), ansamblu de 5 MLP (nu mai bun decât modelul liniar), context de 2 ferestre și scorurile YAMNet ca intrări (fără câștig), 3–4 ferestre la rând (pierde sunetele scurte).
- **Telefon și browser au modele YAMNet diferite**: TFLite (MediaPipe, int8) și TF.js dau embeddinguri fără legătură pe același sunet (cosinus mediu 0,05). Fiecare are deci stratul lui: `danger_head.json` (telefon) și `danger_head_web.json` (browser, antrenat prin `tools/tfjs_yamnet_worker.mjs`). Sunetele învățate pe un dispozitiv nu se mută pe altul.
- Browser (`danger_head_web.json`, `--max-false-alarms 0.0005`): pe setul de test, aplicația față de doar nume: alarmă de incendiu 48 % față de 23 %, claxon 75 % față de 25 %, geam spart 75 % față de 0 %; alarme false 1,3 %, la fel ca numele singure (modelul TF.js e mai zgomotos decât cel de telefon). Verificat și cap-coadă în Chrome: alarma de fum dă ecranul roșu în ~4 s.
- Un test Dart (`danger_head_test.dart`) verifică pe un embedding real că implementarea din aplicație dă aceleași probabilități ca Python.

**Demo fără UI**: `tools/sound_demo.py` ascultă microfonul laptopului (sau un fișier) cu aceleași modele și reguli și afișează alertele colorate după gravitate, cu motivul („YAMNet «Fire alarm» 0,97”, „modelul nostru 0,99”). `--learn "Nume" --level critical` învață un sunet al locației din 3 mostre.
