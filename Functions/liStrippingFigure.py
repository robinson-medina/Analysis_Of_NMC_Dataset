"""
liStrippingFigure - self-contained publication figure documenting the
Li-stripping detection concept (A-002).

Python counterpart of Functions/liStrippingFigure.m, used by
python_scripts/PlotCellSummary.py (todo #012, Feature B).

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24
"""

import os

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib import cm
from matplotlib.colors import Normalize


def li_stripping_figure(time_with_gaps, voltage, all_segs, strip_metric, params, cell_num, cell_label,
                         output_dir, font_name='Times New Roman', font_size=8):
    """Build and save <cellNum>_LiStripping.png in the supplied R-022 directory."""

    n_seg = len(all_segs)
    if n_seg == 0:
        print('[liStrippingFigure] No segments to plot; figure skipped.')
        return

    cmap = cm.get_cmap('viridis', max(n_seg, 2))
    cols = [cmap(i / max(n_seg - 1, 1)) for i in range(n_seg)]

    fig = plt.figure(figsize=(17.4 / 2.54, 14 / 2.54))
    gs = fig.add_gridspec(2, 2)
    title_txt = f'Li-stripping diagnostic - {cell_num}' + (f' ({cell_label})' if cell_label else '')
    fig.suptitle(title_txt, fontsize=font_size + 1)

    # --- Row 1 (full width): ageing V trace + segment tick markers ---
    ax_top = fig.add_subplot(gs[0, :])
    ax_top.plot(pd.DatetimeIndex(time_with_gaps), voltage, '-', color=(0.4, 0.4, 0.4), linewidth=0.4)
    yl = (2.5, 4.5)
    ax_top.set_ylim(yl)
    for i in range(n_seg):
        t0 = pd.Timestamp(all_segs[i]['start_time'])
        ax_top.plot([t0, t0], yl, '-', color=cols[i], linewidth=0.8)
    ax_top.set_xlabel('Date')
    ax_top.set_ylabel('Voltage [V]')
    ax_top.set_title(f'Full ageing trace - {n_seg} post-charge C/5 discharge segments detected',
                      fontweight='normal')
    ax_top.grid(True)

    # --- Row 2 left: V vs time (per segment, time-zeroed) ---
    ax_v = fig.add_subplot(gs[1, 0])
    for i in range(n_seg):
        ax_v.plot(all_segs[i]['timeS_interp'], all_segs[i]['voltage_interp'], '-', color=cols[i], linewidth=0.6)
    ax_v.set_xlim(0, max(500, params['metricWin_s'][1] + 50))
    ax_v.set_xlabel('Time after charge end [s]')
    ax_v.set_ylabel('Voltage [V]')
    ax_v.set_title('C/5 discharge after fast charge', fontweight='normal')
    ax_v.grid(True)

    # --- Row 2 right: dV/dt vs time, with metric window shaded ---
    ax_dv = fig.add_subplot(gs[1, 1])
    dvdt_y_range = (-0.005, 0.0005)
    ax_dv.axvspan(params['metricWin_s'][0], params['metricWin_s'][1], color=(1, 0.85, 0.2), alpha=0.15, zorder=0)
    for i in range(n_seg):
        ax_dv.plot(all_segs[i]['timeS_interp'], all_segs[i]['dVdt_Vpers'], '-', color=cols[i], linewidth=0.6)
    ax_dv.set_xlim(0, max(500, params['metricWin_s'][1] + 50))
    ax_dv.set_ylim(dvdt_y_range)
    ax_dv.set_xlabel('Time after charge end [s]')
    ax_dv.set_ylabel('dV/dt [V/s]')
    ax_dv.set_title(f"dV/dt - metric = max-min over [{params['metricWin_s'][0]:g}, "
                     f"{params['metricWin_s'][1]:g}] s window", fontweight='normal')
    ax_dv.grid(True)

    # Shared colourbar (date axis).
    start_dates = [pd.Timestamp(seg['start_time']) for seg in all_segs]
    norm = Normalize(vmin=0, vmax=max(n_seg - 1, 1))
    sm = cm.ScalarMappable(norm=norm, cmap=cmap)
    sm.set_array([])
    cb = fig.colorbar(sm, ax=ax_dv)
    if n_seg > 1:
        n_ticks = min(5, n_seg)
        tick_idx = np.round(np.linspace(0, n_seg - 1, n_ticks)).astype(int)
        cb.set_ticks(tick_idx)
        cb.set_ticklabels([start_dates[k].strftime('%Y-%m-%d') for k in tick_idx])
    cb.set_label('Segment date', fontsize=font_size)

    # Per-segment metric annotation.
    strip_metric = np.asarray(strip_metric, dtype=float)
    finite_mask = ~np.isnan(strip_metric)
    if np.any(finite_mask):
        txt = (f'Metric: mean={1000 * np.mean(strip_metric[finite_mask]):.3f} mV/s, '
               f'min={1000 * np.min(strip_metric[finite_mask]):.3f} mV/s, '
               f'max={1000 * np.max(strip_metric[finite_mask]):.3f} mV/s')
        ax_v.text(0.02, 0.04, txt, transform=ax_v.transAxes, va='bottom',
                  fontsize=font_size - 1, color=(0.2, 0.2, 0.2))

    for ax in (ax_top, ax_v, ax_dv):
        ax.tick_params(labelsize=font_size)
        for label in ax.get_xticklabels() + ax.get_yticklabels():
            label.set_fontname(font_name)
        for spine in ax.spines.values():
            spine.set_visible(True)

    png_file = os.path.join(output_dir, f'{cell_num}_LiStripping.png')
    fig.savefig(png_file, dpi=300)
    print(f'Li-stripping figure saved:\n  {png_file}')


__all__ = ['li_stripping_figure']
