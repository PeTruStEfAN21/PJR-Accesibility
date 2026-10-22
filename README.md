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
