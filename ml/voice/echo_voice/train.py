"""Fine-tune ReDimNet2 on Romanian speakers heard through a simulated meeting room.

Additive angular margin softmax over the training speakers, 3 s crops, a small learning rate for the
pretrained backbone so it keeps what it knows. Keeps the epoch with the lowest EER on held-out speakers.

Usage: python -m echo_voice.train --data data/speakers --out runs/<name> [--epochs 5] [--smoke]
"""

import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import soundfile as sf
import torch
from torch import nn
from torch.utils.data import DataLoader, Dataset

from echo_voice.augment import apply_room
from echo_voice.data import split_speakers
from echo_voice.evaluate import speaker_trials, trials_eer
from echo_voice.model import EMBEDDING_SIZE, SAMPLE_RATE, embed, load_base

CROP_SECONDS = 3
ROOM_PROBABILITY = 0.6
MARGIN = 0.2
SCALE = 32.0
BACKBONE_LR = 1e-5
HEAD_LR = 1e-3
NOISE_POOL_SIZE = 64
CENTER_CLIPS = 5


class AAMSoftmax(nn.Module):
    """Softmax over speakers with an extra angle added to the true speaker: close voices must separate more."""

    def __init__(self, centers: torch.Tensor, margin: float = MARGIN, scale: float = SCALE) -> None:
        super().__init__()
        self.weight = nn.Parameter(centers.clone())
        self.margin = margin
        self.scale = scale

    def forward(self, embeddings: torch.Tensor, labels: torch.Tensor) -> torch.Tensor:
        cosine = nn.functional.linear(nn.functional.normalize(embeddings), nn.functional.normalize(self.weight))
        cosine = cosine.clamp(-1 + 1e-7, 1 - 1e-7)
        target = torch.cos(torch.acos(cosine.gather(1, labels[:, None])) + self.margin)
        logits = cosine.scatter(1, labels[:, None], target) * self.scale
        return nn.functional.cross_entropy(logits, labels)


def crop_or_tile(wave: np.ndarray, size: int, rng: np.random.Generator) -> np.ndarray:
    if wave.size >= size:
        start = int(rng.integers(wave.size - size + 1))
        return wave[start : start + size]
    return np.resize(wave, size)


class CropDataset(Dataset):
    def __init__(self, items: list[tuple[str, int]], noise_files: list[str], crop: int, augment: bool) -> None:
        self.items = items
        self.noise_files = noise_files
        self.crop = crop
        self.augment = augment
        self._noise: list[np.ndarray] | None = None  # loaded lazily, once per worker

    def __len__(self) -> int:
        return len(self.items)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, int]:
        path, label = self.items[index]
        rng = np.random.default_rng()
        wave = crop_or_tile(sf.read(path, dtype="float32")[0], self.crop, rng)
        if self.augment and rng.random() < ROOM_PROBABILITY:
            if self._noise is None:
                self._noise = [sf.read(p, dtype="float32")[0] for p in self.noise_files]
            wave = apply_room(wave, rng, self._noise)
        return torch.from_numpy(np.ascontiguousarray(wave, dtype=np.float32)), label


def speaker_centers(model: nn.Module, files: list[list[Path]]) -> torch.Tensor:
    """Each speaker's mean embedding under the base model: the softmax starts where the model already is."""
    centers = []
    for clips in files:
        vectors = [embed(model, sf.read(p, dtype="float32")[0][: 8 * SAMPLE_RATE]) for p in clips[:CENTER_CLIPS]]
        mean = np.mean(vectors, axis=0)
        centers.append(mean / np.linalg.norm(mean))
    return torch.from_numpy(np.stack(centers).astype(np.float32))


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--epochs", type=int, default=5)
    parser.add_argument("--batch", type=int, default=24)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--trials", type=int, default=2000)
    parser.add_argument("--size", default="b6")
    parser.add_argument("--dataset", default="vb2+vox2_v0")
    parser.add_argument("--val-clean", action="store_true", help="validate on clean pairs instead of 5–10 m away")
    parser.add_argument("--smoke", action="store_true", help="two steps on the CPU, no validation")
    args = parser.parse_args(argv)
    if args.smoke:
        args.epochs, args.batch, args.workers = 1, 2, 0

    device = "cuda" if torch.cuda.is_available() and not args.smoke else "cpu"
    names = sorted(p.name for p in args.data.iterdir() if p.is_dir() and not p.name.startswith("_"))
    train_speakers, test_speakers = (names, []) if args.smoke else split_speakers(args.data)
    files = [sorted((args.data / s).glob("*.wav")) for s in train_speakers]
    items = [(str(p), label) for label, clips in enumerate(files) for p in clips]
    rng = np.random.default_rng(0)
    noise_files = [items[i][0] for i in rng.choice(len(items), size=min(NOISE_POOL_SIZE, len(items)), replace=False)]
    voices = [s for s in test_speakers if not s.startswith("meeting-")]
    trials = speaker_trials(args.data, voices, args.trials) if voices else []

    model = load_base(args.size, args.dataset).to(device)
    head = AAMSoftmax(speaker_centers(model, files)).to(device)
    optimizer = torch.optim.AdamW(
        [{"params": model.parameters(), "lr": BACKBONE_LR}, {"params": head.parameters(), "lr": HEAD_LR}],
        weight_decay=1e-4,
    )
    loader = DataLoader(
        CropDataset(items, noise_files, CROP_SECONDS * SAMPLE_RATE, augment=True),
        batch_size=args.batch,
        shuffle=True,
        drop_last=True,
        num_workers=args.workers,
        persistent_workers=args.workers > 0,
    )

    args.out.mkdir(parents=True, exist_ok=True)
    log = (args.out / "log.jsonl").open("a", encoding="utf-8")
    far = not args.val_clean
    base_eer = trials_eer(model.eval(), trials, far=far) if trials else math.nan
    print(f"{len(train_speakers)} speakers, {len(items)} clips; base EER {100 * base_eer:.2f}%", flush=True)
    log.write(json.dumps({"epoch": 0, "eer": base_eer}) + "\n")
    best = math.inf

    for epoch in range(1, args.epochs + 1):
        model.train()
        started, seen, total = time.time(), 0, 0.0
        for step, (waves, labels) in enumerate(loader, 1):
            with torch.autocast(device_type=device, dtype=torch.bfloat16, enabled=device == "cuda"):
                embeddings = model(waves.to(device))
            loss = head(embeddings.float(), labels.to(device))
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            optimizer.step()
            seen += waves.shape[0]
            total += loss.item()
            if step % 50 == 0:
                print(f"epoch {epoch} step {step}/{len(loader)} loss {total / step:.3f} "
                      f"{seen / (time.time() - started):.0f} clips/s", flush=True)
            if args.smoke and step >= 2:
                break
        model.eval()
        val = trials_eer(model, trials, far=far) if trials else math.nan
        print(f"epoch {epoch}: loss {total / max(step, 1):.3f}, EER {100 * val:.2f}% (base {100 * base_eer:.2f}%)", flush=True)
        log.write(json.dumps({"epoch": epoch, "loss": total / max(step, 1), "eer": val}) + "\n")
        log.flush()
        if not trials or val < best:
            best = val if trials else best
            torch.save(
                {
                    "base": {"size": args.size, "dataset": args.dataset, "train_type": "lm"},
                    "state_dict": model.state_dict(),
                    "epoch": epoch,
                    "eer": val,
                    "base_eer": base_eer,
                },
                args.out / "best.pt",
            )
    log.close()


if __name__ == "__main__":
    main()
