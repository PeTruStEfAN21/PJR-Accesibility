"""Export a speaker model to ONNX for the presenter page, plus a parity fixture for the browser check."""

import argparse
import base64
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
import torch

from echo_voice.model import SAMPLE_RATE, load_base

OPSET = 18
PARITY_SECONDS = 3


class _Normalized(torch.nn.Module):
    """The page compares embeddings by cosine, so the graph returns them unit-length."""

    def __init__(self, model: torch.nn.Module) -> None:
        super().__init__()
        self.model = model

    def forward(self, audio: torch.Tensor) -> torch.Tensor:
        return torch.nn.functional.normalize(self.model(audio), dim=-1)


def export_onnx(model: torch.nn.Module, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # The exporter restores the wrapper's mode afterwards; a fresh wrapper would put the model in training mode.
    wrapped = _Normalized(model.cpu()).eval()
    example = torch.zeros(1, 3 * SAMPLE_RATE)
    torch.onnx.export(
        wrapped,
        (example,),
        str(path),
        input_names=["audio"],
        output_names=["embedding"],
        dynamic_axes={"audio": {1: "samples"}},
        opset_version=OPSET,
        dynamo=False,
    )


def parity_audio() -> np.ndarray:
    """Fixed, voice-band audio the browser check feeds to both runtimes."""
    rng = np.random.default_rng(1234)
    noise = rng.standard_normal(PARITY_SECONDS * SAMPLE_RATE).astype(np.float32)
    wave = np.convolve(noise, np.ones(8, dtype=np.float32) / 8, mode="same")
    t = np.arange(wave.size) / SAMPLE_RATE
    wave *= 0.5 * (1 + np.sin(2 * np.pi * 4 * t))
    return (0.3 * wave / np.abs(wave).max()).astype(np.float32)


def write_parity_fixture(onnx_path: Path) -> Path:
    audio = parity_audio()
    session = ort.InferenceSession(str(onnx_path), providers=["CPUExecutionProvider"])
    (embedding,) = session.run(["embedding"], {"audio": audio[None, :]})
    fixture = onnx_path.parent / "fixtures" / "parity.json"
    fixture.parent.mkdir(parents=True, exist_ok=True)
    fixture.write_text(
        json.dumps(
            {
                "sample_rate": SAMPLE_RATE,
                "audio_b64": base64.b64encode(audio.astype("<f4").tobytes()).decode(),
                "embedding": [round(float(x), 7) for x in embedding[0]],
            }
        )
    )
    return fixture


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, required=True, help="where to write speaker.onnx")
    parser.add_argument("--size", default="b6")
    parser.add_argument("--dataset", default="vb2+vox2_v0")
    args = parser.parse_args(argv)

    export_onnx(load_base(args.size, args.dataset), args.out)
    fixture = write_parity_fixture(args.out)
    print(f"wrote {args.out} ({args.out.stat().st_size / 1e6:.1f} MB) and {fixture}")


if __name__ == "__main__":
    main()
