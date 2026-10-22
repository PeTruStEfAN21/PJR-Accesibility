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
docker compose up --build          # serverul + pagina prezentatorului pe http://localhost:8000
```
