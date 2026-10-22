# Organizații: compania își gestionează angajații, sunetele locației și prezența la alarmă

**Data:** 2026-10-22 · **Stare:** aprobat; etapa 1 (schema) gata · **Pornește de la:** `2026-10-22-conturi-si-baza-de-date-design.md` (roadmap: „panou HR / organizații”)

## 1. Intenție

O companie care cumpără Echo își face spațiul ei: invită angajații cu deficiențe de auz, le vede nevoile de accesibilitate, împarte sunetele locației (alarma halei învățată o dată ajunge pe toate telefoanele) și, la o alarmă critică, vede cine a confirmat că e în siguranță.

## 2. Decizii

| Întrebare | Decizie | De ce |
|---|---|---|
| Unde stau datele companiei | **Aceeași schemă oriunde**: în Supabase-ul nostru (fiecare companie izolată prin RLS) sau într-un Supabase instalat la companie (Docker), dacă datele nu au voie să iasă din firmă | Un singur cod, aceleași migrații; aplicația schimbă doar `SUPABASE_URL` / `SUPABASE_ANON_KEY` |
| Ce știm despre angajat | **Nevoi, nu diagnostic**: nume afișat, departament, locație și câteva nevoi fixe (subtitrare, alerte vizuale, ceas, limbă, text mare) | Datele despre sănătate sunt categorie specială (GDPR art. 9). Coloane fixe, fără câmp de text liber în care să ajungă detalii medicale |
| Cine adaugă angajatul | Adminul **invită** pe email; angajatul **acceptă** din contul lui | Consimțământ: nimeni nu e pus într-o companie fără să știe. Fără cheia `service_role`, adminul oricum nu poate crea conturi |
| Cine scrie nevoile | **Doar angajatul**; adminii companiei doar le citesc | Angajatul controlează ce împarte |
| Ieșirea din companie | Angajatul pleacă oricând; nevoile și confirmările lui se șterg în cascadă | Dreptul de ștergere |
| Roluri | `admin` și `employee`. Cel puțin un admin rămâne mereu | Simplu; suficient pentru HR / responsabil SSM |
| Server | Neschimbat: doar verifică tokenul, nu are `service_role` | Regula proiectului |

## 3. Schema (migrație nouă `supabase/migrations/20261022180000_organizations.sql`)

- `organizations`: nume, creată prin `create_organization(name)`, care îl face pe apelant admin în aceeași tranzacție.
- `org_locations`: locațiile companiei (Hala 2, Sediul central).
- `org_members`: `(org_id, user_id)`, rol, nume afișat, departament, locație. Adminul schimbă rolul, departamentul și locația; angajatul își schimbă numele afișat.
- `org_invites`: email (litere mici), rol, departament, locație, expiră după 14 zile. `accept_invite(id)` merge doar dacă emailul din tokenul apelantului e cel invitat.
- `member_needs`: un rând per membru: `captions`, `visual_alerts`, `watch_alerts`, `large_text` (boolean), `language` (`ro`, `en`…). Scrie doar angajatul, citesc el și adminii.
- `org_location_sounds`: eticheta, nivelul, **modelul** (`tflite` = telefon, `tfjs` = browser; amprentele nu se potrivesc între ele) și amprenta (`real[]`, 1024 de valori). Scriu adminii, citesc membrii companiei. Doar amprenta, niciodată audio.
- `alarm_events` + `alarm_acks`: `report_alarm(location, kind)` deschide un eveniment (sau îl refolosește pe cel deschis în ultimele 10 minute pentru aceeași locație); fiecare angajat își trimite confirmarea: `safe` sau `need_help`. Adminii văd toate confirmările evenimentelor companiei; angajatul doar pe a lui. Adminul închide evenimentul.
- Funcții `is_org_member(org)` / `is_org_admin(org)` (`security definer`, `stable`) folosite în politici, ca RLS să nu se apeleze recursiv.
- Un trigger împiedică scoaterea sau retrogradarea ultimului admin.
- RLS pe fiecare tabel; `anon` nu are acces la nimic.

## 4. Etape

1. **Acum (înainte să fie folosită baza de date):** migrația, RLS și testele în `server/tests/test_database.py`. Nimic nu se schimbă în aplicație sau pe server; demo-ul de mâine nu e atins.
2. **După demo:** în aplicație: crearea companiei, invitații, acceptarea invitației, ecranul cu nevoile angajatului, sincronizarea sunetelor locației cu `LocationSoundStore`, butoanele „Sunt în siguranță / Am nevoie de ajutor” pe ecranul roșu și lista de prezență pentru admin. Fiecare cu designul ei mic.
3. **Instalare la companie:** ghid în README (Supabase self-hosted în Docker + `supabase db push`).

## 5. Teste (Postgres real, ca până acum)

- Două companii: membrii uneia nu văd nimic din cealaltă (membri, invitații, nevoi, sunete, alarme).
- Doar adminul invită, schimbă roluri, adaugă sunete și locații; un angajat nu poate.
- Invitația se acceptă doar cu emailul invitat și doar înainte să expire; o dată.
- Nevoile: le scrie doar angajatul; adminul le citește, dar nu le poate schimba.
- Ultimul admin nu poate fi scos sau retrogradat.
- Plecarea din companie șterge nevoile și confirmările.
- Alarme: raportarea repetată în 10 minute refolosește evenimentul; angajatul își vede doar confirmarea; adminul le vede pe toate.
- `anon` nu vede nimic.

## 6. Riscuri

- **Responsabilitatea pentru date**: compania e operatorul de date pentru angajații ei, noi suntem persoana împuternicită (contract DPA) când găzduim noi. La instalarea locală, datele nu ajung la noi deloc.
- Lista de prezență nu înlocuiește procedura de evacuare; o spunem în interfață.
- Emailul din invitație trebuie să fie cel cu care angajatul se autentifică (cod pe email sau Google).
