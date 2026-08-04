"""
Summary: Extract OCP-like lookup lines from anode and cathode GITT datasets,
build interpolated profiles, and save the diagnostic figures to pngs/.
Author: Copilot
Date: 2026-04-14
Inputs/Outputs: Reads anode/cathode CSV files with DateTime, TestTime, Current,
and Voltage columns; returns combined anode/cathode tables and optionally writes
combined CSV outputs when requested.
"""

from __future__ import annotations

import argparse
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Tuple

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.integrate import cumulative_trapezoid
from scipy.interpolate import PchipInterpolator


CURRENT_STEP_THRESHOLD_A = 1e-6
INTERPOLATION_STEP_AH = 0.2
BOUNDARY_PADDING_SAMPLES = 50

DEFAULT_ANODE_LOCAL = "NEXTMBS-full-charge-discharge-GITT-full0charge-discharge-NMC-anode.csv"
DEFAULT_CATHODE_LOCAL = "NEXTMBS-full-charge-discharge-GITT-full0charge-discharge-NMC-cathode.csv"
# DataRoot: single switch to the dataset root holding 1_Teardown/2_HalfCell/
# 3_Characterization/4_Ageing. Change this one line to retarget the script.
DATA_ROOT = Path(r"\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot")
OCP_ROOT = DATA_ROOT / "2_HalfCell" / "OCP_data"
DEFAULT_ANODE_NETWORK = OCP_ROOT / "Anode_Graphite" / DEFAULT_ANODE_LOCAL
DEFAULT_CATHODE_NETWORK = OCP_ROOT / "Cathode_NMC532" / DEFAULT_CATHODE_LOCAL


@dataclass
class ProfileResult:
    """Container for a processed OCP profile."""

    boundary_capacity_ah: np.ndarray
    boundary_voltage_v: np.ndarray
    interpolated_capacity_ah: np.ndarray
    interpolated_voltage_v: np.ndarray
    throughput_axis_ah: np.ndarray
    full_voltage_v: np.ndarray


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
        default=project_root / "pngs",
        help="Directory where diagnostic PNG figures are written.",
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
        help="Write combined anode/cathode OCP tables to CSV.",
    )
    parser.add_argument(
        "--no-show-figures",
        action="store_true",
        help="Skip opening figure windows after saving PNG outputs.",
    )
    parser.add_argument(
        "--no-hold-figures",
        action="store_true",
        help="Do not keep figure windows open after showing them.",
    )
    return parser.parse_args()


def resolve_input_path(requested_path: Path, fallback_path: Path) -> Path:
    """Resolve a local project path first, then fall back to the original network path."""

    candidate_paths = [requested_path, fallback_path]
    for candidate_path in candidate_paths:
        if candidate_path.exists():
            return candidate_path

    expected_paths = "\n".join(f"  - {path}" for path in candidate_paths)
    raise FileNotFoundError(
        "Input file not found. Checked the following locations:\n"
        f"{expected_paths}"
    )


def normalize_column_name(column_name: str) -> str:
    """Normalize a column header by removing non-alphanumeric chars and lowercasing."""

    return re.sub(r"[^a-z0-9]", "", str(column_name).lower())


def load_ocp_table(csv_path: Path) -> pd.DataFrame:
    """Load and validate a GITT CSV file."""

    table = pd.read_csv(csv_path, encoding="utf-8-sig", low_memory=False)
    original_columns = [str(column_name) for column_name in table.columns]

    # Support both raw export headers (e.g. "Test Time") and MATLAB-style names ("TestTime").
    canonical_aliases = {
        "TestTime": ["TestTime", "Test Time", "testtime", "test_time"],
        "Current": ["Current", "Current(A)", "I", "current"],
        "Voltage": ["Voltage", "Voltage(V)", "U", "voltage"],
        "DateTime": ["DateTime", "Date Time", "date_time", "datetime"],
    }

    normalized_to_actual = {
        normalize_column_name(column_name): column_name for column_name in original_columns
    }

    resolved_columns: dict[str, str] = {}
    for canonical_name, aliases in canonical_aliases.items():
        for alias in aliases:
            normalized_alias = normalize_column_name(alias)
            if normalized_alias in normalized_to_actual:
                resolved_columns[canonical_name] = normalized_to_actual[normalized_alias]
                break

    rename_map = {
        source_name: canonical_name
        for canonical_name, source_name in resolved_columns.items()
        if source_name != canonical_name
    }
    if rename_map:
        table = table.rename(columns=rename_map)

    required_columns = {"TestTime", "Current", "Voltage"}
    missing_columns = sorted(required_columns.difference(table.columns))
    if missing_columns:
        available_columns = ", ".join(original_columns)
        raise ValueError(
            f"{csv_path} is missing required columns: {', '.join(missing_columns)}. "
            f"Available columns: {available_columns}"
        )

    if "DateTime" in table.columns:
        table["DateTime"] = pd.to_datetime(table["DateTime"], errors="coerce")

    for column_name in ["TestTime", "Current", "Voltage"]:
        table[column_name] = pd.to_numeric(table[column_name], errors="coerce")

    filtered_table = table.dropna(subset=["TestTime", "Current", "Voltage"]).reset_index(drop=True)
    if filtered_table.empty:
        raise ValueError(f"{csv_path} contains no valid numeric rows after filtering.")

    return filtered_table


def select_phase(table: pd.DataFrame, current_filter: pd.Series) -> pd.DataFrame:
    """Filter a raw table to one current-sign phase and reset the index."""

    phase_table = table.loc[current_filter].reset_index(drop=True)
    if phase_table.empty:
        raise ValueError("Selected phase is empty after applying the current filter.")
    return phase_table


def detect_transition_indices(current_a: np.ndarray, direction: str) -> np.ndarray:
    """Detect pulse boundary indices using the same sign logic as the MATLAB script."""

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


def clamp_endpoint(last_index: int, padding_samples: int, signal_length: int) -> int:
    """Clamp the padded endpoint so array indexing stays within bounds."""

    return min(last_index + padding_samples, signal_length - 1)


def create_step_figure(
    x_values: np.ndarray | pd.Series,
    current_a: np.ndarray,
    voltage_v: np.ndarray,
    transition_indices: np.ndarray,
    title_prefix: str,
    x_label: str,
) -> None:
    """Create the two-panel diagnostic figure for current and voltage step detection."""

    figure, axes = plt.subplots(2, 1, sharex=True)
    axes[0].plot(x_values, current_a)
    axes[0].scatter(np.asarray(x_values)[transition_indices], current_a[transition_indices])
    axes[0].set_title(f"{title_prefix}: Current Trace with Detected Steps")
    axes[0].set_xlabel(x_label)
    axes[0].set_ylabel("Current (A)")
    axes[0].legend(["Current", "Detected step indices"], loc="best")

    axes[1].plot(x_values, voltage_v)
    axes[1].scatter(np.asarray(x_values)[transition_indices], voltage_v[transition_indices])
    axes[1].set_title(f"{title_prefix}: Voltage Trace with Detected Steps")
    axes[1].set_xlabel(x_label)
    axes[1].set_ylabel("Voltage (V)")
    axes[1].legend(["Voltage", "Detected step indices"], loc="best")
    figure.tight_layout()


def create_throughput_figure(
    throughput_axis: np.ndarray,
    full_voltage_v: np.ndarray,
    boundary_capacity_axis: np.ndarray,
    boundary_voltage_v: np.ndarray,
    interpolated_capacity_ah: np.ndarray,
    interpolated_voltage_v: np.ndarray,
    title_prefix: str,
    interpolation_legend_text: str,
) -> None:
    """Create the boundary-vs-trajectory diagnostic figure with interpolation overlay."""

    plt.figure()
    plt.plot(boundary_capacity_axis, boundary_voltage_v, "o-")
    plt.plot(throughput_axis, full_voltage_v)
    plt.plot(interpolated_capacity_ah, interpolated_voltage_v)
    plt.title(f"{title_prefix}: Boundary Points vs Full Throughput Curve")
    plt.xlabel("Capacity / Throughput (Ah)")
    plt.ylabel("Voltage (V)")
    plt.legend(["Boundary points", "Full throughput trajectory", interpolation_legend_text], loc="best")
    plt.tight_layout()


def create_interpolation_figure(
    boundary_capacity_ah: np.ndarray,
    boundary_voltage_v: np.ndarray,
    interpolated_capacity_ah: np.ndarray,
    interpolated_voltage_v: np.ndarray,
    title_prefix: str,
    legend_text: str,
) -> None:
    """Create the scaled-profile and interpolation figure."""

    plt.figure()
    plt.plot(boundary_capacity_ah, boundary_voltage_v, "o-")
    plt.plot(interpolated_capacity_ah, interpolated_voltage_v)
    plt.title(f"{title_prefix}: Scaled and Interpolated OCP Line")
    plt.xlabel("Capacity (Ah)")
    plt.ylabel("Voltage (V)")
    plt.legend(["Profile scaled to half-cell capacity", legend_text], loc="best")
    plt.tight_layout()


def build_interpolated_profile(
    boundary_capacity_ah: np.ndarray,
    boundary_voltage_v: np.ndarray,
    interpolation_start_ah: float,
    interpolation_stop_ah: float,
    interpolation_step_ah: float = INTERPOLATION_STEP_AH,
    shift_output_capacity_ah: float = 0.0,
) -> Tuple[np.ndarray, np.ndarray]:
    """Interpolate the reduced profile onto an endpoint-safe regular grid using PCHIP."""

    if interpolation_stop_ah < interpolation_start_ah:
        raise ValueError("Interpolation stop must be greater than or equal to interpolation start.")

    # PCHIP requires strictly increasing x; sort and remove duplicate capacities.
    sort_order = np.argsort(boundary_capacity_ah)
    sorted_capacity_ah = np.asarray(boundary_capacity_ah)[sort_order]
    sorted_voltage_v = np.asarray(boundary_voltage_v)[sort_order]
    unique_capacity_ah, unique_indices = np.unique(sorted_capacity_ah, return_index=True)
    unique_voltage_v = sorted_voltage_v[unique_indices]

    if unique_capacity_ah.size < 2:
        raise ValueError("Insufficient unique capacity points for interpolation.")

    # Build the interpolation axis with a fixed step while guaranteeing that the
    # exact interpolation stop value is included (colon-style stepping can miss
    # the endpoint because of floating-point accumulation).
    interpolation_axis = np.arange(interpolation_start_ah, interpolation_stop_ah + interpolation_step_ah, interpolation_step_ah)
    if interpolation_axis.size == 0 or interpolation_axis[-1] < interpolation_stop_ah:
        interpolation_axis = np.append(interpolation_axis, interpolation_stop_ah)
    interpolation_axis = np.unique(interpolation_axis)

    interpolator = PchipInterpolator(unique_capacity_ah, unique_voltage_v, extrapolate=True)
    interpolated_voltage_v = interpolator(interpolation_axis)
    return interpolation_axis + shift_output_capacity_ah, interpolated_voltage_v


def process_profile(
    phase_table: pd.DataFrame,
    direction: str,
    title_prefix: str,
    boundary_start_offset: int,
    integration_padding_samples: int,
    x_values: np.ndarray | pd.Series,
    x_label: str,
    extend_max_factor: float = 1.0,
    extend_min_fraction: float = 0.0,
    use_absolute_current: bool = False,
    shift_output_capacity_ah: float = 0.0,
    integrate_to_phase_end: bool = False,
) -> ProfileResult:
    """Run one full OCP extraction phase with plotting and interpolation."""

    time_s = phase_table["TestTime"].to_numpy()
    current_a = phase_table["Current"].to_numpy()
    voltage_v = phase_table["Voltage"].to_numpy()

    transition_indices = detect_transition_indices(current_a, direction)
    if boundary_start_offset >= transition_indices.size:
        raise ValueError(
            f"{title_prefix} does not have enough detected transitions for offset {boundary_start_offset}."
        )

    selected_transition_indices = transition_indices[boundary_start_offset:]
    integration_start_index = int(selected_transition_indices[0])
    if integrate_to_phase_end:
        # Match MATLAB windows that integrate from first selected pulse to the end of the phase.
        integration_end_index = len(time_s) - 1
    else:
        integration_end_index = clamp_endpoint(
            int(transition_indices[-1]), integration_padding_samples, len(time_s)
        )

    create_step_figure(x_values, current_a, voltage_v, selected_transition_indices, title_prefix, x_label)

    integration_slice = slice(integration_start_index, integration_end_index + 1)
    integration_current_a = current_a[integration_slice]
    if use_absolute_current:
        integration_current_a = np.abs(integration_current_a)

    throughput_axis = cumulative_trapezoid(
        integration_current_a, time_s[integration_slice], initial=0.0
    )
    full_voltage_v = voltage_v[integration_slice]

    relative_boundary_indices = selected_transition_indices - integration_start_index
    boundary_indices_with_endpoint = np.concatenate(
        [relative_boundary_indices, np.array([len(throughput_axis) - 1], dtype=int)]
    )
    boundary_capacity_ah = throughput_axis[boundary_indices_with_endpoint]
    boundary_voltage_v = voltage_v[
        np.concatenate([selected_transition_indices, np.array([integration_end_index], dtype=int)])
    ]

    interpolation_start_ah = float(np.min(boundary_capacity_ah) - np.max(boundary_capacity_ah) * extend_min_fraction)
    interpolation_stop_ah = float(np.max(boundary_capacity_ah) * extend_max_factor)
    interpolated_capacity_ah, interpolated_voltage_v = build_interpolated_profile(
        boundary_capacity_ah,
        boundary_voltage_v,
        interpolation_start_ah,
        interpolation_stop_ah,
        interpolation_step_ah=INTERPOLATION_STEP_AH,
        shift_output_capacity_ah=shift_output_capacity_ah,
    )

    legend_text = (
        "Profile interpolated + extrapolated with 0.2Ah grid"
        if (extend_max_factor != 1.0 or extend_min_fraction != 0.0)
        else "Profile interpolated with 0.2Ah grid"
    )
    create_throughput_figure(
        throughput_axis,
        full_voltage_v,
        boundary_capacity_ah,
        boundary_voltage_v,
        interpolated_capacity_ah,
        interpolated_voltage_v,
        title_prefix,
        legend_text,
    )

    return ProfileResult(
        boundary_capacity_ah=boundary_capacity_ah,
        boundary_voltage_v=boundary_voltage_v,
        interpolated_capacity_ah=interpolated_capacity_ah,
        interpolated_voltage_v=interpolated_voltage_v,
        throughput_axis_ah=throughput_axis,
        full_voltage_v=full_voltage_v,
    )


def create_comparison_figure(
    title_text: str,
    delithiation_capacity_ah: np.ndarray,
    delithiation_voltage_v: np.ndarray,
    lithiation_capacity_ah: np.ndarray,
    lithiation_voltage_v: np.ndarray,
) -> None:
    """Create the final lithiation-vs-delithiation comparison figure."""

    plt.figure()
    plt.plot(delithiation_capacity_ah, delithiation_voltage_v, linewidth=1.5)
    plt.plot(np.flip(lithiation_capacity_ah), lithiation_voltage_v, linewidth=1.5)
    plt.title(title_text)
    plt.xlabel("Capacity (Ah)")
    plt.ylabel("Voltage (V)")
    plt.legend(["Delithiation", "Lithiation"], loc="best")
    plt.tight_layout()


def build_combined_table(
    delithiation_profile: ProfileResult,
    lithiation_profile: ProfileResult,
    qmax_ah: float,
) -> pd.DataFrame:
    """Combine lithiation and delithiation profiles into one export-ready SoC table."""

    return pd.DataFrame(
        {
            "Mode": np.concatenate(
                [
                    np.repeat("Delithiation", len(delithiation_profile.interpolated_capacity_ah)),
                    np.repeat("Lithiation", len(lithiation_profile.interpolated_capacity_ah)),
                ]
            ),
            "SoC(-)": np.concatenate(
                [
                    delithiation_profile.interpolated_capacity_ah / qmax_ah,
                    lithiation_profile.interpolated_capacity_ah / qmax_ah,
                ]
            ),
            "Voltage(V)": np.concatenate(
                [
                    delithiation_profile.interpolated_voltage_v,
                    lithiation_profile.interpolated_voltage_v,
                ]
            ),
        }
    )


def sanitize_filename(title_text: str) -> str:
    """Convert a figure title into a filesystem-safe PNG filename."""

    safe_title = re.sub(r"[^\w\s-]", "", title_text)
    safe_title = re.sub(r"\s+", "_", safe_title.strip())
    return safe_title or "figure"


def save_all_figures(png_dir: Path) -> None:
    """Save all current figures to PNG files in figure-number order."""

    png_dir.mkdir(parents=True, exist_ok=True)
    figure_numbers = sorted(plt.get_fignums())
    for figure_index, figure_number in enumerate(figure_numbers, start=1):
        figure = plt.figure(figure_number)
        figure_title = ""
        if figure.axes:
            figure_title = figure.axes[-1].get_title()
        output_name = sanitize_filename(figure_title or f"figure_{figure_number}")
        output_path = png_dir / f"{figure_index:02d}_{output_name}.png"
        figure.savefig(output_path, dpi=150, bbox_inches="tight")
        print(f"  Saved: {output_path}")


def main() -> Tuple[pd.DataFrame, pd.DataFrame]:
    """Execute the full OCP extraction workflow and return the combined tables."""

    args = parse_arguments()
    print("--- extractOCPLines started ---")

    anode_csv = resolve_input_path(args.anode_csv, DEFAULT_ANODE_NETWORK)
    cathode_csv = resolve_input_path(args.cathode_csv, DEFAULT_CATHODE_NETWORK)

    print("[1/8] Anode delithiation: loading data...")
    anode_table = load_ocp_table(anode_csv)
    print(f"  Loaded {len(anode_table)} rows from {anode_csv}")
    anode_delithiation_table = select_phase(anode_table, anode_table["Current"] >= 0.0)
    anode_datetime_axis = anode_delithiation_table.get("DateTime", anode_delithiation_table["TestTime"])
    anode_delithiation_profile = process_profile(
        anode_delithiation_table,
        direction="positive",
        title_prefix="Anode Delithiation",
        boundary_start_offset=3,
        integration_padding_samples=BOUNDARY_PADDING_SAMPLES,
        x_values=anode_datetime_axis,
        x_label="DateTime" if "DateTime" in anode_delithiation_table.columns else "Time (s)",
    )
    print(
        "  Done. "
        f"{len(anode_delithiation_profile.interpolated_capacity_ah)} interpolated points, "
        f"Q range [{anode_delithiation_profile.interpolated_capacity_ah.min():.1f}, "
        f"{anode_delithiation_profile.interpolated_capacity_ah.max():.1f}] Ah"
    )

    print("[2/8] Anode lithiation: filtering data...")
    anode_lithiation_table = select_phase(anode_table, anode_table["Current"] <= 0.0)
    anode_lithiation_profile = process_profile(
        anode_lithiation_table,
        direction="negative",
        title_prefix="Anode Lithiation",
        boundary_start_offset=1,
        integration_padding_samples=0,
        x_values=anode_lithiation_table["TestTime"],
        x_label="Time (s)",
        use_absolute_current=True,
        integrate_to_phase_end=True,
    )
    print(
        "  Done. "
        f"{len(anode_lithiation_profile.interpolated_capacity_ah)} interpolated points, "
        f"Q range [{anode_lithiation_profile.interpolated_capacity_ah.min():.1f}, "
        f"{anode_lithiation_profile.interpolated_capacity_ah.max():.1f}] Ah"
    )

    print("[3/8] Anode: plotting comparison figure...")
    create_comparison_figure(
        "Anode Interpolated Lithiation vs Delithiation Profiles",
        anode_delithiation_profile.interpolated_capacity_ah,
        anode_delithiation_profile.interpolated_voltage_v,
        anode_lithiation_profile.interpolated_capacity_ah,
        anode_lithiation_profile.interpolated_voltage_v,
    )

    print("[3b/8] Anode: plotting publication figure...")
    qmax_anode = float(
        max(
            np.max(anode_delithiation_profile.interpolated_capacity_ah),
            np.max(anode_lithiation_profile.interpolated_capacity_ah),
        )
    )
    plt.figure()
    plt.plot(
        anode_delithiation_profile.interpolated_capacity_ah / qmax_anode,
        anode_delithiation_profile.interpolated_voltage_v,
        linewidth=1.5,
    )
    plt.plot(
        anode_lithiation_profile.interpolated_capacity_ah / qmax_anode,
        anode_lithiation_profile.interpolated_voltage_v,
        linewidth=1.5,
    )
    plt.plot(
        anode_delithiation_profile.throughput_axis_ah / qmax_anode,
        anode_delithiation_profile.full_voltage_v,
        "b--",
        linewidth=1.1,
    )
    plt.plot(
        anode_lithiation_profile.throughput_axis_ah / qmax_anode,
        anode_lithiation_profile.full_voltage_v,
        "b--",
        linewidth=1.1,
    )
    plt.title("Anode Interpolated Lithiation vs Delithiation Profiles")
    plt.xlabel("SoC (-)")
    plt.ylabel("Voltage (V)")
    plt.legend(["Delithiation", "Lithiation", "GITT voltage"], loc="best")
    plt.tight_layout()

    anode_combined_table = build_combined_table(
        anode_delithiation_profile,
        anode_lithiation_profile,
        qmax_anode,
    )

    print("[4/8] Cathode delithiation: loading data...")
    cathode_table = load_ocp_table(cathode_csv)
    print(f"  Loaded {len(cathode_table)} rows from {cathode_csv}")
    cathode_delithiation_table = select_phase(cathode_table, cathode_table["Current"] >= 0.0)
    cathode_delithiation_profile = process_profile(
        cathode_delithiation_table,
        direction="positive",
        title_prefix="Cathode Delithiation",
        boundary_start_offset=1,
        integration_padding_samples=BOUNDARY_PADDING_SAMPLES,
        x_values=cathode_delithiation_table["TestTime"],
        x_label="Time (s)",
        extend_max_factor=1.08,
    )
    print(
        "  Done. "
        f"{len(cathode_delithiation_profile.interpolated_capacity_ah)} interpolated points, "
        f"Q range [{cathode_delithiation_profile.interpolated_capacity_ah.min():.1f}, "
        f"{cathode_delithiation_profile.interpolated_capacity_ah.max():.1f}] Ah"
    )

    print("[5/8] Cathode lithiation: filtering data...")
    cathode_lithiation_table = select_phase(cathode_table, cathode_table["Current"] <= 0.0)
    cathode_lithiation_profile = process_profile(
        cathode_lithiation_table,
        direction="negative",
        title_prefix="Cathode Lithiation",
        boundary_start_offset=1,
        integration_padding_samples=0,
        x_values=cathode_lithiation_table["TestTime"],
        x_label="Time (s)",
        use_absolute_current=True,
        integrate_to_phase_end=True,
    )
    print(
        "  Done. "
        f"{len(cathode_lithiation_profile.interpolated_capacity_ah)} interpolated points, "
        f"Q range [{cathode_lithiation_profile.interpolated_capacity_ah.min():.1f}, "
        f"{cathode_lithiation_profile.interpolated_capacity_ah.max():.1f}] Ah"
    )

    print("[6/8] Cathode: plotting comparison figure...")
    create_comparison_figure(
        "Cathode Interpolated Lithiation vs Delithiation Profiles",
        cathode_delithiation_profile.interpolated_capacity_ah,
        cathode_delithiation_profile.interpolated_voltage_v,
        cathode_lithiation_profile.interpolated_capacity_ah,
        cathode_lithiation_profile.interpolated_voltage_v,
    )

    print("[6b/8] Cathode: plotting publication figure...")
    qmax_cathode = float(
        max(
            np.max(cathode_delithiation_profile.interpolated_capacity_ah),
            np.max(cathode_lithiation_profile.interpolated_capacity_ah),
        )
    )
    plt.figure()
    plt.plot(
        cathode_delithiation_profile.interpolated_capacity_ah / qmax_cathode,
        cathode_delithiation_profile.interpolated_voltage_v,
        linewidth=1.5,
    )
    plt.plot(
        cathode_lithiation_profile.interpolated_capacity_ah / qmax_cathode,
        cathode_lithiation_profile.interpolated_voltage_v,
        linewidth=1.5,
    )
    plt.plot(
        cathode_delithiation_profile.throughput_axis_ah / qmax_cathode,
        cathode_delithiation_profile.full_voltage_v,
        "b--",
        linewidth=1.1,
    )
    plt.plot(
        cathode_lithiation_profile.throughput_axis_ah / qmax_cathode,
        cathode_lithiation_profile.full_voltage_v,
        "b--",
        linewidth=1.1,
    )
    plt.title("Cathode Interpolated Lithiation vs Delithiation Profiles")
    plt.xlabel("SoC (-)")
    plt.ylabel("Voltage (V)")
    plt.legend(["Delithiation", "Lithiation", "GITT voltage"], loc="best")
    plt.tight_layout()

    cathode_combined_table = build_combined_table(
        cathode_delithiation_profile,
        cathode_lithiation_profile,
        qmax_cathode,
    )

    print(
        f"[7/8] Combined tables built: T_anode ({len(anode_combined_table)} rows), "
        f"T_cathode ({len(cathode_combined_table)} rows)"
    )

    if args.export_csv:
        args.output_dir.mkdir(parents=True, exist_ok=True)
        anode_output = args.output_dir / "GITT_anode_combined.csv"
        cathode_output = args.output_dir / "GITT_cathode_combined.csv"
        anode_combined_table.to_csv(anode_output, index=False)
        cathode_combined_table.to_csv(cathode_output, index=False)
        print(f"  Wrote: {anode_output}")
        print(f"  Wrote: {cathode_output}")

    print("[8/8] Saving figures to pngs/ folder...")
    save_all_figures(args.png_dir)

    if not args.no_show_figures:
        print("[9/9] Showing figures in non-blocking mode...")
        plt.show(block=False)
        # Flush one GUI event cycle so windows appear without blocking script completion.
        plt.pause(0.1)
        if not args.no_hold_figures:
            print("      Figures are open. Press Enter in this terminal to finish.")
            input()
            plt.close("all")

    print("[9/9] --- extractOCPLines complete ---")
    return anode_combined_table, cathode_combined_table


if __name__ == "__main__":
    main()