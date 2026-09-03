"""
computeStrippingMetric - quantitative Li-stripping indicator for one
post-charge C/5 discharge segment (A-002): max(dV/dt) - min(dV/dt) over an
early-discharge time window.

Python counterpart of Functions/computeStrippingMetric.m.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24
"""

import numpy as np


def compute_stripping_metric(seg, window_s):
    """Return max(dV/dt) - min(dV/dt) over window_s=[t1,t2] for one segment dict."""

    if not seg or 'dVdt_Vpers' not in seg or 'timeS_interp' not in seg:
        return np.nan
    t = seg['timeS_interp']
    y = seg['dVdt_Vpers']
    m = (t >= window_s[0]) & (t <= window_s[1]) & ~np.isnan(y)
    if np.count_nonzero(m) < 5:
        return np.nan
    return np.max(y[m]) - np.min(y[m])


__all__ = ['compute_stripping_metric']
