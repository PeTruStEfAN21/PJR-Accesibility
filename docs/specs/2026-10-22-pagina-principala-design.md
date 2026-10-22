# Design: pagina principală (Echo)

Status: aprobat de Denis David (front-end) pe 2026-10-22. Completează punctul 10 din `2026-10-22-platforma-accesibilitate-design.md` (aranjarea vizuală e la decizia celui care construiește).

## Problema

Pagina principală are patru carduri la fel de mari: Particip, Prezint, Sunetul vizibil, Conversație. Toate cer aceeași atenție, așa că utilizatorul trebuie să le citească pe toate înainte să aleagă (legea lui Hick). Amestecă și două modele mentale: „Prezint” e pentru persoana care aude, de pe laptop, iar sunetele și conversația nu țin de meeting.

## Principii

Încărcare cognitivă mică, o singură alegere evidentă (Hick), grupare după cum gândește utilizatorul (model mental), spațiu generos, text omenesc, cel mult două stiluri de buton, conținut aliniat la stânga, onboarding în context, nu la început (paradoxul utilizatorului activ). Regulile de accesibilitate proiectului au prioritate.

## Ce se schimbă

**Pe telefon** (participantul surd):
1. Salut, aliniat la stânga: „Bună! Cu ce începem?”.
2. O singură acțiune principală, mare: **„Sunt la un meeting”**, cu „Vezi tot ce se spune și cine vorbește.”
3. Grupul „În afara meetingurilor”, cu rânduri simple (fără card): „Sunetele din jur”, „Vorbesc cu cineva”.
4. Jos, un link discret: „Tu prezinți? Deschide modul prezentator”.

**Pe laptop (Chrome, `kIsWeb`)** (prezentatorul):
1. Același salut.
2. Acțiunea principală: **„Eu prezint”**, cu „Pornești meetingul și le arăți celorlalți codul.”
3. Fără sunete și conversație: au nevoie de camera și microfonul telefonului.
4. Jos, un link discret: „Participi la meeting? Intră de aici”.

**Onboarding în context:** la prima deschidere apare un singur indiciu, deasupra acțiunii principale: „Prima dată aici?” și o propoziție despre ce face acțiunea principală. Are două butoane:
- „Am înțeles”: ascunde indiciul paginii principale.
- „Sari peste”: oprește toate indiciile (`tipsEnabled = false`), inclusiv cele pe care le vor adăuga alte ecrane.

Indiciul dispare și când utilizatorul apasă acțiunea principală. Starea se salvează pe dispozitiv, în `AppSettings` (`tipsEnabled`, `seenTips`).

**Stiluri de buton:** `FilledButton` pentru acțiunea primară din indiciu, `TextButton` pentru secundare și linkuri. Acțiunea principală e un panou atingabil în nuanța pală a accentului; uneltele secundare sunt rânduri într-un panou gri (vezi „Direcția vizuală”).

**Lățime:** pe ecrane late, o coloană centrată de 1100 px, cu textul aliniat la stânga.

## Direcția vizuală (Taste)

- **Titlul:** salutul, 24 px pe telefon și 28 px pe laptop, greutate 400, aliniat la stânga.
- **Panouri tonale în loc de umbre:** `#f9f9f9` pe alb, colțuri de 22 px, rânduri cu colțuri de 14 px și margine `#eaeaea`.
- **Un singur accent, teal închis `#1b6e66`:** doar pe iconița acțiunii principale și pe semnul Echo. Panoul principal folosește o nuanță pală din el.
- **Butoane:** un singur buton plin, aproape negru și rotunjit complet; restul sunt butoane text.
- **Iconițe:** outline, gri.
- **Pe laptop:** coloana are 1100 px, cu acțiunea principală pe 7 coloane și indiciul pe 5, terminate la aceeași înălțime.

**Logo** (`app/lib/widgets/echo_logo.dart`): SVG-ul ales de echipă, o ureche al cărei contur se continuă în linii de text, adică sunetul care devine subtitrare. E desenat în cod cu aceleași curbe, încadrat strâns, fără fundalul închis din SVG și la 44 px. VoiceOver citește doar cuvântul „Echo”.

**Metal** (`app/lib/widgets/metal.dart`): doar logo-ul e metalic, în cyan închis: un gradient crom pe față, o margine `#00363F` dedesubt și o linie de lumină pe muchia de sus. Gradientul e o abatere asumată de la Taste, cerută de Denis. Iconițele paginii rămân simple. Iconița acțiunii principale și rotița de setări au cyanul plat al logo-ului, `#007D90` (`EchoPalette.brand`, contrast peste 3:1 pe alb). Celelalte sunt gri.

**Butoane** (`app/lib/theme/echo_style.dart`): două stiluri. `EchoButtons.primary` e plin, aproape negru, rotunjit complet. `EchoButtons.link` e ca un link, subliniat la trecerea cu mouse-ul, la apăsare și la focus de pe tastatură. Niciunul nu are efectul de undă (ripple) care se întinde la apăsare. Panourile atingabile se închid doar puțin la culoare când le apeși.

**Apăsare** (`app/lib/widgets/pressable.dart`, după Emil Kowalski): panoul principal, rândurile și butoanele negre se micșorează la 0,97 cât sunt ținute apăsate, în 160 ms, cu o curbă care pornește repede. Dacă sistemul cere mai puțină mișcare, efectul nu apare deloc.

**Font:** Roboto peste tot, inclus în aplicație (`assets/fonts`, cu ș și ț), ca să apară și pe iPhone. Modul pentru dislexie păstrează OpenDyslexic.

**Ecranul „Intră în meeting”** (`join_screen.dart`) folosește aceleași culori și butoane:
- O propoziție scurtă și eticheta deasupra câmpului de cod.
- Un singur buton plin, „Intră”.
- Scanarea QR, ca link cu iconiță.
- Adresa serverului ascunsă într-un panou gri, unde se vede valoarea curentă și linkul „Schimbă”.

**Modul luminos e implicit:** dacă utilizatorul nu alege altceva în Setări, aplicația pornește luminoasă.

Culorile stau doar pe pagina principală, cu variante pentru temă întunecată și contrast ridicat; tema comună a aplicației rămâne neschimbată. Fontul e Roboto, cerut de Denis, în locul lui Instrument Sans propus de Taste.

Pentru recenzii de design: `flutter build web --dart-define=ECHO_PHONE_PREVIEW=true` arată varianta de telefon în Chrome.

## Accesibilitate

- Fiecare acțiune e un singur nod VoiceOver, cu titlul și explicația; salutul și titlul de grup sunt `header`.
- Fără înălțimi fixe: textul la 200% nu se taie. Ținte de minimum 48 px.
- Paleta paginii are variante pentru tema întunecată și pentru contrast ridicat (alb-negru, cu margini de 2 px); toate textele trec de 4,5:1.

## Teste (widget)

1. Telefon: acțiunea principală e „Sunt la un meeting”, grupul secundar există, iar linkul către prezentator duce la ecranul prezentatorului.
2. Laptop: acțiunea principală e „Eu prezint”, fără sunete și conversație.
3. Indiciul apare la prima pornire; „Am înțeles” îl ascunde și rămâne ascuns după repornire.
4. „Sari peste” ascunde indiciul și oprește indiciile.
5. Apăsarea acțiunii principale marchează indiciul ca văzut.
6. Text la 200% pe un ecran mic: fără overflow.

## În afara scopului

Comutatorul „Arată din nou indiciile” din setări (ecranul altui coleg), indiciile din alte ecrane, animațiile.
