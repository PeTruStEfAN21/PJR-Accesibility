# Ascultare permanentă a sunetelor

**Data:** 2026-10-22 · **Stare:** aprobat (implementat; netestat pe iPhone) · **Pornește de la:** `2026-10-22-sunetul-vizibil-design.md`

## Ce vrem

„Sunetul vizibil” ascultă mereu, nu doar cât stai pe ecranul lui. Singura excepție: cât timp merge subtitrarea (meeting sau conversație), pentru că și ea are nevoie de microfon. Alertele mici rămân discrete; alerta critică insistă până o vezi.

## Criterii de reușită

1. Pornești ascultarea o dată; de atunci pornește singură la fiecare deschidere a aplicației, până o oprești tu.
2. Ecranul „Sunetul vizibil” arată starea reală (ascultă / oprită / în pauză cât merge subtitrarea), și după ce ieși și revii.
3. Când pornește subtitrarea, ascultarea sunetelor se oprește; când se oprește subtitrarea, ascultarea repornește singură. Subtitrarea merge exact ca înainte.
4. După un apel telefonic sau Siri, ascultarea se reia singură (`AudioInterruptionMode.pauseResume`); la revenirea în aplicație repornește dacă tot e oprită.
5. Alertă critică cu aplicația în fundal / telefon blocat: notificarea time-sensitive se repetă la 10 s (sunet, vibrație, ceas) până deschizi aplicația sau confirmi alerta, cel mult 12 ori (2 minute).
6. `flutter test` și `flutter analyze` trec.

## Limite asumate (le spunem la juriu)

- **iPhone:** cu aplicația închisă cu swipe sau după repornirea telefonului nu se ascultă nimic: iOS nu permite niciunei aplicații. Recomandăm și funcția Apple „Recunoaștere sunete”.
- **Android:** ascultarea merge cât aplicația e deschisă (neschimbat).
- **Browser:** pornește singură doar dacă microfonul a fost permis anterior.
- Prima pornire rămâne un gest al utilizatorului (cererea de permisiuni la microfon și notificări are nevoie de context; browserul o cere).

## Niveluri (neschimbate, cu excepția repetării)

| Nivel | Aplicația deschisă | În fundal / blocat |
|---|---|---|
| Informativ | banner 4 s, vibrație scurtă | notificare fără sunet |
| Atenție | banner 8 s, 3 vibrații puternice | notificare time-sensitive cu sunet |
| Critic | ecran roșu, vibrație până confirmi | notificare time-sensitive repetată la 10 s, max. 2 min |

## Cum

| Fișier | Schimbare |
|---|---|
| `features/alerts/sound_listening.dart` (nou) | `SoundListening` (`ChangeNotifier`): dorința „ascultă mereu” salvată în `SharedPreferences` (`alwaysListen`), starea reală, `hold()` / `release()` cu numărător pentru subtitrare, `resumed()` la revenirea în aplicație |
| `core/speech/mic_sharing_speech.dart` (nou) | decorator peste `SpeechService`: `start` cere `hold()`, `stop` (sau un start eșuat) face `release()`. Ecranele de meeting nu se schimbă |
| `features/alerts/critical_repeater.dart` (nou) | temporizator pur (10 s, max. 12, se oprește când aplicația e în prim-plan); folosit de `alert_signals_native.dart` |
| `yamnet_detector.dart` | `audioInterruption: pauseResume` |
| `main.dart`, `app.dart`, `services.dart` | leagă totul; pornire automată la lansare; `AppLifecycleListener` → `resumed()` |
| `sounds_screen.dart`, ARB | butonul folosește `SoundListening`; text nou `soundsPaused` |

## Testare

- `sound_listening_test.dart`: pornire + salvare, pornire automată, oprire, `hold`/`release` (și imbricate), `hold` când e oprită nu pornește nimic, `resumed()` repornește.
- `mic_sharing_speech_test.dart`: start / stop / start eșuat.
- `critical_repeater_test.dart` (fake_async): 12 repetări, oprire la confirmare, nicio repetare în prim-plan.
- Test de widget pe ecranul sunetelor: starea după ieșire și revenire, textul de pauză.
- Pe Mac + iPhone (manual): pornești ascultarea, blochezi telefonul, sirenă de pe alt dispozitiv → notificări repetate; pornești un meeting → subtitrarea merge; îl oprești → ascultarea revine.

## Risc pentru demo

Singura atingere a fluxului principal e decoratorul peste recunoașterea vorbirii. Dacă pe iPhone reluarea microfonului după subtitrare face probleme, se dezactivează lăsând ascultarea oprită (comportamentul de acum).
