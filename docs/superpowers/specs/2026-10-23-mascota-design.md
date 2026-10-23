# Design: Mascota Echo

Status: cerut pe 2026-10-23 („bagă mascota unde consideri că e mai bine, doar să nu suprapopulezi aplicația; vreau să îi faci și animații”), cu cele patru poze desenate de echipă (alertă, bravo, citește, salut). Locurile și animațiile le-am ales eu; se pot schimba.

## 1. Ce e

Un balon de vorbire turcoaz (culoarea logoului) cu două linii de subtitrare pe burtă, ochi, obraji și mâini. Spune din prima ce face Echo: vorbirea devine text.

Este **desenată în cod** (`app/lib/widgets/echo_mascot.dart`, `CustomPainter`), nu e imagine. Așa se mișcă fiecare parte separat (mâinile, ochii, insigna), rămâne clară la orice mărime și nu adaugă fișiere în aplicație.

## 2. Unde apare (o singură dată pe ecran, câte o poză pe loc)

| Poza | Unde | De ce acolo |
|---|---|---|
| Salut / Anunț, apoi Citește | Dashboard pe telefon: mare, în mijloc, deasupra anunțurilor | Intrarea în anunțuri (vezi mai jos) |
| Citește | Anunțuri pe laptop, când nu e niciun anunț | Înlocuiește o listă goală |
| Salut | Meeting → Prezint, lângă „Tu ții meetingul” | Speakerul își salută sala |
| Alertă | Vibrații, lângă titlu | Ecranul despre ce se întâmplă în jur |
| Bravo | Pagina prezentatorului, după „Vocea ta e învățată” | O reușită reală, o dată |

**Nu apare** în meeting (subtitrarea, întrebările, „Ți s-a răspuns”), pe alertele de sunet sau de urgență și pe login. Acolo omul citește sau trebuie să reacționeze, iar mișcarea l-ar distrage. Alerta critică rămâne fără nimic peste ea.

## 2b. Anunțurile pe telefon (cerut pe 2026-10-23)

Pe Dashboard, anunțurile stau închise în spatele mascotei mari (168 px), cu mesajul „Vezi anunțurile!” sau, dacă sunt anunțuri necitite, „Ai un anunț nou!” / „Ai X anunțuri noi!”. Cu anunțuri noi, mascota e în poza Anunț (ține sus un plic cu un punct auriu, diferită de Alertă, care rămâne doar pentru sunete), altfel Salut. Mascota și mesajul formează un singur buton, iar VoiceOver citește mesajul.

La atingere (0,75 s), mascota se micșorează (cu o mică săritură la final) și se mută în colțul titlului „Anunțuri”. Mesajul dispare, titlul apare, lista se deschide sub ea, iar mascota trece în poza Citește. Lista rămâne deschisă până la ieșirea din aplicație. Cu mișcare redusă se deschide direct. În contrast ridicat nu e mascotă, deci lista e deschisă de la început.

## 3. Animații

Fiecare poză se mișcă o dată când apare: la deschiderea ecranului sau la întoarcerea în tab. Apoi stă și clipește rar (la 3–6 s). Atingerea o pornește din nou.

- **Salut** (1,8 s): apare cu un mic salt; mâinile flutură de trei ori, din ce în ce mai încet; liniile de lângă mâini pulsează.
- **Citește** (2,6 s): ochii urmăresc rândurile foii de la stânga la dreapta, de două ori; foaia se leagănă puțin.
- **Alertă** (1,1 s): tresare (o scuturare scurtă), insigna „!” apare elastic, mâna ridicată flutură de două ori.
- **Bravo** (1,5 s): sare de bucurie, cu mâinile sus; steluțele și bifa apar una după alta. Nu clipește (ochii sunt deja închiși de bucurie).

## 4. Accesibilitate

- E doar decor: VoiceOver o sare (`ExcludeSemantics`), textul de lângă ea spune tot.
- **Mișcare redusă** (setarea telefonului): apare direct poza finală, nu se mișcă și nu clipește.
- **Contrast ridicat**: nu se desenează deloc, la fel ca strălucirea din spatele logoului.
- Nu se mișcă în bucle lungi: după intrare rămâne doar clipitul.
- Nu ține locul unui text: fiecare loc are textul lui și fără mascotă.

## 5. Date și GDPR

Nu produce date, nu salvează nimic și nu trimite nimic prin rețea. Nu are nevoie de tabel sau de `activity_log` (regula 9 din CLAUDE.md).
