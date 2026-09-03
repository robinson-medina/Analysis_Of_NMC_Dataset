"""
PlotLiStrippingMethods_Cell35 - Methods figure for the Li-stripping
detection / metric extraction method, Cell_35 only.

Python counterpart of matlab_scripts/PlotLiStrippingMethods_Cell35.m
(todo #103).

DECISION (documented per the "make decisions overnight" instruction): the
MATLAB source reads a cached raw-segment snapshot produced by
misc/EvaluateStrippingFit.m (misc/.cache_stripping/Cell_35_rawSegs.mat),
which is a MATLAB v7.3 (HDF5) .mat file with a nested cell-array-of-structs
layout. Rather than reverse-engineer that HDF5 layout, this port takes the
todo's documented alternative: it regenerates the same set of post-fast-
charge C/5 discharge segments directly from Cell_35's cyclic-ageing CSV
using the shared extract_dvdt_segments_all helper (Functions/
extractDVdtSegmentsAll.py), which implements the identical detection/
interpolation math as the MATLAB cache generator. The alpha grid-search
fit and example-segment selection logic are ported line-for-line from the
MATLAB script.

One single-column two-panel publication figure (stacked (a)/(b)) comparing
a low-alpha ("stripping") segment against an alpha~1 ("no stripping")
segment: (a) V vs t with the analysis window shaded, (b) dV/dt vs t with
power-law fits overlaid.

Output: LiStrippingMethods.{png,pdf} in JournalScripts/pngs/ (R-022).

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24

Compliance: R-001, R-004, R-013, R-016, R-017, R-018, R-019, R-021, R-022, R-024.
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

_SCRIPT_DIR = Path(__file__).resolve().parent
_FUNCTIONS_CANDIDATES = (_SCRIPT_DIR.parent.parent / 'Functions', _SCRIPT_DIR.parent / 'Functions')
for _FUNCTIONS_DIR in _FUNCTIONS_CANDIDATES:
    if (_FUNCTIONS_DIR / "get_figure_output_dir.py").exists():
        if str(_FUNCTIONS_DIR) not in sys.path:
            sys.path.append(str(_FUNCTIONS_DIR))
        break
else:
    raise FileNotFoundError(f"Shared Functions folder not found from {_SCRIPT_DIR}")

from loadAndPreprocessAgeingCsv import load_and_preprocess_ageing_csv  # noqa: E402
from extractDVdtSegmentsAll import extract_dvdt_segments_all  # noqa: E402
from get_figure_output_dir import get_figure_output_dir  # noqa: E402

# Publication palette / fonts (R-017, R-019).
_COL_BLUE = (0.10, 0.30, 0.70)   # "no stripping" / alpha ~ 1
_COL_RED = (0.78, 0.20, 0.15)    # "stripping" / alpha << 1
_COL_GREY = (0.45, 0.45, 0.45)
_COL_BAND = (0.92, 0.92, 0.92)

PUB_FONTSIZE = 8
FIG_W_CM, FIG_H_CM = 9.29, 7.40


def _fit_power_law(t, y, alpha_grid):
    """Grid search over alpha for y = a + b * t^(-alpha); return (alpha, [a, b])."""

    best_rss = np.inf
    best_alpha, best_coef = np.nan, (np.nan, np.nan)
    for a in alpha_grid:
        design = np.column_stack([np.ones_like(t), t ** (-a)])
        coef, *_ = np.linalg.lstsq(design, y, rcond=None)
        residual = y - design @ coef
        rss = np.sum(residual ** 2)
        if rss < best_rss:
            best_rss = rss
            best_alpha = a
            best_coef = coef
    return best_alpha, best_coef


def _prep_segment(seg, coef, alpha, smooth_win, fit_win_s):
    """Return (t, V, dVdt, tFit, yFit) for one segment, matching MATLAB local_prepSegment."""

    t = seg['timeS_interp']
    v = seg['voltage_interp']
    dvdt = pd.Series(np.gradient(v) / np.gradient(t)).rolling(
        window=smooth_win, center=True, min_periods=1).mean().values
    t_fit = np.linspace(fit_win_s[0], fit_win_s[1], 400)
    y_fit = coef[0] + coef[1] * t_fit ** (-alpha)
    return t, v, dvdt, t_fit, y_fit


def main():
    """Generate LiStrippingMethods.pdf for Cell_35."""

    data_root = r'\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot'
    desired_folder = os.path.join(data_root, '4_Ageing', 'Cyclic_ageing_data')
    cell_num = 'Cell_35'

    smooth_win = 11              # movmean window (matches EvaluateStrippingFit.m)
    fit_win_s = (30, 400)        # analysis window [s]
    alpha_grid = np.arange(0.10, 2.00 + 1e-9, 0.02)
    fast_charge_i_a = -11.6

    pngs_dir = str(get_figure_output_dir('PlotLiStrippingMethods_Cell35'))

    print(f'Loading and preprocessing {cell_num}...')
    load_name = os.path.join(desired_folder, cell_num, f'{cell_num}.csv')
    (time_with_gaps, time_s, voltage, current, _cell_temp, _chamber_temp,
     _cum) = load_and_preprocess_ageing_csv(load_name)

    time_index = pd.DatetimeIndex(time_with_gaps)
    start_time, end_time = time_index[0], time_index[-20]
    sel_mask = (time_index >= start_time) & (time_index <= end_time)
    selected_time = time_index[sel_mask]
    selected_voltage = voltage[sel_mask]
    selected_current = current[sel_mask]
    selected_time_s = time_s[sel_mask]

    params = {'tolerance_A': 0.1, 'minSegmentLength': 900, 'maxSegmentLength': 1500,
              'smoothWin': smooth_win}
    raw_segs = extract_dvdt_segments_all(selected_time, selected_voltage, selected_current,
                                          selected_time_s, fast_charge_i_a, params)
    n_seg = len(raw_segs)
    print(f'Detected {n_seg} post-fast-charge C/5 discharge segments.')
    if n_seg == 0:
        raise RuntimeError(f'No segments detected for {cell_num}; nothing to plot.')

    # --- Fit alpha for every segment ---------------------------------------
    alphas = np.full(n_seg, np.nan)
    coefs = np.full((n_seg, 2), np.nan)
    print('Fitting alpha for every segment ... ', end='')
    for k, seg in enumerate(raw_segs):
        t = seg['timeS_interp']
        v = seg['voltage_interp']
        if len(t) < 2:
            continue
        dvdt = pd.Series(np.gradient(v) / np.gradient(t)).rolling(
            window=smooth_win, center=True, min_periods=1).mean().values
        m = (t >= fit_win_s[0]) & (t <= fit_win_s[1]) & ~np.isnan(dvdt)
        if np.count_nonzero(m) < 10:
            continue
        alpha, coef = _fit_power_law(t[m], dvdt[m], alpha_grid)
        alphas[k] = alpha
        coefs[k, :] = coef
    print('done.')

    # --- Pick example segments: low-alpha (early life) + alpha~1 (mid life) -
    early_mask = np.zeros(n_seg, dtype=bool)
    early_mask[:round(n_seg / 4)] = True
    mid_mask = np.zeros(n_seg, dtype=bool)
    mid_mask[round(n_seg / 4):round(3 * n_seg / 4)] = True

    a_early = alphas.copy()
    a_early[~early_mask] = np.nan
    idx_low = int(np.nanargmin(a_early))

    a_mid = np.abs(alphas - 1)
    a_mid[~mid_mask] = np.nan
    idx_unity = int(np.nanargmin(a_mid))

    print(f"Low-alpha example:   segment {idx_low}, alpha = {alphas[idx_low]:.2f}, "
          f"start = {pd.Timestamp(raw_segs[idx_low]['start_time'])}")
    print(f"Alpha-~1 example:    segment {idx_unity}, alpha = {alphas[idx_unity]:.2f}, "
          f"start = {pd.Timestamp(raw_segs[idx_unity]['start_time'])}")

    t_l, v_l, d_l, t_fit_l, y_fit_l = _prep_segment(raw_segs[idx_low], coefs[idx_low], alphas[idx_low],
                                                      smooth_win, fit_win_s)
    t_u, v_u, d_u, t_fit_u, y_fit_u = _prep_segment(raw_segs[idx_unity], coefs[idx_unity], alphas[idx_unity],
                                                      smooth_win, fit_win_s)

    # --- One two-panel figure: (a) V vs t, (b) dV/dt vs t (R-024) -----------
    fig, (ax_a, ax_b) = plt.subplots(2, 1, figsize=(FIG_W_CM / 2.54, FIG_H_CM / 2.54))

    # Panel (a): voltage.
    all_v = np.concatenate([v_l, v_u])
    yl_a = [np.min(all_v), np.max(all_v)]
    yl_a = [yl_a[0] - 0.05 * (yl_a[1] - yl_a[0]), yl_a[1] + 0.05 * (yl_a[1] - yl_a[0])]
    ax_a.axvspan(fit_win_s[0], fit_win_s[1], color=_COL_BAND, zorder=0)
    (h_u,) = ax_a.plot(t_u, v_u, color=_COL_BLUE, linewidth=1.0)
    (h_l,) = ax_a.plot(t_l, v_l, color=_COL_RED, linewidth=1.0)
    ax_a.set_xlim(0, max(np.max(t_l), np.max(t_u)))
    ax_a.set_ylim(yl_a)
    ax_a.set_ylabel('Voltage [V]', fontsize=PUB_FONTSIZE)
    ax_a.grid(True)
    ax_a.legend([h_u, h_l],
                [f'mid-life, \u03b1 = {alphas[idx_unity]:.2f} (no stripping)',
                 f'early life, \u03b1 = {alphas[idx_low]:.2f} (stripping)'],
                loc='upper right', frameon=False, fontsize=PUB_FONTSIZE)
    ax_a.text(np.mean(fit_win_s), yl_a[0] + 0.04 * (yl_a[1] - yl_a[0]), 'analysis window',
              ha='center', fontsize=PUB_FONTSIZE - 2, fontstyle='italic', color=_COL_GREY)
    ax_a.text(0.02, 0.94, '(a)', transform=ax_a.transAxes, fontsize=PUB_FONTSIZE, va='top')

    # Panel (b): dV/dt with power-law fits.
    m_l = (t_l >= fit_win_s[0]) & (t_l <= fit_win_s[1])
    m_u = (t_u >= fit_win_s[0]) & (t_u <= fit_win_s[1])
    all_d = np.concatenate([d_l[m_l], d_u[m_u]]) * 1e3
    yl_b = [np.min(all_d), np.max(all_d)]
    yl_b = [yl_b[0] - 0.20 * (yl_b[1] - yl_b[0]), yl_b[1] + 0.20 * (yl_b[1] - yl_b[0])]
    ax_b.axvspan(fit_win_s[0], fit_win_s[1], color=_COL_BAND, zorder=0)
    (h_u_dat,) = ax_b.plot(t_u, d_u * 1e3, '-', color=_COL_BLUE, linewidth=1.0)
    (h_l_dat,) = ax_b.plot(t_l, d_l * 1e3, '-', color=_COL_RED, linewidth=1.0)
    (h_u_fit,) = ax_b.plot(t_fit_u, y_fit_u * 1e3, '--', color=tuple(c * 0.6 for c in _COL_BLUE), linewidth=0.8)
    (h_l_fit,) = ax_b.plot(t_fit_l, y_fit_l * 1e3, '--', color=tuple(c * 0.6 for c in _COL_RED), linewidth=0.8)
    ax_b.set_xlim(0, max(np.max(t_l), np.max(t_u)))
    ax_b.set_ylim(yl_b)
    ax_b.set_xlabel('Time since current step [s]', fontsize=PUB_FONTSIZE)
    ax_b.set_ylabel('dV/dt [mV/s]', fontsize=PUB_FONTSIZE)
    ax_b.grid(True)
    ax_b.legend([h_u_dat, h_u_fit, h_l_dat, h_l_fit],
                ['mid-life data', f'fit, \u03b1 = {alphas[idx_unity]:.2f}',
                 'early-life data', f'fit, \u03b1 = {alphas[idx_low]:.2f}'],
                loc='best', frameon=False, fontsize=PUB_FONTSIZE, ncol=2)
    ax_b.text(np.mean(fit_win_s), yl_b[0] + 0.04 * (yl_b[1] - yl_b[0]), 'analysis window',
              ha='center', fontsize=PUB_FONTSIZE - 2, fontstyle='italic', color=_COL_GREY)
    ax_b.text(0.02, 0.94, '(b)', transform=ax_b.transAxes, fontsize=PUB_FONTSIZE, va='top')

    for ax in (ax_a, ax_b):
        ax.tick_params(labelsize=PUB_FONTSIZE)
        for label in ax.get_xticklabels() + ax.get_yticklabels():
            label.set_fontname('Times New Roman')
        for spine in ax.spines.values():
            spine.set_visible(True)
            spine.set_linewidth(0.8)  # R-017 item 4: axes frame

    png_file = os.path.join(pngs_dir, 'LiStrippingMethods.png')
    pdf_file = os.path.join(pngs_dir, 'LiStrippingMethods.pdf')
    fig.savefig(png_file, dpi=300)
    fig.savefig(pdf_file)
    print(f'\nMethods figure saved:\n  {png_file}\n  {pdf_file}')


if __name__ == '__main__':
    main()
