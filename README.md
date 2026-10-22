# Echo

## Claude Code

Proiectul activează patru pluginuri prin `.claude/settings.json`:

- [Superpowers](https://github.com/obra/superpowers): brainstorming, planuri, TDD, debugging, code review
- [Taste](https://github.com/Leonxlnx/taste-skill): reguli de gust pentru design frontend (necesită Node 22+ și Chrome, Edge sau Chromium)
- [Caveman](https://github.com/JuliusBrussee/caveman): răspunsuri scurte, cu mai puține tokenuri
- [Karpathy Skills](https://github.com/multica-ai/andrej-karpathy-skills): reguli de lucru după observațiile lui Andrej Karpathy (gândește înainte de cod, simplitate, modificări chirurgicale)

Pe lângă pluginuri, `.claude/skills/` conține cele 50 de skilluri de QA din [qa-skills](https://github.com/petrkindlmann/qa-skills) (licență MIT, în `.claude/skills/QA-SKILLS-LICENSE`). Ele se încarcă automat, fără instalare.

După `git pull`, pornește `claude` în folderul proiectului și acceptă marketplace-urile și pluginurile când ești întrebat.

Dacă nu apare promptul, instalează manual:

```
/plugin install superpowers@claude-plugins-official
/plugin marketplace add Leonxlnx/taste-skill
/plugin install taste-skill@taste-skill
/plugin marketplace add JuliusBrussee/caveman
/plugin install caveman@caveman
/plugin marketplace add multica-ai/andrej-karpathy-skills
/plugin install andrej-karpathy-skills@karpathy-skills
```

### Adaugi un plugin nou

Ca să-l aibă toată echipa, nu doar tu:

1. Instalează-l la nivel de proiect: `claude plugin install <plugin>@<marketplace> --scope project`. Comanda îl trece în `enabledPlugins` din `.claude/settings.json`.
2. Dacă marketplace-ul nu e cel oficial (`claude-plugins-official`), adaugă-l în `extraKnownMarketplaces` din același fișier.
3. Adaugă-l în lista de mai sus (link + o propoziție) și în comenzile de instalare manuală.
4. Adaugă-l în secțiunea „Mod de lucru” din `CLAUDE.md`, dacă schimbă felul în care lucrăm.
5. Fă commit la `.claude/settings.json` și `README.md` împreună.

## Proiectul

Platformă care face meetingurile față în față accesibile persoanelor surde. Contextul complet e în `CLAUDE.md`, designul în `docs/superpowers/specs/`.

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

Fără pașii de mai jos aplicația merge anonim, ca înainte. Detalii în `docs/superpowers/specs/2026-10-22-conturi-si-baza-de-date-design.md`.

1. Creează un proiect pe [supabase.com](https://supabase.com) (planul gratuit ajunge).
2. Trimite schema: `npx supabase link --project-ref <ref>`, apoi `npx supabase db push`.
3. În proiect: Authentication → URL Configuration → Redirect URLs, adaugă `ro.pjr.echo://login-callback` și `http://localhost:8000`. Pentru Google: Authentication → Providers → Google, cu un OAuth client din Google Cloud.
4. Emailul cu cod de 6 cifre (`supabase/templates/magic_link.html`) cere un SMTP propriu (de exemplu Resend): pe planul gratuit Supabase nu permite șabloane cu emailurile lui. Până atunci emailul conține un link care deschide aplicația sau pagina web.
5. În `.env`: `SUPABASE_URL`. Pentru aplicație creează `app/supabase.env.json` (ignorat de git) cu `{"SUPABASE_URL": "...", "SUPABASE_ANON_KEY": "<cheia publishable>"}`, apoi `flutter run --dart-define-from-file=supabase.env.json` (la fel pentru `flutter build web`).

Local, fără cloud: `npx supabase start` (cere Docker), iar emailurile apar în Mailpit pe http://localhost:54324.
