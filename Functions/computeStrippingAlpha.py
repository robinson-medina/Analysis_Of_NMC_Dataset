"""
computeStrippingAlpha - power-law exponent of the dV/dt relaxation shape
for one post-charge C/5 discharge segment (A-002): fits
dV/dt(t) = a + b * t^(-alpha) over a metric window via grid search on alpha.

Python counterpart of Functions/computeStrippingAlpha.m.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24
"""

import numpy as np


def compute_stripping_alpha(seg, window_s, alpha_grid):
    """Return (alpha, rmse) for the best-fit power-law model over window_s."""

    if not seg or 'dVdt_Vpers' not in seg or 'timeS_interp' not in seg:
        return np.nan, np.nan
    t = seg['timeS_interp']
    y = seg['dVdt_Vpers']
    m = (t >= window_s[0]) & (t <= window_s[1]) & ~np.isnan(y)
    if np.count_nonzero(m) < 10:
        return np.nan, np.nan
    tw, yw = t[m], y[m]

    best_rss = np.inf
    best_alpha = np.nan
    for a in alpha_grid:
        design = np.column_stack([np.ones_like(tw), tw ** (-a)])
        coef, *_ = np.linalg.lstsq(design, yw, rcond=None)
        residual = yw - design @ coef
        rss = np.sum(residual ** 2)
        if rss < best_rss:
            best_rss = rss
            best_alpha = a

    rmse = np.sqrt(best_rss / len(yw))
    return best_alpha, rmse


__all__ = ['compute_stripping_alpha']
