# Echo

**Echo** (**E**very **C**onversation **H**eard **O**nscreen) e o platformă care face meetingurile față în față accesibile persoanelor surde și cu deficiențe de auz. Numele apare în interfață doar prin `appTitle` din fișierele ARB; pachetul Dart (`pjr_accesibilitate`), bundle id-ul iOS și folderul repo-ului rămân neschimbate.

- Produsul complet: `docs/prezentare-generala.tex`
- Ce construim pentru demo și cum: `docs/superpowers/specs/2026-10-22-platforma-accesibilitate-design.md` (citește-l înainte de orice decizie)
- Ce e gata și cine ce face mâine: `docs/superpowers/plans/2026-10-22-demo.md`
- **Demo la juriu: 2026-10-23, ~16:00.** Echipă de 4, un singur Mac, telefoane iPhone. Orice alegere favorizează un demo care merge sigur.

## Ce construim

| Componentă | Rol | Ce face |
|---|---|---|
| Asistentul pentru meetinguri | Soluția principală | Subtitrare live pe roluri (Coordonator / Public), mod cu unul sau două dispozitive, mesaje silențioase către prezentator, rezumat + sarcini la final |
| Subtitrări în lumea reală | Bonus 1 | Balon lângă fața celui care vorbește (detecție fețe + mișcarea gurii) |
| Sunetul vizibil | Bonus 2 | Clasificare locală a sunetelor (YAMNet), 3 niveluri de alertă, alerta critică acoperă orice ecran |
| Întreabă meetingul | Extra pentru demo | Agent AI care răspunde la întrebări despre meeting, citând replicile exacte |

## Reguli care nu se negociază

1. **Audio și video nu ajung pe serverul nostru.** Prin rețea circulă doar text. (Excepție asumată pentru demo: motorul de recunoaștere vocală al platformei; vezi designul.)
2. **Rolul vorbitorului nu se transmite doar prin culoare**: mereu și iconiță, poziție și etichetă text.
3. **Alerta critică are prioritate absolută** față de orice ecran.
4. **Accesibilitate în fiecare ecran**: etichete pentru VoiceOver (`Semantics`), mărime text respectată (fără dimensiuni fixe care taie textul), contrast minim WCAG AA, ținte de atingere de minim 48 px, nimic care depinde doar de sunet.
5. **Fără texte hardcodate în interfață**: orice text vizibil trece prin `app/lib/l10n/app_ro.arb` și `app_en.arb`. Română și engleză de la început; o limbă nouă = un fișier ARB nou.
6. **Prezentatorul nu are nevoie de cont.**
7. **Secrete doar în `.env`** (ignorat de git; model în `.env.example`). Cheia API Claude stă doar pe server, niciodată în aplicația de telefon.
8. **Commit-uri ca `selimayann`, fără `Co-Authored-By: Claude`** sau altă atribuire Claude.

## Stack

| Tehnologie | Unde | Rol |
|---|---|---|
| Dart + Flutter | `app/` | Aplicația de pe iPhone (participant, sunete, baloane) și pagina prezentatorului (Flutter web în Chrome) |
| `speech_to_text` | `app/` | Recunoașterea vorbirii prin motorul platformei (iOS / Chrome) pentru demo |
| YAMNet (TFLite), ML Kit Face Detection | `app/` | Sunete și fețe, local pe telefon |
| Python + FastAPI | `server/` | Sesiuni și legătura WebSocket telefon–laptop; AI pe text prin API-ul Claude; agentul „Întreabă meetingul” |
| Docker + Compose | `docker-compose.yml` | Pornește serverul (și pagina prezentatorului) + Redis cu o comandă |
| Supabase (Postgres + Auth) | `supabase/` | Conturi (cod pe email, Google) și meetingurile salvate ale fiecărui utilizator |
| Redis | `docker-compose.yml` | Sesiunile live și limitele AI, comune tuturor instanțelor de server |

## Conturi și date (`supabase/`, `server/app/auth.py`, `hub.py`, `limits.py`)

- **Contul e opțional.** Fără `SUPABASE_URL` / `SUPABASE_ANON_KEY` aplicația și serverul merg exact ca înainte, anonim. Prezentatorul nu are niciodată cont.
- **Login fără parolă**: cod de 6 cifre pe email și Google. Fără Apple deocamdată (decizie de echipă). Fără CAPTCHA și fără coduri dictate prin apel (utilizatori surzi).
- **Ce se salvează**: doar replicile finale (text), rezumatul și setările, în contul participantului. Niciodată audio sau video.
- **Row Level Security pe fiecare tabel**: fiecare utilizator vede doar rândurile lui. Aplicația vorbește direct cu Supabase cu cheia `anon` (publică) + tokenul utilizatorului. Serverul doar verifică tokenul (JWKS sau `SUPABASE_JWT_SECRET`) și **nu folosește cheia `service_role`**.
- **Schema se schimbă doar prin migrații noi** în `supabase/migrations/` (niciodată editând una deja aplicată), cu test în `server/tests/test_database.py`.
- **Sesiunile live nu se salvează în Postgres**: stau în Redis (`REDIS_URL`) sau în memorie dacă lipsește. Codul expiră după 12 h fără activitate.
- **Limite AI** pe oră: `AI_REQUESTS_PER_HOUR` (cont) și `AI_ANONYMOUS_REQUESTS_PER_HOUR` (după IP); peste limită serverul răspunde 429.

## AI (server/)

- SDK oficial `anthropic` (Python), client asincron. Model `claude-opus-5-5`, cu `fallbacks: "default"` (antet `server-side-fallback-2026-07-01`). Efort `medium` pentru rezumat și agent, `low` pentru simplificare.
- Verifică mereu `stop_reason == "refusal"` înainte de a citi răspunsul.
- Rezumat și sarcini: un singur apel cu ieșire structurată (Pydantic). Nu e nevoie de agent acolo.
- **Agentul „Întreabă meetingul”** e scris de noi: buclă proprie de maxim 6 pași, unelte `search_transcript` și `read_lines` peste transcrierea trimisă de telefon. Răspunsul citează replicile ca `[#id]`. Modelul nu inventează: dacă nu găsește în transcriere, spune asta.
- Nu antrenăm modele de limbaj. Partea antrenată de noi (după demo) e clasificatorul de sunete pe locație peste embeddings YAMNet.
- Codul AI se testează cu un client fals; testele nu apelează API-ul real.

## Structura repo-ului

```
app/            Flutter (Dart): iOS + web (prezentator)
  lib/core/       protocol, client WebSocket, API, recunoaștere vorbire, transcriere
  lib/settings/   setări de accesibilitate (persistente)
  lib/theme/      palete daltonism, mod dislexie, contrast
  lib/core/account/  login (Supabase Auth)
  lib/core/history/  meetingurile salvate și înregistrarea lor în timpul meetingului
  lib/features/   home, participant, presenter, alerts, conversation, settings, account, history
  lib/l10n/       traduceri RO / EN (ARB)
server/         Python (FastAPI): app/ (hub sesiuni, ws, auth, limite, ai, agent), tests/
supabase/       config.toml, migrations/ (schema + RLS), templates/ (emailul cu codul)
docs/           prezentare (LaTeX), specificații și planuri superpowers
docker-compose.yml
```

## Comenzi

```
docker compose up --build          # serverul pe :8000 (.env opțional; fără cheie, AI-ul răspunde 503)
cd server && python -m venv .venv && .venv/Scripts/pip install -r requirements-dev.txt   # o dată (pe Mac: .venv/bin/)
cd server && .venv/Scripts/python -m pytest                                              # teste server
TEST_DATABASE_URL=postgresql://postgres@localhost:5432/postgres .venv/Scripts/python -m pytest tests/test_database.py   # schema + RLS pe un Postgres real
npx supabase start                 # Supabase local în Docker (Postgres, Auth, emailuri în Mailpit pe :54324)
npx supabase db reset              # reaplică migrațiile local
npx supabase link --project-ref <ref> && npx supabase db push   # trimite migrațiile în proiectul găzduit
cd app && flutter run --dart-define-from-file=supabase.env.json   # cu conturi (fișier local, ignorat de git; vezi README)
cd app && flutter test             # teste aplicație
cd app && flutter analyze
cd app && flutter run -d chrome    # pagina prezentatorului, pentru dezvoltare
cd app && flutter build web        # build servit de server la http://localhost:8000
cd app && flutter run -d <iphone>  # doar de pe Mac
```

## Mod de lucru

- **Superpowers**: `brainstorming` → design în `docs/superpowers/specs/` → `writing-plans` → implementare cu `test-driven-development` → `verification-before-completion`. Nu se scrie cod de produs nou fără design aprobat.
- **Karpathy Skills**: modificări mici și chirurgicale, cel mai simplu cod care merge, criterii de reușită verificabile.
- **Taste** (`taste-skill:design-taste-frontend`) pentru direcția vizuală; regulile de accesibilitate de mai sus au prioritate. Cere Node 22+ și Chrome / Edge.
- **Caveman** (`/caveman`) pentru răspunsuri scurte când cineva cere.
- **Pluginuri pentru toată echipa**: orice plugin Claude Code nou se instalează cu `--scope project` (ajunge în `enabledPlugins` din `.claude/settings.json`; marketplace-urile neoficiale în `extraKnownMarketplaces`) și se trece în `README.md`, secțiunea „Claude Code”, cu link și comanda de instalare manuală. Niciun plugin folosit în proiect nu rămâne doar pe calculatorul cuiva.
- Interfața și documentația în **română**; identificatorii și comentariile tehnice din cod în engleză.
