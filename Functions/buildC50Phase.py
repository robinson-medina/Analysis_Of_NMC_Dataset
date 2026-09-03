"""
buildC50Phase - assemble a C/50 phase (discharge + matching charge) with a
shared signed-Q axis integrated from the start of the discharge.

Python counterpart of Functions/buildC50Phase.m. Shared by
python_scripts/PlotCellSummary.py (todo #012).

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24
"""

import numpy as np

try:
    from scipy.integrate import cumulative_trapezoid as _cumtrapz
except ImportError:  # pragma: no cover
    from scipy.integrate import cumtrapz as _cumtrapz


def find_matching_charge_seg(disch_seg, charge_segs):
    """Return the first charge segment starting after the discharge ends, or None."""

    disch_end = disch_seg[-1]
    for seg in charge_segs:
        if seg[0] > disch_end:
            return seg
    return None


def build_c50_phase(disch_seg, charge_segs, selected_voltage, selected_current, selected_time_s):
    """
    Assemble a C/50 phase (discharge + matching charge) with a shared
    signed-Q axis integrated from the start of the discharge.

    Returns a dict with keys 'dischQ_Ah', 'dischV', 'chargeQ_Ah', 'chargeV'
    (charge* are empty arrays if no matching charge segment exists).
    """

    result = {'dischQ_Ah': np.array([]), 'dischV': np.array([]),
              'chargeQ_Ah': np.array([]), 'chargeV': np.array([])}
    if len(disch_seg) == 0:
        return result

    matched_chg = find_matching_charge_seg(disch_seg, charge_segs)

    if matched_chg is None:
        s_ts = selected_time_s[disch_seg]
        s_ts = s_ts - s_ts[0]
        s_i = selected_current[disch_seg]
        m = ~np.isnan(s_ts) & ~np.isnan(s_i)
        q = np.full(s_ts.shape, np.nan)
        if np.count_nonzero(m) >= 2:
            q[m] = _cumtrapz(s_i[m], s_ts[m], initial=0) / 3600
        result['dischQ_Ah'] = q
        result['dischV'] = selected_voltage[disch_seg]
        return result

    full_range = np.arange(disch_seg[0], matched_chg[-1] + 1)
    t_full = selected_time_s[full_range].astype(float)
    i_full = selected_current[full_range].astype(float)

    i_clean = np.nan_to_num(i_full, nan=0.0)
    t_clean = t_full.copy()
    if np.any(np.isnan(t_clean)):
        idx_all = np.arange(len(t_clean))
        good = ~np.isnan(t_clean)
        if np.count_nonzero(good) >= 2:
            t_clean[~good] = np.interp(idx_all[~good], idx_all[good], t_clean[good])
        else:
            t_clean = idx_all.astype(float)

    cum_q_full_ah = _cumtrapz(i_clean, t_clean - t_clean[0], initial=0) / 3600

    rel_disch = np.arange(0, len(disch_seg))
    rel_charge = np.arange(matched_chg[0] - disch_seg[0], len(full_range))

    result['dischQ_Ah'] = cum_q_full_ah[rel_disch]
    result['dischV'] = selected_voltage[disch_seg]
    result['chargeQ_Ah'] = cum_q_full_ah[rel_charge]
    result['chargeV'] = selected_voltage[matched_chg]
    return result


__all__ = ['build_c50_phase', 'find_matching_charge_seg']
