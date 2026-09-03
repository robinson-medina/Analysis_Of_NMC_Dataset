"""
plotResistanceIncreaseTile - Draw a resistance-vs-time and resistance-vs-FEC
pair of traces (WITH legend, unlike the capacity tile) into caller-supplied
matplotlib axes.

Python counterpart of Functions/plotResistanceIncreaseTile.m, used by
python_scripts/PlotResistanceIncrease_Detailed.py (todo #019).

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-25

Compliance: R-004, R-013, R-016.
"""

_OHM_LABEL = "Checkup Resistance [$\\Omega$]"


def plot_resistance_increase_tile(ax_time, ax_fec, combined_df, cell_list,
                                   cell_plot_list, label_list, colormap_list, marker_list, plot_title):
    """
    Draw the Time [days] / FEC resistance trace pair (with a legend on each
    subplot) into ax_time/ax_fec.

    Parameters mirror plot_capacity_degradation_tile, plus label_list (one
    legend label per highlighted cell) since - unlike the capacity tile -
    this resistance tile DOES render a legend on both subplots.
    """

    # --- Time vs Resistance ---
    for cell_name in cell_list:
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        current_cell = current_cell.sort_values("Timestamp")
        time_days = (current_cell["Timestamp"] - current_cell["Timestamp"].iloc[0]).dt.total_seconds() / 86400.0
        ax_time.plot(time_days, current_cell["Resistance [Ohm]"], linewidth=2, color=(0.5, 0.5, 0.5, 0.2))

    handles, labels = [], []
    for idx, cell_name in enumerate(cell_plot_list):
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            print(f"Warning: Cell {cell_name} not found in data")
            continue
        current_cell = current_cell.sort_values("Timestamp")
        time_days = (current_cell["Timestamp"] - current_cell["Timestamp"].iloc[0]).dt.total_seconds() / 86400.0
        (handle,) = ax_time.plot(time_days, current_cell["Resistance [Ohm]"], marker="o", linewidth=2,
                                  color=colormap_list[idx], markerfacecolor=colormap_list[idx],
                                  markersize=4, linestyle=marker_list[idx])
        handles.append(handle)
        labels.append(label_list[idx])

    ax_time.grid(True, linestyle="--", alpha=0.6)
    ax_time.tick_params(labelsize=11)
    ax_time.set_xlabel("Time [days]", fontsize=11)
    ax_time.set_ylabel(_OHM_LABEL, fontsize=11)
    if plot_title:
        ax_time.set_title(f"{plot_title} (vs Time)", fontsize=11)
    if handles:
        ax_time.legend(handles, labels, fontsize=11, loc="best")

    # --- FEC vs Resistance ---
    for cell_name in cell_list:
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        ax_fec.plot(current_cell["CheckupResistanceFEC"], current_cell["Resistance [Ohm]"],
                    linewidth=2, color=(0.5, 0.5, 0.5, 0.2))

    handles, labels = [], []
    max_fec_highlight = 0.0
    for idx, cell_name in enumerate(cell_plot_list):
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        (handle,) = ax_fec.plot(current_cell["CheckupResistanceFEC"], current_cell["Resistance [Ohm]"],
                                 marker="o", linewidth=2, color=colormap_list[idx],
                                 markerfacecolor=colormap_list[idx], markersize=4, linestyle=marker_list[idx])
        handles.append(handle)
        labels.append(label_list[idx])
        if current_cell["CheckupResistanceFEC"].notna().any():
            max_fec_highlight = max(max_fec_highlight, float(current_cell["CheckupResistanceFEC"].max()))

    ax_fec.grid(True, linestyle="--", alpha=0.6)
    ax_fec.tick_params(labelsize=11)
    ax_fec.set_xlabel("Full Equivalent Cycles (FEC)", fontsize=11)
    ax_fec.set_ylabel(_OHM_LABEL, fontsize=11)
    if plot_title:
        ax_fec.set_title(f"{plot_title} (vs FEC)", fontsize=11)
    if max_fec_highlight > 0:
        ax_fec.set_xlim(0, max_fec_highlight)
    if handles:
        ax_fec.legend(handles, labels, fontsize=11, loc="best")


__all__ = ["plot_resistance_increase_tile"]
