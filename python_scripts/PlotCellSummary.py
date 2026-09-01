"""
PlotCellSummary - One-page A4 publication summary of a single cell's ageing
trace (current/voltage/temperature time series, checkup capacity/resistance
trend, Li-stripping-vs-age panel, differential capacity, EIS Nyquist
comparison, and BoL/EoL GITT+OCP overlay), plus a standalone Li-stripping
diagnostic figure.

Python counterpart of matlab_scripts/PlotCellSummary.m (todo #012).

DECISIONS (documented per the "make decisions overnight" instruction):
  * The standalone `debugGITTPlot` diagnostic figure (per-episode raw
    current/voltage + detected pulses) is NOT ported - it is a secondary
    debug-only output, not part of the main A4 summary. Can be added later
    on request.
  * The standalone `EISComparison.pdf` export workflow (copied from
    PlotEISData.m) is NOT re-implemented here; `python_scripts/PlotEISData.py`
    already owns EIS-figure generation. Only the small in-figure EIS tile
    (row 6 right) is produced, matching the MATLAB script's own
    `plotEISComparisonOnAxes` re-use.
  * MATLAB's `parula` colormap (used for the BoL->EoL age gradient) has no
    matplotlib built-in equivalent; `viridis` (truncated to its first 88%,
    mirroring the MATLAB trim) is used instead as the closest perceptually
    uniform substitute.
  * The exact month-boundary-forced datetime tick logic in MATLAB is
    replaced by matplotlib's automatic date locator/formatter (simpler,
    visually equivalent for the same purpose).

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24

Compliance: R-001, R-002, R-004, R-013, R-016, R-017, R-018, R-019, R-020.
"""

import os
import sys
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib import cm

matplotlib.rcParams['font.family'] = 'serif'
matplotlib.rcParams['font.serif'] = ['Times New Roman']

_SCRIPT_DIR = Path(__file__).resolve().parent
_FUNCTIONS_CANDIDATES = (_SCRIPT_DIR.parent.parent / 'Functions', _SCRIPT_DIR.parent / 'Functions')
for _FUNCTIONS_DIR in _FUNCTIONS_CANDIDATES:
    if _FUNCTIONS_DIR.exists():
        if str(_FUNCTIONS_DIR) not in sys.path:
            sys.path.append(str(_FUNCTIONS_DIR))
        break
else:
    raise FileNotFoundError(f"Shared Functions folder not found from {_SCRIPT_DIR}")

from loadAndPreprocessAgeingCsv import load_and_preprocess_ageing_csv  # noqa: E402
from findCheckupSegments import find_checkup_segments  # noqa: E402
from extractResistanceValues import extract_resistance_values  # noqa: E402
from analyzeDVdtAfterCharge import analyze_dvdt_after_charge  # noqa: E402
from extractDVdtSegmentsAll import extract_dvdt_segments_all  # noqa: E402
from computeStrippingMetric import compute_stripping_metric  # noqa: E402
from computeStrippingAlpha import compute_stripping_alpha  # noqa: E402
from strippingSmoothWin import stripping_smooth_win  # noqa: E402
from computeCheckupCurves import compute_checkup_curves  # noqa: E402
from getCellLabel import get_cell_label  # noqa: E402
from extractGITTfromTrace import extract_gitt_from_trace  # noqa: E402
from buildC50Phase import build_c50_phase, find_matching_charge_seg  # noqa: E402
from drawTimeBand import draw_time_band  # noqa: E402
from plotEISComparisonOnAxes import plot_eis_comparison_on_axes  # noqa: E402
from plotGITTAndOCP import plot_gitt_and_ocp  # noqa: E402
from liStrippingFigure import li_stripping_figure  # noqa: E402
from get_figure_output_dir import get_figure_output_dir  # noqa: E402

# Publication palette (R-017).
_COL_DARKBLUE = (1 / 255, 17 / 255, 181 / 255)
_COL_RED = (255 / 255, 0, 0)
_COL_BLACK = (0.0, 0.0, 0.0)
PUB_FONTSIZE = 8


def _find_segments(mask, min_length):
    padded = np.concatenate(([False], mask, [False])).astype(int)
    edges = np.diff(padded)
    starts = np.where(edges == 1)[0]
    ends = np.where(edges == -1)[0] - 1
    return [np.arange(s, e + 1) for s, e in zip(starts, ends) if (e - s + 1) >= min_length]


def _nearest_color(target_time, ref_times, ref_colors, default=(0.5, 0.5, 0.5)):
    if len(ref_times) == 0:
        return default
    k = int(np.argmin(np.abs(ref_times - target_time)))
    return ref_colors[k]


def main(cell_num='Cell_22', desired_folder=None):
    """Generate <cellNum>_Summary.png/.pdf and <cellNum>_LiStripping.png."""

    data_root = r'\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot'
    if desired_folder is None:
        desired_folder = os.path.join(data_root, '4_Ageing', 'Cyclic_ageing_data')
    window_size = 5000
    fast_charge_i_a = -11.6

    eis_root_for_comparison = os.path.join(data_root, '4_Ageing', 'EIS_data')
    eis_target_soc_pct = 50
    eis_max_freq_hz = 12000

    gitt_params = {
        'pulseAmp_A': 11.6, 'pulseTol_A': 0.5, 'maxPulseAmp_A': 20,
        'minPulse_s': 60, 'maxPulse_s': 3600, 'minPulseCharge_Ah': 0.15,  # #082 fix (2026-08-26): lowered 1.21 -> 0.15 to keep CC->CV tapered EoL pulses
        'maxIntraEpisodeGap_s': 24 * 3600, 'restThr_A': 0.5, 'minRestDur_s': 7000,
        'pulseFlatnessTol': 0.05, 'gradThr_Apers': 3, 'edgeJump_A': 2,
        'minPulsesPerEpisode': 20, 'maxPulsesPerEpisode': 55,
        'minBoLEoLSeparation_days': 14,
    }

    pngs_dir = str(get_figure_output_dir('PlotCellSummary'))

    cell_label = get_cell_label(cell_num)
    print('\n' + '=' * 40)
    print(f'Plotting summary for cell {cell_num} ({cell_label})')
    print('=' * 40)

    load_name = os.path.join(desired_folder, cell_num, f'{cell_num}.csv')
    print(f'Loading {cell_num} ...')
    (time_with_gaps, time_s, voltage, current, cell_temp, chamber_temp,
     _cum) = load_and_preprocess_ageing_csv(load_name)

    time_index = pd.DatetimeIndex(time_with_gaps)
    start_time, end_time = time_index[0], time_index[-20]
    sel_mask = (time_index >= start_time) & (time_index <= end_time)
    selected_time = time_index[sel_mask]
    selected_voltage = voltage[sel_mask]
    selected_current = current[sel_mask]
    selected_time_s = time_s[sel_mask]

    # --- Reused analyses -----------------------------------------------------
    checkup_segs = find_checkup_segments(time_with_gaps, voltage, current, time_s, start_time, end_time)

    res_time, res_ohm, res_fec = extract_resistance_values(
        time_with_gaps, voltage, current, time_s, start_time, end_time, cell_num, cell_label)
    plt.close('all')  # discard extract_resistance_values' own diagnostic figure

    plotted_dvdt_segs, _dvdt_data = analyze_dvdt_after_charge(
        selected_time, selected_voltage, selected_current, selected_time_s,
        fast_charge_i_a, cell_num, cell_label)
    plt.close('all')  # discard analyze_dvdt_after_charge's own diagnostic figure

    stripping_params = {
        'tolerance_A': 0.1, 'minSegmentLength': 900, 'maxSegmentLength': 1500,
        'metricWin_s': (30, 400), 'smoothWin': stripping_smooth_win(cell_num),
        'alphaGrid': np.arange(0.10, 2.00 + 1e-9, 0.02),
    }
    stripping_rmse_y_max_mvpers = 0.10

    all_dvdt_segs = extract_dvdt_segments_all(
        selected_time, selected_voltage, selected_current, selected_time_s,
        fast_charge_i_a, stripping_params)
    n_all_dvdt = len(all_dvdt_segs)
    stripping_metric = np.zeros(n_all_dvdt)
    stripping_alpha = np.full(n_all_dvdt, np.nan)
    stripping_rmse = np.full(n_all_dvdt, np.nan)
    stripping_time = np.empty(n_all_dvdt, dtype='datetime64[ns]')
    for i, seg in enumerate(all_dvdt_segs):
        stripping_metric[i] = compute_stripping_metric(seg, stripping_params['metricWin_s'])
        stripping_alpha[i], stripping_rmse[i] = compute_stripping_alpha(
            seg, stripping_params['metricWin_s'], stripping_params['alphaGrid'])
        stripping_time[i] = np.datetime64(seg['start_time'])
    print(f'Extracted {n_all_dvdt} post-charge C/5 discharge segments for Li-stripping analysis.')

    # --- Per-checkup curves (shared helper) ----------------------------------
    print('Computing per-checkup OCP / dQdV curves ... ', end='')
    checkups = compute_checkup_curves(checkup_segs, selected_time, selected_voltage,
                                       selected_current, selected_time_s, window_size)
    n_valid = len(checkups)
    valid_start_time = np.array([np.datetime64(c['start_time']) for c in checkups])
    checkup_capacity_ah = np.array([c['capacity_Ah'] for c in checkups])
    checkup_capacity_timestamp = np.array([np.datetime64(c['time_stamp']) for c in checkups])
    print(f'done. {n_valid} valid checkup discharges found.')

    # --- Colour map: one colour per valid checkup ----------------------------
    # DECISION: viridis (truncated to 88%) substitutes for MATLAB's parula
    # (no matplotlib built-in); see module docstring.
    if n_valid > 0:
        cmap = cm.get_cmap('viridis')
        checkup_colors = [cmap(0.88 * i / max(n_valid - 1, 1)) for i in range(n_valid)]
    else:
        checkup_colors = []

    res_colors = [_nearest_color(np.datetime64(t), valid_start_time, checkup_colors) for t in res_time]
    dvdt_start_times = np.array([np.datetime64(seg['time'][0]) for seg in plotted_dvdt_segs])
    dvdt_colors = [_nearest_color(t, valid_start_time, checkup_colors) for t in dvdt_start_times]

    # --- Detect BoL/EoL GITT episodes ----------------------------------------
    print('Detecting GITT episodes (C/5 pulse train) ... ', end='')
    gitt_episodes = extract_gitt_from_trace(time_with_gaps, voltage, current, time_s, gitt_params)
    print(f'found {len(gitt_episodes)} episode(s).')

    valid_time_mask = ~pd.isna(time_index)
    trace_t0 = time_index[valid_time_mask][0]
    trace_t1 = time_index[valid_time_mask][-1]
    bol_gitt, eol_gitt = None, None
    if len(gitt_episodes) == 1:
        ep = gitt_episodes[0]
        ep_start, ep_end = pd.Timestamp(ep['timeStart']), pd.Timestamp(ep['timeEnd'])
        if (ep_start - trace_t0) <= (trace_t1 - ep_end):
            bol_gitt = ep
        else:
            eol_gitt = ep
    elif len(gitt_episodes) >= 2:
        bol_gitt = gitt_episodes[0]
        sep_days = (pd.Timestamp(gitt_episodes[-1]['timeStart']) - pd.Timestamp(gitt_episodes[0]['timeEnd'])).days
        if sep_days >= gitt_params['minBoLEoLSeparation_days']:
            eol_gitt = gitt_episodes[-1]

    # --- C/50 charge segments (mirror of checkup discharge detection) -------
    charge_current_value_a = 58 / 50
    charge_current_tol_a = 0.1
    min_charge_segment_length = 2000
    chg_mask = np.abs(selected_current - charge_current_value_a) <= charge_current_tol_a
    chg_mask[np.isnan(selected_current)] = False
    charge_segs = _find_segments(chg_mask, min_charge_segment_length)

    # --- BoL/EoL C/50 phase (temporally closest checkup to the GITT episode) -
    def _closest_checkup_idx(gitt_ep, fallback_idx):
        if gitt_ep is None or n_valid == 0:
            return fallback_idx
        return int(np.argmin(np.abs(valid_start_time - np.datetime64(gitt_ep['timeStart']))))

    if n_valid >= 1:
        bol_idx = _closest_checkup_idx(bol_gitt, 0)
        bol_c50 = build_c50_phase(checkups[bol_idx]['segment_indices'], charge_segs,
                                   selected_voltage, selected_current, selected_time_s)
    else:
        bol_c50 = {'dischQ_Ah': np.array([]), 'dischV': np.array([]), 'chargeQ_Ah': np.array([]), 'chargeV': np.array([])}
    if n_valid >= 2:
        eol_idx = _closest_checkup_idx(eol_gitt, n_valid - 1)
        eol_c50 = build_c50_phase(checkups[eol_idx]['segment_indices'], charge_segs,
                                   selected_voltage, selected_current, selected_time_s)
    else:
        eol_c50 = {'dischQ_Ah': np.array([]), 'dischV': np.array([]), 'chargeQ_Ah': np.array([]), 'chargeV': np.array([])}

    # --- BoL/EoL band windows -------------------------------------------------
    if bol_gitt is not None:
        bol_start, bol_end = pd.Timestamp(bol_gitt['timeStart']), pd.Timestamp(bol_gitt['timeEnd'])
    else:
        bol_start = time_index[0]
        bol_end = bol_start + pd.Timedelta(days=7)
    if eol_gitt is not None:
        eol_start, eol_end = pd.Timestamp(eol_gitt['timeStart']), pd.Timestamp(eol_gitt['timeEnd'])
    else:
        eol_start = eol_end = None

    eis_col_bol = checkup_colors[0] if n_valid > 0 else _COL_DARKBLUE
    eis_col_eol = checkup_colors[-1] if n_valid > 0 else _COL_RED
    eis_stage_colors = [eis_col_bol, (0 / 255, 140 / 255, 70 / 255), eis_col_eol]
    eis_stage_markers = ['o', 's', 'd']

    # --- Standalone Li-stripping diagnostic figure (Feature B) --------------
    li_stripping_figure(time_with_gaps, voltage, all_dvdt_segs, stripping_metric, stripping_params,
                         cell_num, cell_label, pngs_dir)

    # ==========================================================================
    # Main A4 summary figure
    # ==========================================================================
    fig = plt.figure(figsize=(18.05 / 2.54, 22.00 / 2.54))
    gs = fig.add_gridspec(7, 6, hspace=0.55, wspace=0.9)

    ax_i = fig.add_subplot(gs[0, :])
    ax_i.plot(time_index, current, color=_COL_DARKBLUE, linewidth=1.0)
    ax_i.set_ylabel('Current [A]')
    ax_i.grid(True)

    ax_v = fig.add_subplot(gs[1, :])
    ax_v.plot(time_index, voltage, color=_COL_DARKBLUE, linewidth=1.0)
    ax_v.set_ylabel('Voltage [V]')
    ax_v.set_ylim(2.5, 4.5)
    ax_v.grid(True)

    ax_t = fig.add_subplot(gs[2, :])
    (h_cell,) = ax_t.plot(time_index, cell_temp, color=_COL_DARKBLUE, linewidth=1.0)
    (h_chamber,) = ax_t.plot(time_index, chamber_temp, color=_COL_RED, linewidth=1.0)
    ax_t.set_ylabel('Temperature [\u00b0C]')
    ax_t.legend([h_cell, h_chamber], ['Cell', 'Chamber'], loc='upper right', frameon=False,
                fontsize=PUB_FONTSIZE)
    ax_t.grid(True)

    for i in range(n_valid):
        draw_time_band([ax_i, ax_v, ax_t], pd.Timestamp(checkups[i]['start_time']),
                        pd.Timestamp(checkups[i]['end_time']), checkup_colors[i], 0.25)
    draw_time_band([ax_i, ax_v, ax_t], bol_start, bol_end, _COL_DARKBLUE, 0.12)
    if eol_start is not None:
        draw_time_band([ax_i, ax_v, ax_t], eol_start, eol_end, _COL_RED, 0.12)

    # --- Row 4: Capacity (left) + Resistance (right) twin-axis trend --------
    ax_cap_res = fig.add_subplot(gs[3, :])
    if n_valid > 0:
        ax_cap_res.plot(checkup_capacity_timestamp, checkup_capacity_ah, '-', color=(0.5, 0.5, 0.5), linewidth=1.0)
        for i in range(n_valid):
            ax_cap_res.plot(checkup_capacity_timestamp[i], checkup_capacity_ah[i], 'o',
                             markeredgecolor=_COL_DARKBLUE, markerfacecolor=checkup_colors[i], markersize=5)
    ax_cap_res.set_ylabel('C$_{RPT}$ [Ah]', color=_COL_DARKBLUE)
    ax_cap_res.tick_params(axis='y', labelcolor=_COL_DARKBLUE)
    ax_res = ax_cap_res.twinx()
    if len(res_time) > 0:
        ax_res.plot(res_time, np.asarray(res_ohm) * 1000, '-', color=(0.5, 0.5, 0.5), linewidth=1.0)
        for i in range(len(res_time)):
            ax_res.plot(res_time[i], res_ohm[i] * 1000, 's',
                        markeredgecolor=_COL_RED, markerfacecolor=res_colors[i], markersize=5)
    ax_res.set_ylabel('R$_{RPT}$ [m\u03a9]', color=_COL_RED)
    ax_res.tick_params(axis='y', labelcolor=_COL_RED)
    ax_cap_res.set_xlabel('Date')
    ax_cap_res.set_title('Capacity and resistance vs age', fontweight='normal')
    ax_cap_res.grid(True)

    common_xlim = (time_index[0], time_index[-1])
    for ax in (ax_i, ax_v, ax_t, ax_cap_res):
        ax.set_xlim(common_xlim)

    # --- Row 5: Li-stripping vs age (power-law fit RMSE) ---------------------
    ax_dvdt = fig.add_subplot(gs[4, :])
    if n_all_dvdt == 0:
        ax_dvdt.text(0.5, 0.5, f'No segments at {fast_charge_i_a:.1f} A\nfound for Li-stripping',
                     transform=ax_dvdt.transAxes, ha='center', fontsize=PUB_FONTSIZE - 1)
    else:
        strip_colors = [_nearest_color(t, valid_start_time, checkup_colors) for t in stripping_time]
        ax_dvdt.plot(stripping_time, stripping_rmse * 1000, '-', color=(0.5, 0.5, 0.5), linewidth=1.0)
        for i in range(n_all_dvdt):
            ax_dvdt.plot(stripping_time[i], stripping_rmse[i] * 1000, 'o',
                         markeredgecolor=strip_colors[i], markerfacecolor=strip_colors[i], markersize=4)
        ax_dvdt.set_xlim(common_xlim)
    ax_dvdt.set_xlabel('Date')
    ax_dvdt.set_ylabel('Power-law fit RMSE [mV/s]')
    ax_dvdt.set_title('Li-stripping vs age', fontweight='normal')
    ax_dvdt.set_ylim(0, stripping_rmse_y_max_mvpers)
    ax_dvdt.grid(True)

    # --- Row 6 left: dQ/dV ----------------------------------------------------
    ax_dqdv = fig.add_subplot(gs[5, 0:3])
    for i in range(n_valid):
        ax_dqdv.plot(checkups[i]['voltage_vec'], checkups[i]['dQdV_vec'], color=checkup_colors[i], linewidth=1.0)
    ax_dqdv.set_xlabel('Voltage [V]')
    ax_dqdv.set_ylabel('dQ/dV [As/V]')
    ax_dqdv.set_title('Differential capacity', fontweight='normal')
    ax_dqdv.grid(True)

    # --- Row 6 right: EIS Nyquist comparison ---------------------------------
    ax_eis = fig.add_subplot(gs[5, 3:6])
    plot_eis_comparison_on_axes(ax_eis, eis_root_for_comparison, eis_target_soc_pct, eis_max_freq_hz,
                                 cell_num, eis_stage_colors, eis_stage_markers, True)

    # --- Row 7 left: OCV (BoL/EoL GITT + C/50 OCP overlay) -------------------
    ax_ocv = fig.add_subplot(gs[6, 0:3])
    plot_gitt_and_ocp(ax_ocv, bol_gitt, eol_gitt, bol_c50, eol_c50, eis_col_bol, eis_col_eol)

    # --- Row 7 right: C/50 OCV curves ----------------------------------------
    ax_ocp = fig.add_subplot(gs[6, 3:6])
    for i in range(n_valid):
        ax_ocp.plot(checkups[i]['capacity_Ah_vec'], checkups[i]['voltage_vec'], color=checkup_colors[i], linewidth=1.0)
    ax_ocp.set_xlabel('Discharge capacity [Ah]')
    ax_ocp.set_ylabel('Voltage [V]')
    ax_ocp.set_title('C/50 OCV curves', fontweight='normal')
    ax_ocp.grid(True)

    # --- Publication styling on every axes (R-017/R-019) ---------------------
    for ax in fig.get_axes():
        ax.tick_params(labelsize=PUB_FONTSIZE)
        for label in ax.get_xticklabels() + ax.get_yticklabels():
            label.set_fontname('Times New Roman')
        for spine in ax.spines.values():
            spine.set_visible(True)
            spine.set_linewidth(0.8)

    png_file = os.path.join(pngs_dir, f'{cell_num}_Summary.png')
    pdf_file = os.path.join(pngs_dir, f'{cell_num}_Summary.pdf')
    fig.savefig(png_file, dpi=300)
    fig.savefig(pdf_file)
    print(f'\nSummary figure saved:\n  {png_file}\n  {pdf_file}')


if __name__ == '__main__':
    # Wave 8 override: run one cell/folder per subprocess (parity with RunWave8.m).
    main(cell_num=os.environ.get('WAVE8_CELL', 'Cell_22'),
         desired_folder=os.environ.get('WAVE8_FOLDER'))
