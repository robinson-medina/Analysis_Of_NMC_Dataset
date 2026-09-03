"""
PlotCharacterizationResults - Build the two manuscript figures for a single
CHARACTERIZATION cell (default Cell_4) from the raw ZenodoRoot
characterization data: (1) a two-panel BoL GITT figure (OCV curve +
temperature-dependency dV(T) vs SoC) and (2) an EIS Nyquist panel figure
(one panel per SoC, temperature as line colour).

Python counterpart of matlab_scripts/PlotCharacterizationResults.m (todo #102).

Reads (read-only, R-001):
    3_Characterization/<cell>/<cell>_2-GITT.csv
    3_Characterization/<cell>/EIS/Test_<T>C_impedanceData.csv

Produces (R-018/R-022): vector PDF + PNG in JournalScripts/pngs/
    <cell>_CharacterizationOCV.pdf/.png
    <cell>_CharacterizationEIS.pdf/.png

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24

Compliance: R-001, R-004, R-013, R-016, R-017, R-018, R-019, R-020, R-021, R-022.
"""

import os
import sys
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

matplotlib.rcParams['font.family'] = 'serif'
matplotlib.rcParams['font.serif'] = ['Times New Roman']
matplotlib.rcParams['mathtext.fontset'] = 'stix'

_SCRIPT_DIR = Path(__file__).resolve().parent
_FUNCTIONS_CANDIDATES = (_SCRIPT_DIR.parent.parent / 'Functions', _SCRIPT_DIR.parent / 'Functions')
for _FUNCTIONS_DIR in _FUNCTIONS_CANDIDATES:
    if (_FUNCTIONS_DIR / "get_figure_output_dir.py").exists():
        if str(_FUNCTIONS_DIR) not in sys.path:
            sys.path.append(str(_FUNCTIONS_DIR))
        break
else:
    raise FileNotFoundError(f"Shared Functions folder not found from {_SCRIPT_DIR}")

from get_figure_output_dir import get_figure_output_dir  # noqa: E402

# R-017 preferred colour palette.
_GREEN = (12 / 255, 195 / 255, 82 / 255)
_DARKBLUE = (1 / 255, 17 / 255, 181 / 255)
_RED = (1.0, 0.0, 0.0)
_MAGENTA = (1.0, 0.0, 1.0)
_BLACK = (0.0, 0.0, 0.0)

PUB_FONTSIZE = 8
LW_DATA = 1.0
LW_AXES = 0.8


def _find_runs(mask):
    """Return (starts, ends) 0-based inclusive index arrays of contiguous True runs."""

    padded = np.concatenate(([0], mask.astype(int), [0]))
    dd = np.diff(padded)
    starts = np.where(dd == 1)[0]
    ends = np.where(dd == -1)[0] - 1
    return starts, ends


def _style_axes(ax):
    ax.tick_params(labelsize=PUB_FONTSIZE)
    for label in ax.get_xticklabels() + ax.get_yticklabels():
        label.set_fontname('Times New Roman')
    for spine in ax.spines.values():
        spine.set_visible(True)
        spine.set_linewidth(LW_AXES)
    ax.grid(True)


def main(cell_num='Cell_4'):
    """Generate <cell>_CharacterizationOCV.pdf and <cell>_CharacterizationEIS.pdf."""

    data_root = r'\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot'
    char_folder = os.path.join(data_root, '3_Characterization', cell_num)
    gitt_file = os.path.join(char_folder, f'{cell_num}_2-GITT.csv')
    eis_folder = os.path.join(char_folder, 'EIS')

    # EIS conditions to show: one panel per SoC, temperature as line colour.
    temps_to_show_c = [0, 5, 25, 45]
    eis_soc_list = [10, 50, 90]
    eis_min_freq_hz, eis_max_freq_hz = 0.05, 10000

    # OCV extraction settings (reference OCVextraction.m method).
    pulse_thr_a = 0.3

    # Temperature-dependency sweep settings.
    sweep_temps_c = [45, 25, 0, -15]
    ref_temp_c = 25
    temp_tol_c = 1
    sweep_away_c = 2
    sweep_merge_gap = 3000
    sweep_min_dwell = 1500

    temp_color_map = {45: _RED, 25: _BLACK, 0: _DARKBLUE, -15: _MAGENTA}
    temp_colors = [_DARKBLUE, _GREEN, _BLACK, _RED]  # maps to temps_to_show_c order

    ocv_w_cm, ocv_h_cm = 9.37, 9.6
    eis_w_cm, eis_h_cm = 9.25, 5.2

    pngs_dir = str(get_figure_output_dir('PlotCharacterizationResults'))

    print(f'=== PlotCharacterizationResults: {cell_num} ===')

    # --- Step 1: load the GITT trace and reconstruct the time vector -------
    df = pd.read_csv(gitt_file, dtype={0: str}, header=0)
    print(f'Loading {cell_num}_2-GITT.csv ... done ({len(df)} rows)')

    time_str = df.iloc[:, 0].values
    time_yy_mm_dd = pd.Series([pd.NaT] * len(time_str), dtype='datetime64[ns]')
    time_yy_mm_dd.iloc[0] = pd.to_datetime(time_str[0], format='%d-%b-%Y %H:%M:%S.%f')
    if len(time_str) > 1:
        increase_s = np.cumsum(pd.to_numeric(time_str[1:], errors='coerce'))
        time_yy_mm_dd.iloc[1:] = time_yy_mm_dd.iloc[0] + pd.to_timedelta(increase_s, unit='s')

    voltage_v = df.iloc[:, 1].values.astype(float)
    current_a = df.iloc[:, 2].values.astype(float)
    chamber_temp_c = df.iloc[:, 4].values.astype(float)
    t_s = (time_yy_mm_dd - time_yy_mm_dd.iloc[0]).dt.total_seconds().values

    v, i_arr, t_cham = voltage_v, current_a, chamber_temp_c

    # --- Step 2: detect the OCV rest points ---------------------------------
    pulse_mask = np.abs(i_arr) > pulse_thr_a
    onset_idx = np.where(np.diff(pulse_mask.astype(int)) > 0)[0]  # last rest sample before each pulse

    first_dis_candidates = np.where(i_arr < -pulse_thr_a)[0]
    first_dis = first_dis_candidates[0]
    k_start_candidates = np.where(onset_idx < first_dis)[0]
    k_start = k_start_candidates[-1]
    rest_idx = onset_idx[k_start:]
    print(f'Detected {len(rest_idx)} OCV rest points (after skipping formation).')

    # --- Step 3: coulomb-counted SoC/capacity axis, discharge/charge split -
    cum_q_as = np.concatenate(([0.0], np.cumsum(0.5 * (i_arr[1:] + i_arr[:-1]) * np.diff(t_s))))
    cum_q_as = cum_q_as - cum_q_as[rest_idx[0]]
    gitt_win = slice(rest_idx[0], rest_idx[-1] + 1)
    c0_as = abs(np.min(cum_q_as[gitt_win]))
    c0_ah = c0_as / 3600
    soc_pct = 100 * (cum_q_as / c0_as + 1)

    soc_rest = soc_pct[rest_idx]
    v_rest = v[rest_idx]
    k_bnd = int(np.argmin(soc_rest))

    soc_dis, ocv_dis = soc_rest[:k_bnd + 1], v_rest[:k_bnd + 1]
    soc_chg, ocv_chg = soc_rest[k_bnd:], v_rest[k_bnd:]
    print(f'Discharge OCV: {ocv_dis[0]:.3f} -> {ocv_dis[-1]:.3f} V (SoC {soc_dis[0]:.0f} -> {soc_dis[-1]:.0f} %)')
    print(f'Charge    OCV: {ocv_chg[0]:.3f} -> {ocv_chg[-1]:.3f} V (SoC {soc_chg[0]:.0f} -> {soc_chg[-1]:.0f} %)')

    # --- Step 4: temperature dependency dV(T) vs SoC (discharge sweeps) -----
    target_temps = [t for t in sweep_temps_c if t != ref_temp_c]
    i_dis_end = rest_idx[k_bnd]

    away_mask = np.abs(t_cham - ref_temp_c) > sweep_away_c
    seg_s, seg_e = _find_runs(away_mask)
    s_merged, e_merged = [], []
    k = 0
    while k < len(seg_s):
        s, e = seg_s[k], seg_e[k]
        while k + 1 < len(seg_s) and seg_s[k + 1] - e < sweep_merge_gap:
            k += 1
            e = max(e, seg_e[k])
        s_merged.append(s)
        e_merged.append(e)
        k += 1

    sweeps = []
    for s, e in zip(s_merged, e_merged):
        if s >= i_dis_end:
            continue  # discharge branch only
        window_mask = (np.abs(t_cham[:s] - ref_temp_c) <= temp_tol_c) & (np.abs(i_arr[:s]) < pulse_thr_a)
        candidates = np.where(window_mask)[0]
        if len(candidates) == 0:
            continue
        r_idx = candidates[-1]
        entry = {'soc': soc_pct[r_idx], 'ref_idx': r_idx, 'T': [], 'ptIdx': [], 'V': [], 'dV': []}
        for t0 in target_temps:
            sub_mask = (np.abs(t_cham[s:e + 1] - t0) <= temp_tol_c) & (np.abs(i_arr[s:e + 1]) < pulse_thr_a)
            r_s, r_e = _find_runs(sub_mask)
            if len(r_s) == 0:
                continue
            run_lens = r_e - r_s + 1
            im = int(np.argmax(run_lens))
            if run_lens[im] < sweep_min_dwell:
                continue
            p_idx = s + r_e[im]
            entry['T'].append(t0)
            entry['ptIdx'].append(p_idx)
            entry['V'].append(v[p_idx])
            entry['dV'].append(1000 * (v[p_idx] - v[r_idx]))
        if entry['T']:
            sweeps.append(entry)
    print(f"Discharge temperature sweeps: {len(sweeps)} "
          f"(set-points {'/'.join(str(t) for t in target_temps)} degC)")

    # --- Step 5: Figure 1 - OCV curve (a) and temperature dependency (b) ----
    fig_ocv = plt.figure(figsize=(ocv_w_cm / 2.54, ocv_h_cm / 2.54))
    ocv_panel_h_cm = 3.5190
    ocv_left_m, ocv_right_m, ocv_bot_m, ocv_gap = 1.35, 0.30, 1.20, 1.05
    ocv_plot_w_cm = ocv_w_cm - ocv_left_m - ocv_right_m

    ax_a = fig_ocv.add_axes([
        ocv_left_m / ocv_w_cm, (ocv_bot_m + ocv_panel_h_cm + ocv_gap) / ocv_h_cm,
        ocv_plot_w_cm / ocv_w_cm, ocv_panel_h_cm / ocv_h_cm,
    ])
    h_dis, = ax_a.plot(soc_dis, ocv_dis, '-o', color=_DARKBLUE, markerfacecolor=_DARKBLUE,
                        markersize=3, linewidth=LW_DATA)
    h_chg, = ax_a.plot(soc_chg, ocv_chg, '-o', color=_RED, markerfacecolor=_RED,
                        markersize=3, linewidth=LW_DATA)
    ax_a.set_ylabel('OCV [V]')
    ax_a.set_xlim(0, 100)
    _style_axes(ax_a)
    ax_a.legend([h_dis, h_chg], ['Discharge', 'Charge'], loc='upper left', frameon=False,
                fontsize=PUB_FONTSIZE)
    ax_a.text(0.02, 0.93, '(a)', transform=ax_a.transAxes, fontsize=PUB_FONTSIZE,
              fontweight='bold', fontname='Times New Roman')

    ax_b = fig_ocv.add_axes([ocv_left_m / ocv_w_cm, ocv_bot_m / ocv_h_cm,
                              ocv_plot_w_cm / ocv_w_cm, ocv_panel_h_cm / ocv_h_cm])
    ax_b.axhline(0, linestyle=':', color=(0.5, 0.5, 0.5), linewidth=0.75)
    h_t, lbl_t = [], []
    for t0 in target_temps:
        soc_vals, dv_vals = [], []
        for entry in sweeps:
            if t0 in entry['T']:
                j = entry['T'].index(t0)
                soc_vals.append(entry['soc'])
                dv_vals.append(entry['dV'][j])
        order = np.argsort(soc_vals)
        soc_sorted = np.array(soc_vals)[order]
        dv_sorted = np.array(dv_vals)[order]
        (h,) = ax_b.plot(soc_sorted, dv_sorted, '-o', color=temp_color_map[t0],
                          markerfacecolor=temp_color_map[t0], markersize=3, linewidth=LW_DATA)
        h_t.append(h)
        lbl_t.append(f'{t0} \u00b0C')
    ax_b.set_xlabel('State of charge [%]')
    ax_b.set_ylabel('\u0394V vs 25 \u00b0C [mV]')
    ax_b.set_xlim(0, 100)
    _style_axes(ax_b)
    ax_b.legend(h_t, lbl_t, loc='upper right', frameon=False, ncol=len(h_t), fontsize=PUB_FONTSIZE)
    ax_b.text(0.02, 0.93, '(b)', transform=ax_b.transAxes, fontsize=PUB_FONTSIZE,
              fontweight='bold', fontname='Times New Roman')

    ocv_pdf = os.path.join(pngs_dir, f'{cell_num}_CharacterizationOCV.pdf')
    ocv_png = os.path.join(pngs_dir, f'{cell_num}_CharacterizationOCV.png')
    fig_ocv.savefig(ocv_png, dpi=300)
    fig_ocv.savefig(ocv_pdf)
    print(f'Wrote {ocv_pdf}')

    # --- Step 6: Figure 2 - EIS Nyquist panels (one SoC per panel) ----------
    n_s, n_t = len(eis_soc_list), len(temps_to_show_c)
    re_c = [[None] * n_t for _ in range(n_s)]
    im_c = [[None] * n_t for _ in range(n_s)]
    all_re, all_im = [], []
    for ti, temp_c in enumerate(temps_to_show_c):
        eis_file = os.path.join(eis_folder, f'Test_{temp_c}C_impedanceData.csv')
        e_df = pd.read_csv(eis_file)
        for pi, soc in enumerate(eis_soc_list):
            r_re = e_df[f'R_real_ohm_SoC{soc}'].values * 1000
            r_im = -e_df[f'R_img_ohm_SoC{soc}'].values * 1000
            frq = e_df[f'Freq_Hz_SoC{soc}'].values
            keep = (~np.isnan(r_re)) & (~np.isnan(r_im)) & (~np.isnan(frq)) & \
                   (frq >= eis_min_freq_hz) & (frq <= eis_max_freq_hz)
            re_c[pi][ti] = r_re[keep]
            im_c[pi][ti] = r_im[keep]
            all_re.append(r_re[keep])
            all_im.append(r_im[keep])

    all_re_cat = np.concatenate(all_re)
    all_im_cat = np.concatenate(all_im)
    x_lo, x_hi = np.min(all_re_cat), np.max(all_re_cat)
    y_lo, y_hi = np.min(all_im_cat), np.max(all_im_cat)
    x_pad = 0.04 * (x_hi - x_lo)
    y_pad = 0.06 * (y_hi - y_lo)
    common_x = (x_lo - x_pad, x_hi + x_pad)
    common_y = (y_lo - y_pad, y_hi + y_pad)

    fig_eis, axes_eis = plt.subplots(1, n_s, figsize=(eis_w_cm / 2.54, eis_h_cm / 2.54))
    fig_eis.subplots_adjust(bottom=0.36, top=0.88, wspace=0.08)
    temp_handles = [None] * n_t
    mid_panel = (n_s - 1) // 2  # 0-based middle panel index
    for pi, ax in enumerate(axes_eis):
        for ti in range(n_t):
            (h,) = ax.plot(re_c[pi][ti], im_c[pi][ti], '-', color=temp_colors[ti], linewidth=LW_DATA)
            if pi == 0:
                temp_handles[ti] = h
        ax.set_title(f'SoC {eis_soc_list[pi]}%', fontweight='normal', fontsize=PUB_FONTSIZE)
        ax.set_xlim(common_x)
        ax.set_ylim(common_y)
        _style_axes(ax)
        if pi == mid_panel:
            x_r = common_x[1] - common_x[0]
            y_r = common_y[1] - common_y[0]
            ax.text(common_x[0] + 0.62 * x_r, common_y[0] + 0.69 * y_r, '0.05 Hz',
                    fontsize=PUB_FONTSIZE - 1, color=_BLACK, ha='left', va='center')
            ax.text(common_x[0] + 0.33 * x_r, common_y[0] + 0.12 * y_r, '10 kHz',
                    fontsize=PUB_FONTSIZE - 1, color=_BLACK, ha='left', va='center')
        if pi == 0:
            ax.set_ylabel('-Z$_{im}$ [m\u03a9]')
        else:
            ax.set_yticklabels([])

    fig_eis.text(0.5, 0.19, 'Z$_{re}$ [m\u03a9]', ha='center', fontsize=PUB_FONTSIZE,
                 fontname='Times New Roman', color=_BLACK)
    fig_eis.legend(temp_handles, [f'{t} \u00b0C' for t in temps_to_show_c], loc='lower center',
                   ncol=n_t, frameon=False, fontsize=PUB_FONTSIZE, bbox_to_anchor=(0.5, 0.01))

    eis_pdf = os.path.join(pngs_dir, f'{cell_num}_CharacterizationEIS.pdf')
    eis_png = os.path.join(pngs_dir, f'{cell_num}_CharacterizationEIS.png')
    fig_eis.savefig(eis_png, dpi=300)
    fig_eis.savefig(eis_pdf)
    print(f'Wrote {eis_pdf}')

    # --- Step 7: summary -----------------------------------------------------
    print('\n--- Summary ---')
    print(f'Cell            : {cell_num}')
    print(f'GITT OCV points : {len(soc_dis)} discharge, {len(soc_chg)} charge')
    print(f'Full capacity   : {c0_ah:.2f} Ah (from discharge depth)')
    print(f"Temp sweeps     : {len(sweeps)} discharge sweeps, set-points "
          f"{'/'.join(str(t) for t in target_temps)} degC")
    print(f"EIS panels      : SoC {'/'.join(str(s) for s in eis_soc_list)} %, "
          f"temperatures {'/'.join(str(t) for t in temps_to_show_c)} degC")
    print(f'EIS freq window : {eis_min_freq_hz:.2f} Hz to {eis_max_freq_hz:.0f} Hz')
    print(f'Figures written to {pngs_dir}')


if __name__ == '__main__':
    # Wave 8 override: run one characterization cell per subprocess (parity with RunWave8.m).
    main(cell_num=os.environ.get('WAVE8_CELL', 'Cell_4'))
