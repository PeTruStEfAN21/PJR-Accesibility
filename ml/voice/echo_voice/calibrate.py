"""From cosine similarity to the page's decision: a calibrated probability and the threshold on it."""

import math

import numpy as np

# Keeps the fit finite when the two groups are perfectly separated.
L2 = 1e-3
NEWTON_STEPS = 100


def _logistic_fit(positives: np.ndarray, negatives: np.ndarray) -> tuple[float, float]:
    """Weighted logistic regression p = sigmoid(scale * cosine + bias); each class weighs half."""
    x = np.concatenate([positives, negatives]).astype(np.float64)
    y = np.concatenate([np.ones(positives.size), np.zeros(negatives.size)])
    w = np.concatenate([np.full(positives.size, 0.5 / positives.size), np.full(negatives.size, 0.5 / negatives.size)])
    design = np.stack([x, np.ones_like(x)], axis=1)
    theta = np.zeros(2)
    for _ in range(NEWTON_STEPS):
        p = 1.0 / (1.0 + np.exp(-(design @ theta)))
        gradient = design.T @ (w * (p - y)) + L2 * np.array([theta[0], 0.0])
        hessian = design.T @ (design * (w * p * (1 - p))[:, None]) + L2 * np.diag([1.0, 1e-9])
        step = np.linalg.solve(hessian, gradient)
        theta -= step
        if np.abs(step).max() < 1e-10:
            break
    return float(theta[0]), float(theta[1])


def fit_head(
    same: np.ndarray,
    diff: np.ndarray,
    speaker_scores: np.ndarray,
    room_scores: np.ndarray,
    min_speaker_hit: float = 0.95,
) -> dict:
    """scale and bias from all same / different evidence; threshold = the highest probability that still
    labels at least min_speaker_hit of the speaker's lines "Speaker". Without test meetings, same-speaker
    pairs stand in for the speaker's lines."""
    positives = np.concatenate([np.asarray(same, float), np.asarray(speaker_scores, float)])
    negatives = np.concatenate([np.asarray(diff, float), np.asarray(room_scores, float)])
    scale, bias = _logistic_fit(positives, negatives)

    kept = np.asarray(speaker_scores if len(speaker_scores) else same, dtype=np.float64)
    probabilities = np.sort(1.0 / (1.0 + np.exp(-(scale * kept + bias))))
    may_lose = int(math.floor((1 - min_speaker_hit) * probabilities.size + 1e-9))
    return {"scale": scale, "bias": bias, "threshold": float(probabilities[may_lose])}
