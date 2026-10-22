# Design: asistentul pentru meetinguri fizice (demo 23 oct. 2026)

Status: aprobat de echipă pe 2026-10-22 („apucă-te acum de feature”). Înlocuiește secțiunile despre meeting din `2026-10-22-platforma-accesibilitate-design.md` (rolurile din dispozitiv, filtrul de ecou ca mecanism principal). Restul acelui document rămâne valabil: Sunetul vizibil, baloanele, rezumatul, „Întreabă meetingul”, setările, protocolul de bază, rețeaua de demo.

## 1. Intenție

O persoană surdă stă într-o sală, într-un meeting **fizic**, cu telefonul în mână. Nu există niciun meeting online și niciun link de meet. Ea vrea trei lucruri:

1. să citească live ce se spune și să știe **cine** vorbește: speakerul sau cineva din sală, inclusiv „cineva din sală a pus o întrebare: …”;
2. să pună ea o întrebare fără să vorbească: apasă un buton, speakerul e anunțat, ea scrie întrebarea, iar întrebarea e citită cu voce tare în sală;
3. să afle **că i s-a răspuns și ce i s-a răspuns**, fără să caute prin transcriere: aplicația recunoaște singură răspunsul speakerului și i-l arată.

Echipa a respins varianta în care telefonul „intră într-un meeting” printr-un link și primește transcriptul. Legătura dintre telefon și laptop rămâne (fără ea, alerta nu ajunge la speaker), dar se prezintă ca „conectează-te la speaker”, făcută o singură dată, prin QR, în sală.

## 2. Cine e în sală și ce are

| Cine | Dispozitiv | Ce face |
|---|---|---|
| Speakerul | Laptopul de pe care prezintă, Chrome, pagina Echo deschisă, fără cont | Își înregistrează vocea la început; laptopul ascultă sala; primește alertele și întrebările |
| Persoana surdă | iPhone cu aplicația Echo | Scanează QR-ul de pe laptop; citește subtitrările; pune întrebări; vede răspunsurile |
| Restul sălii | nimic | Vorbesc normal; întrebările lor apar marcate pe telefon |

## 3. Obiective, non-obiective, anti-obiective

**Obiective (demo, amândouă la fel de importante, cerut explicit de echipă):**
- **A. Recunoașterea vocii speakerului.** Laptopul învață vocea speakerului și etichetează singur fiecare replică: „Speaker” sau „Din sală”.
- **B. „Ți s-a răspuns”.** După ce întrebarea persoanei surde e citită, aplicația detectează automat răspunsul speakerului și îl arată pe telefon.
- Plus: întrebările puse de cei din sală apar marcate ca întrebări; butonul „Vreau să întreb” ajunge instant pe laptop; întrebarea scrisă poate fi citită de laptop cu voce sintetizată.

**Non-obiective:** login / conturi (vin mai târziu, cerut de echipă), separarea mai multor persoane din sală între ele (Public 1 / Public 2), antrenarea de la zero a rețelei de amprentă (o pornim de la ReDimNet2 și o adaptăm noi), recunoașterea vorbirii 100% locală, mod complet fără laptop.

**Anti-obiective (eșec chiar dacă „merge tehnic”):**
- audio trimis pe serverul nostru (amprenta vocii se calculează în browser; prin rețea circulă doar text);
- persoana surdă trebuie să „intre într-un meeting” printr-un link sau cod tastat ca într-o aplicație de videoconferință;
- vocea sintetizată care citește întrebarea ajunge înapoi în subtitrări ca replică a speakerului;
- „Ți s-a răspuns” afișat pentru ceva ce nu e răspuns (mai bine niciun card decât un card greșit);
- rolul vorbitorului transmis doar prin culoare.

## 4. Fluxul cap-coadă

1. **Speakerul** deschide `http://localhost:8000` pe laptop, alege „Prezint”. Pagina creează sesiunea (ca acum) și îi cere să citească un text afișat, cu voce normală, **~20 de secunde**. O bară arată progresul. La final, pagina îi spune „Vocea ta e învățată”.
2. Pagina arată un **QR** mare și textul „Persoana care folosește Echo scanează codul”. Codul de 6 caractere rămâne ca rezervă, dar nu e calea principală.
3. **Persoana surdă** deschide aplicația, apasă „Conectează-te la speaker”, scanează QR-ul. Telefonul trece direct pe ecranul de subtitrări.
4. **Laptopul ascultă** (Web Speech în Chrome) și, în paralel, calculează amprenta vocii pentru fiecare replică finală. Replica pleacă spre telefon cu eticheta `coordinator` (speakerul) sau `public` (din sală).
5. Pentru replicile finale **din sală**, telefonul cere AI-ului „e întrebare?”. Dacă da, replica primește marcajul „Întrebare din sală”.
6. **Persoana surdă apasă „Vreau să întreb”.** Laptopul afișează imediat o alertă vizibilă, fără sunet: „Persoana care folosește Echo vrea să pună o întrebare”. Telefonul deschide câmpul de scris.
7. Ea scrie și trimite întrebarea. Pe laptop apar **textul mare** și două butoane: „Citește cu voce tare” (voce sintetizată în Chrome) și „Am citit-o eu”. Speakerul alege.
8. După oricare dintre ele, laptopul trimite `read`, iar pe telefon întrebarea primește starea „Citită, se așteaptă răspunsul”. Cât timp vocea sintetizată vorbește, laptopul **nu ascultă** (altfel s-ar subtitra pe sine).
9. **Speakerul răspunde cu voce.** Telefonul trimite periodic AI-ului întrebarea + replicile spuse de atunci. Când AI-ul decide că a primit răspuns, pe telefon apare cardul **„Ți s-a răspuns”**: întrebarea, răspunsul pe scurt și replicile din care vine (ca `[#id]`, atingere = sare la replică). Telefonul vibrează și VoiceOver anunță cardul.
10. Restul rămâne ca acum: rezumat + sarcini și „Întreabă meetingul” la final.

## 5. Recunoașterea vocii speakerului (obiectivul A)

### Decis în conversație
- Rulează **pe laptop, în Chrome**, pentru că acolo transcrierea și sunetul brut pot merge în paralel. Pe iPhone, recunoașterea vorbirii ține microfonul ocupat.
- **Antrenăm noi** partea care decide „e speakerul sau nu”, pe date de vorbire, inclusiv înregistrări din meetinguri de test făcute de echipă (secțiunea 5bis). Nu se pune problema timpului: se face cum trebuie.
- Oamenii din sală sunt colegi de muncă, voci necunoscute aplicației, la distanțe diferite de laptop. Modelul trebuie să meargă pe ei fără să-i fi auzit înainte.
- Butonul **„Vorbesc eu”** pe laptop forțează eticheta „Speaker” cât timp e activ.

### Cum (deciziile mele, pot fi schimbate)
- **Modelul de bază: ReDimNet2-B6** (Interspeech 2026, licență MIT, `PalabraAI/redimnet2`), varianta antrenată pe VoxBlink2 + VoxCeleb2 (`vb2+vox2_v0`, `lm`). VoxBlink2 are peste 100.000 de vorbitori de pe YouTube, în multe limbi. Eroare (EER) pe VoxCeleb1-O: 0,23%, față de ~0,7–0,8% la CAM++. Pe VOICES (înregistrări de departe, în camere reale): 2,55%. Are 12,3 milioane de parametri, primește direct sunetul brut (16 kHz) și scoate o amprentă de 192 de numere.
- **Antrenarea noastră (`ml/voice/`, Python + PyTorch, pe placa video RTX 3050 a laptopului):**
  1. **Fine-tuning** pe vorbire în română (TidyVoice / Common Voice RO), cu sală simulată: ecou (răspuns la impuls sintetic, RT60 0,2–0,8 s), distanță, zgomot de birou și alte voci pe fundal. Rată de învățare mică, ca să nu strice ce știe deja modelul.
  2. **Calibrarea și pragul**, învățate pe meetingurile de test ale echipei (5bis).
  3. **Regula de livrare:** modelul nostru ajunge în aplicație doar dacă bate modelul de bază pe aceleași date de test, nefolosite la antrenare (română + meetinguri de test). Altfel livrăm baza cu calibrarea noastră. Se compară și ReDimNet2+ (`lab260/redimnet2-plus`, Apache 2.0, antrenat pentru zgomot și ecou), dacă se încarcă direct.
  - Rezultatul: `speaker.onnx` (exportat de noi, cu lungime variabilă) + `voice_head.json` (prag și calibrare) în `app/web/voice/`.
- **Date:** TidyVoice (derivat din Common Voice, făcut special pentru verificarea vorbitorului, 81 de limbi) sau Common Voice în română, de pe Mozilla Data Collective. Descărcarea cere un cont și acceptarea termenilor (doar pentru verificarea vorbitorului, ceea ce facem noi), deci o face un om din echipă. Plus înregistrările din meetingurile de test. Datele audio nu intră în git și nu ajung pe server.
- **În browser:** captură cu `getUserMedia` + `AudioWorklet`, mono, 16 kHz, buffer circular de ~15 s, în paralel cu Web Speech. Modelul rulează cu `onnxruntime-web`, pe WebGPU când există, altfel WASM. Codul Flutter vorbește cu el prin `dart:js_interop`. Fișierele se servesc din `app/web/voice/`, fără CDN. Dacă B6 e prea lent în Chrome pe laptopul de demo (peste 1,5 s per replică), se trece pe ReDimNet2-B3, mai mic, antrenat la fel.
- **Înregistrarea vocii (enrollment):** ~20 s citite de speaker → amprente pe ferestre de ~3 s → medie normalizată. Stă doar în pagină (și în `localStorage`).
- **Potrivire per replică:** la fiecare rezultat final din Web Speech, sunetul de la sfârșitul replicii anterioare până acum (1,5–8 s), fără liniștea de la margini → amprentă → similaritate cosinus → scor calibrat. Peste pragul din `voice_head.json` → `coordinator`, altfel `public`. Pragul e înclinat spre „Speaker”: speakerul etichetat „Din sală” e mai grav, pentru că îi ascunde răspunsul.
- **Replicile parțiale** pleacă cu eticheta replicii anterioare; eticheta se fixează la final.

### 5bis. Meeting de test
- Pe pagina prezentatorului, modul **„Meeting de test”**: totul merge normal, iar în plus fiecare replică finală își păstrează clipul audio, textul, eticheta și scorul. La final, un ecran de **verificare**: lista replicilor, cu „Ascultă” și eticheta corectă (Speaker / Din sală) de bifat de echipă. Apoi **„Descarcă”** salvează pe laptop o arhivă (WAV-uri + `labels.json` + clipul de enrollment).
- Arhiva nu pleacă nicăieri: se copiază în `ml/voice/data/meetings/`. `ml/voice` o folosește la **evaluare** (acuratețea pe meetingul real, câte replici ale speakerului au fost pierdute) și la **antrenare** (speakerul ca vorbitor cunoscut, replicile din sală ca exemple de „altcineva”).
- Toți cei din meetingul de test știu că sunt înregistrați și sunt de acord.
- **Criteriu de reușită:** pe un meeting de test nou (nefolosit la antrenare), ≥ 95% din replicile speakerului etichetate „Speaker” și ≥ 85% din replicile colegilor etichetate „Din sală”.

## 6. „Ți s-a răspuns” (obiectivul B)

- **Cine verifică:** telefonul, pentru că el ține transcrierea și știe care e întrebarea în așteptare.
- **Când:** după `read`, de fiecare dată când sosește o replică finală (oricare etichetă, ca un răspuns etichetat greșit „Din sală” să nu se piardă), cu o întârziere de 3 s de la ultima replică finală (ca să nu taie răspunsul la jumătate). Maxim un apel în curs. AI-ul primește etichetele și preferă replicile speakerului, dar nu le ignoră pe celelalte.
- **Ce trimite:** întrebarea + replicile de după trimiterea întrebării (toate, inclusiv cele din sală, cu id și etichetă). AI-ul știe că speakerul poate citi întâi întrebarea cu voce tare și că asta nu e răspuns. Verificarea pornește la `read`; dacă `read` nu ajunge, persoana o poate porni cu „Caută răspunsul”.
- **Ce primește:** `{answered: bool, answer: str, line_ids: [int]}`. `answered = true` doar dacă speakerul chiar a răspuns la întrebarea asta. Un răspuns de tipul „revin mai târziu” sau „nu știu” e tot răspuns, cu `answer` care spune asta.
- **Când se oprește:** la primul `answered = true`, după 5 minute de la `read` (întrebarea rămâne „Citită” cu mesajul „Nu am găsit încă un răspuns” și un buton „Caută din nou”), sau când persoana pune altă întrebare. O singură întrebare în așteptare la un moment dat; o nouă întrebare o înlocuiește pe cea veche.
- **Model:** `claude-opus-5-5`, `fallbacks: "default"`, efort `low` (e o clasificare scurtă, trebuie să fie rapidă). Ieșire structurată (Pydantic). Verifică `stop_reason == "refusal"`.
- **Fără cheie API (503):** cardul nu apare; întrebarea rămâne „Citită”. Nu există euristică pentru răspuns (anti-obiectiv: card greșit).

## 7. Întrebările din sală

- Doar pentru replicile finale `public`. Telefonul apelează AI-ul, iar replica se afișează imediat și primește marcajul când vine răspunsul.
- Același model, efort `low`. Poate primi mai multe replici într-un apel (lot de până la 5, la 1 s) ca să nu facă un apel per frază.
- **Fără cheie API:** euristică locală: replica se termină cu „?” sau începe cu un cuvânt interogativ (RO: cine, ce, când, cum, de ce, unde, care, cât, câte, poți, puteți, se poate; EN: who, what, when, how, why, where, which, can, could, do, does, is, are).

## 8. Protocol (diferențe față de designul inițial)

WebSocket (`/ws/{code}`), JSON, aceleași reguli de relay:

| `type` | Cine trimite | Schimbare |
|---|---|---|
| `caption` | prezentator | `speaker` vine acum din amprenta vocii (`coordinator` / `public`), nu din dispozitiv. |
| `notify` | participant | `kind` nou: `hand` (vrea să întrebe, fără text). `question` rămâne pentru textul întrebării. |
| `read` | prezentator | **nou**: `id` (al notificării `question`), `by` = `voice` (citită de laptop) sau `speaker` (citită de om). |
| `seen` | prezentator | rămâne, pentru `hand` și celelalte mesaje rapide |

REST nou (server, fără stare, doar text):
- `POST /api/ai/answer-check` `{lang, question, lines}` → `{answered, answer, line_ids}`
- `POST /api/ai/questions` `{lang, lines}` → `{question_ids: [int]}`

## 9. Ecrane

**Laptop (prezentator):** pas de enrollment → QR mare → ecran de lucru cu: subtitrarea proprie (cu eticheta fiecărei replici, ca să vadă speakerul dacă îl recunoaște), butonul „Vorbesc eu”, zona de alerte (alerta `hand` mare, întrebarea cu cele două butoane), „Reînvață vocea” și „Meeting de test”.

**Telefon (participant):** ecranul de subtitrări existent, cu:
- etichetele „Speaker” / „Din sală” (iconiță + poziție + text, nu doar culoare);
- marcajul „Întrebare din sală” (iconiță + text);
- butonul mare „Vreau să întreb” (minim 48 px, mereu vizibil) → câmp de scris → „Trimite”;
- starea întrebării proprii: Trimisă → Citită, se așteaptă răspunsul → Ți s-a răspuns;
- cardul „Ți s-a răspuns” fixat sus până la închidere.

Textele noi trec prin `app_ro.arb` și `app_en.arb`. Ecranul de start: „Conectează-te la speaker” (scanează QR) în locul formulării de tip „intră în meeting”.

## 10. Ce rămâne neschimbat

Sunetul vizibil, baloanele lângă fețe, rezumatul și „Întreabă meetingul”, setările de accesibilitate, serverul ca simplu releu + AI pe text, Docker, rețeaua de demo pe hotspot, fără login.

## 11. Riscuri

1. **Amprenta vocii în Chrome** e partea nouă: viteza lui B6 în `onnxruntime-web` și aceleași amprente în browser și în Python. Se verifică primele, cu un test care compară amprentele din browser și din Python pe același WAV.
2. **Microfonul laptopului aude colegii de departe mai slab.** Augmentarea cu distanță și ecou la antrenare, plus meetingurile de test în sala reală.
3. **Vocea sintetizată** poate lipsi în română pe laptop (Chrome folosește vocile sistemului); rămâne „Am citit-o eu”.
4. **Latența AI** pentru „Ți s-a răspuns”: efort `low`, un singur apel în curs, întârziere de 3 s.
5. Fără internet nu merg nici transcrierea, nici AI-ul (neschimbat).

## 12. Lăsat la decizia celui care construiește

Hiperparametrii fine-tuning-ului, forma exactă a calibrării, textul de citit la enrollment, aranjarea vizuală (cu Taste), textele exacte ale mesajelor, structura internă a fișierelor, promptul pentru `answer-check` și `questions`.
