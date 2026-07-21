"""
Value-based media file scoring using numpy.

Runs entirely on-device via Chaquopy (no internet required).
Called from MainActivity.kt via Chaquopy's Python bridge.

Composite score = 0.40 * recency  +  0.30 * frequency  +  0.30 * (1 - size_norm)

  recency   : exponential decay e^(-days_since_access / 30)
              High score = recently accessed (valuable, keep it)

  frequency : normalised access count  (access_count / max_access_count)
              High score = opened often (valuable, keep it)

  size_norm : log-normalised file size  (log(size) / log(max_size))
              Large file with low use → low value score → good deletion candidate

Threshold 0.35: files below this score are flagged isRecommendedForDeletion.
"""

import numpy as np


_W_RECENCY = 0.40
_W_FREQ = 0.30
_W_SIZE = 0.30
_DELETE_THRESHOLD = 0.35
_RECENCY_HALF_LIFE = 30.0  # days


def score_files(days_since_access, access_counts, size_bytes):
    """
    Vectorised scoring of a file catalogue.

    Args:
        days_since_access : list[float]  – days since each file was last accessed
        access_counts     : list[int]    – how many times each file was accessed
        size_bytes        : list[int]    – file size in bytes

    Returns:
        dict with:
            scores     : list[float]  – value score [0, 1] per file
            recommended: list[bool]   – True = recommend for deletion
            reasons    : list[str]    – short human-readable explanation
    """
    try:
        if not days_since_access:
            return {"scores": [], "recommended": [], "reasons": []}

        days = np.array(days_since_access, dtype=float).clip(0, 365)
        counts = np.array(access_counts, dtype=float)
        sizes = np.array(size_bytes, dtype=float)

        # --- Recency: exponential decay ---
        recency = np.exp(-days / _RECENCY_HALF_LIFE)

        # --- Frequency: log-normalised access count ---
        log_counts = np.log1p(counts)
        max_log_count = log_counts.max() if log_counts.max() > 0 else 1.0
        freq = (log_counts / max_log_count).clip(0, 1)

        # --- Size: log-normalised, large files get lower value contribution ---
        log_sizes = np.log1p(sizes)
        max_log_size = log_sizes.max() if log_sizes.max() > 0 else 1.0
        size_norm = (log_sizes / max_log_size).clip(0, 1)
        size_score = 1.0 - size_norm  # invert: large file = low size_score

        scores = _W_RECENCY * recency + _W_FREQ * freq + _W_SIZE * size_score

        recommended = (scores < _DELETE_THRESHOLD).tolist()
        reasons = _build_reasons(recency, freq, size_norm, days.astype(int))

        return {
            "scores": scores.tolist(),
            "recommended": recommended,
            "reasons": reasons,
        }
    except Exception as e:
        n = len(days_since_access)
        return {
            "scores": [0.5] * n,
            "recommended": [False] * n,
            "reasons": [f"scoring_error: {e}"] * n,
        }


def _build_reasons(recency, freq, size_norm, days_int):
    reasons = []
    for r, f, s, d in zip(recency, freq, size_norm, days_int):
        parts = []
        if r < 0.30:
            parts.append(f"not accessed in {d} days")
        if f < 0.10:
            parts.append("rarely opened")
        if s > 0.70:
            parts.append("large file")
        reasons.append(", ".join(parts) if parts else "low overall utility")
    return reasons
