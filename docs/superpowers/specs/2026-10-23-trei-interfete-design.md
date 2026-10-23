# Trei interfețe pe telefon: admin, angajat care aude, angajat care citește

Data: 2026-10-23 · Stare: **propunere, așteaptă aprobarea echipei**

## 1. Intenție

Aplicația de telefon arată acum același ecran tuturor. În companie sunt însă trei feluri de oameni, cu nevoi diferite:

- **angajatul care citește ce se spune** (surd sau cu deficiențe de auz): îi trebuie subtitrările, sunetele vizibile și alertele;
- **angajatul care aude**: e de obicei colegul care vorbește, ridică o alarmă pentru un coleg, răspunde la alarma companiei și folosește antrenorul de claritate;
- **adminul**: pe lângă propriile nevoi, administrează compania (angajați, locații, sunete, prezența la alarmă, istoricul).

Aplicația alege interfața după ce scrie în baza de date despre om. Nu se mai ghicește și nu se mai caută prin meniuri.

## 2. Decizii (luate cu echipa)

| Decizie | Ce am ales | De ce |
|---|---|---|
| Ce le deosebește | `org_members.experience`: `standard` (aude) / `visual` (citește), plus rolul existent `admin` / `employee` | Două întrebări separate: *cum participă* și *ce administrează* |
| Adminul | **Strat peste tipul lui**, nu un al treilea tip. Un admin `visual` are și subtitrările, și instrumentele de companie | Un admin poate fi el însuși surd |
| Cine stabilește tipul | **Hibrid**: adminul îl poate pune pe invitație, angajatul îl vede înainte să accepte și îl schimbă oricând | Adminul pregătește demo-ul / compania, omul rămâne stăpân pe datele lui (art. 16) |
| Cum se numește în interfață | „Citesc ce se spune” / „Aud ce se spune”. Niciodată „surd”, „surdo-mut” sau alt diagnostic | Nevoie, nu diagnostic; „surdo-mut” e simțit ca jignitor de comunitatea surzilor |
| Fără cont sau fără companie | Pagina principală de acum, neschimbată | Prezentatorul nu are cont (regula 6); demo-ul merge și fără Supabase |

## 3. Baza de date (gata, aplicată pe Supabase)

- `supabase/migrations/20261023120000_member_experience.sql`: `member_experience` (`standard`, `visual`), coloanele `org_members.experience`, `org_members.experience_confirmed_at`, `org_invites.experience`; `my_invites()` întoarce tipul; `accept_invite()` îl copiază.
- `experience_confirmed_at` e gol până când angajatul alege sau confirmă el însuși. Dacă adminul schimbă tipul, se golește din nou.
- Orice schimbare făcută de altcineva intră în `activity_log` ca `member_experience_changed`, **fără valoare**. Rândurile pleacă atunci când omul pleacă din companie.
- `supabase/migrations/20261023130000_close_internal_functions.sql` (găsit de verificarea de securitate Supabase): RLS pe tabelele istoricului; funcțiile de trigger și orice funcție nu mai pot fi apelate de un utilizator nelogat.
- Teste: 106 în `server/tests/test_database.py` (Postgres 18) și un test pe Supabase-ul găzduit, într-o tranzacție anulată.

## 4. Cum alege aplicația interfața

```
fără cont / fără companie           → pagina principală de acum
cont + companie, tip neconfirmat    → o dată: ecranul „Cum folosești Echo?”
cont + companie, tip visual         → pagina „Citesc”
cont + companie, tip standard       → pagina „Aud”
+ admin în oricare companie         → în plus, secțiunea „Compania ta” sus pe pagină
```

- **Mai multe companii**: tipul ține de om, nu de companie. Dacă e `visual` în oricare companie, primește pagina „Citesc”. Când își schimbă tipul, se schimbă în toate companiile lui.
- Tipul se citește odată cu companiile (`Organizations.refresh`). Fără rețea rămâne ultima interfață cunoscută (salvată local, cum se salvează și setările).
- **Alerta critică acoperă orice ecran, în toate cele trei interfețe** (regula 3). Nu se schimbă nimic la ea.

## 5. Ecranele

### 5.1 „Cum folosești Echo?” (o dată, apoi din „Compania mea”)

- Două opțiuni mari, fiecare cu iconiță, titlu și o propoziție. Nu se deosebesc doar prin culoare (regula 2):
  - **Citesc ce se spune**: subtitrări în meetinguri, sunete și alarme pe ecran și prin vibrații.
  - **Aud ce se spune**: instrumentele colegului care vorbește: alarmă pentru un coleg, răspunsul la alarmă, antrenorul de claritate.
- Dacă tipul a fost pus de admin: „{companie} a ales pentru tine: Citesc ce se spune. Poți schimba oricând.”
- Informarea, înainte de alegere (art. 13): „Administratorii companiei văd ce alegi aici, ca să știe cum te anunță la o alarmă. Nu vede nimeni altcineva. Poți schimba oricând din Compania mea.”
- Butonul **Continuă** salvează alegerea și o confirmă (`experience_confirmed_at`).

### 5.2 Pagina „Citesc” (angajatul care citește)

Pagina de acum a telefonului, cu aceeași ordine:

1. Acțiunea principală: **Conectează-te la speaker** (subtitrările).
2. **Sunetele** (pornit / oprit).
3. „Altele”: Conversație, Istoric, Alarmă pentru un coleg.

### 5.3 Pagina „Aud” (angajatul care aude)

1. Acțiunea principală: **Conversație cu un coleg** (el vorbește, colegul surd citește pe ecran).
2. **Alarmă pentru un coleg** (există deja, ecranul de urgență).
3. „Pe calculator”: **Antrenorul de claritate**, cu o explicație: se deschide în Chrome, pe calculator, lângă Teams / Meet.
4. „Altele”: Conectează-te la speaker, Sunetele, Istoric. Rămân disponibile, doar nu mai sunt pe primul loc.

### 5.4 Stratul de admin („Compania ta”, sus pe pagină, în ambele tipuri)

- Un card **Compania ta** cu: numărul de angajați, invitațiile deschise și, în timpul unei alarme, **prezența** (cine a răspuns „Sunt bine” / „Am nevoie de ajutor”). Cei care primesc totul vizual apar primii, cu iconiță și etichetă text.
- Cardul deschide `OrgScreen` (vederea de admin care există deja), cu două adăugiri:
  - la **Invită**: alegerea tipului (implicit „Aud ce se spune”) și propoziția „Angajatul vede ce ai ales și poate schimba”;
  - în lista angajaților: tipul fiecăruia și „neconfirmat” până confirmă omul. Adminul poate schimba tipul; o casetă de confirmare îi spune că schimbarea apare în istoricul angajatului.

## 6. Aplicație: ce se schimbă

| Fișier | Schimbare |
|---|---|
| `app/lib/core/org/org_store.dart` | `OrgMembership` cu `experience`, `experienceConfirmed`; `OrgInvite` cu `experience`; `myOrganizations()` citește coloanele noi; `setExperience()`, `confirmExperience()`; `invite(..., experience)`; lista angajaților cu tipul |
| `app/lib/core/org/organizations.dart` | `experience` (al omului, din toate companiile), `isAdminAnywhere`, `needsExperienceChoice` |
| `app/lib/features/home/home_screen.dart` | Alege pagina după §4; cardurile existente (`_MainAction`, `_ToolRow`) se refolosesc, nu se scriu altele |
| `app/lib/features/organization/experience_screen.dart` (nou) | Ecranul din §5.1 |
| `app/lib/features/organization/org_screen.dart` | Tipul la invitație și în lista angajaților (§5.4); „Cum folosești Echo?” în vederea angajatului |
| `app/lib/l10n/app_ro.arb`, `app_en.arb` | Textele noi, în română și engleză (regula 5) |

Pagina prezentatorului (laptop, fără cont) **nu se schimbă**.

## 7. Accesibilitate (regula 4)

- Cele două opțiuni din §5.1 sunt butoane radio cu `Semantics` (selectat / neselectat) și ținte de minim 48 px; textul nu are înălțime fixă.
- Tipul unui angajat, în lista adminului: iconiță + etichetă text, niciodată doar culoare.
- Nimic din cele trei pagini nu depinde de sunet. Pagina „Aud” e pentru un om care aude, dar alertele ei rămân vizuale.

## 8. Teste

- `flutter test`:
  - pagina principală pentru fiecare caz din §4 (fără cont, neconfirmat, `visual`, `standard`, admin + `visual`, admin + `standard`);
  - ecranul §5.1 salvează și confirmă;
  - `org_store` citește și scrie coloanele noi (cu clientul fals existent);
  - alerta critică apare peste fiecare dintre cele trei pagini.
- Baza de date: gata (§3).

## 9. GDPR

| Principiu | Cum îl respectăm |
|---|---|
| Temei legal (art. 6 și art. 9) | „Citesc ce se spune” dezvăluie o deficiență de auz, deci e o dată despre sănătate (art. 9). Temeiul: obligațiile angajatorului privind securitatea în muncă și adaptarea locului de muncă, art. 9(2)(b) (în România, Legea 319/2006 și Legea 448/2006). Compania e operatorul și își asumă temeiul; noi suntem persoana împuternicită când găzduim |
| Transparență (art. 13 / 14) | Invitația arată tipul ales de admin înainte de acceptare; ecranul §5.1 spune cine vede alegerea și de ce; o schimbare făcută de admin apare în „Istoricul meu” |
| Minimizare (art. 5(1)(c)) | O singură coloană cu două valori, ca nevoie, nu ca diagnostic, fără text liber. Istoricul spune doar *că* s-a schimbat, nu valoarea. Colegii nu se văd între ei (RLS), deci tipul îl vede doar omul și adminii companiei lui |
| Exactitate și rectificare (art. 5(1)(d), art. 16) | Omul își schimbă tipul oricând; ce a pus adminul rămâne „neconfirmat” până confirmă omul |
| Limitarea stocării (art. 5(1)(e)) | Tipul stă pe rândul de membru: pleacă din companie, pleacă și tipul, cu rândurile lui din istoricul companiei. Restul istoricului: 12 luni, ca până acum |
| Dreptul la ștergere (art. 17) | Ștergerea contului șterge rândurile de membru, deci și tipul, plus rândurile `member_experience_changed` despre om |
| Securitate (art. 32) | RLS, drepturi doar pe coloanele `experience` și `experience_confirmed_at`, confirmarea o poate face doar omul (trigger), orice schimbare făcută de altcineva intră în istoric |
| Evaluare de impact (art. 35) | Date despre sănătate ale angajaților: recomandăm companiei o DPIA înainte de folosirea reală |

## 10. Ce nu intră acum

- Tipuri mai fine (de exemplu „folosesc limbajul semnelor”): doar dacă le cere o nevoie concretă, tot ca nevoie, nu ca diagnostic.
- Interfețe diferite pe laptop (pagina prezentatorului rămâne una singură).
- Exportul datelor (art. 20), ca la istoric.

## 11. Riscuri

- **Demo-ul de azi**: schimbarea paginii principale atinge ecranul pe care îl vede juriul primul. Fără cont, sau dacă citirea companiilor eșuează, aplicația arată pagina de acum, deci demo-ul fără conturi nu se schimbă.
- Un om în două companii, cu tipuri diferite puse de admini diferiți: câștigă `visual`, iar ecranul §5.1 îi cere să confirme.
- Juridic: interfața informează, dar nu înlocuiește informarea făcută de companie către angajați.
