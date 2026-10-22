"""The pretrained speaker model: ReDimNet2 from its GitHub repo, pinned to one commit."""

import numpy as np
import torch

SAMPLE_RATE = 16000
EMBEDDING_SIZE = 192

# Code from this commit; weights from the repo's v1.0.0 release (see redimnet2/__init__.py there).
REPO = "PalabraAI/redimnet2:c5bbe0b76e37df698c403f8844e41304ceab6307"


def load_base(size: str = "b6", dataset: str = "vb2+vox2_v0", train_type: str = "lm") -> torch.nn.Module:
    model = torch.hub.load(
        REPO,
        "redimnet2",
        model_name=size,
        train_type=train_type,
        dataset=dataset,
        pretrained=True,
        trust_repo=True,
        skip_validation=True,
    )
    return model.eval()


@torch.no_grad()
def embed(model: torch.nn.Module, wave: np.ndarray) -> np.ndarray:
    """16 kHz mono float samples -> unit-length speaker embedding."""
    device = next(model.parameters()).device
    batch = torch.from_numpy(np.ascontiguousarray(wave, dtype=np.float32))[None, :].to(device)
    vector = torch.nn.functional.normalize(model(batch), dim=-1)[0]
    return vector.cpu().numpy()
