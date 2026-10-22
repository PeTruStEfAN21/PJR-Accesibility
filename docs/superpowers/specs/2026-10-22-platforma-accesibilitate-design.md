# Design: platformă de accesibilitate pentru persoane surde (demo 23 oct. 2026)

Status: cerut de echipă pe 2026-10-22 („da, și după fă fundația”); fundația e construită după acest document. Punctul 9 așteaptă confirmarea echipei. Produsul complet e descris în `docs/prezentare-generala.tex`. Acest document fixează **ce construim pentru demo-ul de mâine** și cum.

## 1. Intenție

Persoana surdă urmărește un meeting fizic ca pe un film subtitrat, știe cine vorbește (coordonator sau public) și poate trimite o întrebare prezentatorului fără să întrerupă. Același motor dă subtitrări lângă fețe în conversații și alerte vizuale pentru alarme.

Pentru juriu contează trei momente (scenariul din prezentare) plus un extra:
1. **Meeting**: laptopul la prezentator, telefonul la utilizator, replici colorate pe roluri, „Am o întrebare” apare instant pe laptop.
2. **Conversație**: balonul fiecărui vorbitor lângă fața lui.
3. **Siguranță**: alarmă de incendiu dintr-un difuzor, telefonul devine roșu și vibrează.
4. **Extra „Întreabă meetingul”**: după meeting, utilizatorul întreabă în limbaj natural („Ce trebuie să fac eu?”), iar agentul răspunde citând replicile exacte.

## 2. Constrângeri

- Termen: demo pe **2026-10-23, ~16:00**. Echipă de 4. Un singur Mac (construiește pentru iPhone), restul pe Windows.
- Telefoane: **iPhone**. Laptop prezentator: Chrome.
- Impuse: **Flutter** (aplicația pe telefon) și **Docker**.
- Limbi: **română și engleză** de la început, altele după proiect.
- Fără cont pentru prezentator: cod scurt sau QR.

## 3. Obiective, non-obiective, anti-obiective

**Obiective (demo):** cele 4 momente de mai sus merg cap-coadă pe un iPhone real și un laptop, pe hotspot.

**Non-obiective (rămân în prezentare / roadmap):** recunoaștere vocală 100% locală (Whisper pe dispozitiv), Public 1 / Public 2 separați prin diarizare, antrenare pe locație a sunetelor (se poate arăta ca prototip dacă rămâne timp), panou HR, ceas inteligent, ochelari AR, ieșirea cea mai apropiată calculată din hartă (în demo e text configurat).

**Anti-obiective (eșec chiar dacă „merge tehnic”):**
- informația despre rol transmisă **doar** prin culoare;
- audio sau video trimise pe server;
- o alertă critică ascunsă sau întârziată de alt ecran;
- un demo care depinde de Wi-Fi-ul sălii.

## 4. Arhitectură

```
iPhone (Flutter, iOS)                    Laptop prezentator (Chrome)
 - recunoaștere vorbire (motorul iOS)      - pagina prezentatorului (Flutter web)
 - subtitrări pe roluri                    - recunoaștere vorbire (Web Speech, Chrome)
 - mesaje rapide -> prezentator            - notificări silențioase
 - YAMNet: alarme                          
 - cameră + ML Kit: baloane                
        \                                   /
         \--- WebSocket (doar text) ------/
                         |
            server/ (Python, FastAPI, Docker, rulează pe laptop)
             - sesiuni: cod scurt, legătură între dispozitive
             - AI pe text (API Claude): rezumat, sarcini, text simplificat
             - agent „Întreabă meetingul” (unelte peste transcriere)
             - servește build-ul Flutter web pentru prezentator
```

### Decizii luate de echipă
- Flutter pentru aplicație, Docker pentru server, Python pentru tot ce e AI pe server.
- API Claude pentru partea de limbaj. Spre server pleacă doar text.
- „Întreabă meetingul” ca extra pentru demo.

### Decizii luate de mine (pot fi schimbate)
- **Recunoașterea vorbirii folosește motorul platformei** (pachetul `speech_to_text`: SFSpeechRecognizer pe iOS, Web Speech în Chrome). Ambele pot trimite audio la Apple / Google. Prezentarea spune „audio nu părăsește dispozitivul”; pentru demo spunem deschis că versiunea finală trece pe Whisper local. Motivul: nu e timp pentru Whisper pe iPhone până mâine.
- **Rolurile vin din dispozitiv**, nu din cameră: ce aude laptopul e „Coordonator”, ce aude telefonul e „Public”. Scanarea sălii cu camera e extra.
- **Ecou**: telefonul aude și prezentatorul. Telefonul ignoră propriile replici cât timp a sosit o replică de la coordonator în ultimele 1,5 s sau dacă textul seamănă (≥ 60% cuvinte comune) cu o replică recentă a coordonatorului.
- **Un singur serviciu Python** pentru legătură + AI (mai puține piese de pornit mâine).
- **Model**: `claude-opus-5-5` cu `fallbacks: "default"` (dacă modelul refuză, API-ul încearcă automat alt model). Efort `medium` pentru rezumat și agent, `low` pentru simplificare.
- **Agentul** e o buclă scrisă de noi (maxim 6 pași) cu două unelte: `search_transcript` și `read_lines`. Răspunsul citează replicile ca `[#12]`; serverul extrage numerele.
- **Rețea de demo**: hotspot de pe un iPhone. Laptopul rulează `docker compose up`; prezentatorul deschide `http://localhost:8000` (Chrome cere context sigur pentru microfon, iar `localhost` e considerat sigur). Telefonul se conectează la IP-ul laptopului din `PUBLIC_URL` (în `.env`).
- **Legătura nu e criptată end-to-end în demo** (doar text, rețea locală). Criptarea cu cheie în QR e în roadmap.
- **Demo-ul se ține în română**; engleza se arată din setări (interfață + limba vorbită).
- **Alarma din demo rulează pe ecranul „Sunetul vizibil”** (momentul 3 e separat de meeting). Stratul de alertă e deja global, deci dacă detectorul ascultă, alerta acoperă orice ecran. Ascultarea simultană cu subtitrarea pe iPhone (un singur microfon) rămâne extra.
- **Modul „un singur dispozitiv” nu intră în demo.** Ecranul „Conversație” acoperă subtitrarea fără prezentator.
- **Toate setările de accesibilitate sunt deja în fundație** (nu consumă timp de persoană mâine).
- **Rezervă pentru demo:** linkul din QR deschis în Safari încarcă versiunea web direct pe ecranul de subtitrări, fără aplicație instalată.

## 5. Protocol (WebSocket, JSON)

Conectare: `GET /ws/{code}?role=presenter|participant`. Serverul trimite fiecare mesaj valid tuturor celorlalți din aceeași sesiune. Mesaj maxim 4 KB. Tipuri:

| `type` | Cine trimite | Câmpuri |
|---|---|---|
| `joined` | server | `code`, `role`, `peers` (roluri conectate) |
| `peer` | server | `role`, `connected` |
| `caption` | prezentator / participant | `id`, `speaker` (`coordinator` / `public`), `text`, `final`, `lang`, `ts` |
| `notify` | participant | `id`, `kind` (`question` / `repeat` / `slower` / `custom`), `text`, `ts` |
| `seen` | prezentator | `id` (notificarea văzută) |
| `error` | server | `message` |

REST:
- `POST /api/sessions` → `{code}` (6 caractere fără 0/O/1/I; expiră după 12 h fără activitate)
- `GET /api/config` → `{public_url}`
- `POST /api/ai/summary` `{lang, lines}` → `{summary, tasks: [{text, owner}]}`
- `POST /api/ai/simplify` `{lang, text}` → `{text}`
- `POST /api/ai/ask` `{lang, lines, question}` → `{answer, citations: [id]}`
- `GET /health`

`lines` = `[{id, speaker, text}]`. Transcrierea stă pe telefon; serverul nu o păstrează. (După demo: participantul autentificat își poate salva meetingurile în cont; vezi `2026-10-22-conturi-si-baza-de-date-design.md`.)

## 6. Aplicația Flutter (`app/`)

O singură aplicație, două moduri:
- **Participant (iPhone)**: introduce codul sau scanează QR, vede subtitrările (coordonatorul fixat sus, cu iconiță de microfon și eticheta „Coordonator”; publicul jos, cu iconiță de persoană și eticheta „Public”), trimite mesaje rapide, cere rezumatul și pune întrebări agentului.
- **Prezentator (Chrome pe laptop)**: creează sesiunea, arată codul + QR, ascultă și trimite subtitrări, primește notificări fără sunet, le marchează „văzut”.
- **Un singur dispozitiv**: telefonul ascultă singur, fără server.
- **Sunetul vizibil**: YAMNet pe telefon; nivel critic = ecran complet roșu, vibrație repetată, mesaj „ALARMĂ DE INCENDIU” + ieșirea configurată. Se suprapune peste orice ecran.
- **Conversație**: cameră + detecție fețe (ML Kit), vorbitorul activ după deschiderea gurii, balon lângă față.

Accesibilitate (toate în setări, salvate pe dispozitiv): limba interfeței, limba vorbită, mărime text (100–200%), mod dislexie (OpenDyslexic, spațiere mărită), paletă (standard, protanopie, deuteranopie, tritanopie), contrast ridicat, temă luminoasă / întunecată / sistem, oprirea derulării automate. Toate elementele au etichete pentru VoiceOver.

## 7. Împărțirea echipei

| Cine | Ce |
|---|---|
| 1 (Mac) | ecranul participantului, construcția pe iPhone, permisiuni iOS |
| 2 | serverul Python + Docker, pagina prezentatorului |
| 3 | Sunetul vizibil (YAMNet) + ecranul de alertă |
| 4 | baloanele lângă fețe + „Întreabă meetingul” în aplicație + scenariul demo |

## 8. Riscuri

- SFSpeechRecognizer pe iOS oprește ascultarea după ~1 minut: serviciul o repornește automat.
- Microfonul pe iOS e folosit fie de recunoașterea vorbirii, fie de YAMNet; în demo alerta rulează pe ecranul ei. Dacă rămâne timp: alternare automată.
- Firewall-ul laptopului poate bloca portul 8000 pentru telefon: de testat dimineața.
- Fără internet nu merg nici recunoașterea vorbirii, nici AI-ul: hotspot cu date mobile.

## 9. De confirmat de echipă

- Recunoașterea vorbirii prin motorul iOS / Chrome poate trimite audio la Apple / Google. Prezentarea promite procesare locală. Echipa decide ce spune juriului (propunere: „demo pe motorul platformei, produsul final pe Whisper local”).

## 10. Lăsat la decizia celui care construiește

Aranjarea vizuală exactă (cu Taste), textele mesajelor rapide în engleză, pragurile YAMNet, animațiile, structura internă a fișierelor din fiecare funcție.
