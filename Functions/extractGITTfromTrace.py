"""
extractGITTfromTrace - Find back-to-back discharge+charge GITT episodes in
an ageing trace and extract the per-pulse OCV.

Python counterpart of Functions/extractGITTfromTrace.m, used by
python_scripts/PlotCellSummary.py (todo #012).

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24
Assumption: A-001 (see docs/assumptions.md)

Compliance: R-004, R-012.
"""

import numpy as np

try:
    # NumPy >= 2.0 name (np.trapz was deprecated in 2.0 and removed in 2.5).
    _trapz = np.trapezoid
except AttributeError:  # pragma: no cover - NumPy < 2.0 fallback
    _trapz = np.trapz

_DEFAULTS = {
    'pulseAmp_A': 11.6, 'pulseTol_A': 0.5, 'maxPulseAmp_A': 20,
    'minPulse_s': 60, 'maxPulse_s': 3600, 'minPulseCharge_Ah': 0.15,
    'maxIntraEpisodeGap_s': 24 * 3600, 'restThr_A': 0.5,
    'minRestDur_s': 600, 'pulseFlatnessTol': 0.05, 'edgeJump_A': 2,
    'gradThr_Apers': 3, 'minPulsesPerEpisode': 20, 'maxPulsesPerEpisode': 55,
}


def _find_runs(mask):
    """Return (starts, ends) 0-based inclusive index arrays of contiguous True runs."""

    padded = np.concatenate(([False], mask, [False])).astype(int)
    dd = np.diff(padded)
    starts = np.where(dd == 1)[0]
    ends = np.where(dd == -1)[0] - 1
    return starts, ends


def extract_gitt_from_trace(time_with_gaps, voltage, current, time_s, params):
    """
    Detect GITT episodes (clusters of C/5 +/- pulses) and extract per-pulse OCV.

    Returns a list of dicts, one per detected episode, with keys:
    time_start, time_end, pulse_start_times, pulse_end_times,
    pulse_start_idx, pulse_end_idx, pulse_modes, cumQ_signed_Ah, OCV_V,
    ocv_idx, ocv_modes, q_per_pulse_Ah.
    """

    p = dict(_DEFAULTS)
    p.update({k: v for k, v in params.items() if v is not None})

    gitt_episodes = []
    time_s = np.asarray(time_s, dtype=float)
    current = np.asarray(current, dtype=float)
    voltage = np.asarray(voltage, dtype=float)
    n = len(current)

    # 1) Pulse mask: current excursion above rest and below cycling amplitude.
    pulse_mask = (np.abs(current) > p['restThr_A']) & (np.abs(current) < p['maxPulseAmp_A']) & ~np.isnan(current)
    pulse_starts, pulse_ends = _find_runs(pulse_mask)
    if len(pulse_starts) == 0:
        return gitt_episodes

    # 3) Filter pulses by duration + peak amplitude + charge; build the pulse table.
    pulse_start_idx, pulse_end_idx, pulse_modes = [], [], []
    for s, e in zip(pulse_starts, pulse_ends):
        if np.isnan(time_s[s]) or np.isnan(time_s[e]):
            continue
        dur = time_s[e] - time_s[s]
        if dur < p['minPulse_s'] or dur > p['maxPulse_s']:
            continue
        # Pulse-acceptance test (#082 fix, ported 2026-08-26 from
        # matlab_scripts/PlotCellSummary.m): a genuine C/5 GITT pulse can end
        # in a CC->CV taper near the SoC extremes (voltage cutoff hit
        # mid-pulse), which the old whole-pulse flatness test wrongly rejected
        # (confirmed on A3.10_Cell_22 EoL). Replaced with two taper-invariant
        # checks: (1) peak |I| must sit at the nominal C/5 amplitude - a CV
        # tail can only decay FROM that peak - and (2) the pulse must transfer
        # a minimum charge (real SoC change, not brief noise).
        i_pulse = current[s:e + 1]
        t_pulse = time_s[s:e + 1]
        keep_m = ~np.isnan(i_pulse) & ~np.isnan(t_pulse)
        i_pulse = i_pulse[keep_m]
        t_pulse = t_pulse[keep_m]
        if len(i_pulse) == 0:
            continue
        i_peak = np.max(np.abs(i_pulse))
        if abs(i_peak - p['pulseAmp_A']) > p['pulseTol_A']:
            continue
        if len(i_pulse) < 2:
            continue
        q_pulse_ah = _trapz(i_pulse, t_pulse) / 3600
        if abs(q_pulse_ah) < p['minPulseCharge_Ah']:
            continue
        mode = 'discharge' if np.nanmean(current[s:e + 1]) < 0 else 'charge'
        pulse_start_idx.append(s)
        pulse_end_idx.append(e)
        pulse_modes.append(mode)

    n_pulses = len(pulse_start_idx)
    if n_pulses == 0:
        return gitt_episodes

    pulse_start_idx = np.array(pulse_start_idx)
    pulse_end_idx = np.array(pulse_end_idx)
    pulse_start_time = time_with_gaps[pulse_start_idx]
    pulse_end_time = time_with_gaps[pulse_end_idx]

    # 4) Cluster pulses into episodes by inter-pulse time gap.
    cluster_id = np.zeros(n_pulses, dtype=int)
    for i in range(1, n_pulses):
        gap_s = (pulse_start_time[i] - pulse_end_time[i - 1]) / np.timedelta64(1, 's')
        cluster_id[i] = cluster_id[i - 1] + (1 if gap_s > p['maxIntraEpisodeGap_s'] else 0)

    # 5) Build episode list for clusters with pulse counts in range.
    min_half, max_half = 23 - 3, 26 + 3
    half_boundary_thr_s = 4 * 3600

    for c in range(cluster_id.max() + 1):
        idx = np.where(cluster_id == c)[0]
        if len(idx) < p['minPulsesPerEpisode'] or len(idx) > p['maxPulsesPerEpisode']:
            continue

        intra_gaps_s = (pulse_start_time[idx[1:]] - pulse_end_time[idx[:-1]]) / np.timedelta64(1, 's')
        half_boundaries = np.where(intra_gaps_s > half_boundary_thr_s)[0]
        half_starts_local = np.concatenate(([0], half_boundaries + 1))
        half_ends_local = np.concatenate((half_boundaries, [len(idx) - 1]))
        half_sizes = half_ends_local - half_starts_local + 1
        if np.any(half_sizes < min_half) or np.any(half_sizes > max_half):
            print(f"  [GITT] Rejected cluster ({pulse_start_time[idx[0]]} -> {pulse_end_time[idx[-1]]}, "
                  f"{len(idx)} pulses, halves = [{','.join(str(x) for x in half_sizes)}]).")
            continue

        # --- Refinement inside the validated cluster ------------------------
        s_first = pulse_start_idx[idx[0]]
        s_last_cluster_pulse = pulse_end_idx[idx[-1]]
        while s_first > 0:
            if np.isnan(current[s_first - 1]) or abs(current[s_first - 1]) >= p['restThr_A']:
                break
            s_first -= 1

        t_end_search = time_s[s_last_cluster_pulse] + p['maxIntraEpisodeGap_s']
        candidate = np.where(~np.isnan(time_s) & (time_s <= t_end_search))[0]
        s_last = candidate[-1] if len(candidate) else n - 1
        if s_last < s_first:
            s_last = n - 1

        seg = np.arange(s_first, s_last + 1)
        i_seg = current[seg]
        t_seg = time_s[seg]
        di_dt = np.diff(i_seg) / np.diff(t_seg)
        abs_di_dt = np.abs(di_dt)

        rest_mask = np.abs(i_seg[:-1]) < p['restThr_A']
        is_edge = (abs_di_dt > p['gradThr_Apers']) & rest_mask
        is_edge = np.nan_to_num(is_edge, nan=0.0).astype(bool)

        edge_run_starts, _ = _find_runs(is_edge)
        if len(edge_run_starts) == 0:
            continue

        pre_pulse_global = seg[edge_run_starts]           # last resting sample (OCV anchor)
        pulse_start_idx_r = seg[edge_run_starts + 1]       # first ramp sample (pulse start)

        pulse_modes_r = ['discharge' if di_dt[k] < 0 else 'charge' for k in edge_run_starts]

        # Pulse end: walk forward until |I| < restThr_A or the next pulse starts.
        pulse_end_idx_r = np.zeros(len(edge_run_starts), dtype=int)
        for k in range(len(edge_run_starts)):
            walk_end = pre_pulse_global[k + 1] if k < len(edge_run_starts) - 1 else s_last
            pe = pulse_start_idx_r[k]
            for j in range(pulse_start_idx_r[k], walk_end + 1):
                if np.isnan(current[j]) or abs(current[j]) < p['restThr_A']:
                    pe = j - 1
                    break
                pe = j
            pulse_end_idx_r[k] = pe

        # Truncate to the episode boundary: stop once the inter-pulse gap
        # exceeds maxIntraEpisodeGap_s (we walked into the next episode), OR
        # once a pulse's own duration/charge is far outside what a genuine
        # C/5 GITT pulse can be (found 2026-08-25, Cell_34, ported from the
        # MATLAB fix in matlab_scripts/PlotCellSummary.m): the refined
        # rising-edge scan above has NO amplitude/charge gate (unlike the
        # coarse pass), so within the maxIntraEpisodeGap_s lookahead window
        # it can pick up one extra unrelated pulse - e.g. the start of the
        # next test phase - as a spurious "one more GITT pulse". A nominal
        # full C/5 pulse carries ~2.42 Ah over ~12.5 min; allow a generous
        # margin so legitimately longer/CV-tapered pulses near the SoC
        # extremes still pass, while the much larger/longer next-phase pulse
        # does not. This MAXIMUM is a FIXED value, decoupled from the
        # per-pulse MINIMUM minPulseCharge_Ah (0.15 Ah, #082 2026-08-26).
        max_single_pulse_charge_ah = 3.63  # ~1.5x the nominal full C/5 pulse charge (2.42 Ah)
        max_single_pulse_dur_s = 30 * 60                         # 30 min
        n_keep = len(pulse_start_idx_r)
        for k in range(len(pulse_start_idx_r)):
            if k > 0:
                gap_s = time_s[pulse_start_idx_r[k]] - time_s[pulse_end_idx_r[k - 1]]
                if not np.isnan(gap_s) and gap_s > p['maxIntraEpisodeGap_s']:
                    n_keep = k
                    break
            s, e = pulse_start_idx_r[k], pulse_end_idx_r[k]
            dur_s = time_s[e] - time_s[s]
            tk, ik = time_s[s:e + 1], current[s:e + 1]
            m = ~np.isnan(tk) & ~np.isnan(ik)
            qk = _trapz(ik[m], tk[m]) / 3600 if np.count_nonzero(m) >= 2 else 0.0
            if (not np.isnan(dur_s) and dur_s > max_single_pulse_dur_s) or abs(qk) > max_single_pulse_charge_ah:
                n_keep = k
                break
        pulse_start_idx_r = pulse_start_idx_r[:n_keep]
        pulse_end_idx_r = pulse_end_idx_r[:n_keep]
        pulse_modes_r = pulse_modes_r[:n_keep]
        pre_pulse_global = pre_pulse_global[:n_keep]

        n_p = len(pulse_start_idx_r)
        if n_p < p['minPulsesPerEpisode'] or n_p > p['maxPulsesPerEpisode']:
            print(f"  [GITT] Refinement rejected cluster ({time_with_gaps[s_first]}, {n_p} pulses "
                  f"out of [{p['minPulsesPerEpisode']},{p['maxPulsesPerEpisode']}]).")
            continue

        # Per-pulse signed Ah (trapezoidal over [pulseStart, pulseEnd]).
        q_per_pulse_ah = np.zeros(n_p)
        for k in range(n_p):
            s, e = pulse_start_idx_r[k], pulse_end_idx_r[k]
            tk, ik = time_s[s:e + 1], current[s:e + 1]
            m = ~np.isnan(tk) & ~np.isnan(ik)
            if np.count_nonzero(m) >= 2:
                q_per_pulse_ah[k] = _trapz(ik[m], tk[m]) / 3600

        # OCV anchors.
        ocv_idx = np.zeros(n_p + 1, dtype=int)
        ocv_modes = [None] * (n_p + 1)
        ocv_idx[0] = pre_pulse_global[0]
        ocv_modes[0] = pulse_modes_r[0]
        for k in range(0, n_p - 1):
            ocv_idx[k + 1] = pre_pulse_global[k + 1]
            ocv_modes[k + 1] = pulse_modes_r[k]
        last_e = pulse_end_idx_r[-1]
        ocv_idx[n_p] = last_e  # fallback
        ocv_modes[n_p] = pulse_modes_r[-1]
        rem = np.arange(last_e + 1, n)
        if len(rem) >= 2:
            i_r = current[rem]
            t_r = time_s[rem]
            di_dt_r = np.diff(i_r) / np.diff(t_r)
            rest_mask_r = np.abs(i_r[:-1]) < p['restThr_A']
            is_edge_r = (np.abs(di_dt_r) > p['gradThr_Apers']) & rest_mask_r
            is_edge_r = np.nan_to_num(is_edge_r, nan=0.0).astype(bool)
            first_edge_r = np.where(is_edge_r)[0]
            if len(first_edge_r):
                ocv_idx[n_p] = rem[first_edge_r[0]]

        ocv_v = voltage[ocv_idx]
        ep = {
            'timeStart': time_with_gaps[pulse_start_idx_r[0]],
            'timeEnd': time_with_gaps[pulse_end_idx_r[-1]],
            'pulseStartTimes': time_with_gaps[pulse_start_idx_r],
            'pulseEndTimes': time_with_gaps[pulse_end_idx_r],
            'pulseStartIdx': pulse_start_idx_r,
            'pulseEndIdx': pulse_end_idx_r,
            'pulseModes': pulse_modes_r,
            'cumQ_signed_Ah': np.concatenate(([0.0], np.cumsum(q_per_pulse_ah))),
            'OCV_V': ocv_v,
            'ocvIdx': ocv_idx,
            'ocvModes': ocv_modes,
            'q_per_pulse_Ah': q_per_pulse_ah,
        }
        gitt_episodes.append(ep)

    return gitt_episodes


__all__ = ['extract_gitt_from_trace']
