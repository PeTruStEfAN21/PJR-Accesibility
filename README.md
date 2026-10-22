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

## Proiectul

Platformă care face meetingurile față în față accesibile persoanelor surde. Contextul complet e în `CLAUDE.md`, designul în `docs/superpowers/specs/`.

- `app/`: aplicația Flutter (iPhone + pagina prezentatorului în Chrome)
- `server/`: serverul Python (FastAPI): legătura telefon–laptop și partea de AI
- `docs/`: prezentarea și documentele de design

Pornire rapidă:

```
cp .env.example .env               # completează ANTHROPIC_API_KEY și PUBLIC_URL
cd app && flutter build web && cd ..
docker compose up --build          # serverul + pagina prezentatorului pe http://localhost:8000
```
