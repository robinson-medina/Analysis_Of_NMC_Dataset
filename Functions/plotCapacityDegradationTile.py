"""
plotCapacityDegradationTile - Draw a relative-capacity-vs-time and
relative-capacity-vs-FEC pair of traces into caller-supplied matplotlib axes.

Python counterpart of Functions/plotCapacityDegradationTile.m, used by
python_scripts/PlotCapacityDegradation_detailed.py (todo #018).

Mirrors the MATLAB tile helper exactly: draws every cell in cell_list as a
faint grey background trace (2 pt line, alpha 0.2), then the highlighted
cells in cell_plot_list as colored 'o'-marker traces. No legend is drawn on
either axes - this matches the current no-legend convention already applied
to every capacity-degradation figure in the MATLAB script.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-25

Compliance: R-004, R-013, R-016.
"""


def plot_capacity_degradation_tile(ax_time, ax_fec, combined_df, cell_list,
                                    cell_plot_list, colormap_list, marker_list, plot_title):
    """
    Draw the Time [days] / FEC relative-capacity trace pair into ax_time/ax_fec.

    Parameters
    ----------
    ax_time, ax_fec : matplotlib.axes.Axes
        Target axes for the Time [days] and FEC subplots respectively.
    combined_df : pandas.DataFrame
        Table with columns cell_number, Timestamp, "Capacity [Ah]",
        CheckupCapacityFEC.
    cell_list : list of str
        All cell numbers in the dataset, drawn as thin grey background
        traces for context.
    cell_plot_list : list of str
        Highlighted cell numbers to draw in color.
    colormap_list : list
        Line color per highlighted cell (matplotlib color spec).
    marker_list : list of str
        Line style per highlighted cell (e.g. '-', '--').
    plot_title : str
        Base title, suffixed with '(vs Time)' / '(vs FEC)'. Pass '' for no title.

    Returns
    -------
    None (draws directly into ax_time/ax_fec; no legend is created).
    """

    # --- Time vs Relative Capacity ---
    # Background: every cell in the dataset, thin grey lines for context (no legend).
    for cell_name in cell_list:
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        current_cell = current_cell.sort_values("Timestamp")
        time_days = (current_cell["Timestamp"] - current_cell["Timestamp"].iloc[0]).dt.total_seconds() / 86400.0
        rel_capacity = current_cell["Capacity [Ah]"] / current_cell["Capacity [Ah]"].iloc[0] * 100
        ax_time.plot(time_days, rel_capacity, linewidth=2, color=(0.5, 0.5, 0.5, 0.2))

    # Highlighted cells: colored 'o'-marker traces (still no legend).
    for idx, cell_name in enumerate(cell_plot_list):
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            print(f"Warning: Cell {cell_name} not found in data")
            continue
        current_cell = current_cell.sort_values("Timestamp")
        time_days = (current_cell["Timestamp"] - current_cell["Timestamp"].iloc[0]).dt.total_seconds() / 86400.0
        rel_capacity = current_cell["Capacity [Ah]"] / current_cell["Capacity [Ah]"].iloc[0] * 100
        ax_time.plot(time_days, rel_capacity, marker="o", linewidth=2, color=colormap_list[idx],
                     markerfacecolor=colormap_list[idx], markersize=4, linestyle=marker_list[idx])

    ax_time.grid(True, linestyle="--", alpha=0.6)
    ax_time.tick_params(labelsize=11)
    ax_time.set_xlabel("Time [days]", fontsize=11)
    ax_time.set_ylabel("Relative Capacity [%]", fontsize=11)
    if plot_title:
        ax_time.set_title(f"{plot_title} (vs Time)", fontsize=11)
    ax_time.set_xlim(0, 425)
    ax_time.set_ylim(78, 103)

    # --- FEC vs Relative Capacity ---
    for cell_name in cell_list:
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        rel_capacity = current_cell["Capacity [Ah]"] / current_cell["Capacity [Ah]"].iloc[0] * 100
        ax_fec.plot(current_cell["CheckupCapacityFEC"], rel_capacity, linewidth=2, color=(0.5, 0.5, 0.5, 0.2))

    max_fec_highlight = 0.0
    for idx, cell_name in enumerate(cell_plot_list):
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        rel_capacity = current_cell["Capacity [Ah]"] / current_cell["Capacity [Ah]"].iloc[0] * 100
        ax_fec.plot(current_cell["CheckupCapacityFEC"], rel_capacity, marker="o", linewidth=2,
                    color=colormap_list[idx], markerfacecolor=colormap_list[idx], markersize=4,
                    linestyle=marker_list[idx])
        if current_cell["CheckupCapacityFEC"].notna().any():
            max_fec_highlight = max(max_fec_highlight, float(current_cell["CheckupCapacityFEC"].max()))

    ax_fec.grid(True, linestyle="--", alpha=0.6)
    ax_fec.tick_params(labelsize=11)
    ax_fec.set_xlabel("Full Equivalent Cycles (FEC)", fontsize=11)
    ax_fec.set_ylabel("Relative Capacity [%]", fontsize=11)
    if plot_title:
        ax_fec.set_title(f"{plot_title} (vs FEC)", fontsize=11)
    ax_fec.set_ylim(78, 103)
    ax_fec.set_xlim(0, max_fec_highlight)


__all__ = ["plot_capacity_degradation_tile"]
