# Cardul „Sunete” și vibrația aleasă pentru fiecare nivel de alertă

Înlocuiește punctul 3 („Pastila «Sunete»”) din `2026-10-22-ecrane-alerta-design.md`. Restul acelui design (ecranele de alertă pe tip de sunet) rămâne valabil.

## De ce

Pastila „Sunete” din bara de sus pornește/oprește ascultarea dintr-o atingere, fără să spună ce face funcția, iar ecranul ei se deschide doar cu apăsare lungă, pe care utilizatorii nu o descoperă. Vibrația e singurul semnal al unei alerte pe care un utilizator surd îl simte fără să se uite la telefon, dar azi e fixă pe nivel și nu poate fi încercată înainte de o alertă reală. Utilizatorul vrea să aleagă vibrația fiecărui nivel, ca la alegerea tonului de apel pe iPhone: atingi o opțiune, o simți, rămâne aleasă.

## Ce se construiește

1. **Pastila „Sunete” dispare din bara de sus.** `SoundsPill` se șterge (widget, ARB-urile ei, testele ei).
2. **Card „Sunete” pe ecranul principal**, la fel ca „Conectează-te la speaker” (același widget `_MainAction`: iconiță, titlu, o frază, săgeată), imediat sub el. Doar pe telefon (`!presenterFirst`), ca acum. Fraza spune starea: „Pornit: telefonul te alertează la alarme, claxoane și numele tău” / „Oprit: atinge ca să pornești alertele de sunet” / „Pus pe pauză cât rulează subtitrările” / (detectorul lipsește, ex. previzualizare web) „Indisponibil pe acest dispozitiv: atinge pentru detalii” (a patra frază: decizia constructorului). Atingerea deschide ecranul „Sunete”.
3. **Ecranul „Sunete”** (`sounds_screen.dart`, refăcut), în stil listă grupată iOS (secțiuni cu titlu mic și rânduri pe fundal tonal):
   - **Explicația** (2–3 fraze): telefonul ascultă sunetele din jur pe dispozitiv, nimic nu pleacă pe internet; la un sunet recunoscut, ecranul se schimbă și telefonul vibrează; alertele critice acoperă orice ecran până le închizi.
   - **Comutator „Alerte de sunet”** (Switch), aceeași logică ca butonul de azi (`SoundListening.enable/disable`), plus starea (ascultă / pauză / oprit) ca live region. Dacă detectorul lipsește, comutatorul e dezactivat și apare mesajul de azi `soundsDetectorMissing`.
   - **Secțiunea „Vibrații”**: 3 rânduri, câte unul pe nivel: Critic, Important, Informativ. Fiecare rând: iconița și eticheta nivelului (nu doar culoare), exemple de sunete („alarmă de incendiu, sirenă”), iar în dreapta numele vibrației alese și o săgeată.
   - Atingerea unui rând deschide **ecranul de alegere** pentru acel nivel: lista celor 3 vibrații. Fiecare rând are nume, o descriere scurtă și bifă la cea aleasă. **Atingerea unui rând redă vibrația pe loc și o alege** (ca la tonurile de apel). Alegerea se salvează imediat; nu există buton „Salvează”. **Vibrațiile sunt unice pe niveluri** (decizia utilizatorului): fiecare nivel are mereu altă vibrație, ca o alarmă de incendiu să nu se simtă niciodată ca o alertă de nume. Rândurile vibrațiilor folosite de alt nivel spun asta sub descriere („Folosită la Important”); alegerea uneia schimbă vibrațiile între cele două niveluri, iar un mesaj scurt (SnackBar, anunțat și pentru VoiceOver) spune ce s-a schimbat („Important folosește acum Lungă”). Sub listă, o notă: alertele critice repetă vibrația până le închizi.
   - **Butoanele de test** de azi (alarmă de incendiu, claxon, nume) rămân la final, în secțiunea „Încearcă o alertă”: arată ecranul de alertă cu vibrația aleasă.
4. **Cele 3 vibrații** sunt exact tiparele de azi din `Haptic` (`alert_signals_native.dart`, `alert_signals_web.dart`), cu nume pentru utilizator:
   | `Haptic` | Nume | Descriere |
   |---|---|---|
   | `long` | Lungă | Un buzz lung și puternic |
   | `strong` | Triplă | Trei buzz-uri puternice la rând |
   | `light` | Scurtă | Un buzz scurt și ușor |
   Valorile implicite sunt cele de azi: Critic → Lungă, Important → Triplă, Informativ → Scurtă.
5. **Alerta folosește vibrația aleasă.** `AlertController` primește vibrația fiecărui nivel din setări în loc de maparea fixă. Comportamentul pe nivel nu se schimbă: critica repetă vibrația aleasă până e închisă, de fiecare dată după ce tiparul s-a terminat plus 50 ms (Lungă 450 ms → la 0,5 s, ca azi; Triplă 1500 ms → la 1,55 s; Scurtă 150 ms → la 0,2 s), ca tiparul să nu fie tăiat de următoarea redare (decizia constructorului, marcată aici; durata fiecărui tipar stă lângă `Haptic`) și nu dispare singură; importanta 8 s, informativa 4 s; un nivel mai mic nu ascunde unul mai mare.
6. **Salvare**: în `AppSettings` (SharedPreferences, pe telefon), cheie `alertHaptics`, JSON `{"critical":"long","warning":"strong","info":"light"}`. O valoare necunoscută sau lipsă, ori o salvare în care două niveluri au aceeași vibrație → toate trei revin la implicit.

## Constrângeri

- Regulile din `CLAUDE.md`: texte doar prin ARB (RO + EN), `Semantics` pe rânduri (rândul de vibrație e buton cu stare „selectat”), ținte de minim 48 px, fără înălțimi fixe care taie textul la mărime mare, contrast AA, nivelul nu doar prin culoare.
- Alerta critică își păstrează prioritatea absolută (regula 3), oricare ar fi vibrația aleasă.
- Previzualizarea folosește exact aceeași funcție ca alerta reală (`AlertSignals.vibrate`), ca să simți ce vei primi. În browser vibrează doar unde browserul permite (nu în Safari pe iPhone); acolo atingerea doar alege.
- Previzualizarea nu pornește alerta, nu schimbă ecranul și nu repetă (o singură redare, chiar și pentru vibrația folosită la critic). Tiparele durează sub 1,5 s, deci o atingere nouă nu oprește vibrația în curs (`AlertSignals.clear()` ar șterge și notificările); pornește pur și simplu pe cea nouă.

## Non-scopuri

- Vibrații noi sau tipare desenate de utilizator. Vibrațiile din Setările iPhone (Bătaie de inimă, S.O.S. etc.) nu sunt accesibile aplicațiilor.
- Alegerea vibrației per sunet (ex. doar pentru claxon). Doar per nivel.
- Sincronizarea alegerii în cont (Supabase).
- Opțiunea „Fără vibrație”.
- Vibrația notificărilor de sistem cât aplicația e în fundal (`alert_signals_native.dart`, `notify`): rămâne cea de azi. Pe iPhone notificarea folosește oricum vibrația sistemului; pe Android tiparul ține de canalul de notificare, creat o singură dată. Alegerea se aplică vibrației din aplicație (`AlertSignals.vibrate`), cea care se repetă la critic.

## Lăsate constructorului

Aranjarea exactă și spațierea (după `EchoPalette`/`EchoStyle` existente și skillurile Taste / apple-design), iconițele, textele exacte în limitele de mai sus, dacă ecranul de alegere e o pagină nouă sau o foaie (`showModalBottomSheet`), structura internă a fișierelor.
