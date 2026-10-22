# ml/voice — recunoașterea vocii speakerului

Antrenarea, evaluarea și exportul modelului care decide dacă o replică e spusă de speaker sau de cineva din sală. Pagina prezentatorului rulează modelul exportat în Chrome (`app/web/voice/`). Designul: `docs/specs/2026-10-22-meeting-fizic-design.md`.

Modelul de bază e **ReDimNet2-B6** (`PalabraAI/redimnet2`, licență MIT), varianta `vb2+vox2_v0`, `lm`. Codul modelului se încarcă prin `torch.hub` de la un commit fixat (`echo_voice/model.py`), iar greutățile din release-ul `v1.0.0` al aceluiași repo. Primește sunet brut, mono, 16 kHz, și întoarce o amprentă de 192 de numere, normalizată.

## Instalare (o dată)

Pe Windows, cu Python 3.14 oficial (nu cel din MSYS2) și o placă NVIDIA:

```
cd ml/voice
py -3.14 -m venv .venv
.venv/Scripts/pip install -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu130
.venv/Scripts/python -c "import torch; print(torch.cuda.is_available())"
```

Pe Mac: `python3 -m venv .venv && .venv/bin/pip install -r requirements.txt` (fără CUDA; antrenarea merge mult mai încet).

## Teste

```
.venv/Scripts/python -m pytest -q            # toate (prima rulare descarcă modelul, ~50 MB)
.venv/Scripts/python -m pytest -q -m "not slow"
```

## Exportul pentru Chrome

```
.venv/Scripts/python -m echo_voice.export --out ../../app/web/voice/speaker.onnx
```

Scrie `speaker.onnx` (intrare `audio` `[1, eșantioane]`, ieșire `embedding` `[1, 192]`) și `fixtures/parity.json`, pe care pagina `voice/check.html` îl folosește ca să verifice că browserul calculează aceeași amprentă ca Python.

## Clipurile de test

`tests/fixtures/` conține trei clipuri de 3 s în română din VoxPopuli (CC0): două de la același vorbitor, din ședințe diferite, unul de la altul. Detaliile sunt în `tests/fixtures/README.md`.
