# Echo

## Claude Code

Proiectul activează cinci pluginuri prin `.claude/settings.json`:

- [Superpowers](https://github.com/obra/superpowers): brainstorming, planuri, TDD, debugging, code review
- [Taste](https://github.com/Leonxlnx/taste-skill): reguli de gust pentru design frontend (necesită Node 22+ și Chrome, Edge sau Chromium)
- [Caveman](https://github.com/JuliusBrussee/caveman): răspunsuri scurte, cu mai puține tokenuri
- [Karpathy Skills](https://github.com/multica-ai/andrej-karpathy-skills): reguli de lucru după observațiile lui Andrej Karpathy (gândește înainte de cod, simplitate, modificări chirurgicale)
- [Impeccable](https://impeccable.style) ([pbakaus/impeccable](https://github.com/pbakaus/impeccable)): limbaj de design pentru frontend, cu comenzi ca `/impeccable audit`, `/impeccable critique`, `/impeccable polish`

Pe lângă pluginuri, `.claude/skills/` conține skilluri care se încarcă automat, fără instalare:

- cele 50 de skilluri de QA din [qa-skills](https://github.com/petrkindlmann/qa-skills) (licență MIT, în `.claude/skills/QA-SKILLS-LICENSE`);
- cele 15 skilluri de design și animație ale lui Emil Kowalski din [emilkowalski/skills](https://github.com/emilkowalski/skills) (licență MIT, în `.claude/skills/EMIL-SKILLS-LICENSE`), de exemplu `emil-design-eng`, `animate`, `review-animations`, `break-ui`, `apple-design`. Pentru o versiune nouă: `npx skills@latest add emilkowalski/skills` sau copiezi din nou folderul `skills/`.

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
```

### Servere MCP

`.mcp.json` declară serverele MCP ale proiectului, iar `.claude/settings.json` le aprobă automat (`enabledMcpjsonServers`):

- [Playwright MCP](https://github.com/microsoft/playwright-mcp) (`@playwright/mcp@0.0.83`): Claude deschide și controlează Chrome, ca să verifice pagina prezentatorului (`flutter build web` + server pe http://localhost:8000). Necesită Node 18+ și Chrome.

Dacă nu pornește singur: `claude mcp add --scope project playwright -- npx @playwright/mcp@0.0.83`.

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
docker compose up --build          # serverul + pagina prezentatorului pe http://localhost:8000
```
