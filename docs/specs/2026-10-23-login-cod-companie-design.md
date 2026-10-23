# Login Admin / Angajat cu codul companiei

Data: 2026-10-23 · Stare: **implementat; migrația aplicată pe Supabase-ul găzduit cu acordul lui Ayan.** Cerut de Ayan („sari peste întrebări, vreau să văd ce iese”); deciziile marcate „alegerea noastră” pot fi schimbate

## 1. Intenție

Aplicația merge în trei direcții: **adminul** care administrează echipa, **angajatul care citește ce se spune** și **angajatul care aude** (designul `2026-10-23-trei-interfete-design.md`). Intrarea în aplicație trebuie să spună din prima în care direcție merge omul:

- adminul își face contul și compania;
- adminul generează un **cod al companiei** și îl dă angajaților (pe chat, pe hârtie, pe ecran);
- angajatul intră cu **codul companiei, numele lui și emailul**, confirmă emailul cu un cod de 6 cifre și are contul gata, direct în companie;
- adminul vede angajații și poate scoate pe cineva (demisie, plecare).

## 2. Decizii

| Decizie | Ce am ales | De ce |
|---|---|---|
| Cum se verifică omul | **Cod de 6 cifre pe email** (Supabase Auth + Resend, există deja) | Cerut de Ayan în locul SMS-ului: gratuit, fără Twilio. Text, nu apel (utilizatori surzi) |
| Selector | **Admin / Angajat** sus pe ecranul de login, același `GlassSegmented` ca la Meeting | Același UI ca restul aplicației |
| Google | Rămâne **doar la Admin** (alegerea noastră) | La web, Google pleacă din pagină și s-ar pierde codul companiei scris de angajat |
| Codul companiei | 8 caractere fără litere ușor de confundat (fără 0/O, 1/I/L), afișat `ABCD-EFGH`, **valabil 7 zile**, câte unul activ pe companie; unul nou îl anulează pe cel vechi (alegerea noastră) | Ușor de dictat și de scris; o scurgere a codului are efect limitat |
| Cum se păstrează codul | **Doar amprenta lui (SHA-256)**; textul îl vede adminul o singură dată, când îl generează | Cine citește baza de date nu poate intra în companii |
| Încercări greșite | **Maxim 5 pe oră** pentru un cont | Codul nu poate fi ghicit prin încercări |
| Tipul angajatului | Angajatul alege la intrare „Citesc ce se spune” / „Aud ce se spune”; alegerea lui e confirmată (`experience_confirmed_at`) | Omul decide (art. 16); fără „surd” sau „surdo-mut” în interfață |
| Invitațiile pe email | **Rămân** (alegerea noastră) | Nu stricăm ce merge; codul e o cale în plus |

## 3. Baza de date (migrație nouă `20261023150000_company_join_codes.sql`)

- `org_join_codes`: `org_id` (cheie, un cod activ pe companie), `code_hash` (unic), `created_by`, `created_at`, `expires_at`. RLS pornit, **fără nicio regulă și fără drepturi** pentru `anon` / `authenticated`: se ajunge la ea doar prin funcții.
- `org_join_attempts`: `user_id`, `at`. Doar pentru limită; rândurile mai vechi de o oră se șterg la fiecare încercare. Fără drepturi directe.
- `new_join_code(target_org uuid) returns text`: doar adminul companiei. Șterge codul vechi, salvează amprenta celui nou și întoarce textul o singură dată.
- `join_code_info(target_org uuid) returns table (expires_at timestamptz)`: doar adminul. Spune dacă există un cod activ și până când, fără cod.
- `revoke_join_code(target_org uuid)`: doar adminul.
- `join_with_code(code text, member_name text, member_experience member_experience) returns uuid`: orice utilizator logat. Verifică limita de încercări, găsește compania după amprentă și expirare, adaugă omul ca `employee` cu numele, emailul din token și tipul ales (confirmat). Dacă e deja în companie, întoarce compania fără să schimbe nimic.
- `org_members`: se citesc și `experience`, `experience_confirmed_at` în lista adminului (coloanele există).
- `activity_log`: evenimente noi `member_joined` (intrarea **cu cod**; invitațiile pe email își păstrează fluxul de până acum), `member_removed` (adminul care a scos și pe cine) și `member_left` (omul a plecat singur).
- Teste în `server/tests/test_database.py`: doar adminul generează și vede codul; codul vechi nu mai merge; cod expirat sau greșit nu merge; a 6-a încercare greșită într-o oră e refuzată; angajatul intră cu numele și tipul lui, ca `employee`; nu se poate face admin prin cod; tabelele noi nu se pot citi direct; evenimentele ajung în istoric; nelogații nu pot apela nimic.

## 4. Aplicația

- `SignInScreen`: selector **Admin / Angajat**.
  - **Admin**: email → cod → (dacă nu are companie) numele companiei → ecranul companiei.
  - **Angajat**: codul companiei, numele, „Citesc ce se spune” / „Aud ce se spune”, email → cod → intrarea în companie. Dacă codul companiei e greșit sau expirat, omul rămâne logat și îl poate rescrie.
- `OrgScreen` (adminul): secțiunea **Codul companiei** (generează, copiază, valabil până la …, anulează) și, la fiecare angajat, tipul lui cu iconiță + text („Citește ce se spune” / „Aude ce se spune”). Scoaterea unui angajat există deja.
- `OrgStore`: `newJoinCode`, `joinCodeInfo`, `revokeJoinCode`, `joinWithCode`; `OrgMember.experience`.
- Texte noi doar prin ARB, în română și engleză.
- Paginile diferite pentru „Citesc” / „Aud” din designul `trei-interfete` **nu intră aici**: loginul doar salvează tipul, pe care paginile acelea îl vor folosi.

## 5. Accesibilitate

Selectorul și alegerea tipului: butoane cu `Semantics` (selectat / neselectat), minim 48 px, iconiță + text. Erorile: iconiță + text, anunțate (`liveRegion`). Codul companiei: o singură casetă, litere mari, fără dimensiuni fixe care taie textul. Nimic nu depinde de sunet.

## 6. GDPR

| Principiu | Cum îl respectăm |
|---|---|
| Temei legal | Contul și apartenența la companie: executarea relației de muncă / interesul legitim al companiei (art. 6(1)(b)/(f)). Tipul „Citesc ce se spune” e dată despre sănătate: art. 9(2)(b), ca în designul `trei-interfete` |
| Informare înainte (art. 13) | Pe ecranul angajatului, deasupra butonului: „Intri în compania care ți-a dat codul. Administratorii ei văd numele, emailul și cum folosești Echo, ca să știe cum te anunță la o alarmă. Poți ieși oricând din Compania mea.” |
| Minimizare | Numele (max 100 caractere), emailul (îl are deja contul) și tipul cu două valori. Fără telefon, fără text liber. Codul se păstrează doar ca amprentă. Încercările greșite: doar contul și ora, șterse după o oră |
| Păstrare | Codul: 7 zile. Încercările: o oră. Rândul de membru: cât e omul în companie. Istoricul: 12 luni, ca până acum |
| La ștergerea contului | Pleacă rândul de membru, încercările și (prin `forget_user_activity`) legătura cu contul din istoric, ca la celelalte evenimente |
| Securitate | Tabele fără acces direct, funcții `security definer` cu `search_path` fixat care verifică `auth.uid()`, limită de încercări, nelogații nu apelează nimic |

## 7. Riscuri

- **Emailurile**: de pe `onboarding@resend.dev`, Resend trimite doar la adresa contului Resend până verificăm un domeniu. La demo: adminul cu Google sau domeniu verificat.
- **Baza găzduită** e comună echipei: migrația a fost aplicată după acordul lui Ayan, după ce testele au trecut pe un Postgres 18 local (116/116).
