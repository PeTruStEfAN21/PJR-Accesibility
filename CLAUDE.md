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
| ReDimNet2 (amprenta vocii, ONNX) + `onnxruntime-web` | `app/web/voice/` | Recunoașterea vocii speakerului, local în Chrome |
| Python + PyTorch (CUDA) | `ml/voice/` | Fine-tuning ReDimNet2 pe română și sală simulată, calibrare, export ONNX; evaluare pe meetinguri de test |
| Python + FastAPI | `server/` | Sesiuni și legătura WebSocket telefon–laptop; AI pe text prin API-ul Claude; agentul „Întreabă meetingul” |
| Docker + Compose | `docker-compose.yml` | Pornește serverul (și pagina prezentatorului) cu o comandă |

## AI (server/)

- SDK oficial `anthropic` (Python), client asincron. Model `claude-opus-5-5`, cu `fallbacks: "default"` (antet `server-side-fallback-2026-07-01`). Efort `medium` pentru rezumat și agent, `low` pentru simplificare.
- Verifică mereu `stop_reason == "refusal"` înainte de a citi răspunsul.
- Rezumat și sarcini: un singur apel cu ieșire structurată (Pydantic). Nu e nevoie de agent acolo.
- **Agentul „Întreabă meetingul”** e scris de noi: buclă proprie de maxim 6 pași, unelte `search_transcript` și `read_lines` peste transcrierea trimisă de telefon. Răspunsul citează replicile ca `[#id]`. Modelul nu inventează: dacă nu găsește în transcriere, spune asta.
- Nu antrenăm modele de limbaj. Antrenăm noi: modelul de recunoaștere a vocii speakerului, pornind de la ReDimNet2 (`ml/voice/`: fine-tuning pe română + sală simulată, calibrare pe meetinguri de test; ajunge în aplicație doar dacă bate modelul de bază) și, după demo, clasificatorul de sunete pe locație peste embeddings YAMNet.
- „Ți s-a răspuns” și „e întrebare?”: apeluri scurte cu ieșire structurată, efort `low`.
- Codul AI se testează cu un client fals; testele nu apelează API-ul real.

## Structura repo-ului

```
app/            Flutter (Dart): iOS + web (prezentator)
  lib/core/       protocol, client WebSocket, API, recunoaștere vorbire, transcriere
  lib/settings/   setări de accesibilitate (persistente)
  lib/theme/      palete daltonism, mod dislexie, contrast
  lib/features/   home, participant, presenter, alerts, conversation, settings
  lib/l10n/       traduceri RO / EN (ARB)
server/         Python (FastAPI): app/ (sesiuni, ws, ai, agent), tests/
ml/voice/       Python: antrenarea și evaluarea recunoașterii vocii; datele audio nu intră în git
docs/           prezentare (LaTeX), specificații și planuri superpowers
docker-compose.yml
```

## Comenzi

```
docker compose up --build          # serverul pe :8000 (.env opțional; fără cheie, AI-ul răspunde 503)
cd server && python -m venv .venv && .venv/Scripts/pip install -r requirements-dev.txt   # o dată (pe Mac: .venv/bin/)
cd server && .venv/Scripts/python -m pytest                                              # teste server
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
- **Taste** (`taste-skill:design-taste-frontend`) pentru direcția vizuală; regulile de accesibilitate de mai sus au prioritate. Cere Node 22+ și Chrome / Edge.
- **Caveman** (`/caveman`) pentru răspunsuri scurte când cineva cere.
- **Pluginuri pentru toată echipa**: orice plugin Claude Code nou se instalează cu `--scope project` (ajunge în `enabledPlugins` din `.claude/settings.json`; marketplace-urile neoficiale în `extraKnownMarketplaces`) și se trece în `README.md`, secțiunea „Claude Code”, cu link și comanda de instalare manuală. Niciun plugin folosit în proiect nu rămâne doar pe calculatorul cuiva.
- Interfața și documentația în **română**; identificatorii și comentariile tehnice din cod în engleză.
