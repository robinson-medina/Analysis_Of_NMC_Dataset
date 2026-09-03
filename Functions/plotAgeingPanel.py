"""
plotAgeingPanel - Draw one ageing-overview panel (capacity or resistance)
into a matplotlib axes.

Python counterpart of Functions/plotAgeingPanel.m, used by
python_scripts/PlotAgeingCombinedOverview.py (todo #101).

Plots every cell in cell_list_all as a faint grey background trace, then the
highlighted cells (cell_plot_list) as coloured traces, so multi-panel
figures can compose several such calls with a shared legend.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24

Compliance: R-004, R-017.
"""

import numpy as np

_LW_DATA = 1.0                  # R-017: data traces 1.0 pt
_GREY = (0.75, 0.75, 0.75)      # faint background cells


def _local_xy(cur, x_mode, y_mode, fec_col, resistance_scale):
    """Compute (x, y) arrays for one cell's rows, per x_mode/y_mode."""

    if x_mode == 'time':
        x = (cur['Timestamp'] - cur['Timestamp'].iloc[0]).dt.total_seconds().values / 86400.0
    elif x_mode == 'fec':
        x = cur[fec_col].values
    else:
        raise ValueError("x_mode must be 'time' or 'fec'.")

    if y_mode == 'capacity':
        y = cur['Capacity [Ah]'].values / cur['Capacity [Ah]'].values[0]
    elif y_mode == 'resistance':
        y = cur['Resistance [Ohm]'].values * resistance_scale
    else:
        raise ValueError("y_mode must be 'capacity' or 'resistance'.")

    return x, y


def plot_ageing_panel(ax, df, cell_list_all, cell_plot_list, color_list, marker_list,
                       x_mode, y_mode, resistance_scale=1):
    """
    Draw one ageing-overview panel (capacity or resistance) into ax.

    Parameters
    ----------
    ax : matplotlib.axes.Axes
    df : pandas.DataFrame
        Preprocessed table with columns 'cell_number', 'Timestamp',
        'Capacity [Ah]'/'Resistance [Ohm]', and the FEC column.
    cell_list_all : list of str
        All cell names to draw faint in the background.
    cell_plot_list : list of str
        Highlighted cell names (draw order == legend order).
    color_list : list of RGB tuples, one per highlighted cell.
    marker_list : list of matplotlib line styles, one per highlighted cell.
    x_mode : 'time' or 'fec'.
    y_mode : 'capacity' or 'resistance'.
    resistance_scale : float
        Multiplier for resistance (e.g. 1000 for mOhm); ignored for capacity.

    Returns
    -------
    handles : list of matplotlib.lines.Line2D
        Highlighted line handles (for a shared legend).
    max_x_highlight : float
        Max x across highlighted cells (for a common xlim).
    """

    if y_mode == 'capacity':
        fec_col = 'CheckupCapacityFEC'
    elif y_mode == 'resistance':
        fec_col = 'CheckupResistanceFEC'
    else:
        raise ValueError('y_mode must be capacity or resistance.')

    # Faint background: every cell in the dataset.
    for cell_name in cell_list_all:
        cur = df[df['cell_number'] == cell_name]
        if cur.empty:
            continue
        x, y = _local_xy(cur, x_mode, y_mode, fec_col, resistance_scale)
        ax.plot(x, y, '-', linewidth=_LW_DATA, color=_GREY, zorder=1)

    # Highlighted cells (deterministic colour/order for the shared legend).
    handles = []
    max_x_highlight = 0.0
    for cell_name, color, marker in zip(cell_plot_list, color_list, marker_list):
        cur = df[df['cell_number'] == cell_name]
        if cur.empty:
            print(f'plot_ageing_panel: Cell {cell_name} not found.')
            continue
        x, y = _local_xy(cur, x_mode, y_mode, fec_col, resistance_scale)
        (h,) = ax.plot(x, y, marker, linewidth=_LW_DATA, color=color, zorder=2)
        handles.append(h)
        if len(x) > 0:
            max_x_highlight = max(max_x_highlight, np.max(x))

    return handles, max_x_highlight


__all__ = ['plot_ageing_panel']
