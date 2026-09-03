"""
plotResistanceIncreasePublication - Publication-ready resistance-increase
figures (Time panel, with an optional stacked FEC panel), plus a dedicated
FEC-only variant. Unlike the capacity-degradation publication helpers, these
DO render a legend (matching current MATLAB behaviour).

Python counterpart of the plotResistanceIncreasePublication /
plotResistanceIncreasePublicationFECOnly local functions at the bottom of
matlab_scripts/PlotResistanceIncrease_Detailed.m (todo #019).

Deviation from MATLAB (documented, non-manuscript debug script only): the
MATLAB y-axis label uses a `\vphantom{\tilde{C}}` LaTeX macro purely to align
the resistance figure's left margin with the paired capacity figure's label
height. matplotlib's mathtext does not support \vphantom, so the Python
labels omit it (visually near-identical vertical position, no data impact).

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-25

Compliance: R-001, R-004, R-013, R-016, R-017, R-018, R-019, R-020.
"""

import matplotlib.pyplot as plt

_PUB_FONTSIZE = 8
_LW_AXES = 0.8
_LW_BACKGROUND = 1.0
_LW_HIGHLIGHT = 1.0
_GREY = (0.75, 0.75, 0.75)
_DEFAULT_LABEL = "Checkup Resistance [$\\Omega$]"

# MATLAB legend location strings -> matplotlib loc strings.
_LEGEND_LOC_MAP = {
    "northeast": "upper right", "northwest": "upper left",
    "southeast": "lower right", "southwest": "lower left",
    "north": "upper center", "south": "lower center", "best": "best",
}


def _mpl_loc(matlab_loc):
    """Translate a MATLAB legend location string to its matplotlib equivalent."""

    return _LEGEND_LOC_MAP.get(matlab_loc, "best")


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

    if lims is None:
        return
    lo, hi = lims
    getter = ax.get_yticks if axis == "y" else ax.get_xticks
    setter = ax.set_yticks if axis == "y" else ax.set_xticks
    set_lim = ax.set_ylim if axis == "y" else ax.set_xlim
    in_range_ticks = [tick for tick in getter().tolist() if lo <= tick <= hi]
    setter(sorted(set(in_range_ticks) | {lo, hi}))
    set_lim(lo, hi)


def _draw_time_panel(ax, combined_df, cell_list, cell_plot_list, label_list, colormap_list, marker_list,
                      plot_title, resistance_scale, resistance_label, y_limits, x_limits, plain_title,
                      legend_location, legend_fontsize, nudge_legend_up):
    """Draw the Time [days] vs resistance panel (background + highlighted cells + legend)."""

    for cell_name in cell_list:
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        current_cell = current_cell.sort_values("Timestamp")
        time_days = (current_cell["Timestamp"] - current_cell["Timestamp"].iloc[0]).dt.total_seconds() / 86400.0
        ax.plot(time_days, current_cell["Resistance [Ohm]"] * resistance_scale, linewidth=_LW_BACKGROUND, color=_GREY)

    handles, labels = [], []
    for idx, cell_name in enumerate(cell_plot_list):
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            print(f"Warning: Cell {cell_name} not found in data")
            continue
        current_cell = current_cell.sort_values("Timestamp")
        time_days = (current_cell["Timestamp"] - current_cell["Timestamp"].iloc[0]).dt.total_seconds() / 86400.0
        (handle,) = ax.plot(time_days, current_cell["Resistance [Ohm]"] * resistance_scale,
                             linewidth=_LW_HIGHLIGHT, color=colormap_list[idx], linestyle=marker_list[idx])
        handles.append(handle)
        labels.append(label_list[idx])

    if x_limits is not None:
        ax.set_xlim(x_limits)
        _add_boundary_ticks(ax, "x", x_limits)
    if plot_title:
        title_text = plot_title if plain_title else f"{plot_title} (vs Time)"
        ax.set_title(title_text, fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    ax.set_xlabel("Time [days]", fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    ax.set_ylabel(resistance_label, fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    if y_limits is not None:
        ax.set_ylim(y_limits)
        _add_boundary_ticks(ax, "y", y_limits)
        ax.yaxis.set_major_formatter(lambda value, _pos: f"{value:.2f}")
    _style_axes(ax)
    if handles:
        legend = ax.legend(handles, labels, loc=_mpl_loc(legend_location), frameon=False, fontsize=legend_fontsize)
        if nudge_legend_up:
            # MATLAB nudges this legend up by 0.06 normalized units so it clears the data
            # it would otherwise overlap (R-021 documented exception).
            bbox = legend.get_bbox_to_anchor().transformed(ax.transAxes.inverted())
            legend.set_bbox_to_anchor((bbox.x0, bbox.y0 + 0.06, bbox.width, bbox.height), transform=ax.transAxes)


def _draw_fec_panel(ax, combined_df, cell_list, cell_plot_list, label_list, colormap_list, marker_list,
                     plot_title, resistance_scale, resistance_label, y_limits, legend_location, legend_fontsize,
                     plain_title=False):
    """Draw the FEC vs resistance panel (background + highlighted cells + legend)."""

    for cell_name in cell_list:
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        ax.plot(current_cell["CheckupResistanceFEC"], current_cell["Resistance [Ohm]"] * resistance_scale,
                linewidth=_LW_BACKGROUND, color=_GREY)

    handles, labels = [], []
    max_fec_highlight = 0.0
    for idx, cell_name in enumerate(cell_plot_list):
        current_cell = combined_df[combined_df["cell_number"] == cell_name]
        if current_cell.empty:
            continue
        (handle,) = ax.plot(current_cell["CheckupResistanceFEC"], current_cell["Resistance [Ohm]"] * resistance_scale,
                             linewidth=_LW_HIGHLIGHT, color=colormap_list[idx], linestyle=marker_list[idx])
        handles.append(handle)
        labels.append(label_list[idx])
        if current_cell["CheckupResistanceFEC"].notna().any():
            max_fec_highlight = max(max_fec_highlight, float(current_cell["CheckupResistanceFEC"].max()))

    if max_fec_highlight > 0:
        ax.set_xlim(0, max_fec_highlight)
    if plot_title:
        title_text = plot_title if plain_title else f"{plot_title} (vs FEC)"
        ax.set_title(title_text, fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    ax.set_xlabel("Full Equivalent Cycles [cycles]", fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    ax.set_ylabel(resistance_label, fontsize=_PUB_FONTSIZE, fontname="Times New Roman")
    if y_limits is not None:
        ax.set_ylim(y_limits)
        _add_boundary_ticks(ax, "y", y_limits)
    ax.yaxis.set_major_formatter(lambda value, _pos: f"{value:.2f}")
    _style_axes(ax)
    if handles:
        ax.legend(handles, labels, loc=_mpl_loc(legend_location), frameon=False, fontsize=legend_fontsize)


def plot_resistance_increase_publication(combined_df, cell_list, cell_plot_list, label_list, colormap_list,
                                          marker_list, png_filename, pdf_filename, plot_title="", include_fec=True,
                                          legend_location="southwest", resistance_scale=1,
                                          resistance_label=_DEFAULT_LABEL, y_limits=None,
                                          use_plain_top_title=False, x_limits=None):
    """
    Build the resistance-increase publication figure: Time panel always,
    plus an FEC panel if include_fec=True (matches MATLAB
    plotResistanceIncreasePublication; used with include_fec=False for the
    Calendar Ageing Effect figure - fig. 11).
    """

    fig_width_cm = 7.90 if include_fec else 8.0962
    fig_height_cm = 8.8 if include_fec else 3.5190
    fig = plt.figure(figsize=(fig_width_cm / 2.54, fig_height_cm / 2.54))

    if include_fec:
        ax_top = fig.add_subplot(2, 1, 1)
        ax_bottom = fig.add_subplot(2, 1, 2)
    else:
        ax_top = fig.add_subplot(1, 1, 1)
        ax_bottom = None

    # R-021 exception: legend text is 1 pt smaller than the axis/caption text
    # for this function (unlike the FEC-only variant below).
    legend_fontsize = _PUB_FONTSIZE - 1

    _draw_time_panel(ax_top, combined_df, cell_list, cell_plot_list, label_list, colormap_list, marker_list,
                      plot_title, resistance_scale, resistance_label, y_limits, x_limits, use_plain_top_title,
                      legend_location, legend_fontsize, nudge_legend_up=True)

    if include_fec:
        _draw_fec_panel(ax_bottom, combined_df, cell_list, cell_plot_list, label_list, colormap_list, marker_list,
                         plot_title, resistance_scale, resistance_label, y_limits, legend_location, legend_fontsize)

    fig.tight_layout()
    fig.savefig(png_filename, dpi=300, bbox_inches="tight")
    fig.savefig(pdf_filename, bbox_inches="tight")
    print(f"Publication PDF saved: {pdf_filename}")
    plt.close(fig)


def plot_resistance_increase_publication_fec_only(combined_df, cell_list, cell_plot_list, label_list,
                                                    colormap_list, marker_list, png_filename, pdf_filename,
                                                    plot_title="", legend_location="southwest",
                                                    resistance_scale=1, resistance_label=_DEFAULT_LABEL,
                                                    y_limits=None):
    """Build the FEC-only resistance-increase publication figure (fig. 5)."""

    fig = plt.figure(figsize=(8.0962 / 2.54, 3.5190 / 2.54))
    ax = fig.add_subplot(1, 1, 1)
    _draw_fec_panel(ax, combined_df, cell_list, cell_plot_list, label_list, colormap_list, marker_list,
                     plot_title, resistance_scale, resistance_label, y_limits, legend_location, _PUB_FONTSIZE,
                     plain_title=True)
    fig.tight_layout()
    fig.savefig(png_filename, dpi=300, bbox_inches="tight")
    fig.savefig(pdf_filename, bbox_inches="tight")
    print(f"Publication PDF saved: {pdf_filename}")
    plt.close(fig)


__all__ = ["plot_resistance_increase_publication", "plot_resistance_increase_publication_fec_only"]
