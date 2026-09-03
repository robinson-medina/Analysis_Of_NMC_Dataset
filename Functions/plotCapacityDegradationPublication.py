"""
plotCapacityDegradationPublication - Publication-ready capacity-degradation
figures (Time panel, with an optional stacked FEC panel), plus a dedicated
FEC-only variant.

Python counterpart of the plotCapacityDegradationPublication /
plotCapacityDegradationPublicationFECOnly local functions at the bottom of
matlab_scripts/PlotCapacityDegradation_detailed.m (todo #018).

Both figures use the current MATLAB publication styling: single-column
8.0962 cm width, 8 pt Times New Roman text throughout, 0.8 pt background
traces / 1.0 pt highlighted traces / 0.8 pt axes frame (R-017 item 4),
dimensionless y-axis (default 0.90-1.05) with 2-decimal tick labels, and NO
legend (intentionally omitted per the current publication request - the
label_list/legend_location parameters are kept for signature parity only).

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-25

Compliance: R-001, R-004, R-013, R-016, R-017, R-018, R-019, R-020, R-022.
"""

import matplotlib.pyplot as plt

_PUB_FONTSIZE = 8
_LW_AXES = 0.8
_LW_BACKGROUND = 1.0
_LW_HIGHLIGHT = 1.0
_GREY = (0.75, 0.75, 0.75)
# MATLAB's coded default (never actually exercised - every current caller
# passes its own $\tilde{C}_{RPT}\,[-]$ label); kept only for signature parity.
_DEFAULT_Y_LABEL = r"$\hat{C}_{RPT}\,[-]$"


def _style_axes(ax):
    """Apply the shared 8 pt Times New Roman / 0.8 pt axes-frame styling (R-017/R-019/R-021)."""

    ax.tick_params(labelsize=_PUB_FONTSIZE, width=_LW_AXES)
    for label in ax.get_xticklabels() + ax.get_yticklabels():
        label.set_fontname("Times New Roman")
    for spine in ax.spines.values():
        spine.set_visible(True)
        spine.set_linewidth(_LW_AXES)
    ax.grid(True)


def _add_boundary_ticks(ax, axis, lims):
    """Ensure both limit boundaries are present among the tick marks (MATLAB xticks/yticks parity)."""

    lo, hi = lims
    getter = ax.get_yticks if axis == "y" else ax.get_xticks
    setter = ax.set_yticks if axis == "y" else ax.set_xticks
    set_lim = ax.set_ylim if axis == "y" else ax.set_xlim
    in_range_ticks = [tick for tick in getter().tolist() if lo <= tick <= hi]
    setter(sorted(set(in_range_ticks) | {lo, hi}))
    set_lim(lo, hi)  # re-lock the view in case set_*ticks re-triggered autoscale


def _draw_time_panel(ax, combined_df, cell_list, cell_plot_list, colormap_list, marker_list,
                      plot_title, x_limits, y_limits, y_axis_label):
    """Draw the Time [days] vs relative-capacity panel (background + highlighted cells)."""

    for cell_name in cell_list:
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        current_cell = current_cell.sort_values("Timestamp")
        time_days = (current_cell["Timestamp"] - current_cell["Timestamp"].iloc[0]).dt.total_seconds() / 86400.0
        rel_capacity = current_cell["Capacity [Ah]"] / current_cell["Capacity [Ah]"].iloc[0]
        ax.plot(time_days, rel_capacity, linewidth=_LW_BACKGROUND, color=_GREY)

    for idx, cell_name in enumerate(cell_plot_list):
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            print(f"Warning: Cell {cell_name} not found in data")
            continue
        current_cell = current_cell.sort_values("Timestamp")
        time_days = (current_cell["Timestamp"] - current_cell["Timestamp"].iloc[0]).dt.total_seconds() / 86400.0
        rel_capacity = current_cell["Capacity [Ah]"] / current_cell["Capacity [Ah]"].iloc[0]
        ax.plot(time_days, rel_capacity, linewidth=_LW_HIGHLIGHT, color=colormap_list[idx],
                linestyle=marker_list[idx])

    ax.set_xlim(x_limits)
    ax.set_ylim(y_limits)
    _add_boundary_ticks(ax, "x", x_limits)
    _add_boundary_ticks(ax, "y", y_limits)
    ax.yaxis.set_major_formatter(lambda value, _pos: f"{value:.2f}")
    if plot_title:
        ax.set_title(f"{plot_title} (vs Time)", fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    ax.set_xlabel("Time [days]", fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    ax.set_ylabel(y_axis_label, fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    _style_axes(ax)
    # Legend intentionally omitted per publication request (matches MATLAB).


def _draw_fec_panel(ax, combined_df, cell_list, cell_plot_list, colormap_list, marker_list,
                     plot_title, y_limits, y_axis_label, plain_title=False):
    """Draw the FEC vs relative-capacity panel (background + highlighted cells)."""

    max_fec = 0.0
    for cell_name in cell_list:
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        rel_capacity = current_cell["Capacity [Ah]"] / current_cell["Capacity [Ah]"].iloc[0]
        ax.plot(current_cell["CheckupCapacityFEC"], rel_capacity, linewidth=_LW_BACKGROUND, color=_GREY)
        if current_cell["CheckupCapacityFEC"].notna().any():
            max_fec = max(max_fec, float(current_cell["CheckupCapacityFEC"].max()))

    max_fec_highlight = 0.0
    for idx, cell_name in enumerate(cell_plot_list):
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        rel_capacity = current_cell["Capacity [Ah]"] / current_cell["Capacity [Ah]"].iloc[0]
        ax.plot(current_cell["CheckupCapacityFEC"], rel_capacity, linewidth=_LW_HIGHLIGHT,
                color=colormap_list[idx], linestyle=marker_list[idx])
        if current_cell["CheckupCapacityFEC"].notna().any():
            max_fec_highlight = max(max_fec_highlight, float(current_cell["CheckupCapacityFEC"].max()))

    if max_fec_highlight <= 0:
        max_fec_highlight = max_fec

    ax.set_ylim(y_limits)
    ax.set_xlim(0, max_fec_highlight)
    _add_boundary_ticks(ax, "y", y_limits)
    ax.yaxis.set_major_formatter(lambda value, _pos: f"{value:.2f}")
    if plot_title:
        title_text = plot_title if plain_title else f"{plot_title} (vs FEC)"
        ax.set_title(title_text, fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    ax.set_xlabel("Full Equivalent Cycles [cycles]", fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    ax.set_ylabel(y_axis_label, fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    _style_axes(ax)
    # Legend intentionally omitted per publication request (matches MATLAB).


def plot_capacity_degradation_publication(combined_df, cell_list, cell_plot_list, label_list,
                                           colormap_list, marker_list, png_filename, pdf_filename,
                                           plot_title="", include_fec=True, legend_location="southwest",
                                           x_limits=(0, 425), y_limits=(0.90, 1.05),
                                           y_axis_label=_DEFAULT_Y_LABEL):
    """
    Build the capacity-degradation publication figure: Time panel always,
    plus an FEC panel if include_fec=True (matches MATLAB
    plotCapacityDegradationPublication; used with include_fec=False for the
    Calendar Ageing Effect figure - fig. 11).

    label_list/legend_location are accepted for signature parity only; no
    legend is rendered (matches the current MATLAB "Legend intentionally
    omitted" behaviour).
    """

    fig_height_cm = 8.8 if include_fec else 3.5190
    fig = plt.figure(figsize=(8.0962 / 2.54, fig_height_cm / 2.54))

    if include_fec:
        ax_top = fig.add_subplot(2, 1, 1)
        ax_bottom = fig.add_subplot(2, 1, 2)
    else:
        ax_top = fig.add_subplot(1, 1, 1)
        ax_bottom = None

    _draw_time_panel(ax_top, combined_df, cell_list, cell_plot_list, colormap_list, marker_list,
                      plot_title, x_limits, y_limits, y_axis_label)

    if include_fec:
        _draw_fec_panel(ax_bottom, combined_df, cell_list, cell_plot_list, colormap_list, marker_list,
                         plot_title, y_limits, y_axis_label)

    fig.tight_layout()
    fig.savefig(png_filename, dpi=300, bbox_inches="tight")
    fig.savefig(pdf_filename, bbox_inches="tight")
    print(f"Publication PDF saved: {pdf_filename}")
    plt.close(fig)


def plot_capacity_degradation_publication_fec_only(combined_df, cell_list, cell_plot_list, label_list,
                                                     colormap_list, marker_list, png_filename, pdf_filename,
                                                     plot_title="", legend_location="southwest",
                                                     y_axis_label=_DEFAULT_Y_LABEL):
    """
    Build the FEC-only capacity-degradation publication figure (fig. 5,
    "Effect of C-rate at 25 degC"). Matches MATLAB
    plotCapacityDegradationPublicationFECOnly, including its hard-coded
    (0.90, 1.05) y-limits and plain (unsuffixed) title.
    """

    fig = plt.figure(figsize=(8.0962 / 2.54, 3.5190 / 2.54))
    ax = fig.add_subplot(1, 1, 1)
    _draw_fec_panel(ax, combined_df, cell_list, cell_plot_list, colormap_list, marker_list,
                     plot_title, (0.90, 1.05), y_axis_label, plain_title=True)
    fig.tight_layout()
    fig.savefig(png_filename, dpi=300, bbox_inches="tight")
    fig.savefig(pdf_filename, bbox_inches="tight")
    print(f"Publication PDF saved: {pdf_filename}")
    plt.close(fig)


__all__ = ["plot_capacity_degradation_publication", "plot_capacity_degradation_publication_fec_only"]
