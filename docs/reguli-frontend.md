# Reguli pentru frontend

Regulile de mai jos vin din [Web Interface Guidelines](https://vercel.com/design/guidelines) ale Vercel ([vercel-labs/web-interface-guidelines](https://github.com/vercel-labs/web-interface-guidelines), licență MIT), adaptate pentru Flutter (iPhone și pagina prezentatorului în Chrome). Se aplică la orice ecran nou sau modificat, împreună cu regulile proiectului, care au prioritate.


## Interacțiuni

- **Tastatura merge peste tot** pe pagina prezentatorului: Tab ajunge la orice control, în ordine logică; Enter și Space îl activează.
- **Focus vizibil**: orice control focalizabil are un contur clar, neacoperit de bare sau panouri.
- **Focus gestionat**: un dialog ține focusul în interior și îl întoarce la buton când se închide.
- **Ținta de atingere egală cu ce se vede**, minim 48 px (`MaterialTapTargetSize.padded`). Nicio zonă care pare apăsabilă și nu e.
- **Butoane care încarcă**: păstrează eticheta și arată un indicator; nu dispar și nu își schimbă lățimea.
- **Fără pâlpâire**: un indicator de încărcare apare după ~200 ms și rămâne cel puțin ~400 ms.
- **Acțiunile distructive** cer confirmare sau oferă „Anulează” câteva secunde.
- **Gesturile au alternativă**: orice glisare sau tragere are și un buton.
- **Actualizările care apar singure** (mesaj nou, alertă, eroare) se anunță cititorului de ecran (`SemanticsService.announce` sau `Semantics(liveRegion: true)`).
- **Lipirea textului** e permisă în orice câmp; codurile de sesiune se pot lipi întregi.

## Animații

- **Respectă „Reducere mișcare”**: `MediaQuery.disableAnimationsOf(context)` oprește animațiile decorative.
- **Animă doar când explică** o cauză și un efect, sau confirmă o apăsare (`Pressable`: scară 0,97, 160 ms).
- **Doar transformări și opacitate**: `AnimatedScale`, `FadeTransition`, `SlideTransition`; nu anima lățimi, înălțimi sau padding.
- **Întreruptibile**: o animație nu blochează următoarea atingere.
- **Pornesc de unde vin**: un meniu crește din butonul care l-a deschis.

## Așezare

- **Aliniere deliberată**: totul se aliniază la marginea coloanei, la grilă sau la linia de bază a textului.
- **Verifică la trei lățimi**: telefon (390), laptop (1280), ecran foarte lat (2560), și cu text mărit la 200%.
- **Zone sigure**: `SafeArea` pentru notch și bara de jos pe iPhone.
- **Fără bare de derulare inutile**: conținutul nu depășește ecranul din greșeală.
- **Lasă layoutul să decidă**: `Row`, `Column`, `Wrap`, `Expanded` în loc de mărimi calculate de mână.

## Conținut

- **Explicația lângă control**, nu în tooltip.
- **Niciun ecran fără ieșire**: fiecare ecran are un pas următor sau o cale de revenire.
- **Toate stările desenate**: gol, puțin, mult, eroare, fără conexiune.
- **Ghilimele românești** („ ”) și caracterul `…`, nu trei puncte.
- **Starea nu se arată doar prin culoare**: mereu și text sau iconiță.
- **Iconițele singure au etichetă** (`tooltip` sau `Semantics(label:)`); decorul e ascuns cu `ExcludeSemantics`.
- **Titluri ierarhice**: `Semantics(header: true)` pe titlurile de ecran și de secțiune.
- **Texte lungi**: layoutul rezistă la nume scurte, obișnuite și foarte lungi.
- **Formate după limbă**: date, ore și numere prin `intl`, după limba aleasă.
- **Spațiu care nu se rupe** între număr și unitate: `10 min`.

## Formulare

- **Enter trimite** când câmpul e singurul din formular (`textInputAction: TextInputAction.done`, `onSubmitted`).
- **Etichetă pentru fiecare câmp**, vizibilă deasupra lui, nu doar ca placeholder.
- **Nu bloca tastarea**: acceptă orice și explică ce e greșit.
- **Butonul de trimitere rămâne activ** până la trimitere; abia atunci se dezactivează și arată progresul.
- **Eroarea stă lângă câmp** și spune cum se repară, nu doar ce e greșit.
- **Tastatura potrivită**: `keyboardType` și `autofillHints` corecte; fără corectare automată la coduri și adrese.
- **Placeholderul e un exemplu** (`ABC123`), nu o instrucțiune.
- **Spațiile de la capete se taie** înainte de validare.

## Performanță

- **Testează pe iPhone în modul de economisire a bateriei** și în Chrome cu procesorul încetinit.
- **Fără muncă grea pe firul principal**: clasificarea sunetelor și procesarea rulează în afara lui (`compute` sau izolat).
- **Liste lungi** cu `ListView.builder`, nu `Column` cu toate elementele.
- **Imaginile au dimensiuni fixate**, ca layoutul să nu sară când se încarcă.
- **Fonturile sunt incluse în aplicație** (Roboto și OpenDyslexic în `assets/fonts`), deci textul nu sare la încărcare.

## Design

- **Umbre în două straturi** (lumină ambientală și directă), sau deloc.
- **Colțuri concentrice**: raza unui element interior e mai mică sau egală cu a celui exterior.
- **Nuanțe consecvente**: pe un fundal colorat, bordura și textul secundar iau aceeași nuanță.
- **Contrast minim WCAG AA**; hover, apăsare și focus au mai mult contrast decât starea de repaus.
- **Culoarea browserului** se potrivește cu fundalul paginii (`theme-color` în `web/index.html`).

## Texte

- **Diateză activă și verbe**: „Intră în meeting”, nu „Intrarea se va face”.
- **Etichete precise**: „Salvează rezumatul”, nu „Continuă”.
- **Cât mai puține cuvinte** și aceiași termeni peste tot.
- **Cifre pentru numere**: „3 participanți”.
- **Erorile spun ce urmează**: „Nu găsim meetingul. Verifică codul sau cere-l din nou prezentatorului.”
