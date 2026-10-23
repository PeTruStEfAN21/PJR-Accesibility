# Echo

**Echo** (**E**very **C**onversation **H**eard **O**nscreen) e o platformă care face meetingurile față în față accesibile persoanelor surde și cu deficiențe de auz. Numele apare în interfață doar prin `appTitle` din fișierele ARB; pachetul Dart (`pjr_accesibilitate`), bundle id-ul iOS și folderul repo-ului rămân neschimbate.

- Produsul complet: `docs/prezentare-generala.tex`
- Ce construim pentru demo și cum: `docs/superpowers/specs/2026-10-22-platforma-accesibilitate-design.md` (citește-l înainte de orice decizie)
- Meetingul fizic (vocea speakerului, întrebări, „Ți s-a răspuns”): `docs/superpowers/specs/2026-10-22-meeting-fizic-design.md`; înlocuiește partea de meeting din designul de mai sus
- Ce e gata și cine ce face mâine: `docs/superpowers/plans/2026-10-22-demo.md`
- **Demo la juriu: 2026-10-23, ~16:00.** Echipă de 4, un singur Mac, telefoane iPhone. Orice alegere favorizează un demo care merge sigur.

## Ce construim

| Componentă | Rol | Ce face |
|---|---|---|
| Asistentul pentru meetinguri | Soluția principală | Meeting **fizic**, persoana surdă cu telefonul în mână. Laptopul speakerului ascultă sala, îi recunoaște vocea (model antrenat de noi) și etichetează replicile Speaker / Din sală; întrebările din sală sunt marcate; butonul „Vreau să întreb” alertează speakerul, întrebarea scrisă e citită cu voce tare, iar răspunsul speakerului e detectat automat („Ți s-a răspuns”); rezumat + sarcini la final. Fără link de meet: telefonul se leagă o dată de laptop prin QR |
| Subtitrări în lumea reală | Bonus 1 | Balon lângă fața celui care vorbește (detecție fețe + mișcarea gurii) |
| Sunetul vizibil | Bonus 2 | Clasificare locală a sunetelor (YAMNet), 3 niveluri de alertă, alerta critică acoperă orice ecran |
| Întreabă meetingul | Extra pentru demo | Agent AI care răspunde la întrebări despre meeting, citând replicile exacte |
| Antrenorul de claritate | Meetinguri **online** | Colegul **auzitor** deschide Echo în Chrome pe calculatorul lui, lângă Teams / Meet. Echo îi ascultă vocea local și îi arată discret câte o alertă, ca persoana surdă să poată citi subtitrarea: vorbește prea repede, peste alt coleg (cu cod de echipă), microfonul îl prinde slab, fără pauze între idei, 5 minute fără pauză, zgomot la el. Fereastră mereu deasupra meetingului (Document Picture-in-Picture), mod demonstrație cu praguri scurte. Meetingul fizic nu se schimbă |

## Reguli care nu se negociază

1. **Audio și video nu ajung pe serverul nostru.** Prin rețea circulă doar text. (Excepție asumată pentru demo: motorul de recunoaștere vocală al platformei; vezi designul.)
2. **Rolul vorbitorului nu se transmite doar prin culoare**: mereu și iconiță, poziție și etichetă text.
3. **Alerta critică are prioritate absolută** față de orice ecran.
4. **Accesibilitate în fiecare ecran**: etichete pentru VoiceOver (`Semantics`), mărime text respectată (fără dimensiuni fixe care taie textul), contrast minim WCAG AA, ținte de atingere de minim 48 px, nimic care depinde doar de sunet.
5. **Fără texte hardcodate în interfață**: orice text vizibil trece prin `app/lib/l10n/app_ro.arb` și `app_en.arb`. Română și engleză de la început; o limbă nouă = un fișier ARB nou.
6. **Prezentatorul nu are nevoie de cont.**
7. **Secrete doar în `.env`** (ignorat de git; model în `.env.example`). Cheia API Claude stă doar pe server, niciodată în aplicația de telefon.
8. **Commit-uri ca `selimayann`, fără `Co-Authored-By: Claude`** sau altă atribuire Claude.
9. **Orice funcționalitate nouă care produce date le salvează în baza de date**: migrație nouă, RLS, drepturi doar pe coloanele alese de om (Supabase dă implicit totul lui `authenticated`, deci întâi `revoke all`), test în `server/tests/test_database.py`. Acțiunile importante ale oamenilor intră în `activity_log`. Ce rămâne doar pe telefon (amprenta vocii, modelele) se spune explicit în design, cu motivul.
10. **GDPR în tot ce facem**: fiecare design are temei legal, informarea omului înainte (în interfață), minimizare (coloane fixe, fără text liber, fără date de care nu e nevoie), termen de păstrare și ce se întâmplă la ștergerea contului. Model: `docs/superpowers/specs/2026-10-23-istoric-activitate-design.md` §11.

## Stack

| Tehnologie | Unde | Rol |
|---|---|---|
| Dart + Flutter | `app/` | Aplicația de pe iPhone (participant, sunete, baloane) și pagina prezentatorului (Flutter web în Chrome) |
| `speech_to_text` | `app/` | Recunoașterea vorbirii prin motorul platformei (iOS / Chrome) pentru demo |
| YAMNet (TFLite), ML Kit Face Detection | `app/` | Sunete și fețe, local pe telefon |
| ReDimNet2 (amprenta vocii, ONNX) + `onnxruntime-web` | `app/web/voice/` | Recunoașterea vocii speakerului, local în Chrome |
| Python + PyTorch (CUDA) | `ml/voice/` | Fine-tuning ReDimNet2 pe română și sală simulată, calibrare, export ONNX; evaluare pe meetinguri de test; calibrarea ritmului vorbirii pentru antrenorul de claritate |
| Python + FastAPI | `server/` | Sesiuni și legătura WebSocket telefon–laptop; AI pe text prin API-ul Claude; agentul „Întreabă meetingul” |
| Docker + Compose | `docker-compose.yml` | Pornește serverul (și pagina prezentatorului) + Redis cu o comandă |
| Supabase (Postgres + Auth) | `supabase/` | Conturi (cod pe email, Google) și meetingurile salvate ale fiecărui utilizator |
| Redis | `docker-compose.yml` | Sesiunile live și limitele AI, comune tuturor instanțelor de server |

## Conturi și date (`supabase/`, `server/app/auth.py`, `hub.py`, `limits.py`)

- **Contul e opțional.** Fără `SUPABASE_URL` / `SUPABASE_ANON_KEY` aplicația și serverul merg exact ca înainte, anonim. Prezentatorul nu are niciodată cont.
- **Login fără parolă**: cod de 6 cifre pe email și Google. Fără Apple deocamdată (decizie de echipă). Fără CAPTCHA și fără coduri dictate prin apel (utilizatori surzi).
- **Ce se salvează**: doar replicile finale (text), rezumatul și setările, în contul participantului, plus istoricul activității (alarme și meetinguri, `activity_log`). Niciodată audio sau video.
- **Row Level Security pe fiecare tabel**: fiecare utilizator vede doar rândurile lui. Excepție: adminii unei companii văd istoricul companiei și meetingurile salvate pentru ea, doar prin funcții (`company_activity`, `company_meeting`) care înregistrează citirea în istoricul angajatului.
- **Istoricul activității** (`supabase/migrations/…_activity_log.sql`): se adaugă doar rânduri, nimeni nu modifică sau șterge din aplicație; IP-ul nu ajunge niciodată în aplicație; 12 luni, apoi se șterge; la ștergerea contului pleacă meetingurile, alarmele rămân fără legătura cu contul. Alarmele colegilor le scrie serverul cu rolul `echo_audit` (`AUDIT_DATABASE_URL`), care poate doar să adauge. Aplicația vorbește direct cu Supabase cu cheia `anon` (publică) + tokenul utilizatorului. Serverul doar verifică tokenul (JWKS sau `SUPABASE_JWT_SECRET`) și **nu folosește cheia `service_role`**.
- **Schema se schimbă doar prin migrații noi** în `supabase/migrations/` (niciodată editând una deja aplicată), cu test în `server/tests/test_database.py`.
- **Companii** (`supabase/migrations/…_organizations.sql`, `app/lib/core/org/`, `app/lib/features/organization/`): angajatul intră doar acceptând o invitație pe emailul lui; despre el se salvează **nevoi, nu diagnostic** (coloane fixe, fără text liber), scrise doar de el; angajații se văd doar pe ei, adminii văd tot din compania lor; compania păstrează mereu un admin. Sunetele comune păstrează doar amprenta și modelul (`tflite` telefon / `tfjs` browser, nu se potrivesc între ele). Aceeași schemă pe Supabase-ul nostru sau instalat la companie.
- **Sesiunile live nu se salvează în Postgres**: stau în Redis (`REDIS_URL`) sau în memorie dacă lipsește. Codul expiră după 12 h fără activitate.
- **Limite AI** pe oră: `AI_REQUESTS_PER_HOUR` (cont) și `AI_ANONYMOUS_REQUESTS_PER_HOUR` (după IP); peste limită serverul răspunde 429.

## AI (server/)

- SDK oficial `anthropic` (Python), client asincron. Model `claude-opus-5-5`, cu `fallbacks: "default"` (antet `server-side-fallback-2026-07-01`). Efort `medium` pentru rezumat și agent, `low` pentru simplificare.
- Verifică mereu `stop_reason == "refusal"` înainte de a citi răspunsul.
- Rezumat și sarcini: un singur apel cu ieșire structurată (Pydantic). Nu e nevoie de agent acolo.
- **Agentul „Întreabă meetingul”** e scris de noi: buclă proprie de maxim 6 pași, unelte `search_transcript` și `read_lines` peste transcrierea trimisă de telefon. Răspunsul citează replicile ca `[#id]`. Modelul nu inventează: dacă nu găsește în transcriere, spune asta.
- Nu antrenăm modele de limbaj. Părțile antrenate de noi: (1) modelul de recunoaștere a vocii speakerului, pornind de la ReDimNet2 (`ml/voice/`: fine-tuning pe română + sală simulată, calibrare pe meetinguri de test; ajunge în aplicație doar dacă bate modelul de bază); (2) detectorul de sunete periculoase peste embeddings YAMNet (`tools/train_danger_sounds.py` → `app/assets/models/danger_head*.json`, câte unul pentru telefon și browser) și, pe dispozitiv, amprentele sunetelor locației. Demo fără UI: `tools/sound_demo.py`.
- „Ți s-a răspuns” și „e întrebare?”: apeluri scurte cu ieșire structurată, efort `low`.
- Codul AI se testează cu un client fals; testele nu apelează API-ul real.

## Structura repo-ului

```
app/            Flutter (Dart): iOS + web (prezentator)
  lib/core/       protocol, client WebSocket, API, recunoaștere vorbire, transcriere
  lib/settings/   setări de accesibilitate (persistente)
  lib/theme/      culorile și forma Echo dintr-o singură sursă (EchoPalette → tema Material), palete daltonism, mod dislexie, contrast
  lib/core/account/  login (Supabase Auth)
  lib/core/history/  meetingurile salvate și înregistrarea lor în timpul meetingului
  lib/features/   home, participant, presenter, alerts, conversation, settings, account, history, coach (antrenorul de claritate)
  lib/l10n/       traduceri RO / EN (ARB)
server/         Python (FastAPI): app/ (hub sesiuni, ws, auth, limite, ai, agent), tests/
supabase/       config.toml, migrations/ (schema + RLS), templates/ (emailul cu codul)
ml/voice/       Python: antrenarea și evaluarea recunoașterii vocii; datele audio nu intră în git
docs/           prezentare (LaTeX), specificații și planuri superpowers
tools/          scripturi: refacerea modelului YAMNet, antrenarea detectorului de sunete, demo în terminal
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
cd ml/voice && .venv/Scripts/python -m pytest -q                       # teste recunoașterea vocii (instalare: ml/voice/README.md)
cd ml/voice && .venv/Scripts/python -m echo_voice.train --data data/speakers --out runs/<nume> --batch 6
cd ml/voice && .venv/Scripts/python -m echo_voice.ship                 # alege și exportă modelul de voce în app/web/voice/
```

## Mod de lucru

- **Superpowers**: `brainstorming` → design în `docs/superpowers/specs/` → `writing-plans` → implementare cu `test-driven-development` → `verification-before-completion`. Nu se scrie cod de produs nou fără design aprobat.
- **Karpathy Skills**: modificări mici și chirurgicale, cel mai simplu cod care merge, criterii de reușită verificabile.
- **Designul aplicației:** `docs/superpowers/specs/2026-10-23-redesign-design.md`. Un singur build web: până la 600 px lățime aplicația de telefon cu bara plutitoare (Dashboard, Meeting, Vibrații, Urgență, Setări, în `features/home/phone_shell.dart`; titluri mari în stil iOS pe taburi, iconițe conturate în pătrat moale prin `RowIcon`), peste, pagina de laptop. Culorile noi se adaugă doar în `EchoPalette`; textul trebuie să aibă contrast ≥ 7:1 (testat în `test/theme/theme_contrast_test.dart`).
- **Taste** (`taste-skill:design-taste-frontend`) pentru direcția vizuală; regulile de accesibilitate de mai sus au prioritate. Cere Node 22+ și Chrome / Edge.
- **Impeccable** (`/impeccable audit`, `/impeccable critique`, `/impeccable polish`) și **skillurile lui Emil Kowalski** (`emil-design-eng`, `review-animations`, `break-ui`) pentru verificarea și finisarea interfeței, după Taste. Aceleași reguli de accesibilitate au prioritate.
- **Reguli de frontend**: `docs/reguli-frontend.md` (Web Interface Guidelines de la Vercel, adaptate pentru Flutter) se aplică la orice ecran nou sau modificat; skillul `web-design-guidelines` verifică codul după ele. Regulile de mai sus au prioritate.
- **Caveman** (`/caveman`) pentru răspunsuri scurte când cineva cere.
- **Pluginuri pentru toată echipa**: orice plugin Claude Code nou se instalează cu `--scope project` (ajunge în `enabledPlugins` din `.claude/settings.json`; marketplace-urile neoficiale în `extraKnownMarketplaces`) și se trece în `README.md`, secțiunea „Claude Code”, cu link și comanda de instalare manuală. La fel pentru serverele MCP: în `.mcp.json` cu versiune fixă, aprobate în `enabledMcpjsonServers` și trecute în README. Niciun plugin sau server MCP folosit în proiect nu rămâne doar pe calculatorul cuiva.
- Interfața și documentația în **română**; identificatorii și comentariile tehnice din cod în engleză.
