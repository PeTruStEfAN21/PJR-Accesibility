# Echo

## Proiectul

Platformă care face meetingurile față în față accesibile persoanelor surde. Designul în `docs/specs/`.

- `app/`: aplicația Flutter (iPhone + pagina prezentatorului în Chrome)
- `server/`: serverul Python (FastAPI): legătura telefon–laptop și partea de AI
- `docs/`: prezentarea și documentele de design

Pornire rapidă:

```
cp .env.example .env               # completează ANTHROPIC_API_KEY și PUBLIC_URL
cd app && flutter build web && cd ..
docker compose up --build          # serverul + Redis + pagina prezentatorului pe http://localhost:8000
```

### Conturi și meetinguri salvate (opțional)

Fără pașii de mai jos aplicația merge anonim, ca înainte. Detalii în `docs/specs/2026-10-22-conturi-si-baza-de-date-design.md`.

1. Creează un proiect pe [supabase.com](https://supabase.com) (planul gratuit ajunge).
2. Trimite schema: `npx supabase link --project-ref <ref>`, apoi `npx supabase db push`.
3. În proiect: Authentication → URL Configuration → Redirect URLs, adaugă `ro.pjr.echo://login-callback` și `http://localhost:8000`. Pentru Google: Authentication → Providers → Google, cu un OAuth client din Google Cloud.
4. Emailul cu cod de 6 cifre (`supabase/templates/magic_link.html`) pleacă prin Resend (SMTP). Pune `RESEND_API_KEY` în `supabase/.env`. Fără un domeniu verificat în Resend, emailurile ajung doar la adresa contului Resend: verifică un domeniu înainte de utilizatori reali.
5. În `.env`: `SUPABASE_URL`. Pentru aplicație creează `app/supabase.env.json` (ignorat de git) cu `{"SUPABASE_URL": "...", "SUPABASE_ANON_KEY": "<cheia publishable>"}`, apoi `flutter run --dart-define-from-file=supabase.env.json` (la fel pentru `flutter build web`).

Local, fără cloud: `npx supabase start` (cere Docker), iar emailurile apar în Mailpit pe http://localhost:54324.

### Companii (organizații)

Cu conturi activate, din **Contul meu → Compania mea** un angajator își face compania, invită angajații pe email (ei acceptă din contul lor), le vede nevoile de accesibilitate (fără diagnostic), împarte sunetele locației învățate o dată și, la o alarmă critică, vede cine a răspuns „Sunt în siguranță” sau „Am nevoie de ajutor”. Detalii: `docs/specs/2026-10-22-organizatii-design.md`.

**Instalare la companie** (datele nu ies din firmă): aceeași schemă rulează pe un Supabase găzduit de companie.

1. Pe un server al companiei, [Supabase self-hosted cu Docker](https://supabase.com/docs/guides/self-hosting/docker) (Postgres + Auth). Setează SMTP-ul companiei pentru emailurile cu cod.
2. Trimite schema din acest repo: `npx supabase db push --db-url postgresql://postgres:<parola>@<server>:5432/postgres`.
3. Serverul Echo (`docker compose up --build`) cu `SUPABASE_URL` și `SUPABASE_JWT_SECRET` ale instalării din firmă, în `.env`.
4. Aplicația, construită cu `supabase.env.json` care arată spre Supabase-ul firmei (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).

Testele schemei rulează pe orice Postgres: `TEST_DATABASE_URL=... python -m pytest tests/test_database.py`. Fără Docker, un Postgres temporar merge cu `initdb -D <folder> -U postgres --auth=trust`, apoi `pg_ctl -D <folder> -o "-p 54329" start` și `TEST_DATABASE_URL=postgresql://postgres@localhost:54329/postgres`.

### Alarma dată de un coleg

Un coleg intrat în cont dă o alarmă de urgență din aplicație („Alarmă de urgență” pe ecranul principal); o primesc cei intrați în cont aflați la cel mult 500 m. Cere conturile de mai sus. Detalii în `docs/specs/2026-10-22-alarma-manuala-design.md`.

- Serverul: `POST /api/alarms`, `POST /api/alarms/{id}/cancel` (cu cont, cel mult 3 alarme pe oră) și `/ws/alarms` pentru ascultare.
- Cine a dat alarma ajunge la `AlarmRecorder` (`server/app/alarms.py`). Deocamdată se scrie doar în logul serverului (`docker compose logs server`); salvarea în baza de date se adaugă acolo.
- Pe Mac, după `git pull`: `cd app/ios && pod install` (pachetul de locație `geolocator`).
