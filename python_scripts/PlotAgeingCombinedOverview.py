"""
PlotAgeingCombinedOverview - Merged capacity-degradation + resistance-increase
publication figures (CyclicAgeing.pdf / CalendarAgeing.pdf).

Python counterpart of matlab_scripts/PlotAgeingCombinedOverview.m (todo #101).
Builds two figures, each stacking capacity degradation (panel a, top) above
resistance increase (panel b, bottom) for the same highlighted cells with one
shared legend. Reads the OverviewCapacityData/OverviewResistanceData CSVs
from the cyclic/calendar ageing data folders (R-001, read-only) and plots
every cell as a faint grey background trace via Functions/plotAgeingPanel.py.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24

Compliance: R-001, R-004, R-013, R-016, R-017, R-018, R-019, R-021, R-022, R-023.
"""

import os
import re
import sys
from pathlib import Path

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

matplotlib.rcParams['font.family'] = 'serif'
matplotlib.rcParams['font.serif'] = ['Times New Roman']
matplotlib.rcParams['mathtext.fontset'] = 'stix'  # closest mathtext match to Times New Roman

_SCRIPT_DIR = Path(__file__).resolve().parent
_FUNCTIONS_CANDIDATES = (_SCRIPT_DIR.parent.parent / 'Functions', _SCRIPT_DIR.parent / 'Functions')
for _FUNCTIONS_DIR in _FUNCTIONS_CANDIDATES:
    if _FUNCTIONS_DIR.exists():
        if str(_FUNCTIONS_DIR) not in sys.path:
            sys.path.append(str(_FUNCTIONS_DIR))
        break
else:
    raise FileNotFoundError(f"Shared Functions folder not found from {_SCRIPT_DIR}")

from plotAgeingPanel import plot_ageing_panel  # noqa: E402
from get_figure_output_dir import get_figure_output_dir  # noqa: E402

# R-017 preferred colour palette.
_GREEN = (12 / 255, 195 / 255, 82 / 255)
_DARKBLUE = (1 / 255, 17 / 255, 181 / 255)
_RED = (1.0, 0.0, 0.0)
_MAGENTA = (1.0, 0.0, 1.0)
_BLACK = (0.0, 0.0, 0.0)

PUB_FONTSIZE = 8       # R-021 default caption size
LW_AXES = 0.8           # R-017 item 4: axes frame
RES_SCALE = 1000        # Ohm -> mOhm
CAP_YLIM = (0.90, 1.05)
RES_YLIM = (1.10, 9.00)
CAP_YLABEL = r'$\tilde{C}_{RPT}\,[-]$'
RES_YLABEL = r'$R_{RPT}\,[\mathrm{m}\Omega]$'

# Panel geometry: same format as the OCV figure (R-023: 3.5190 cm plot boxes).
W_CM, H_CM = 9.35, 9.6
PANEL_H_CM = 3.5190
LEFT_M, RIGHT_M, BOT_M, GAP = 1.45, 0.30, 1.20, 1.05
PLOT_W_CM = W_CM - LEFT_M - RIGHT_M


def _load_overview(csv_path, quantity):
    """Read one overview CSV and normalise its column names (MATLAB parity)."""

    df = pd.read_csv(csv_path)
    df = df.rename(columns={'CellNum': 'cell_number'})
    if quantity == 'capacity':
        df = df.rename(columns={'CheckupCapacityTimeStamp': 'Timestamp',
                                 'CheckupCapacity_Ah': 'Capacity [Ah]'})
    elif quantity == 'resistance':
        df = df.rename(columns={'CheckupResistanceTimeStamp': 'Timestamp',
                                 'CheckupResistance_Ohm': 'Resistance [Ohm]'})
    df['cell_number'] = df['cell_number'].astype(str).str.extract(r'(Cell_\d+)', expand=False)
    df['Timestamp'] = pd.to_datetime(df['Timestamp'])
    return df


def _style_axes(ax):
    """Apply the shared R-017/R-019/R-021 publication styling to one axes."""

    ax.tick_params(labelsize=PUB_FONTSIZE)
    for label in ax.get_xticklabels() + ax.get_yticklabels():
        label.set_fontname('Times New Roman')
    for spine in ax.spines.values():
        spine.set_visible(True)
        spine.set_linewidth(LW_AXES)
    ax.grid(True)


def _add_boundary_ticks(ax, axis, ylim_or_xlim):
    """Ensure both limit boundaries are present among the tick marks (MATLAB parity)."""

    getter = ax.get_yticks if axis == 'y' else ax.get_xticks
    setter = ax.set_yticks if axis == 'y' else ax.set_xticks
    set_lim = ax.set_ylim if axis == 'y' else ax.set_xlim
    lo, hi = ylim_or_xlim
    # Keep only in-range auto ticks so out-of-bound "nice" locator ticks
    # (e.g. matplotlib's pre-draw locator proposing 0 or 10 just outside a
    # 1.10-9.00 range) cannot silently re-expand the axis view.
    in_range_ticks = [t for t in getter().tolist() if lo <= t <= hi]
    ticks = sorted(set(in_range_ticks) | {lo, hi})
    setter(ticks)
    set_lim(lo, hi)  # re-lock the view in case set_*ticks re-triggered autoscale


def main():
    """Generate CyclicAgeing.pdf and CalendarAgeing.pdf."""

    data_root = r'\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot'
    io_folder_cyclic = os.path.join(data_root, '4_Ageing', 'Cyclic_ageing_data')
    io_folder_calendar = os.path.join(data_root, '4_Ageing', 'Calendar_ageing_data')

    pngs_dir = str(get_figure_output_dir('PlotAgeingCombinedOverview'))

    cap_cyclic = _load_overview(os.path.join(io_folder_cyclic, 'OverviewCapacityData_36cell.csv'), 'capacity')
    cap_calendar = _load_overview(os.path.join(io_folder_calendar, 'OverviewCapacityData_5cell.csv'), 'capacity')
    res_cyclic = _load_overview(os.path.join(io_folder_cyclic, 'OverviewResistanceData_36cell.csv'), 'resistance')
    res_calendar = _load_overview(os.path.join(io_folder_calendar, 'OverviewResistanceData_5cell.csv'), 'resistance')

    configs = [
        {
            'name': 'CyclicAgeing',
            'cap_df': cap_cyclic, 'res_df': res_cyclic,
            'cells_hi': ['Cell_12', 'Cell_23', 'Cell_34', 'Cell_35'],
            'colors': [_GREEN, _DARKBLUE, _RED, _MAGENTA],
            'labels': ['Cell_12 - C/2 - C/2', 'Cell_23 - 1C - C/2',
                       'Cell_34 - 3C/2 - C/2', 'Cell_35 - 2C - C/2'],
            'x_mode': 'fec',
            'x_label': 'Full Equivalent Cycles [cycles]',
            'x_lim_fixed': None,
            'legend_loc': 'upper right',
        },
        {
            'name': 'CalendarAgeing',
            'cap_df': cap_calendar, 'res_df': res_calendar,
            'cells_hi': ['Cell_57', 'Cell_11', 'Cell_45', 'Cell_26', 'Cell_28'],
            'colors': [_GREEN, _DARKBLUE, _RED, _MAGENTA, _BLACK],
            'labels': ['Cell_57 | 0 degC | Avg SoC 100%', 'Cell_11 | 25 degC | Avg SoC 100%',
                       'Cell_45 | 45 degC | Avg SoC 10%', 'Cell_26 | 45 degC | Avg SoC 50%',
                       'Cell_28 | 45 degC | Avg SoC 100%'],
            'x_mode': 'time',
            'x_label': 'Time [days]',
            'x_lim_fixed': (0, 400),
            'legend_loc': 'upper left',
        },
    ]

    print('--- PlotAgeingCombinedOverview: starting figure generation ---')

    for cfg in configs:
        markers = ['-'] * len(cfg['cells_hi'])
        cap_cells = sorted(cfg['cap_df']['cell_number'].unique())
        res_cells = sorted(cfg['res_df']['cell_number'].unique())

        fig = plt.figure(figsize=(W_CM / 2.54, H_CM / 2.54))

        # (a) capacity degradation (top).
        ax_cap = fig.add_axes([
            LEFT_M / W_CM, (BOT_M + PANEL_H_CM + GAP) / H_CM,
            PLOT_W_CM / W_CM, PANEL_H_CM / H_CM,
        ])
        _, max_x_cap = plot_ageing_panel(ax_cap, cfg['cap_df'], cap_cells, cfg['cells_hi'],
                                          cfg['colors'], markers, cfg['x_mode'], 'capacity', 1)
        ax_cap.set_ylabel(CAP_YLABEL)
        ax_cap.set_ylim(CAP_YLIM)
        _add_boundary_ticks(ax_cap, 'y', CAP_YLIM)
        ax_cap.yaxis.set_major_formatter(lambda v, _pos: f'{v:.2f}')
        _style_axes(ax_cap)
        ax_cap.text(0.02, 0.93, '(a)', transform=ax_cap.transAxes, fontsize=PUB_FONTSIZE,
                    fontweight='bold', fontname='Times New Roman')

        # (b) resistance increase (bottom).
        ax_res = fig.add_axes([LEFT_M / W_CM, BOT_M / H_CM, PLOT_W_CM / W_CM, PANEL_H_CM / H_CM])
        h_res, max_x_res = plot_ageing_panel(ax_res, cfg['res_df'], res_cells, cfg['cells_hi'],
                                              cfg['colors'], markers, cfg['x_mode'], 'resistance', RES_SCALE)
        ax_res.set_ylabel(RES_YLABEL)
        ax_res.set_xlabel(cfg['x_label'])
        ax_res.set_ylim(RES_YLIM)
        _add_boundary_ticks(ax_res, 'y', RES_YLIM)
        ax_res.yaxis.set_major_formatter(lambda v, _pos: f'{v:.2f}')
        _style_axes(ax_res)
        ax_res.text(0.02, 0.93, '(b)', transform=ax_res.transAxes, fontsize=PUB_FONTSIZE,
                    fontweight='bold', fontname='Times New Roman')

        # Shared x-limits across both panels.
        if cfg['x_mode'] == 'fec':
            xm = max(max_x_cap, max_x_res)
            if xm <= 0:
                xm = 1
            ax_cap.set_xlim(0, xm)
            ax_res.set_xlim(0, xm)
        else:
            ax_cap.set_xlim(cfg['x_lim_fixed'])
            ax_res.set_xlim(cfg['x_lim_fixed'])
            _add_boundary_ticks(ax_cap, 'x', cfg['x_lim_fixed'])
            _add_boundary_ticks(ax_res, 'x', cfg['x_lim_fixed'])

        # One shared legend, on the bottom panel (R-017 item 5: frameless).
        ax_res.legend(h_res, cfg['labels'], loc=cfg['legend_loc'], frameon=False,
                      fontsize=PUB_FONTSIZE)

        png_file = os.path.join(pngs_dir, f"{cfg['name']}.png")
        pdf_file = os.path.join(pngs_dir, f"{cfg['name']}.pdf")
        fig.savefig(png_file, dpi=300)
        fig.savefig(pdf_file)
        print(f'Wrote {pdf_file}')

    print('--- PlotAgeingCombinedOverview: figure generation complete ---')


if __name__ == '__main__':
    main()
