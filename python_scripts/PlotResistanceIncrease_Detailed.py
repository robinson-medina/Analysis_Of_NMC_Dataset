"""
Resistance Increase Overview - NEXTBMS Plotting Data (detailed/debug figures)
==========================================================================
Summary: Generates publication-quality plots showing battery resistance
         increase over time under various test conditions (DoD,
         temperature, C-rate, SoC, voltage limits).

Python counterpart of matlab_scripts/PlotResistanceIncrease_Detailed.m
(todo #019). Full rewrite 2026-08-25 to match the current MATLAB script's
combined/tiled figure layout (previous version predated the 2026-08-07
restructuring and wrote its outputs into the read-only ZenodoRoot data
folder, violating R-001/R-022).

Usage: run with no arguments; reads the Overview*Data resistance CSVs
       exported by ExtractAgeingData.m/py from DATA_ROOT/4_Ageing/.

Produces: PNG (+ vector PDF for the two dedicated publication figures) in
          JournalScripts/Figures/python/PlotResistanceIncrease_Detailed/ (R-022).

Author: Tim Meulenbreuks, Robinson Medina, NEXTBMS Team; Python port by GitHub Copilot
Date: 2026-03-05 (created)  Last synced: 2026-08-25

Data Source:
  - Cyclic:   OverviewResistanceData_36cell.csv
  - Calendar: OverviewResistanceData_5cell.csv
  - Columns:  CellNum, CellLabel, CheckupResistanceTimeStamp,
              CheckupResistance_Ohm, CheckupResistanceFEC.

Outputs (matches MATLAB exactly):
  - All Cells Overview (Plot 1) is skipped.
  - CheckupResistanceVsTime_DoD_Temperature_.png (Plot 2+3, 2x2 tiled).
  - CheckupResistanceVsTime_CrateComparison_.png (Plot 4+6, 2x3 tiled).
  - CheckupResistanceVsTime_VsCrate25DegC_.{png,pdf} (Plot 5, dedicated publication export).
  - CheckupResistanceVsTime_AvgSoC_HighV_.png (Plot 7+8, 2x2 tiled).
  - CheckupResistanceVsTime_StationaryStorage_DriveCycle_.png (Plot 10+11, 2x2 tiled).
  - CheckupResistanceVsTime_CalendarAgeingEffect_.{png,pdf} (Plot 9, dedicated publication export).

2026-08-12 note (todo #056): the publication PDFs this script used to deploy
were SUPERSEDED by PlotAgeingCombinedOverview.py; this script is retained as
a debug/exploration tool and writes only to its R-022 script-owned directory.
==========================================================================
"""

import sys
from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd

# Make the shared plot_resistance_increase_tile()/publication helpers importable,
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

from plotResistanceIncreaseTile import plot_resistance_increase_tile  # noqa: E402
from plotResistanceIncreasePublication import (  # noqa: E402
    plot_resistance_increase_publication,
    plot_resistance_increase_publication_fec_only,
)
from get_figure_output_dir import get_figure_output_dir  # noqa: E402

# Single configurable dataset root (Zenodo layout, todo #055). Read-only (R-001).
DATA_ROOT = Path(r"\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot")
IO_FOLDER_CYCLIC = DATA_ROOT / "4_Ageing" / "Cyclic_ageing_data"
IO_FOLDER_CALENDAR = DATA_ROOT / "4_Ageing" / "Calendar_ageing_data"
# Resolve this entry script's language-partitioned R-022 output directory.
# The resolver also creates the directory, so every save below stays confined
# to the ownership path instead of the legacy shared pngs folder.
PNGS_DIR = get_figure_output_dir("PlotResistanceIncrease_Detailed")

INPUT_CSV_CYCLIC = IO_FOLDER_CYCLIC / "OverviewResistanceData_36cell.csv"
INPUT_CSV_CALENDAR = IO_FOLDER_CALENDAR / "OverviewResistanceData_5cell.csv"

# R-017 publication palette (shared by Plot 4+6's 25 degC tile and Plot 5's dedicated export).
_GREEN = (12 / 255, 195 / 255, 82 / 255)
_DARKBLUE = (1 / 255, 17 / 255, 181 / 255)
_RED = (1.0, 0.0, 0.0)
_MAGENTA = (1.0, 0.0, 1.0)
_BLACK = (0.0, 0.0, 0.0)


def _rename_column_if_exists(dataframe, old_name, new_name):
    """Rename a column only if it exists, to support legacy CSV schemas."""

    if old_name in dataframe.columns:
        dataframe = dataframe.rename(columns={old_name: new_name})
    return dataframe


def _load_overview_csv(csv_path):
    """Load an OverviewResistanceData CSV and normalize columns to the shared schema."""

    dataframe = pd.read_csv(csv_path)
    dataframe = _rename_column_if_exists(dataframe, "CellNum", "cell_number")
    dataframe = _rename_column_if_exists(dataframe, "CheckupResistanceTimeStamp", "Timestamp")
    dataframe = _rename_column_if_exists(dataframe, "CheckupResistance_Ohm", "Resistance [Ohm]")

    dataframe["cell_number"] = dataframe["cell_number"].astype(str).str.extract(r"(Cell_\d+)", expand=False)
    dataframe = dataframe[dataframe["cell_number"].notna()].copy()
    # MATLAB parses with InputFormat 'dd-MMM-yyyy HH:mm:ss' (e.g. "24-Feb-2024 01:39:27").
    dataframe["Timestamp"] = pd.to_datetime(dataframe["Timestamp"], format="%d-%b-%Y %H:%M:%S")
    return dataframe


def main():
    """Generate every resistance-increase debug/publication figure, matching the MATLAB script."""

    print("--- PlotResistanceIncrease_Detailed: starting figure generation ---")

    combined_df_cyclic = _load_overview_csv(INPUT_CSV_CYCLIC)
    cell_list = combined_df_cyclic["cell_number"].unique().tolist()

    combined_df_calendar = _load_overview_csv(INPUT_CSV_CALENDAR)
    cell_list_calendar = combined_df_calendar["cell_number"].unique().tolist()

    # Plot 1: All cells overview - skipped (superseded by the comparison plots below).
    print("Skipping Plot 1 (All Cells Overview).")

    # Plot 2+3: Effect of DoD (col 1) and Effect of Temperature (col 2), combined 2x2 tiles.
    print("Generating Plot 2+3: Effect of DoD + Effect of Temperature (combined)...")
    cell_plot_list_dod = ["Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_27", "Cell_30", "Cell_16"]
    label_list_dod = ["Cell_12 - 100% DoD", "Cell_56 - 100% DoD", "Cell_89 - 100% DoD", "Cell_93 - 100% DoD",
                       "Cell_27 - 70% DoD", "Cell_30 - 40% DoD", "Cell_16 - 10% DoD"]
    colormap_list_dod = ["b", "r", "g", (1, 0.5, 0), (0.5, 0, 0.5), (0.6, 0.3, 0), (1, 0.75, 0.8)]
    marker_list_dod = ["-"] * len(cell_plot_list_dod)

    cell_plot_list_temp = ["Cell_60", "Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_29"]
    label_list_temp = ["Cell_60 - 0 degC", "Cell_12 - 25 degC", "Cell_56 - 25 degC", "Cell_89 - 25 degC",
                        "Cell_93 - 25 degC", "Cell_29 - 45 degC"]
    colormap_list_temp = ["b", (1, 0.5, 0), (1, 0.5, 0), (1, 0.5, 0), (1, 0.5, 0), "r"]
    linestyle_list_temp = ["-", "--", ":", "-.", "-", "-"]

    fig, axes = plt.subplots(2, 2, figsize=(1400 / 100, 900 / 100))
    plot_resistance_increase_tile(axes[0, 0], axes[1, 0], combined_df_cyclic, cell_list,
                                   cell_plot_list_dod, label_list_dod, colormap_list_dod, marker_list_dod,
                                   "Effect of Depth of Discharge (DoD)")
    plot_resistance_increase_tile(axes[0, 1], axes[1, 1], combined_df_cyclic, cell_list,
                                   cell_plot_list_temp, label_list_temp, colormap_list_temp, linestyle_list_temp,
                                   "Effect of Temperature")
    fig.tight_layout()
    fig.savefig(PNGS_DIR / "CheckupResistanceVsTime_DoD_Temperature_.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    # Plot 4+6: C-rate effect at 0 degC (col 1), 25 degC (col 2), 45 degC (col 3), combined 2x3 tiles.
    print("Generating Plot 4+6: C-rate effect at 0/25/45 degC (combined)...")
    cell_plot_list_0c = ["Cell_63", "Cell_60", "Cell_66", "Cell_68"]
    label_list_0c = ["Cell_63 - C/4 - C/2 - 0 degC", "Cell_60 - C/2 - C/2 - 0 degC",
                      "Cell_66 - 3C/4 - C/2 - 0 degC", "Cell_68 - 1C - C/2 - 0 degC"]
    colormap_list_0c = ["b", "r", "g", (1, 0.5, 0)]
    marker_list_0c = ["-"] * len(cell_plot_list_0c)

    cell_plot_list_25c = ["Cell_12", "Cell_23", "Cell_34", "Cell_35"]
    label_list_25c = ["Cell_12 - C/2 - C/2", "Cell_23 - 1C - C/2", "Cell_34 - 3C/2 - C/2", "Cell_35 - 2C - C/2"]
    # Reuse the project publication palette (R-017) - same highlighted cells as fig. 5's dedicated export below.
    colormap_list_25c = [_GREEN, _DARKBLUE, _RED, _MAGENTA]
    marker_list_25c = ["-"] * len(cell_plot_list_25c)

    cell_plot_list_45c = ["Cell_29", "Cell_8", "Cell_9", "Cell_47"]
    label_list_45c = ["Cell_29 - C/2 - C/2 - 45 degC", "Cell_8 - C/2 - 1C - 45 degC",
                       "Cell_9 - 1C - C/2 - 45 degC", "Cell_47 - 1C - 1C - 45 degC"]
    colormap_list_45c = ["b", "r", "g", (1, 0.5, 0)]
    marker_list_45c = ["-"] * len(cell_plot_list_45c)

    fig, axes = plt.subplots(2, 3, figsize=(1600 / 100, 900 / 100))
    plot_resistance_increase_tile(axes[0, 0], axes[1, 0], combined_df_cyclic, cell_list,
                                   cell_plot_list_0c, label_list_0c, colormap_list_0c, marker_list_0c,
                                   "Effect of C-rate at 0 degC")
    plot_resistance_increase_tile(axes[0, 1], axes[1, 1], combined_df_cyclic, cell_list,
                                   cell_plot_list_25c, label_list_25c, colormap_list_25c, marker_list_25c,
                                   "Effect of C-rate at 25 degC")
    plot_resistance_increase_tile(axes[0, 2], axes[1, 2], combined_df_cyclic, cell_list,
                                   cell_plot_list_45c, label_list_45c, colormap_list_45c, marker_list_45c,
                                   "Effect of C-rate at 45 degC")
    fig.tight_layout()
    fig.savefig(PNGS_DIR / "CheckupResistanceVsTime_CrateComparison_.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    # Plot 5: Effect of C-rate at 25 degC (dedicated journal publication export, fig. 5 - kept standalone).
    print("Generating Plot 5: Effect of C-rate at 25 degC (publication export)...")
    cell_plot_list = ["Cell_12", "Cell_23", "Cell_34", "Cell_35"]
    label_list = ["Cell_12 - C/2 - C/2", "Cell_23 - 1C - C/2", "Cell_34 - 3C/2 - C/2", "Cell_35 - 2C - C/2"]
    colormap_list = [_GREEN, _DARKBLUE, _RED, _MAGENTA]
    marker_list = ["-"] * len(cell_plot_list)
    output_file = PNGS_DIR / "CheckupResistanceVsTime_VsCrate25DegC_.png"
    output_file_pdf = PNGS_DIR / "CheckupResistanceVsTime_VsCrate25DegC_.pdf"
    resistance_scale_plot5 = 1000  # convert Ohm to mOhm
    # matplotlib mathtext has no \vphantom; the MATLAB label's phantom-height trick
    # (alignment with the paired capacity figure's C-tilde label) is dropped here
    # (debug/exploration script only - see docs/done.md for the full rationale).
    resistance_label_plot5 = r"$R_{RPT}\,[\mathrm{m}\Omega]$"
    y_limits_plot5 = (1.10, 9.00)
    plot_resistance_increase_publication_fec_only(
        combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, marker_list,
        output_file, output_file_pdf, "", "northeast", resistance_scale_plot5, resistance_label_plot5,
        y_limits_plot5)

    # Plot 7+8: Effect of Average SoC (col 1) and Effect of High Voltage (col 2), combined 2x2 tiles.
    print("Generating Plot 7+8: Effect of Average SoC + Effect of High Voltage (combined)...")
    cell_plot_list_soc = ["Cell_40", "Cell_1", "Cell_3"]
    label_list_soc = ["Cell_40 - 75% avg SoC - 50% DoD", "Cell_1 - 50% avg SoC - 50% DoD",
                       "Cell_3 - 25% avg SoC - 50% DoD"]
    colormap_list_soc = ["b", "r", "g"]
    marker_list_soc = ["-"] * len(cell_plot_list_soc)

    cell_plot_list_highv = ["Cell_9", "Cell_5", "Cell_22"]
    label_list_highv = ["Cell_9 - 2.75V-4.35V - CC - CC", "Cell_5 - 2.75V-4.45V - CC - CC",
                         "Cell_22 - 2.75V-4.45V - CCCV - CC"]
    colormap_list_highv = ["b", "r", "g"]
    marker_list_highv = ["-"] * len(cell_plot_list_highv)

    fig, axes = plt.subplots(2, 2, figsize=(1400 / 100, 900 / 100))
    plot_resistance_increase_tile(axes[0, 0], axes[1, 0], combined_df_cyclic, cell_list,
                                   cell_plot_list_soc, label_list_soc, colormap_list_soc, marker_list_soc,
                                   "Effect of Average SoC")
    plot_resistance_increase_tile(axes[0, 1], axes[1, 1], combined_df_cyclic, cell_list,
                                   cell_plot_list_highv, label_list_highv, colormap_list_highv, marker_list_highv,
                                   "Effect of High Voltage")
    fig.tight_layout()
    fig.savefig(PNGS_DIR / "CheckupResistanceVsTime_AvgSoC_HighV_.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    # Plot 10+11: Stationary storage cycle (col 1) and Drive cycle (col 2), combined 2x2 tiles.
    print("Generating Plot 10+11: Stationary storage cycle + Drive cycle (combined)...")
    cell_plot_list_stat = ["Cell_74", "Cell_46", "Cell_17", "Cell_53"]
    label_list_stat = ["Cell_74 - 0 degrees", "Cell_46 - 25 degrees", "Cell_17 - 45 degrees",
                        "Cell_53 - dynamic temperatures"]
    colormap_list_stat = ["b", "r", "g", (0.5, 0.5, 0.5)]
    marker_list_stat = ["-"] * len(cell_plot_list_stat)

    cell_plot_list_drive = ["Cell_72", "Cell_42", "Cell_25", "Cell_49"]
    # Cell_14 label kept verbatim from the MATLAB source (label text only; the trace itself
    # still plots cell_plot_list_drive[2] = Cell_25 - looks like a pre-existing MATLAB label typo).
    label_list_drive = ["Cell_72 - 0 degrees", "Cell_42 - 25 degrees", "Cell_14 - 45 degrees",
                         "Cell_49 - dynamic temperatures"]
    colormap_list_drive = ["b", "r", "g", (0.5, 0.5, 0.5)]
    marker_list_drive = ["-"] * len(cell_plot_list_drive)

    fig, axes = plt.subplots(2, 2, figsize=(1400 / 100, 900 / 100))
    plot_resistance_increase_tile(axes[0, 0], axes[1, 0], combined_df_cyclic, cell_list,
                                   cell_plot_list_stat, label_list_stat, colormap_list_stat, marker_list_stat,
                                   "Stationary storage cycle")
    plot_resistance_increase_tile(axes[0, 1], axes[1, 1], combined_df_cyclic, cell_list,
                                   cell_plot_list_drive, label_list_drive, colormap_list_drive, marker_list_drive,
                                   "Drive cycle")
    fig.tight_layout()
    fig.savefig(PNGS_DIR / "CheckupResistanceVsTime_StationaryStorage_DriveCycle_.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    # Plot 9: Calendar Ageing Effect (dedicated journal publication export, fig. 11 - kept standalone).
    print("Generating Plot 9: Calendar Ageing Effect (publication export)...")
    # Keep the same 5 highlighted calendar cells as the paired capacity figure
    # so subplot (a) and (b) are directly comparable and no un-labeled gray line remains.
    cell_plot_list_calendar = ["Cell_57", "Cell_11", "Cell_45", "Cell_26", "Cell_28"]
    avg_soc_calendar_cells = [1, 1, 0.1, 0.5, 1]
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
    output_file_calendar = PNGS_DIR / "CheckupResistanceVsTime_CalendarAgeingEffect_.png"
    output_file_calendar_pdf = PNGS_DIR / "CheckupResistanceVsTime_CalendarAgeingEffect_.pdf"
    calendar_label = ""
    resistance_scale = 1000  # convert Ohm to mOhm for publication display
    resistance_label = r"$R_{RPT}\,[\mathrm{m}\Omega]$"
    calendar_y_lim = (1.10, 9.00)
    calendar_x_lim = (0, 400)  # consistent x-range for publication figures
    calendar_plain_title = True  # remove '(vs Time)' from this publication figure title
    plot_resistance_increase_publication(
        combined_df_calendar, cell_list_calendar, cell_plot_list_calendar, label_list_calendar,
        colormap_list_calendar, marker_list_calendar, output_file_calendar, output_file_calendar_pdf,
        calendar_label, False, "northwest", resistance_scale, resistance_label, calendar_y_lim,
        calendar_plain_title, calendar_x_lim)

    print("--- PlotResistanceIncrease_Detailed: figure generation complete ---")
    print("All resistance plots generated successfully!")


if __name__ == "__main__":
    main()
