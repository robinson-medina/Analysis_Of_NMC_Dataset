"""
extractDVdtSegmentsAll - Return EVERY post-charge constant-current discharge
segment in a trace (unlike analyze_dvdt_after_charge, which only returns 5),
each interpolated onto a 1 s grid with smoothed dV/dt.

Python counterpart of Functions/extractDVdtSegmentsAll.m.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24

Compliance: R-004, R-012.
"""

import numpy as np
import pandas as pd


def extract_dvdt_segments_all(selected_time, selected_voltage, selected_current, selected_time_s,
                                target_current_a, params):
    """
    Detect every constant-current segment near target_current_a and compute
    its interpolated (1 s grid) voltage + smoothed dV/dt.

    Parameters
    ----------
    selected_time : array of datetime64
    selected_voltage : array [V]
    selected_current : array [A]
    selected_time_s : array [s], seconds-since-start
    target_current_a : float
        Target |I| value (e.g. -11.6 A for C/5 discharge).
    params : dict with keys 'tolerance_A', 'minSegmentLength', 'maxSegmentLength', 'smoothWin'.

    Returns
    -------
    all_segs : list of dict
        One dict per detected segment with keys 'start_time',
        'timeS_interp', 'voltage_interp', 'dVdt_Vpers'.
    """

    all_segs = []
    mask = np.abs(selected_current - target_current_a) <= params['tolerance_A']
    mask[np.isnan(selected_current)] = False

    padded = np.concatenate(([False], mask, [False])).astype(int)
    edges = np.diff(padded)
    run_starts = np.where(edges == 1)[0]
    run_ends = np.where(edges == -1)[0] - 1

    # Duration filter in seconds from the timestamps (row-count-invariant, see MATLAB notes).
    dur_s = selected_time_s[run_ends] - selected_time_s[run_starts]
    keep = (dur_s >= (params['minSegmentLength'] - 1)) & (dur_s <= (params['maxSegmentLength'] - 1))
    run_starts = run_starts[keep]
    run_ends = run_ends[keep]

    for s, e in zip(run_starts, run_ends):
        idx = np.arange(s, e + 1)
        seg_v = selected_voltage[idx]
        seg_ts = selected_time_s[idx]
        seg_t = selected_time[idx]
        if len(seg_ts) == 0 or np.isnan(seg_ts[0]) or np.isnan(seg_ts[-1]):
            continue
        seg_ts = seg_ts - seg_ts[0]
        # Guard against duplicate time samples (sub-second row splits).
        seg_ts, iu = np.unique(seg_ts, return_index=True)
        seg_v = seg_v[iu]
        # Interpolate onto a uniform 1 s grid.
        t_interp = np.arange(0, np.floor(np.max(seg_ts)) + 1)
        if len(t_interp) < 3:
            continue
        v_interp = np.interp(t_interp, seg_ts, seg_v)
        # Smoothed dV/dt via gradient ratio (matches analyzeDVdtAfterCharge).
        dvdt = pd.Series(np.gradient(v_interp) / np.gradient(t_interp)).rolling(
            window=params['smoothWin'], center=True, min_periods=1).mean().values

        all_segs.append({
            'start_time': seg_t[0],
            'timeS_interp': t_interp,
            'voltage_interp': v_interp,
            'dVdt_Vpers': dvdt,
        })

    return all_segs


__all__ = ['extract_dvdt_segments_all']
