"""
Summary: Extract OCP-like lookup lines from GITT datasets for anode/cathode,
then scale/interpolate and merge each half-cell GITT profile with its slow
charge/discharge curve into one two-panel publication figure: panel (a) is
the graphite anode, panel (b) the NMC532 cathode (R-024). Anode data is
sourced from one combined anode CSV file containing both modes.

Python counterpart of matlab_scripts/extractOCPLines.m (todo #022). Ported
2026-08-25 to match the CURRENT MATLAB source (single combined
`OCP_HalfCell.pdf` two-panel figure), which supersedes the older separate
`Anode.pdf`/`Cathode.pdf` architecture the previous Python port targeted.

Produces: Vector figure 'OCP_HalfCell.pdf' (+ .png at the same stem) plus
per-figure PNG snapshots in the script-owned R-022 directory. No .fig/.mat
files are written.

Author: Copilot
Date: 2026-08-25
Inputs/Outputs: Reads anode/cathode CSV files with DateTime, TestTime, Current,
and Voltage columns, plus 4 slow charge/discharge CSVs; writes the combined
publication PDF/PNG, per-electrode diagnostic PNGs, and optionally the
combined anode/cathode SoC-vs-voltage tables to CSV.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Tuple

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from matplotlib.lines import Line2D
from scipy.integrate import cumulative_trapezoid
from scipy.interpolate import PchipInterpolator

# Register the shared resolver from either the JournalScripts staging layout or the public layout.
SCRIPT_DIR = Path(__file__).resolve().parent
FUNCTIONS_CANDIDATES = (SCRIPT_DIR.parent.parent / "Functions", SCRIPT_DIR.parent / "Functions")
for FUNCTIONS_DIR in FUNCTIONS_CANDIDATES:
    if FUNCTIONS_DIR.exists():
        if str(FUNCTIONS_DIR) not in sys.path:
            sys.path.append(str(FUNCTIONS_DIR))
        break
else:
    raise FileNotFoundError(f"Shared Functions folder not found from {SCRIPT_DIR}")

from get_figure_output_dir import get_figure_output_dir  # noqa: E402

CURRENT_STEP_THRESHOLD_A = 1e-6
INTERPOLATION_POINT_COUNT = 100  # matches MATLAB's linspace(qMin, qMax, 100)

# ACTIVE MATERIAL MASSES [g] - used to convert the slow charge/discharge CSVs'
# specific-capacity column (mAh/g) to an absolute mAh throughput axis.
MASS_ANODE_G = 0.01668
MASS_CATHODE_G = 0.03553

DEFAULT_ANODE_LOCAL = "NEXTMBS-full-charge-discharge-GITT-full0charge-discharge-NMC-anode.csv"
DEFAULT_CATHODE_LOCAL = "NEXTMBS-full-charge-discharge-GITT-full0charge-discharge-NMC-cathode.csv"
# DataRoot: single switch to the dataset root holding 1_Teardown/2_HalfCell/
# 3_Characterization/4_Ageing. Change this one line to retarget the script.
DATA_ROOT = Path(r"\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot")
OCP_ROOT = DATA_ROOT / "2_HalfCell" / "OCP_data"
DEFAULT_ANODE_NETWORK = OCP_ROOT / "Anode_Graphite" / DEFAULT_ANODE_LOCAL
DEFAULT_CATHODE_NETWORK = OCP_ROOT / "Cathode_NMC532" / DEFAULT_CATHODE_LOCAL

# R-017 publication palette (RGB 0-1).
COL_DARK_BLUE = (1 / 255, 17 / 255, 181 / 255)
COL_RED = (1.0, 0.0, 0.0)
COL_BLACK = (0.0, 0.0, 0.0)
COL_GREEN = (12 / 255, 195 / 255, 82 / 255)  # defined for palette parity; unused (matches MATLAB's unused colGreen)
# Dimmed variants (65% base colour + 35% white) so the GITT traces read as a
# lighter-intensity overlay behind the solid slow charge/discharge lines.
COL_RED_LIGHT = tuple(0.65 * np.array(COL_RED) + 0.35 * np.array([1.0, 1.0, 1.0]))
COL_DARK_BLUE_LIGHT = tuple(0.65 * np.array(COL_DARK_BLUE) + 0.35 * np.array([1.0, 1.0, 1.0]))

PUB_FONT = "Times New Roman"
PUB_FONTSIZE = 8  # R-021 default: paper caption size


def parse_arguments() -> argparse.Namespace:
    """Parse command-line arguments for reproducible script execution."""

    project_root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser(description="Extract OCP-like lookup lines from GITT CSV files.")
    parser.add_argument(
        "--anode-csv",
        type=Path,
        default=project_root / DEFAULT_ANODE_LOCAL,
        help="Path to the combined anode GITT CSV file.",
    )
    parser.add_argument(
        "--cathode-csv",
        type=Path,
        default=project_root / DEFAULT_CATHODE_LOCAL,
        help="Path to the combined cathode GITT CSV file.",
    )
    parser.add_argument(
        "--png-dir",
        type=Path,
        default=get_figure_output_dir("extractOCPLines"),
        help="Directory where diagnostic and publication figures are written.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=project_root,
        help="Directory for optional combined CSV exports.",
    )
    parser.add_argument(
        "--export-csv",
        action="store_true",
        help="Write combined anode/cathode SoC-vs-voltage tables to CSV.",
    )
    parser.add_argument(
        "--no-show-figures",
        action="store_true",
        help="Skip opening figure windows after saving PNG outputs.",
    )
    return parser.parse_args()


def resolve_input_path(requested_path: Path, fallback_path: Path) -> Path:
    """Resolve a local project path first, then fall back to the original network path."""

    for candidate_path in (requested_path, fallback_path):
        if candidate_path.exists():
            return candidate_path

    expected_paths = "\n".join(f"  - {path}" for path in (requested_path, fallback_path))
    raise FileNotFoundError(f"Input file not found. Checked the following locations:\n{expected_paths}")


def _normalize_column_name(column_name: str) -> str:
    """Lowercase and strip non-alphanumerics so header variants compare equal."""

    return re.sub(r"[^a-z0-9]", "", str(column_name).lower())


def load_ocp_table(csv_path: Path) -> pd.DataFrame:
    """Load and validate a GITT CSV file (columns: TestTime, Current, Voltage)."""

    table = pd.read_csv(csv_path, encoding="utf-8-sig", low_memory=False)

    # Support both raw export headers (e.g. "Test Time") and MATLAB-style
    # names ("TestTime") produced by readtable's automatic sanitisation.
    canonical_aliases = {
        "TestTime": ["TestTime", "Test Time", "test_time"],
        "Current": ["Current", "Current(A)", "current"],
        "Voltage": ["Voltage", "Voltage(V)", "voltage"],
    }
    # Keep the FIRST column mapping to each normalized name so a raw export's
    # "Test Time" (seconds) wins over a derived "TestTime" (hours) duplicate,
    # matching MATLAB readtable. The throughput integral divides by 3600
    # assuming SECONDS, so picking the hours column made every GITT throughput
    # 3600x too small and collapsed the GITT curves to x=0 (#114).
    normalized_to_actual = {}
    for actual_column in table.columns:
        normalized_to_actual.setdefault(_normalize_column_name(actual_column), actual_column)
    rename_map = {}
    for canonical_name, aliases in canonical_aliases.items():
        for alias in aliases:
            actual = normalized_to_actual.get(_normalize_column_name(alias))
            if actual is not None:
                rename_map[actual] = canonical_name
                break
    table = table.rename(columns=rename_map)
    # After the rename both "Test Time" and "TestTime" become "TestTime"; keep
    # the first (the seconds column) and drop the later hours duplicate (#114).
    table = table.loc[:, ~table.columns.duplicated(keep="first")]

    for column_name in ("TestTime", "Current", "Voltage"):
        if column_name not in table.columns:
            raise ValueError(f"{csv_path} is missing required column '{column_name}'.")
        table[column_name] = pd.to_numeric(table[column_name], errors="coerce")

    filtered_table = table.dropna(subset=["TestTime", "Current", "Voltage"]).reset_index(drop=True)
    if filtered_table.empty:
        raise ValueError(f"{csv_path} contains no valid numeric rows after filtering.")
    return filtered_table


def find_transition_indices(current_a: np.ndarray, direction: str) -> np.ndarray:
    """Detect pulse boundary indices (0-based), matching MATLAB's find(diff(current)...)."""

    current_diff = np.diff(current_a)
    if direction == "positive":
        transition_indices = np.flatnonzero(current_diff > CURRENT_STEP_THRESHOLD_A)
    elif direction == "negative":
        transition_indices = np.flatnonzero(current_diff < -CURRENT_STEP_THRESHOLD_A)
    else:
        raise ValueError(f"Unsupported direction: {direction}")

    if transition_indices.size == 0:
        raise ValueError("No current-step transitions were detected in the selected phase.")
    return transition_indices


def process_delithiation_phase(
    time_s: np.ndarray, current_a: np.ndarray, voltage_v: np.ndarray, idx: np.ndarray, start_offset: int
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """
    Integrate throughput and extract Q/V boundary points for a delithiation
    (positive-current) GITT phase.

    Mirrors MATLAB's `time(index(k+1):index(end)+50)` windowing, where
    start_offset = k (e.g. 2 for anode delithiation, 1 for cathode
    delithiation, using MATLAB's 1-based `index(3)`/`index(2)`).

    Returns (throughput_ah, full_voltage_v, boundary_q_ah, boundary_v).
    """

    s = idx[start_offset]
    e = idx[-1] + 50
    throughput_ah = cumulative_trapezoid(current_a[s:e + 1], time_s[s:e + 1], initial=0.0) / 3600.0
    full_voltage_v = voltage_v[s:e + 1]

    q_positions = np.concatenate([idx[start_offset:] - s, [len(throughput_ah) - 1]])
    boundary_q_ah = throughput_ah[q_positions]
    v_positions = np.concatenate([idx[start_offset:], [idx[-1] + 50]])
    boundary_v = voltage_v[v_positions]
    return throughput_ah, full_voltage_v, boundary_q_ah, boundary_v


def process_lithiation_phase(
    time_s: np.ndarray, current_a: np.ndarray, voltage_v: np.ndarray, idx: np.ndarray
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """
    Integrate throughput and extract Q/V boundary points for a lithiation
    (negative-current) GITT phase, mirroring MATLAB's `time(index(1):end)`
    windowing on the absolute current.

    Returns (throughput_ah, full_voltage_v, boundary_q_ah, boundary_v).
    """

    s = idx[0]
    throughput_ah = cumulative_trapezoid(np.abs(current_a[s:]), time_s[s:], initial=0.0) / 3600.0
    full_voltage_v = voltage_v[s:]

    q_positions = np.concatenate([idx - s, [len(throughput_ah) - 1]])
    boundary_q_ah = throughput_ah[q_positions]
    v_positions = np.concatenate([idx, [len(voltage_v) - 1]])
    boundary_v = voltage_v[v_positions]
    return throughput_ah, full_voltage_v, boundary_q_ah, boundary_v


def interpolate_profile(boundary_q_ah: np.ndarray, boundary_v: np.ndarray,
                         n_points: int = INTERPOLATION_POINT_COUNT) -> Tuple[np.ndarray, np.ndarray]:
    """
    PCHIP-interpolate boundary Q/V points onto n_points evenly spaced over
    [min(Q), max(Q)], matching MATLAB's `linspace(qMin,qMax,100)` +
    `interp1(Q,V,Qsave,'pchip')`.
    """

    order = np.argsort(boundary_q_ah)
    q_sorted = np.asarray(boundary_q_ah)[order]
    v_sorted = np.asarray(boundary_v)[order]
    q_unique, unique_idx = np.unique(q_sorted, return_index=True)
    v_unique = v_sorted[unique_idx]
    if q_unique.size < 2:
        raise ValueError("Insufficient unique capacity points for interpolation.")

    q_save = np.linspace(np.min(boundary_q_ah), np.max(boundary_q_ah), n_points)
    interpolator = PchipInterpolator(q_unique, v_unique, extrapolate=True)
    v_save = interpolator(q_save)
    return q_save, v_save


def _plot_steps_tile(ax, time_s: np.ndarray, current_a: np.ndarray, voltage_v: np.ndarray,
                      idx: np.ndarray, title: str) -> None:
    """Twin-axis current/voltage-vs-time tile with detected-step markers (MATLAB yyaxis)."""

    ax_voltage = ax.twinx()
    (h_current,) = ax.plot(time_s, current_a, color="tab:blue")
    h_current_steps = ax.scatter(time_s[idx], current_a[idx], color="tab:blue")
    ax.set_ylabel("Current (A)")
    (h_voltage,) = ax_voltage.plot(time_s, voltage_v, color="tab:orange")
    ax_voltage.scatter(time_s[idx], voltage_v[idx], color="tab:orange")
    ax_voltage.set_ylabel("Voltage (V)")
    ax.set_title(title)
    ax.set_xlabel("Time (s)")
    ax.legend([h_current, h_voltage, h_current_steps], ["Current", "Voltage", "Detected step indices"], loc="best")


def _plot_boundary_tile(ax, boundary_q_ah: np.ndarray, boundary_v: np.ndarray, throughput_ah: np.ndarray,
                         full_voltage_v: np.ndarray, interp_q_ah: np.ndarray, interp_v: np.ndarray,
                         title: str) -> None:
    """Boundary-points-vs-full-throughput-trajectory QC tile."""

    ax.plot(boundary_q_ah, boundary_v, "o-")
    ax.plot(throughput_ah, full_voltage_v)
    ax.plot(interp_q_ah, interp_v)
    ax.set_title(title)
    ax.set_xlabel("Capacity / Throughput (Ah)")
    ax.set_ylabel("Voltage (V)")
    ax.legend(["Boundary points", "Full throughput trajectory", "Interpolated profile (100 pts)"], loc="best")


def build_diagnostics_figure(figure_name: str, electrode_label: str, delith: dict, lith: dict, png_dir: Path):
    """Build and save the 2x2 tiled GITT-detection diagnostics figure for one electrode."""

    fig, axes = plt.subplots(2, 2, figsize=(1324 / 96, 839 / 96))
    if fig.canvas.manager is not None:
        fig.canvas.manager.set_window_title(figure_name)
    _plot_steps_tile(axes[0, 0], delith["time"], delith["current"], delith["voltage"], delith["idx"],
                      f"{electrode_label} Delithiation: Detected Steps")
    _plot_boundary_tile(axes[0, 1], delith["q"], delith["v"], delith["throughput"], delith["full_voltage"],
                         delith["qsave"], delith["vsave"],
                         f"{electrode_label} Delithiation: Boundary Points vs Full Throughput Curve")
    _plot_steps_tile(axes[1, 0], lith["time"], lith["current"], lith["voltage"], lith["idx"],
                      f"{electrode_label} Lithiation: Detected Steps")
    _plot_boundary_tile(axes[1, 1], lith["q"], lith["v"], lith["throughput"], lith["full_voltage"],
                         lith["qsave"], lith["vsave"],
                         f"{electrode_label} Lithiation: Boundary Points vs Full Throughput Curve")
    fig.tight_layout()

    # Save explicitly here (R-022): matplotlib's ax.twinx() (used for the
    # steps tiles) adds extra untitled axes to fig.axes, which would break a
    # generic "grab the last axes' title" filename-sniffing save loop (MATLAB
    # has no such issue since yyaxis keeps one Axes object per tile).
    png_dir.mkdir(parents=True, exist_ok=True)
    output_path = png_dir / f"{sanitize_filename(figure_name)}.png"
    fig.savefig(output_path, dpi=150, bbox_inches="tight")
    print(f"  Saved: {output_path}")
    return fig


def build_combined_table(qsave_delith: np.ndarray, vsave_delith: np.ndarray,
                          qsave_lith: np.ndarray, vsave_lith: np.ndarray, qmax_ah: float) -> pd.DataFrame:
    """Combine lithiation/delithiation interpolated profiles into one SoC-vs-voltage table."""

    return pd.DataFrame({
        "Mode": np.concatenate([np.repeat("Delithiation", len(qsave_delith)), np.repeat("Lithiation", len(qsave_lith))]),
        "SoC(-)": np.concatenate([qsave_delith / qmax_ah, qsave_lith / qmax_ah]),
        "Voltage(V)": np.concatenate([vsave_delith, vsave_lith]),
    })


def _process_electrode(csv_path: Path, label: str, delith_start_offset: int, png_dir: Path,
                       delith_drop: str = "last") -> dict:
    """Run the full delithiation+lithiation extraction pipeline for one electrode."""

    raw_table = load_ocp_table(csv_path)
    print(f"  Loaded {len(raw_table)} rows from {csv_path}")

    # --- Delithiation (positive current) ---
    delith_table = raw_table.loc[raw_table["Current"] >= 0.0].reset_index(drop=True)
    time_d = delith_table["TestTime"].to_numpy()
    current_d = delith_table["Current"].to_numpy()
    voltage_d = delith_table["Voltage"].to_numpy()
    idx_d = find_transition_indices(current_d, "positive")
    # Electrode-specific first/last transition drop, matching MATLAB
    # extractOCPLines.m: anode delith uses index(1:end-1) (drop last), cathode
    # delith uses index(2:end) (drop first). Dropping the wrong end put the
    # cathode's first GITT boundary one pulse too early (pre-pulse rest, #114).
    idx_d = idx_d[1:] if delith_drop == "first" else idx_d[:-1]
    throughput_d, full_voltage_d, q_d, v_d = process_delithiation_phase(
        time_d, current_d, voltage_d, idx_d, delith_start_offset)
    qsave_d, vsave_d = interpolate_profile(q_d, v_d)

    # --- Lithiation (negative current) ---
    lith_table = raw_table.loc[raw_table["Current"] <= 0.0].reset_index(drop=True)
    time_l = lith_table["TestTime"].to_numpy()
    current_l = lith_table["Current"].to_numpy()
    voltage_l = lith_table["Voltage"].to_numpy()
    idx_l = find_transition_indices(current_l, "negative")
    idx_l = idx_l[1:]  # drop first transition (matches MATLAB index(2:end))
    throughput_l, full_voltage_l, q_l, v_l = process_lithiation_phase(time_l, current_l, voltage_l, idx_l)
    qsave_l, vsave_l = interpolate_profile(q_l, v_l)

    print(f"  Done. {len(qsave_d)} interpolated points, Q range [{qsave_d.min():.1f}, {qsave_d.max():.1f}] Ah")
    print(f"  Done. {len(qsave_l)} interpolated points, Q range [{qsave_l.min():.1f}, {qsave_l.max():.1f}] Ah")

    delith = {"time": time_d, "current": current_d, "voltage": voltage_d, "idx": idx_d,
              "throughput": throughput_d, "full_voltage": full_voltage_d, "q": q_d, "v": v_d,
              "qsave": qsave_d, "vsave": vsave_d}
    lith = {"time": time_l, "current": current_l, "voltage": voltage_l, "idx": idx_l,
            "throughput": throughput_l, "full_voltage": full_voltage_l, "q": q_l, "v": v_l,
            "qsave": qsave_l, "vsave": vsave_l}

    build_diagnostics_figure(f"{label} GITT Detection Diagnostics", label, delith, lith, png_dir)
    qmax = float(max(np.max(qsave_d), np.max(qsave_l)))
    combined_table = build_combined_table(qsave_d, vsave_d, qsave_l, vsave_l, qmax)
    return {"delith": delith, "lith": lith, "qmax": qmax, "table": combined_table}


def _style_publication_axes(ax) -> None:
    """Apply R-017/R-019/R-021 styling to one publication axes."""

    ax.grid(True)
    for spine in ax.spines.values():
        spine.set_visible(True)
        spine.set_linewidth(0.8)
    ax.tick_params(labelsize=PUB_FONTSIZE)
    for tick_label in ax.get_xticklabels() + ax.get_yticklabels():
        tick_label.set_fontname(PUB_FONT)


def _plot_gitt_panel(ax, throughput_del_ah: np.ndarray, full_voltage_del: np.ndarray,
                      q_del_ah: np.ndarray, v_del: np.ndarray,
                      throughput_lith_ah: np.ndarray, full_voltage_lith: np.ndarray,
                      q_lith_ah: np.ndarray, v_lith: np.ndarray):
    """
    Draw the dashed GITT delithiation/lithiation lines + boundary markers on one
    publication panel. The delithiation trace/markers are mirrored about their
    own max (mAh) so they read right-to-left down to 0; lithiation is left as-is.

    Returns (legend_proxy_delithiation, legend_proxy_lithiation).
    """

    x_gitt_del = throughput_del_ah * 1000
    q_gitt_del = q_del_ah * 1000
    m_gitt_del = max(np.max(x_gitt_del), np.max(q_gitt_del))

    ax.plot(m_gitt_del - x_gitt_del, full_voltage_del, "--", color=COL_RED_LIGHT, linewidth=0.6, zorder=2)
    ax.plot(throughput_lith_ah * 1000, full_voltage_lith, "--", color=COL_DARK_BLUE_LIGHT, linewidth=0.6, zorder=2)
    ax.plot(m_gitt_del - q_gitt_del, v_del, "o", color=COL_RED_LIGHT, markerfacecolor=COL_RED_LIGHT,
            markersize=1.5, linestyle="none", zorder=3)
    ax.plot(q_lith_ah * 1000, v_lith, "o", color=COL_DARK_BLUE_LIGHT, markerfacecolor=COL_DARK_BLUE_LIGHT,
            markersize=1.5, linestyle="none", zorder=3)

    # Legend-only proxy handles combining the dashed GITT line with its relaxation marker.
    proxy_del = Line2D([], [], linestyle="--", color=COL_RED_LIGHT, linewidth=0.6,
                        marker="o", markersize=3, markerfacecolor=COL_RED_LIGHT)
    proxy_lith = Line2D([], [], linestyle="--", color=COL_DARK_BLUE_LIGHT, linewidth=0.6,
                         marker="o", markersize=3, markerfacecolor=COL_DARK_BLUE_LIGHT)
    return proxy_del, proxy_lith


def main() -> Tuple[pd.DataFrame, pd.DataFrame]:
    """Execute the full OCP extraction workflow and return the combined tables."""

    args = parse_arguments()
    print("--- extractOCPLines started ---")

    anode_csv = resolve_input_path(args.anode_csv, DEFAULT_ANODE_NETWORK)
    cathode_csv = resolve_input_path(args.cathode_csv, DEFAULT_CATHODE_NETWORK)

    print("[1/7] Anode: extracting delithiation + lithiation GITT profiles...")
    anode = _process_electrode(anode_csv, "Anode", delith_start_offset=2, png_dir=args.png_dir,
                               delith_drop="last")

    print("[2/7] Cathode: extracting delithiation + lithiation GITT profiles...")
    cathode = _process_electrode(cathode_csv, "Cathode", delith_start_offset=1, png_dir=args.png_dir,
                                 delith_drop="first")

    print(f"[3/7] Combined tables built: T_anode ({len(anode['table'])} rows), "
          f"T_cathode ({len(cathode['table'])} rows)")

    if args.export_csv:
        args.output_dir.mkdir(parents=True, exist_ok=True)
        anode_output = args.output_dir / "GITT_anode_combined.csv"
        cathode_output = args.output_dir / "GITT_cathode_combined.csv"
        anode["table"].to_csv(anode_output, index=False)
        cathode["table"].to_csv(cathode_output, index=False)
        print(f"  Wrote: {anode_output}")
        print(f"  Wrote: {cathode_output}")

    # --- Publication figure: one combined two-panel PDF (R-024) -------------
    print("[4/7] Building the combined anode/cathode publication figure...")
    pub_fig_width_cm, pub_fig_height_cm = 9.24, 6.60
    fig_pub, (ax_anode, ax_cathode) = plt.subplots(
        2, 1, figsize=(pub_fig_width_cm / 2.54, pub_fig_height_cm / 2.54))

    proxy_del_a, proxy_lith_a = _plot_gitt_panel(
        ax_anode, anode["delith"]["throughput"], anode["delith"]["full_voltage"],
        anode["delith"]["q"], anode["delith"]["v"],
        anode["lith"]["throughput"], anode["lith"]["full_voltage"],
        anode["lith"]["q"], anode["lith"]["v"])
    ax_anode.set_ylabel("Voltage [V]", fontname=PUB_FONT, fontsize=PUB_FONTSIZE)
    ax_anode.set_xlim(0, 5)
    ax_anode.set_ylim(0, 0.6)
    _style_publication_axes(ax_anode)
    ax_anode.text(0.02, 0.96, "(a)", transform=ax_anode.transAxes, fontname=PUB_FONT,
                  fontsize=PUB_FONTSIZE, ha="left", va="top")

    proxy_del_c, proxy_lith_c = _plot_gitt_panel(
        ax_cathode, cathode["delith"]["throughput"], cathode["delith"]["full_voltage"],
        cathode["delith"]["q"], cathode["delith"]["v"],
        cathode["lith"]["throughput"], cathode["lith"]["full_voltage"],
        cathode["lith"]["q"], cathode["lith"]["v"])
    ax_cathode.set_xlim(0, 6.2)
    ax_cathode.set_ylim(2.5, 4.5)
    ax_cathode.set_xlabel("Throughput [mAh]", fontname=PUB_FONT, fontsize=PUB_FONTSIZE)
    ax_cathode.set_ylabel("Voltage [V]", fontname=PUB_FONT, fontsize=PUB_FONTSIZE)
    _style_publication_axes(ax_cathode)
    ax_cathode.text(0.02, 0.96, "(b)", transform=ax_cathode.transAxes, fontname=PUB_FONT,
                     fontsize=PUB_FONTSIZE, ha="left", va="top")
    # No legend on panel (b) (user decision, MATLAB source 2026-08-13): the
    # single legend on panel (a) covers both panels.

    # --- Slow charge/discharge overlay (solid lines, both panels) -----------
    print("[5/7] Slow charge/discharge: overlaying anode and cathode curves...")
    anode_dir = anode_csv.parent
    cathode_dir = cathode_csv.parent
    t_anode_charge = pd.read_csv(anode_dir / "anode_NExtBMS_fCharge.csv")
    t_anode_discharge = pd.read_csv(anode_dir / "anode_NExtBMS_fDischarge.csv")
    t_cathode_charge = pd.read_csv(cathode_dir / "cathode_NExtBMS_fCharge.csv")
    t_cathode_discharge = pd.read_csv(cathode_dir / "cathode_NExtBMS_fDischarge.csv")

    # Anode: mirror the slow delithiation (charge) x-axis about its own max (mAh),
    # independently from the GITT delithiation mirror above.
    x_slow_del_anode = t_anode_charge.iloc[:, 0].to_numpy() * MASS_ANODE_G
    m_slow_del_anode = np.max(x_slow_del_anode)
    h_anode_charge, = ax_anode.plot(m_slow_del_anode - x_slow_del_anode, t_anode_charge.iloc[:, 1].to_numpy(),
                                     "-", color=COL_RED, linewidth=1.0, zorder=1)
    h_anode_discharge, = ax_anode.plot(t_anode_discharge.iloc[:, 0].to_numpy() * MASS_ANODE_G,
                                        t_anode_discharge.iloc[:, 1].to_numpy(),
                                        "-", color=COL_DARK_BLUE, linewidth=1.0, zorder=1)
    # Single shared legend for the whole figure, on panel (a), upper-right.
    ax_anode.legend([proxy_del_a, proxy_lith_a, h_anode_charge, h_anode_discharge],
                     ["GITT delithiation", "GITT lithiation", "Slow delithiation", "Slow lithiation"],
                     loc="upper right", frameon=False, fontsize=PUB_FONTSIZE, prop={"family": PUB_FONT})

    x_slow_del_cathode = t_cathode_charge.iloc[:, 0].to_numpy() * MASS_CATHODE_G
    m_slow_del_cathode = np.max(x_slow_del_cathode)
    ax_cathode.plot(m_slow_del_cathode - x_slow_del_cathode, t_cathode_charge.iloc[:, 1].to_numpy(),
                     "-", color=COL_RED, linewidth=1.0, zorder=1)
    ax_cathode.plot(t_cathode_discharge.iloc[:, 0].to_numpy() * MASS_CATHODE_G,
                     t_cathode_discharge.iloc[:, 1].to_numpy(),
                     "-", color=COL_DARK_BLUE, linewidth=1.0, zorder=1)
    # Cathode legend intentionally omitted (see panel (a) note above).

    fig_pub.tight_layout()

    save_dir = args.png_dir
    save_dir.mkdir(parents=True, exist_ok=True)
    pdf_file_ocp = save_dir / "OCP_HalfCell.pdf"
    png_file_ocp = save_dir / "OCP_HalfCell.png"
    fig_pub.savefig(pdf_file_ocp, bbox_inches="tight")
    print(f"OCP half-cell publication PDF saved: {pdf_file_ocp}")
    fig_pub.savefig(png_file_ocp, dpi=300, bbox_inches="tight")
    print(f"OCP half-cell publication PNG saved: {png_file_ocp}")

    print("[6/7] Diagnostic figures already saved to pngs/ (see [1/7]/[2/7] above).")

    if not args.no_show_figures:
        print("[7/7] Showing figures in non-blocking mode...")
        plt.show(block=False)
        plt.pause(0.1)

    print("--- extractOCPLines complete ---")
    return anode["table"], cathode["table"]


def sanitize_filename(title_text: str) -> str:
    """Convert a figure title into a filesystem-safe PNG filename."""

    safe_title = re.sub(r"[^\w\s-]", "", title_text)
    safe_title = re.sub(r"\s+", "_", safe_title.strip())
    return safe_title or "figure"


if __name__ == "__main__":
    main()
