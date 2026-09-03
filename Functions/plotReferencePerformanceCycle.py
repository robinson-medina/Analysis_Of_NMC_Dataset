"""
plotReferencePerformanceCycle - Publication-formatted overview plot (current,
voltage, temperature) for a user-selected Reference Performance Cycle (RPC)
time window, with zone boundaries/shading/labels.

Python counterpart of Functions/plotReferencePerformanceCycle.m (todo #010).

DECISION (documented per the "make decisions overnight" instruction, see
docs/todo.md #010 for full notes): the MATLAB source additionally renders two
pixel-level zoom insets (voltage + current) with hand-tuned connector lines,
delta-V/delta-I arrows and a C_RPT integration-window LaTeX annotation. That
logic depends on MATLAB-specific figure-pixel/TightInset bookkeeping
(uistack, getpixelposition, iterative stabilization loops) with no clean
matplotlib equivalent, and is purely decorative (does not change the
underlying data/curves). It is intentionally NOT ported here; only the core
3-panel RPC figure (current/voltage/temperature, zone shading, zone
boundaries, zone labels/arrows, shared styling, PDF export) is implemented.
This gap is tracked in docs/todo.md so it can be revisited on request.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24

Compliance: R-004, R-017, R-018, R-019, R-020, R-022.
"""

import os

import matplotlib
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# R-019: Times New Roman for every text element in journal-publication figures.
matplotlib.rcParams['font.family'] = 'serif'
matplotlib.rcParams['font.serif'] = ['Times New Roman']

# R-017 item 3: preferred publication colour palette (RGB 0-1).
_DARKBLUE = (1 / 255, 17 / 255, 181 / 255)
_RED = (1.0, 0.0, 0.0)
_BLACK = (0.0, 0.0, 0.0)
_GREY = (0.5, 0.5, 0.5)
_SHADE = (0.95, 0.95, 0.95)

PUB_FONTSIZE = 8  # R-021 default: paper caption (\footnotesize) size


def plot_reference_performance_cycle(time_with_gaps, current, voltage, cell_temp, chamber_temp,
                                      cumulative_integral, cell_num, cell_label, start_time, end_time,
                                      output_dir):
    """
    Create the RPC publication figure (current/voltage/temperature) zoomed to
    [start_time, end_time], with zone shading/boundaries/labels, and export it
    as a vector PDF to the R-022 directory supplied by its entry script.

    Parameters mirror the MATLAB signature exactly; cumulative_integral is
    accepted but unused (kept for call-site parity, capacity is not plotted
    in the RPC view).

    Returns
    -------
    fig : matplotlib.figure.Figure
    """

    del cumulative_integral  # kept for interface parity only, not plotted here

    # Normalise datetimes and swap if given in reverse order.
    start_time = pd.Timestamp(start_time)
    end_time = pd.Timestamp(end_time)
    if end_time < start_time:
        start_time, end_time = end_time, start_time

    time_with_gaps = pd.DatetimeIndex(time_with_gaps)
    current = np.asarray(current, dtype=float)
    voltage = np.asarray(voltage, dtype=float)
    cell_temp = np.asarray(cell_temp, dtype=float)
    chamber_temp = np.asarray(chamber_temp, dtype=float)

    # Mask to the requested zoom window (NaT comparisons are already False).
    valid_mask = (time_with_gaps >= start_time) & (time_with_gaps <= end_time) & ~pd.isna(time_with_gaps)
    time_plot = time_with_gaps[valid_mask]
    current_plot = current[valid_mask]
    voltage_plot = voltage[valid_mask]
    cell_temp_plot = cell_temp[valid_mask]
    chamber_temp_plot = chamber_temp[valid_mask]

    if len(time_plot) == 0:
        raise ValueError(f"No data points found in the requested RPC window [{start_time}, {end_time}].")

    # Trim any leading all-NaN rows (synthetic gap marker artefacts), then
    # prepend one synthetic sample at start_time so the trace starts flush
    # with the left x-limit instead of leaving visible blank space.
    leading_finite_mask = ~(np.isnan(current_plot) & np.isnan(voltage_plot)
                             & np.isnan(cell_temp_plot) & np.isnan(chamber_temp_plot))
    first_real_idx = np.argmax(leading_finite_mask) if leading_finite_mask.any() else None
    if first_real_idx is None:
        raise ValueError(f"No finite plotted samples found in the requested RPC window [{start_time}, {end_time}].")
    if first_real_idx > 0:
        time_plot = time_plot[first_real_idx:]
        current_plot = current_plot[first_real_idx:]
        voltage_plot = voltage_plot[first_real_idx:]
        cell_temp_plot = cell_temp_plot[first_real_idx:]
        chamber_temp_plot = chamber_temp_plot[first_real_idx:]
    if time_plot[0] > start_time:
        time_plot = pd.DatetimeIndex([start_time]).append(time_plot)
        current_plot = np.concatenate(([current_plot[0]], current_plot))
        voltage_plot = np.concatenate(([voltage_plot[0]], voltage_plot))
        cell_temp_plot = np.concatenate(([cell_temp_plot[0]], cell_temp_plot))
        chamber_temp_plot = np.concatenate(([chamber_temp_plot[0]], chamber_temp_plot))

    # R-021: double-column (figure*) sizing tuned so the tight-cropped export
    # is ~97% of \textwidth; preserves the MATLAB 17.4:10-ish aspect ratio.
    fig_w_cm, fig_h_cm = 18.91, 10.87
    fig, (ax1, ax2, ax3) = plt.subplots(
        3, 1, figsize=(fig_w_cm / 2.54, fig_h_cm / 2.54), sharex=True
    )
    fig.canvas.manager.set_window_title(f'{cell_num} - Reference Performance Cycle') if fig.canvas.manager else None

    # --- Panel 1: current -------------------------------------------------
    ax1.plot(time_plot, current_plot, color=_DARKBLUE, linewidth=1.0)
    ax1.set_ylabel('Current [A]', fontsize=PUB_FONTSIZE)
    ax1.grid(True)
    for spine in ax1.spines.values():
        spine.set_visible(True)
        spine.set_linewidth(0.8)
    ax1.set_axisbelow(False)  # keep gridlines on top of shading (R-017-equivalent 'Layer'=top)

    # --- Panel 2: voltage ---------------------------------------------------
    ax2.plot(time_plot, voltage_plot, color=_DARKBLUE, linewidth=1.0)
    ax2.set_ylabel('Voltage [V]', fontsize=PUB_FONTSIZE)
    ax2.grid(True)
    for spine in ax2.spines.values():
        spine.set_visible(True)
        spine.set_linewidth(0.8)

    # --- Panel 3: cell + chamber temperature --------------------------------
    (h_cell,) = ax3.plot(time_plot, cell_temp_plot, color=_DARKBLUE, linewidth=1.0, label='Cell')
    (h_chamber,) = ax3.plot(time_plot, chamber_temp_plot, color=_RED, linewidth=1.0, label='Chamber')
    ax3.set_ylabel('Temperature [\u00b0C]', fontsize=PUB_FONTSIZE)
    ax3.legend([h_cell, h_chamber], ['Cell', 'Chamber'], loc='lower left',
               frameon=False, fontsize=PUB_FONTSIZE)  # R-017 item 5: frameless legend
    ax3.grid(True)
    for spine in ax3.spines.values():
        spine.set_visible(True)
        spine.set_linewidth(0.8)
    ax3.set_xlabel('Time', fontsize=PUB_FONTSIZE)

    all_axes = [ax1, ax2, ax3]
    for ax in all_axes:
        ax.set_xlim(start_time, end_time)
        ax.tick_params(labelsize=PUB_FONTSIZE)
        for label in ax.get_xticklabels() + ax.get_yticklabels():
            label.set_fontname('Times New Roman')

    # --- Zone boundaries/shading/labels -------------------------------------
    zone1_start_time = pd.Timestamp(2024, 4, 23, 11, 15, 59)
    zone1_end_time = pd.Timestamp(2024, 4, 24, 0, 14, 59)
    zone2_end_time = pd.Timestamp(2024, 4, 28, 3, 12, 5)
    zone3_end_time = pd.Timestamp(2024, 4, 29, 3, 4, 16)
    zone4_end_time = pd.Timestamp(2024, 4, 29, 22, 3, 25)

    zone_window_start = max(zone1_start_time, start_time)
    zone_window_end = min(zone4_end_time, end_time)
    if zone_window_end < zone_window_start:
        zone_window_start, zone_window_end = zone_window_end, zone_window_start

    internal_boundaries = sorted([zone1_end_time, zone2_end_time, zone3_end_time])
    internal_boundaries = [max(b, zone_window_start) for b in internal_boundaries]
    internal_boundaries = [min(b, zone_window_end) for b in internal_boundaries]

    zone_edges = [zone_window_start] + internal_boundaries + [zone_window_end]
    zone_labels = ['Initialization', 'C/50 (dis) charge cycle', 'Pulses', 'Drive cycle']

    # Vertical dashed boundary lines on every subplot at each internal boundary.
    for boundary_time in internal_boundaries:
        for ax in all_axes:
            ax.axvline(boundary_time, linestyle='--', color=_GREY, linewidth=0.75)

    # Freeze y-limits now (before shading/arrows) so nothing autoscales later.
    ylims = {ax: ax.get_ylim() for ax in all_axes}
    for ax in all_axes:
        ax.set_ylim(ylims[ax])

    # Optional zone 0: shaded preamble before zone_window_start (no label/arrow).
    if zone_window_start > start_time:
        for ax in all_axes:
            ax.axvspan(start_time, zone_window_start, color=_SHADE, zorder=0)

    # Shade every other zone (2nd and 4th) for visual separation.
    for zone_idx in range(4):
        if (zone_idx + 1) % 2 == 0:
            zone_start, zone_end = zone_edges[zone_idx], zone_edges[zone_idx + 1]
            for ax in all_axes:
                ax.axvspan(zone_start, zone_end, color=_SHADE, zorder=0)

    # Re-plot traces on top of the shaded regions so lines stay dominant.
    ax1.plot(time_plot, current_plot, '-', color=_DARKBLUE, linewidth=1.0, zorder=3)
    ax2.plot(time_plot, voltage_plot, '-', color=_DARKBLUE, linewidth=1.0, zorder=3)
    ax3.plot(time_plot, chamber_temp_plot, '-', color=_RED, linewidth=1.0, zorder=3)
    ax3.plot(time_plot, cell_temp_plot, '-', color=_DARKBLUE, linewidth=1.0, zorder=3)

    # Zone double-headed arrows + centered labels, drawn above ax1 (top panel),
    # matching the combined-characterization-figure placement convention.
    y_lim_current = ylims[ax1]
    y_range_current = y_lim_current[1] - y_lim_current[0]
    y_pos_arrow = y_lim_current[1] + 0.06 * y_range_current
    y_pos_label = y_lim_current[1] + 0.14 * y_range_current

    window_days = (end_time - start_time).total_seconds() / 86400.0
    arrow_inset = pd.Timedelta(days=0.01 * window_days)

    for zone_idx in range(4):
        zone_start, zone_end = zone_edges[zone_idx], zone_edges[zone_idx + 1]
        zone_mid = zone_start + (zone_end - zone_start) / 2

        x_left = zone_start + arrow_inset
        x_right = zone_end - arrow_inset
        if x_right <= x_left:
            x_left, x_right = zone_start, zone_end

        # Double-headed arrow shaft + heads (matplotlib '<->' arrowstyle).
        ax1.annotate(
            '', xy=(x_right, y_pos_arrow), xytext=(x_left, y_pos_arrow),
            xycoords='data', textcoords='data', annotation_clip=False,
            arrowprops=dict(arrowstyle='<->', color=_BLACK, linewidth=0.75, shrinkA=0, shrinkB=0),
        )
        # Zone label centered above its arrow.
        ax1.annotate(
            zone_labels[zone_idx], xy=(zone_mid, y_pos_label), xycoords='data',
            ha='center', va='bottom', fontsize=PUB_FONTSIZE, fontname='Times New Roman',
            annotation_clip=False,
        )

    fig.subplots_adjust(top=0.85, hspace=0.35)  # reserve headroom for zone labels/arrows

    # --- Export as vector PDF to the caller-owned R-022 directory ---------
    pdf_path = os.path.join(output_dir, 'NextBMS_ReferencePerformanceCycle.pdf')
    fig.savefig(pdf_path, bbox_inches='tight')
    print(f'RPC PDF saved: {pdf_path}')

    return fig


__all__ = ['plot_reference_performance_cycle']
