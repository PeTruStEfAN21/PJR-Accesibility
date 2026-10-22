# ml/voice — recunoașterea vocii speakerului

Aici se antrenează, se evaluează și se exportă modelul care decide dacă o replică e spusă de speaker sau de cineva din sală. Pagina prezentatorului rulează modelul exportat direct în Chrome (`app/web/voice/`), iar sunetul nu pleacă de pe laptop. Designul: `docs/superpowers/specs/2026-10-22-meeting-fizic-design.md`.

## Cum funcționează

1. **Modelul de bază** e **ReDimNet2-B6** (`PalabraAI/redimnet2`, licență MIT), varianta `vb2+vox2_v0`, `lm`, antrenată pe peste 100.000 de vorbitori. Codul se încarcă prin `torch.hub` de la un commit fixat (`echo_voice/model.py`), iar greutățile din release-ul `v1.0.0`. Primește sunet brut, mono, 16 kHz, și scoate o amprentă de 192 de numere.
2. **Fine-tuning** (`echo_voice/train.py`) pe vorbitori români, cu sală simulată (`echo_voice/augment.py`): ecou cu RT60 între 0,2 și 0,8 s, distanță de 1–4 m și zgomot sau altă voce la 5–20 dB.
3. **Calibrarea** (`echo_voice/calibrate.py`) transformă asemănarea dintre voci (cosinus) într-o probabilitate și alege pragul: cel mai mare prag care lasă cel puțin 95% din replicile speakerului etichetate „Speaker”.
4. **Livrarea** (`echo_voice/ship.py`) compară modelul de bază cu fiecare rulare din `runs/*/best.pt`, pe date nefolosite la antrenare, și exportă câștigătorul în `app/web/voice/speaker.onnx` și `voice_head.json`. Scrie și un raport în `reports/`.

## Instalare (o dată)

Pe Windows, cu Python 3.14 oficial (nu cel din MSYS2) și placă NVIDIA:

```
cd ml/voice
py -3.14 -m venv .venv
.venv/Scripts/pip install -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu130
.venv/Scripts/python -c "import torch; print(torch.cuda.is_available())"
```

Pe Mac: `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt`, fără CUDA. Antrenarea merge mult mai încet acolo, dar testele și exportul merg.

## Date

Datele audio stau în `data/`, care nu intră în git.

**Vorbire în română (VoxPopuli, licență CC0, fără cont).** Sunt discursuri din Parlamentul European, cu vorbitorii etichetați: ~16 GB, 84 de vorbitori, ~26.000 de clipuri.

```
mkdir -p data/raw/voxpopuli_ro && cd data/raw/voxpopuli_ro
for f in train-00000-of-00005 train-00001-of-00005 train-00002-of-00005 train-00003-of-00005 train-00004-of-00005 validation-00000-of-00001 test-00000-of-00001; do
  curl -L -C - -o $f.parquet https://huggingface.co/datasets/facebook/voxpopuli/resolve/main/ro/$f.parquet
done
cd ../../..
.venv/Scripts/python -m echo_voice.data --source voxpopuli --src data/raw/voxpopuli_ro --out data/speakers
```

**Opțional: Common Voice în română** (mai mulți vorbitori, voci obișnuite). Se descarcă de pe https://datacollective.mozillafoundation.org, cu cont și acceptarea termenilor: se folosește doar pentru verificarea vorbitorului, adică exact ce facem. Arhiva se dezarhivează în `data/raw/common_voice_ro/`, unde trebuie să fie `validated.tsv` și `clips/`, apoi:

```
.venv/Scripts/python -m echo_voice.data --source common_voice --src data/raw/common_voice_ro --out data/speakers
```

## Meetingul de test (cel mai important pentru sala voastră)

Modelul învață din parlament, dar pragul trebuie potrivit pe laptopul și sala voastră.

1. **Cine:** 3–5 colegi. Unul e speaker, ceilalți stau în locuri diferite din sală și pun întrebări, normal, ca la un meeting.
2. **Consimțământ:** toți știu că se înregistrează și sunt de acord. Clipurile rămân pe laptop.
3. Pe laptop, în Chrome, deschideți `http://localhost:8000` → „Prezint”. Speakerul citește textul afișat 20 de secunde.
4. Porniți comutatorul **„Meeting de test”**, apoi **„Pornește subtitrarea”**. Țineți meetingul 10–15 minute.
5. **„Oprește subtitrarea”** deschide ecranul de verificare. Ascultați replicile la care nu sunteți siguri, corectați eticheta (Speaker / Din sală), apoi **„Descarcă”**.
6. Copiați arhiva `echo-test-meeting-<dată>.zip` în `ml/voice/data/meetings/`.
7. Faceți 3–5 meetinguri, de fiecare dată cu alt speaker. Numele unuia sau două dintre ele (fără `.zip`) se trec câte unul pe linie în `ml/voice/heldout_meetings.txt`. Acestea nu se folosesc la calibrare, ci doar la verdictul final.

```
.venv/Scripts/python -m echo_voice.data --source meetings --src data/meetings --out data/speakers
```

## Antrenare, evaluare, livrare

```
.venv/Scripts/python -m echo_voice.train --data data/speakers --out runs/<nume> --epochs 5 --batch 6
.venv/Scripts/python -m echo_voice.evaluate          # modelul de bază: EER + meetingurile ținute deoparte
.venv/Scripts/python -m echo_voice.ship              # alege, calibrează și exportă în app/web/voice/
```

- Pe un RTX 3050 de laptop (6 GB), lotul maxim care încape în memoria plăcii e **6** clipuri de 3 s, adică ~9 clipuri pe secundă și ~40 de minute pe epocă cu VoxPopuli.
- `train` salvează după fiecare epocă `runs/<nume>/best.pt` (cea mai mică EER pe vorbitorii ținuți deoparte) și `log.jsonl`.
- După `ship`: `cd ../../app && flutter build web`, apoi verificați în Chrome `http://localhost:8000/voice/check.html`. Cosinusul cu Python trebuie să fie ≥ 0,999, iar durata pentru 8 s ≤ 1,5 s, cu placa video liberă.

### Raportul (`reports/<dată>-ship.md`)

| Coloană | Ce înseamnă |
|---|---|
| EER | Rata de eroare egală pe perechi de clipuri (același vorbitor / vorbitori diferiți); mai mic e mai bine |
| Speaker → „Speaker” | Cât din replicile speakerului au primit eticheta corectă; trebuie ≥ 95% |
| Sală → „Din sală” | Cât din replicile colegilor au primit eticheta corectă; ținta e ≥ 85% |
| Prag | Pragul de probabilitate scris în `voice_head.json` |

Fără meetinguri ținute deoparte, cifrele vin din perechi VoxPopuli și raportul spune asta. Un meeting sub țintă e marcat „sub criteriu”.

## Teste

```
.venv/Scripts/python -m pytest -q                  # toate (prima rulare descarcă modelul, ~50 MB)
.venv/Scripts/python -m pytest -q -m "not slow"    # fără cele care încarcă modelul
```

`tests/fixtures/` conține trei clipuri de 3 s în română din VoxPopuli (CC0): două de la același vorbitor, din ședințe diferite, și unul de la altcineva. Detaliile sunt în `tests/fixtures/README.md`.
