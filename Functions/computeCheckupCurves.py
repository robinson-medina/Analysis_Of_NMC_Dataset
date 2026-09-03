"""
computeCheckupCurves - Compute per-checkup OCP / capacity / dQ-dV curves.

Python counterpart of Functions/computeCheckupCurves.m (todo #021). Single,
authoritative implementation of the checkup-discharge math shared by
Functions/analyzeCheckupDischarge.py and any future PlotCellSummary.py port.
Performs NO plotting and NO file I/O; callers add FEC/SoC/OCV interpolation
and plotting on top.

Acceptance test (identical to the MATLAB implementation): a segment is a
valid checkup discharge only if it STARTS above 4.1 V and ENDS below 2.76 V.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24

Compliance: R-004 (Python 3.9+), R-006 (Ah/V/s units), R-012 (commented).
"""

import numpy as np
import pandas as pd

try:
    # scipy >= 1.6 name (cumtrapz is deprecated/removed in newer releases).
    from scipy.integrate import cumulative_trapezoid as _cumtrapz
except ImportError:  # pragma: no cover - older scipy fallback
    from scipy.integrate import cumtrapz as _cumtrapz


def _moving_average(data, window_size):
    """Centered moving average matching MATLAB's movmean (edge-shrinking)."""
    return pd.Series(data).rolling(window=window_size, center=True, min_periods=1).mean().values


def compute_checkup_curves(segments, selected_time, selected_voltage, selected_current,
                            selected_time_s, window_size):
    """
    Compute per-checkup OCP / capacity / dQ-dV curves for every valid segment.

    Parameters
    ----------
    segments : list of numpy.ndarray
        Index ranges (into the selected_* arrays) of candidate checkup segments,
        e.g. from find_checkup_segments.
    selected_time : numpy.ndarray of datetime64
        Datetime array for the selected range.
    selected_voltage : numpy.ndarray
        Voltage array for the selected range [V].
    selected_current : numpy.ndarray
        Current array for the selected range [A].
    selected_time_s : numpy.ndarray
        Seconds-since-start array for the selected range [s].
    window_size : int
        movmean window for the dQ/dV smoothing pipeline.

    Returns
    -------
    checkups : list of dict
        One dict per valid checkup (empty list if none found), each with keys:
        'segment_number', 'segment_indices', 'capacity_Ah_vec', 'voltage_vec',
        'dQdV_vec', 'start_time', 'end_time', 'capacity_Ah', 'time_stamp'
        (mirrors the MATLAB struct-array field names).
    """

    checkups = []
    if not segments:
        return checkups

    for i, segment_indices in enumerate(segments):
        s_v = selected_voltage[segment_indices]          # segment voltage [V]
        s_i = selected_current[segment_indices]           # segment current [A]
        s_t = selected_time[segment_indices]               # segment datetime
        s_ts = selected_time_s[segment_indices]            # segment time [s]
        s_ts = s_ts - s_ts[0]                              # normalise to start at 0 s

        # Acceptance test: only complete discharge cycles (start > 4.1 V, end < 2.76 V).
        if not (s_v[-1] < 2.76 and s_v[0] > 4.1):
            continue

        # Per-sample discharge capacity [Ah]; discharge current is negative,
        # so negating the integral gives a positive, increasing capacity trace.
        cap_vec = -_cumtrapz(s_i, s_ts, initial=0) / 3600

        # Smoothed dQ/dV via the movmean/gradient pipeline (identical
        # smoothing to the MATLAB implementation): smooth I and V, integrate
        # charge, then take gradient(charge)/gradient(V) and smooth again.
        sm_i = _moving_average(s_i, window_size)
        sm_v = _moving_average(s_v, window_size)
        charge = _cumtrapz(sm_i, s_ts, initial=0)
        dv = np.gradient(sm_v)
        dv[dv == 0] = np.nan  # avoid division by zero, matches MATLAB Inf->NaN-safe behaviour
        dqdv = _moving_average(np.gradient(charge) / dv, window_size)

        checkups.append({
            'segment_number': i,                       # 0-based position in `segments`
            'segment_indices': segment_indices,
            'capacity_Ah_vec': cap_vec,
            'voltage_vec': s_v,
            'dQdV_vec': dqdv,
            'start_time': s_t[0],
            'end_time': s_t[-1],
            'capacity_Ah': -np.min(_cumtrapz(s_i, s_ts, initial=0) / 3600),  # scalar capacity
            'time_stamp': s_t[0],
        })

    return checkups


__all__ = ['compute_checkup_curves']
