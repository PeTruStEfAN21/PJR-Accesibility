# Design: conturi, meetinguri salvate și server scalabil

Status: cerut și aprobat de echipă pe 2026-10-22. Se lucrează pe branch-ul `feature/database` și se unește în `main` **după** demo-ul din 2026-10-23.

## 1. Intenție

Participantul își face cont și își revede oricând meetingurile: replicile, rezumatul, „Întreabă meetingul”. Serverul poate rula în mai multe instanțe fără ca prezentatorul și participantul să trebuiască să fie pe aceeași.

## 2. Decizii

| Întrebare | Decizie | De ce |
|---|---|---|
| Unde stau conversațiile | Pe server, în Postgres, protejate cu Row Level Security | Merg pe orice telefon, se pot șterge oricând, AI-ul merge și pe meetinguri vechi. Varianta criptată end-to-end rămâne în roadmap. |
| Furnizor | Supabase (Postgres + Auth) | O singură piesă pentru bază de date și login; SDK Flutter oficial; se poate găzdui și în Docker. |
| Metode de login | Cod de 6 cifre pe email, Google | Fără parolă (WCAG 2.2, 3.3.8). **Fără Apple** (decizia echipei; vezi riscuri). Fără CAPTCHA și coduri prin apel vocal. |
| Cine scrie în baza de date | Aplicația direct, cu cheia `anon` + tokenul utilizatorului | RLS face verificarea în baza de date; mai puțin cod la noi. |
| Ce face serverul cu conturile | Verifică tokenul (JWKS sau secret) ca să aplice limitele AI per cont | Nu are cheia `service_role`; nu poate citi datele nimănui. |
| Sesiuni live | Redis: cheie cu expirare + pub/sub pentru mesaje | Scalare pe orizontală. Fără `REDIS_URL` rămâne în memorie, ca înainte. |
| Contul e obligatoriu? | Nu | Fără configurație Supabase totul merge ca în demo. Prezentatorul nu are cont (regula 6). |

Fraza din designul demo-ului „Transcrierea stă pe telefon; serverul nu o păstrează” devine: **transcrierea se salvează doar în contul participantului care a ales să se autentifice**. Regula 1 (fără audio și video pe server) rămâne neschimbată.

## 3. Schema (`supabase/migrations/20261022120000_saved_meetings.sql`)

- `profiles`: un rând per cont (creat automat la înregistrare), nume, setări de accesibilitate (JSONB).
- `meetings`: `owner_id`, titlu, limbă (`ro-RO`), codul sesiunii, început / sfârșit.
- `meeting_lines`: replicile finale; `seq` = numărul citat de AI (`[#seq]`); `caption_id` unic per meeting, deci retrimiterea unui lot nu dublează replicile; index full-text `simple` (merge pentru RO și EN).
- `summaries`: rezumat + sarcini (JSONB), unul per meeting.
- `search_meetings(query)`: caută în titluri și replici, rulează cu drepturile utilizatorului.
- `delete_my_account()`: șterge contul apelantului și, în cascadă, tot ce ține de el.
- RLS pe toate tabelele; `anon` nu are acces la nimic.

## 4. Aplicația

- Configurare prin `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`. Fără ele, interfața de cont nu apare.
- `MeetingRecorder` salvează replicile finale în loturi, la 30 s și la ieșirea din meeting; dacă rețeaua pică, lotul rămâne la coadă. Replicile parțiale nu se salvează.
- Ecrane noi: autentificare, cont (deconectare, ștergere cont), istoric cu căutare, meeting salvat (replici, rezumat, „Întreabă meetingul”).

## 5. Server

- `auth.py`: tokenul Supabase, opțional. Token invalid → 401; fără token → anonim.
- `limits.py`: limite pe oră la `/api/ai/*`, per cont sau per IP, în memorie sau Redis → 429 cu `Retry-After`.
- `hub.py`: `LocalHub` (un proces) și `RedisHub` (mai multe instanțe). Protocolul WebSocket nu se schimbă.

## 6. Teste

- `server/tests/test_database.py`: migrațiile pe un Postgres real (`TEST_DATABASE_URL`), cu Supabase simulat (`tests/db/supabase_stub.sql`): RLS între doi utilizatori, căutare, ștergerea contului.
- `server/tests/test_accounts.py`, `test_redis.py`: tokenuri, limite, două instanțe de server legate prin Redis (`fakeredis`).
- `app/test/`: înregistrarea meetingului, fluxul de login, istoricul, cu servicii false.

## 7. Riscuri și ce rămâne

- **App Store, regula 4.8**: dacă aplicația are login cu Google, Apple poate cere și Sign in with Apple. Codul pe email (contul nostru) poate fi suficient, dar nu e garantat la review. De reevaluat înainte de publicare.
- Contorul de conexiuni din Redis poate rămâne greșit dacă o instanță de server cade brusc; expiră odată cu sesiunea.
- Căutarea `simple` nu ignoră diacriticele („sarcina” ≠ „sarcină”). Îmbunătățire: `unaccent` într-o coloană separată.
- Roadmap: criptare end-to-end a replicilor, passkeys (Supabase le are în beta), panou HR / organizații, ștergere automată după X zile.
