"""
Capacity Degradation Overview - NEXTBMS Plotting Data (detailed/debug figures)
==========================================================================
Summary: Generates publication-quality plots showing battery capacity
         degradation over time under various test conditions (DoD,
         temperature, C-rate, SoC, voltage limits).

Python counterpart of matlab_scripts/PlotCapacityDegradation_detailed.m
(todo #018). Full rewrite 2026-08-25 to match the current MATLAB script's
combined/tiled figure layout (previous version predated the 2026-08-07
restructuring and wrote its outputs into the read-only ZenodoRoot data
folder, violating R-001/R-022).

Usage: run with no arguments; reads the Overview*Data capacity CSVs
       exported by ExtractAgeingData.m/py from DATA_ROOT/4_Ageing/.

Produces: PNG (+ vector PDF for the two dedicated publication figures) in
          JournalScripts/pngs/ (R-022).

Author: Tim Meulenbreuks, Robinson Medina, NEXTBMS Team; Python port by GitHub Copilot
Date: 2026-02-24 (created)  Last synced: 2026-08-25

Data Source: OverviewCapacityData_36cell.csv / OverviewCapacityData_5cell.csv
  - Contains capacity checkup measurements from battery ageing tests.
  - Columns: CellNum, CellLabel, CheckupCapacityTimeStamp,
             CheckupCapacity_Ah, CheckupCapacityFEC.

Outputs (matches MATLAB exactly):
  - All Cells Overview (Plot 1) is skipped.
  - RelativeCapacityVsTime_DoD_Temperature_.png (Plot 2+3, 2x2 tiled).
  - RelativeCapacityVsTime_CrateComparison_.png (Plot 4+6, 2x3 tiled).
  - RelativeCapacityVsTime_VsCrate25DegC_.{png,pdf} (Plot 5, dedicated publication export).
  - RelativeCapacityVsTime_AvgSoC_HighV_.png (Plot 7+8, 2x2 tiled).
  - RelativeCapacityVsTime_StationaryStorage_DriveCycle_.png (Plot 10+11, 2x2 tiled).
  - RelativeCapacityVsTime_CalendarAgeingEffect_.{png,pdf} (Plot 9, dedicated publication export).

Note: Relative capacity = Current capacity / Initial capacity (dimensionless
      ratio for the publication figures; percentage for the tiled debug figures).

2026-08-12 note (todo #056): the publication PDFs this script used to deploy
were SUPERSEDED by PlotAgeingCombinedOverview.py (CalendarAgeing.pdf /
CyclicAgeing.pdf are what the manuscript imports). This script is retained as
a debug/exploration tool; it writes to JournalScripts/pngs/ only.
==========================================================================
"""

import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

# Make the shared plot_capacity_degradation_tile()/publication helpers importable,
# Add Functions/ from either the JournalScripts staging layout or the public repository layout.
_SCRIPT_DIR = Path(__file__).resolve().parent
_FUNCTIONS_CANDIDATES = (_SCRIPT_DIR.parent.parent / "Functions", _SCRIPT_DIR.parent / "Functions")
for _FUNCTIONS_DIR in _FUNCTIONS_CANDIDATES:
    if _FUNCTIONS_DIR.exists():
        if str(_FUNCTIONS_DIR) not in sys.path:
            sys.path.append(str(_FUNCTIONS_DIR))
        break
else:
    raise FileNotFoundError(f"Shared Functions folder not found from {_SCRIPT_DIR}")

from plotCapacityDegradationTile import plot_capacity_degradation_tile  # noqa: E402
from plotCapacityDegradationPublication import (  # noqa: E402
    plot_capacity_degradation_publication,
    plot_capacity_degradation_publication_fec_only,
)
from get_figure_output_dir import get_figure_output_dir  # noqa: E402

# Single configurable dataset root (Zenodo layout, todo #055). Read-only (R-001).
DATA_ROOT = Path(r"\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot")
IO_FOLDER_CYCLIC = DATA_ROOT / "4_Ageing" / "Cyclic_ageing_data"
IO_FOLDER_CALENDAR = DATA_ROOT / "4_Ageing" / "Calendar_ageing_data"
# Primary publication output location (R-022).
PNGS_DIR = get_figure_output_dir("PlotCapacityDegradation_detailed")

INPUT_CSV_CYCLIC = IO_FOLDER_CYCLIC / "OverviewCapacityData_36cell.csv"
INPUT_CSV_CALENDAR = IO_FOLDER_CALENDAR / "OverviewCapacityData_5cell.csv"

# R-017 publication palette (shared by Plot 4+6's 25 degC tile and Plot 5's dedicated export).
_GREEN = (12 / 255, 195 / 255, 82 / 255)
_DARKBLUE = (1 / 255, 17 / 255, 181 / 255)
_RED = (1.0, 0.0, 0.0)
_MAGENTA = (1.0, 0.0, 1.0)
_BLACK = (0.0, 0.0, 0.0)


def _load_overview_csv(csv_path):
    """Load an OverviewCapacityData CSV and normalize columns to the shared schema."""

    dataframe = pd.read_csv(csv_path)
    dataframe = dataframe.rename(columns={
        "CellNum": "cell_number",
        "CheckupCapacityTimeStamp": "Timestamp",
        "CheckupCapacity_Ah": "Capacity [Ah]",
    })
    # Defensive extraction: normalizes CellNum to plain "Cell_XX" (already a no-op
    # now that the dataset uses the plain form; kept in case older CSVs recur).
    dataframe["cell_number"] = dataframe["cell_number"].astype(str).str.extract(r"(Cell_\d+)", expand=False)
    dataframe = dataframe[dataframe["cell_number"].notna()].copy()
    # MATLAB parses with InputFormat 'dd-MMM-yyyy HH:mm:ss' (e.g. "24-Feb-2024 01:39:27").
    dataframe["Timestamp"] = pd.to_datetime(dataframe["Timestamp"], format="%d-%b-%Y %H:%M:%S")
    return dataframe


def main():
    """Generate every capacity-degradation debug/publication figure, matching the MATLAB script."""

    combined_df_cyclic = _load_overview_csv(INPUT_CSV_CYCLIC)
    cell_list = combined_df_cyclic["cell_number"].unique().tolist()

    combined_df_calendar = _load_overview_csv(INPUT_CSV_CALENDAR)
    cell_list_calendar = combined_df_calendar["cell_number"].unique().tolist()

    print("--- PlotCapacityDegradation_detailed: starting figure generation ---")

    # Plot 1: All cells overview - skipped (superseded by the comparison plots below).
    print("Skipping Plot 1 (All Cells Overview).")

    # Plot 2+3: Effect of DoD (col 1) and Effect of Temperature (col 2), combined 2x2 tiles.
    print("Generating Plot 2+3: Effect of DoD + Effect of Temperature (combined)...")
    cell_plot_list_dod = ["Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_27", "Cell_30", "Cell_16"]
    colormap_list_dod = ["b", "r", "g", (1, 0.5, 0), (0.5, 0, 0.5), (0.6, 0.3, 0), (1, 0.75, 0.8)]
    marker_list_dod = ["-"] * len(cell_plot_list_dod)

    cell_plot_list_temp = ["Cell_60", "Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_29"]
    colormap_list_temp = ["b", (1, 0.5, 0), (1, 0.5, 0), (1, 0.5, 0), (1, 0.5, 0), "r"]
    linestyle_list_temp = ["-", "--", ":", "-.", "-", "-"]

    fig, axes = plt.subplots(2, 2, figsize=(1400 / 100, 900 / 100))
    plot_capacity_degradation_tile(axes[0, 0], axes[1, 0], combined_df_cyclic, cell_list,
                                    cell_plot_list_dod, colormap_list_dod, marker_list_dod,
                                    "Effect of Depth of Discharge (DoD)")
    plot_capacity_degradation_tile(axes[0, 1], axes[1, 1], combined_df_cyclic, cell_list,
                                    cell_plot_list_temp, colormap_list_temp, linestyle_list_temp,
                                    "Effect of Temperature")
    fig.tight_layout()
    fig.savefig(PNGS_DIR / "RelativeCapacityVsTime_DoD_Temperature_.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    # Plot 4+6: C-rate effect at 0 degC (col 1), 25 degC (col 2), 45 degC (col 3), combined 2x3 tiles.
    print("Generating Plot 4+6: C-rate effect at 0/25/45 degC (combined)...")
    cell_plot_list_0c = ["Cell_63", "Cell_60", "Cell_66", "Cell_68"]
    colormap_list_0c = ["b", "r", "g", (1, 0.5, 0)]
    marker_list_0c = ["-"] * len(cell_plot_list_0c)

    cell_plot_list_25c = ["Cell_12", "Cell_23", "Cell_34", "Cell_35"]
    # Reuse the project publication palette (R-017) - same highlighted cells as fig. 5's dedicated export below.
    colormap_list_25c = [_GREEN, _DARKBLUE, _RED, _MAGENTA]
    marker_list_25c = ["-"] * len(cell_plot_list_25c)

    cell_plot_list_45c = ["Cell_29", "Cell_8", "Cell_9", "Cell_47"]
    colormap_list_45c = ["b", "r", "g", (1, 0.5, 0)]
    marker_list_45c = ["-"] * len(cell_plot_list_45c)

    fig, axes = plt.subplots(2, 3, figsize=(1600 / 100, 900 / 100))
    plot_capacity_degradation_tile(axes[0, 0], axes[1, 0], combined_df_cyclic, cell_list,
                                    cell_plot_list_0c, colormap_list_0c, marker_list_0c,
                                    "Effect of C-rate at 0 degC")
    plot_capacity_degradation_tile(axes[0, 1], axes[1, 1], combined_df_cyclic, cell_list,
                                    cell_plot_list_25c, colormap_list_25c, marker_list_25c,
                                    "Effect of C-rate at 25 degC")
    plot_capacity_degradation_tile(axes[0, 2], axes[1, 2], combined_df_cyclic, cell_list,
                                    cell_plot_list_45c, colormap_list_45c, marker_list_45c,
                                    "Effect of C-rate at 45 degC")
    fig.tight_layout()
    fig.savefig(PNGS_DIR / "RelativeCapacityVsTime_CrateComparison_.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    # Plot 5: Effect of C-rate at 25 degC (dedicated journal publication export, fig. 5 - kept standalone).
    print("Generating Plot 5: Effect of C-rate at 25 degC (publication export)...")
    cell_plot_list = ["Cell_12", "Cell_23", "Cell_34", "Cell_35"]
    label_list = ["Cell_12 - C/2 - C/2", "Cell_23 - 1C - C/2", "Cell_34 - 3C/2 - C/2", "Cell_35 - 2C - C/2"]
    colormap_list = [_GREEN, _DARKBLUE, _RED, _MAGENTA]
    marker_list = ["-"] * len(cell_plot_list)
    output_file = PNGS_DIR / "RelativeCapacityVsTime_VsCrate25DegC_.png"
    output_file_pdf = PNGS_DIR / "RelativeCapacityVsTime_VsCrate25DegC_.pdf"
    # No precomposed C-with-tilde glyph exists for tex/Times; mathtext renders \tilde fine.
    y_label_plot5 = r"$\tilde{C}_{RPT}\,[-]$"
    plot_capacity_degradation_publication_fec_only(
        combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, marker_list,
        output_file, output_file_pdf, "", "southeast", y_label_plot5)

    # Plot 7+8: Effect of Average SoC (col 1) and Effect of High Voltage (col 2), combined 2x2 tiles.
    print("Generating Plot 7+8: Effect of Average SoC + Effect of High Voltage (combined)...")
    cell_plot_list_soc = ["Cell_40", "Cell_1", "Cell_3"]
    colormap_list_soc = ["b", "r", "g"]
    marker_list_soc = ["-"] * len(cell_plot_list_soc)

    cell_plot_list_highv = ["Cell_9", "Cell_5", "Cell_22"]
    colormap_list_highv = ["b", "r", "g"]
    marker_list_highv = ["-"] * len(cell_plot_list_highv)

    fig, axes = plt.subplots(2, 2, figsize=(1400 / 100, 900 / 100))
    plot_capacity_degradation_tile(axes[0, 0], axes[1, 0], combined_df_cyclic, cell_list,
                                    cell_plot_list_soc, colormap_list_soc, marker_list_soc,
                                    "Effect of Average SoC")
    plot_capacity_degradation_tile(axes[0, 1], axes[1, 1], combined_df_cyclic, cell_list,
                                    cell_plot_list_highv, colormap_list_highv, marker_list_highv,
                                    "Effect of High Voltage")
    fig.tight_layout()
    fig.savefig(PNGS_DIR / "RelativeCapacityVsTime_AvgSoC_HighV_.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    # Plot 10+11: Stationary storage cycle (col 1) and Drive cycle (col 2), combined 2x2 tiles.
    print("Generating Plot 10+11: Stationary storage cycle + Drive cycle (combined)...")
    cell_plot_list_stat = ["Cell_74", "Cell_46", "Cell_17", "Cell_53"]
    colormap_list_stat = ["b", "r", "g", (0.5, 0.5, 0.5)]
    marker_list_stat = ["-"] * len(cell_plot_list_stat)

    cell_plot_list_drive = ["Cell_72", "Cell_42", "Cell_25", "Cell_49"]
    colormap_list_drive = ["b", "r", "g", (0.5, 0, 0.5)]
    marker_list_drive = ["-"] * len(cell_plot_list_drive)

    fig, axes = plt.subplots(2, 2, figsize=(1400 / 100, 900 / 100))
    plot_capacity_degradation_tile(axes[0, 0], axes[1, 0], combined_df_cyclic, cell_list,
                                    cell_plot_list_stat, colormap_list_stat, marker_list_stat,
                                    "Stationary storage cycle")
    plot_capacity_degradation_tile(axes[0, 1], axes[1, 1], combined_df_cyclic, cell_list,
                                    cell_plot_list_drive, colormap_list_drive, marker_list_drive,
                                    "Drive cycle")
    fig.tight_layout()
    fig.savefig(PNGS_DIR / "RelativeCapacityVsTime_StationaryStorage_DriveCycle_.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    # Plot 9: Calendar Ageing Effect (dedicated journal publication export, fig. 11 - kept standalone).
    print("Generating Plot 9: Calendar Ageing Effect (publication export)...")
    # Highlight all 5 calendar cells so no un-labeled gray trajectory remains
    # (the 5th cell, Cell_28, was previously drawn only as a gray background line).
    cell_plot_list_calendar = ["Cell_57", "Cell_11", "Cell_45", "Cell_26", "Cell_28"]
    # Per-cell average SoC values from Ageing Test Plan.
    avg_soc_calendar_cells = [1, 1, 0.1, 0.5, 1]  # Cell_57, Cell_11, Cell_45, Cell_26, Cell_28
    label_list_calendar = [
        f"Cell_57 | 0 degC | (Avg SoC = {avg_soc_calendar_cells[0] * 100:.1f}%)",
        f"Cell_11 | 25 degC | (Avg SoC = {avg_soc_calendar_cells[1] * 100:.1f}%)",
        f"Cell_45 | 45 degC | (Avg SoC = {avg_soc_calendar_cells[2] * 100:.1f}%)",
        f"Cell_26 | 45 degC | (Avg SoC = {avg_soc_calendar_cells[3] * 100:.1f}%)",
        f"Cell_28 | 45 degC | (Avg SoC = {avg_soc_calendar_cells[4] * 100:.1f}%)",
    ]
    # Use the project publication palette (R-017) for calendar figure highlights.
    colormap_list_calendar = [_GREEN, _DARKBLUE, _RED, _MAGENTA, _BLACK]
    marker_list_calendar = ["-"] * len(cell_plot_list_calendar)
    output_file_calendar = PNGS_DIR / "RelativeCapacityVsTime_CalendarAgeingEffect_.png"
    output_file_calendar_pdf = PNGS_DIR / "RelativeCapacityVsTime_CalendarAgeingEffect_.pdf"
    calendar_label = ""
    y_label_fig11 = r"$\tilde{C}_{RPT}\,[-]$"
    # Consistent x-limits and y-limits for the publication figure.
    calendar_x_lim = (0, 400)
    calendar_y_lim = (0.90, 1.05)
    plot_capacity_degradation_publication(
        combined_df_calendar, cell_list_calendar, cell_plot_list_calendar, label_list_calendar,
        colormap_list_calendar, marker_list_calendar, output_file_calendar, output_file_calendar_pdf,
        calendar_label, False, "southwest", calendar_x_lim, calendar_y_lim, y_label_fig11)

    print("--- PlotCapacityDegradation_detailed: figure generation complete ---")
    print("All plots generated successfully!")


if __name__ == "__main__":
    main()
