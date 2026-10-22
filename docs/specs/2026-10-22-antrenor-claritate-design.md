# Design: Antrenorul de claritate pentru meetingurile online

Status: cerut și aprobat de echipă pe 2026-10-22 („hai să începem să implementăm”). Funcție nouă, separată. Meetingul fizic (`2026-10-22-meeting-fizic-design.md`) rămâne exact cum e.

## 1. Intenție

Brief-ul cere ca locul de muncă să se adapteze persoanei, nu invers. Aproape toate aplicațiile pentru surzi îi cer persoanei surde să se adapteze; aici se inversează rolurile: **Echo îi ajută pe colegii auzitori** să vorbească în meetingurile online (Teams, Zoom, Meet) astfel încât colegul surd să poată **citi clar subtitrarea**. Asta face ușoară angajarea unei persoane surde: firma nu trebuie să schimbe nimic altceva, colegii primesc semnale discrete, la momentul potrivit.

## 2. Cine, ce, unde

- **Utilizatorul e colegul auzitor**, pe calculatorul lui, în timpul unui meeting online.
- Deschide Echo în Chrome → „Sunt coleg într-un meeting online” → (opțional) își învață vocea → intră cu un cod de meeting (sau creează unul și îl dă colegilor) → permite microfonul.
- Echo ascultă **doar microfonul lui, local**, și îi arată **alertele lui**: pe pagină și într-o fereastră mică **mereu deasupra** (Document Picture-in-Picture), care stă peste Teams / Zoom / Meet.
- Prin rețea pleacă doar „vorbesc: da / nu” (pentru alerta de suprapunere). Niciun sunet nu iese de pe calculator.

## 3. Cele 6 alerte (personale, pentru colegul care vorbește)

| Alertă | Când | Din ce cod existent |
|---|---|---|
| „Vorbești prea repede pentru subtitrare” | ritmul vorbirii tale peste prag, pe ultimele ~20 s de vorbire a ta | regula de voce/zgomot din `speaker_labeler.dart` + numărarea silabelor (nou) |
| „Vorbești în același timp cu altcineva” | tu și alt coleg vorbiți simultan ≥ 1,5 s | legătura prin server (`SessionConnection`, sesiuni) + mesaj nou `speaking` |
| „Microfonul te prinde slab: apropie-te sau verifică-l” | vocea ta e prea slabă față de zgomot, ~10 s de vorbire la rând | aceeași regulă de voce/zgomot |
| „Ai vorbit 5 minute fără pauză: lasă loc de întrebări” | vorbești ≥ 5 min cu pauze sub 3 s | detectorul de voce |
| „Zgomot la tine: pune mute când nu vorbești” | YAMNet vede zgomot (muzică, tastare, ventilație…) ≥ 5 s cât nu vorbești | YAMNet din `app/web/js/yamnet.js` |
| „Fă pauze între idei” | de 2 ori în 2 minute, ≥ 12 s de vorbire fără nicio pauză de 0,4 s | detectorul de voce |

**Reguli comune:** fără sunet; iconiță + text (nu doar culoare); câte o alertă odată, cea mai importantă prima (suprapunere > microfon slab > prea repede > fraze fără pauză > 5 minute > zgomot); rămâne cel puțin 6 s, dispare când situația s-a rezolvat; aceeași alertă nu revine mai des de o dată la 3 minute.

## 4. Cum (deciziile mele, pot fi schimbate)

- **Ritmul se măsoară din sunet, nu din transcriere.** Recunoașterea vorbirii din Chrome se poate opri când fila e în fundal (colegul e în fila / aplicația meetingului). Se numără nucleele de silabă: vârfuri de energie precedate și urmate de scăderi, doar în cadre cu voce (metoda de Jong & Wempe, 2009). Nu depinde de limbă și nu cere internet.
- **Pragul de „prea repede”** pornește de la ~170 de cuvinte pe minut (peste el, cititorii de subtitrare au dificultăți; studiul Jensema) și se transformă în silabe pe secundă **calibrat pe română**: VoxPopuli RO are transcrierea fiecărui clip, deci se poate măsura raportul dintre silabele detectate și cuvinte (`ml/voice`, același algoritm ca în aplicație, verificat pe aceleași semnale de test).
- **Doar vocea colegului contează.** Fără căști, microfonul aude și colegii din difuzoare (Chrome nu poate scoate sunetul altor aplicații). Colegul își poate învăța vocea 20 s (ecranul și modelul de voce existente); atunci fiecare segment de vorbire ≥ 1 s e verificat cu amprenta și doar cele ale lui intră în alerte. Cu căști, pasul ăsta se poate sări.
- **Detectorul de voce lucrează pe cadre de 30 ms**, la 16 kHz, din bufferul de captură existent (`echo_voice.js`, fără să încarce modelul de voce dacă vocea nu e învățată). Pragul de zgomot se actualizează continuu (cea mai liniștită cincime din ultimele 10 s).
- **Analiza e pornită de sunet, nu de cronometre**, ca să meargă și cu fila în fundal (Chrome rărește cronometrele în fundal, dar nu și procesarea audio).
- **Fereastra mereu deasupra:** buton „Arată alertele peste meeting” (cere un clic, cum cere browserul). Dacă browserul nu are Document Picture-in-Picture, alertele rămân pe pagină.
- **Suprapunerea:** fiecare pagină trimite `speaking` doar la schimbare (cu o întârziere de 300 ms ca să nu clipească). Serverul îl transmite celorlalți colegi din aceeași sesiune.
- **Pragurile** stau într-un singur fișier (`app/lib/features/coach/coach_thresholds.dart`), ușor de ajustat după primele meetinguri reale.

## 5. Protocol (adăugiri)

- Rol nou la WebSocket: `colleague` (`/ws/{code}?role=colleague`).
- Mesaj nou `speaking` `{id, active: bool, ts}`, trimis doar de `colleague`, transmis celorlalți din sesiune.
- Sesiunea se creează cu `POST /api/sessions` (existent); oricare coleg o poate crea și le dă codul celorlalți.

## 6. Ce NU se schimbă

Meetingul fizic: pagina prezentatorului, telefonul persoanei surde, recunoașterea vocii, alertele de sunet, conturile. Funcția nouă le refolosește, nu le modifică.

## 6b. Date și GDPR

- **Nu se salvează nimic în baza de date, intenționat.** Alertele privesc felul în care vorbește un coleg; păstrate, ar putea fi folosite la evaluarea lui, ceea ce nu e scopul. Nu intră nici în `activity_log`. Dacă se adaugă vreodată un raport după meeting (acum non-obiectiv), e al colegului, în contul lui, cu designul lui.
- **Prin rețea** pleacă doar `speaking` (da / nu), către colegii din aceeași sesiune; nu se păstrează pe server.
- **Amprenta vocii** (date biometrice, art. 9) rămâne doar în browserul colegului (`coachVoiceEnrollment`), niciodată pe server. Ecranul spune asta înainte și după învățare, iar „Șterge vocea” o șterge pe loc (art. 17); temeiul e consimțământul colegului, care o învață doar dacă vrea.

## 7. Non-obiective

Camera (fața, buzele), jargonul, raportul de după meeting, integrarea directă în Teams / Zoom (add-in), subtitrarea pentru persoana surdă în meetingul online (o face platforma meetingului).

## 8. Riscuri

1. **Numărarea silabelor** e mai puțin precisă decât o transcriere; de aceea alerta cere ~20 s de vorbire și un prag calibrat, iar pragul se ajustează după primele meetinguri.
2. **Document Picture-in-Picture** e doar în Chrome / Edge pe desktop.
3. **Fără căști și fără vocea învățată**, vocile colegilor din difuzoare pot declanșa alerte; pagina recomandă căști sau vocea învățată.

## 9. Lăsat la decizia celui care construiește

Aspectul vizual (cu Taste / Impeccable), textele exacte, structura fișierelor din `features/coach/`.
