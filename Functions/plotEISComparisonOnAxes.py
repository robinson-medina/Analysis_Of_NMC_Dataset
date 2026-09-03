"""
plotEISComparisonOnAxes - plot BoL/MoL/EoL Nyquist traces at one SoC on a
provided matplotlib axes using publication styling and fixed axis limits.

Python counterpart of Functions/plotEISComparisonOnAxes.m, used by
python_scripts/PlotCellSummary.py (todo #012).

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24
"""

import os
import re

import numpy as np
import pandas as pd

_STAGE_FOLDERS = ['1_BOL_EIS', '2_MOL_EIS', '3_EOL_EIS']
_STAGE_LABELS = ['BoL', 'MoL', 'EoL']


def plot_eis_comparison_on_axes(ax, eis_root_folder, target_soc_pct, max_freq, cell_num,
                                 stage_colors, stage_markers, show_title=True):
    """
    Overlay whichever life-stage impedance files exist for cell_num.

    Parameters mirror the MATLAB signature; stage_colors is a list of 3
    RGB tuples (BoL, MoL, EoL), stage_markers a list of 3 matplotlib marker
    strings.

    Returns
    -------
    plotted_count : int
    """

    ax.grid(True, which='both')
    for spine in ax.spines.values():
        spine.set_visible(True)

    legend_handles, legend_labels = [], []
    plotted_count = 0

    if not os.path.isdir(eis_root_folder):
        ax.text(0.5, 0.5, 'EIS root folder not found', transform=ax.transAxes, ha='center')
        return plotted_count

    for stage_idx, stage_folder_name in enumerate(_STAGE_FOLDERS):
        stage_folder = os.path.join(eis_root_folder, stage_folder_name)
        if not os.path.isdir(stage_folder):
            continue
        stage_csv = os.path.join(stage_folder, f'{cell_num}_impedanceData.csv')
        if not os.path.isfile(stage_csv):
            continue

        data = pd.read_csv(stage_csv)
        col_names = list(data.columns)

        r_real_col = ''
        for col in col_names:
            m = re.fullmatch(r'R_real_ohm_SoC(\d+)', col)
            if not m:
                continue
            if abs(float(m.group(1)) - target_soc_pct) < 1e-9:
                r_real_col = col
                break
        if not r_real_col:
            continue

        soc_suffix = r_real_col.split('R_real_ohm_SoC')[1]
        r_img_col = f'R_img_ohm_SoC{soc_suffix}'
        freq_col = f'Freq_Hz_SoC{soc_suffix}'
        if r_img_col not in col_names:
            continue

        r_real = data[r_real_col].values
        r_img = data[r_img_col].values
        if freq_col in col_names:
            freq = data[freq_col].values
            valid = ~np.isnan(r_real) & ~np.isnan(r_img) & ~np.isnan(freq) & (freq <= max_freq)
        else:
            valid = ~np.isnan(r_real) & ~np.isnan(r_img)
        r_real = r_real[valid]
        r_img = r_img[valid]
        if len(r_real) == 0:
            continue

        (h,) = ax.plot(r_real, -r_img, '-', color=stage_colors[stage_idx], linewidth=1.0,
                        marker=stage_markers[stage_idx], markersize=5,
                        markerfacecolor=stage_colors[stage_idx], markeredgecolor=stage_colors[stage_idx])
        plotted_count += 1
        legend_handles.append(h)
        legend_labels.append(f'{_STAGE_LABELS[stage_idx]} (SoC {target_soc_pct:.0f}%)')

    ax.set_xlabel(r'R$_{real}$ [$\Omega$]')
    ax.set_ylabel(r'-R$_{img}$ [$\Omega$]')
    ax.set_xlim(0.7e-3, 3e-3)
    ax.set_ylim(-0.4e-3, 0.3e-3)
    ax.set_aspect('equal', adjustable='box')
    if show_title:
        ax.set_title(f'EIS comparison (SoC {target_soc_pct:.0f}%)', fontweight='normal')

    if legend_handles:
        ax.legend(legend_handles, legend_labels, loc='best', frameon=False)
    else:
        ax.text(0.5, 0.5, f'No EIS traces at SoC {target_soc_pct:.0f}%', transform=ax.transAxes, ha='center')

    return plotted_count


__all__ = ['plot_eis_comparison_on_axes']
