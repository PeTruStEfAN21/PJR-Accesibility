# Echo

## Claude Code

Proiectul activează șase pluginuri prin `.claude/settings.json`:

- [Superpowers](https://github.com/obra/superpowers): brainstorming, planuri, TDD, debugging, code review
- [Taste](https://github.com/Leonxlnx/taste-skill): reguli de gust pentru design frontend (necesită Node 22+ și Chrome, Edge sau Chromium)
- [Caveman](https://github.com/JuliusBrussee/caveman): răspunsuri scurte, cu mai puține tokenuri
- [Karpathy Skills](https://github.com/multica-ai/andrej-karpathy-skills): reguli de lucru după observațiile lui Andrej Karpathy (gândește înainte de cod, simplitate, modificări chirurgicale)
- [Impeccable](https://impeccable.style) ([pbakaus/impeccable](https://github.com/pbakaus/impeccable)): limbaj de design pentru frontend, cu comenzi ca `/impeccable audit`, `/impeccable critique`, `/impeccable polish`
- [UI UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill): bază de date de stiluri, palete, combinații de fonturi și reguli UX, cu ghid pentru Flutter (licență MIT)

Pe lângă pluginuri, `.claude/skills/` conține skilluri care se încarcă automat, fără instalare:

- cele 50 de skilluri de QA din [qa-skills](https://github.com/petrkindlmann/qa-skills) (licență MIT, în `.claude/skills/QA-SKILLS-LICENSE`);
- cele 15 skilluri de design și animație ale lui Emil Kowalski din [emilkowalski/skills](https://github.com/emilkowalski/skills) (licență MIT, în `.claude/skills/EMIL-SKILLS-LICENSE`), de exemplu `emil-design-eng`, `animate`, `review-animations`, `break-ui`, `apple-design`. Pentru o versiune nouă: `npx skills@latest add emilkowalski/skills` sau copiezi din nou folderul `skills/`.
- skillul `web-design-guidelines` din [vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) (licență MIT, în `.claude/skills/VERCEL-GUIDELINES-LICENSE`): verifică interfața după [Web Interface Guidelines](https://vercel.com/design/guidelines). Varianta adaptată pentru Flutter, pe care o urmăm, e în `docs/reguli-frontend.md`. Pentru o versiune nouă: `npx skills add https://github.com/vercel-labs/agent-skills --skill web-design-guidelines`.

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
/plugin marketplace add pbakaus/impeccable
/plugin install impeccable@impeccable
/plugin marketplace add nextlevelbuilder/ui-ux-pro-max-skill
/plugin install ui-ux-pro-max@ui-ux-pro-max-skill
```

### Servere MCP

`.mcp.json` declară serverele MCP ale proiectului, iar `.claude/settings.json` le aprobă automat (`enabledMcpjsonServers`):

- [Playwright MCP](https://github.com/microsoft/playwright-mcp) (`@playwright/mcp@0.0.83`): Claude deschide și controlează Chrome, ca să verifice pagina prezentatorului (`flutter build web` + server pe http://localhost:8000). Necesită Node 18+ și Chrome.

- [Krea MCP](https://www.krea.ai/mcp) (`https://api.krea.ai/mcp`): generare de imagini și clipuri video cu AI, pentru videoul de prezentare. Serverul e găzduit de Krea, deci nu are versiune; contul se leagă prin OAuth, fără cheie în repo: în Claude Code rulezi `/mcp`, alegi `krea` și te loghezi în Krea în browser. Consumă creditele contului Krea.

Dacă nu pornește singur: `claude mcp add --scope project playwright -- npx @playwright/mcp@0.0.83` și `claude mcp add --scope project --transport http krea https://api.krea.ai/mcp`.

### Videoul de prezentare (`video/`)

`video/` conține [Claude Code Video Toolkit](https://github.com/digitalsamba/claude-code-video-toolkit) (licență MIT, în `video/LICENSE`), copiat la commitul `da3f474` (2026-10-22), găsit prin lista [wilwaldon/Claude-Code-Video-Toolkit](https://github.com/wilwaldon/Claude-Code-Video-Toolkit). Am păstrat skillurile (Remotion, FFmpeg, ElevenLabs, înregistrare cu Playwright etc.), comenzile (`/video`, `/record-demo`, `/scene-review`, `/generate-voiceover`), componentele, șabloanele `product-demo` și `sprint-review` și uneltele Python. Am scos exemplele, showcase-ul, imaginile Docker pentru GPU în cloud și testele toolkitului.

Lucrezi din folderul lui, ca să se încarce skillurile, comenzile și `video/CLAUDE.md`:

```
cd video
claude            # apoi /video; proiectul Echo stă în video/projects/ și intră în git
```

Necesită Node 18+; pentru unelte (voce, muzică, subtitrări) și `uv` (`uv sync` în `video/`). Cheile opționale (de ex. `ELEVENLABS_API_KEY`) stau în `video/.env`, după modelul `video/.env.example`; fișierul e ignorat de git. Videourile randate (`out/`, `*.mp4`) nu intră în git. Pe Windows, rulează o dată `git config core.longpaths true`, pentru că unele căi din skillul Remotion sunt lungi.

### Adaugi un plugin nou

Ca să-l aibă toată echipa, nu doar tu:

1. Instalează-l la nivel de proiect: `claude plugin install <plugin>@<marketplace> --scope project`. Comanda îl trece în `enabledPlugins` din `.claude/settings.json`.
2. Dacă marketplace-ul nu e cel oficial (`claude-plugins-official`), adaugă-l în `extraKnownMarketplaces` din același fișier.
3. Adaugă-l în lista de mai sus (link + o propoziție) și în comenzile de instalare manuală.
4. Adaugă-l în secțiunea „Mod de lucru” din `CLAUDE.md`, dacă schimbă felul în care lucrăm.
5. Fă commit la `.claude/settings.json` și `README.md` împreună.

La fel pentru un server MCP: `claude mcp add --scope project <nume> -- <comandă>` (ajunge în `.mcp.json`), cu versiune fixă, apoi numele lui în `enabledMcpjsonServers` și o linie în „Servere MCP”.

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
4. Emailul cu cod de 6 cifre (`supabase/templates/magic_link.html`) pleacă prin Resend (SMTP). Pune `RESEND_API_KEY` în `supabase/.env`. Fără un domeniu verificat în Resend, emailurile ajung doar la adresa contului Resend: verifică un domeniu înainte de utilizatori reali.
5. În `.env`: `SUPABASE_URL`. Pentru aplicație creează `app/supabase.env.json` (ignorat de git) cu `{"SUPABASE_URL": "...", "SUPABASE_ANON_KEY": "<cheia publishable>"}`, apoi `flutter run --dart-define-from-file=supabase.env.json` (la fel pentru `flutter build web`).

Local, fără cloud: `npx supabase start` (cere Docker), iar emailurile apar în Mailpit pe http://localhost:54324.
### Aplicația Android (APK)

```
cd app && flutter build apk --release --dart-define-from-file=supabase.env.json --dart-define=ECHO_SERVER=https://pjr-accesibility.onrender.com
```

Rezultatul e `app/build/app/outputs/flutter-apk/app-release.apk` (toate arhitecturile, ~96 MB), cu conturile din `supabase.env.json` și serverul găzduit pe Render ca adresă implicită. Cere Android SDK și un JDK (`flutter doctor`). Semnătura e cea de debug a calculatorului care îl construiește: un APK nou se instalează peste cel vechi doar dacă vine de pe același calculator. Iconițele aplicației (Android, notificări, iOS) se refac din logo cu `python tools/app_icon.py`.


### Companii (organizații)

Cu conturi activate, din **Contul meu → Compania mea** un angajator își face compania, invită angajații pe email (ei acceptă din contul lor), le vede nevoile de accesibilitate (fără diagnostic), împarte sunetele locației învățate o dată și, la o alarmă critică, vede cine a răspuns „Sunt în siguranță” sau „Am nevoie de ajutor”. Detalii: `docs/superpowers/specs/2026-10-22-organizatii-design.md`.

**Instalare la companie** (datele nu ies din firmă): aceeași schemă rulează pe un Supabase găzduit de companie.

1. Pe un server al companiei, [Supabase self-hosted cu Docker](https://supabase.com/docs/guides/self-hosting/docker) (Postgres + Auth). Setează SMTP-ul companiei pentru emailurile cu cod.
2. Trimite schema din acest repo: `npx supabase db push --db-url postgresql://postgres:<parola>@<server>:5432/postgres`.
3. Serverul Echo (`docker compose up --build`) cu `SUPABASE_URL` și `SUPABASE_JWT_SECRET` ale instalării din firmă, în `.env`.
4. Aplicația, construită cu `supabase.env.json` care arată spre Supabase-ul firmei (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).

Testele schemei rulează pe orice Postgres: `TEST_DATABASE_URL=... python -m pytest tests/test_database.py`. Fără Docker, un Postgres temporar merge cu `initdb -D <folder> -U postgres --auth=trust`, apoi `pg_ctl -D <folder> -o "-p 54329" start` și `TEST_DATABASE_URL=postgresql://postgres@localhost:54329/postgres`.

### Alarma dată de un coleg

Un coleg intrat în cont dă o alarmă de urgență din aplicație („Alarmă de urgență” pe ecranul principal); o primesc cei intrați în cont aflați la cel mult 500 m. Cere conturile de mai sus. Detalii în `docs/superpowers/specs/2026-10-22-alarma-manuala-design.md`.

- Serverul: `POST /api/alarms`, `POST /api/alarms/{id}/cancel` (cu cont, cel mult 3 alarme pe oră) și `/ws/alarms` pentru ascultare.
- Cine a dat alarma (cont, email, IP, ora, locul) se salvează în istoricul activității din baza de date (`activity_log`), prin rolul Postgres `echo_audit`, care poate doar să adauge rânduri; rândurile mai vechi de 12 luni se șterg o dată pe zi. Pentru activare: în SQL editorul Supabase `alter role echo_audit with login password '…';`, apoi adresa de conectare în `AUDIT_DATABASE_URL` din `.env` (la Supabase găzduit, prin pooler, utilizatorul e `echo_audit.<project-ref>`; model în `.env.example`). Fără variabilă, sau dacă baza de date nu răspunde, alarma se scrie în logul serverului (`docker compose logs server`).
- Pe Mac, după `git pull`: `cd app/ios && pod install` (pachetul de locație `geolocator`).
