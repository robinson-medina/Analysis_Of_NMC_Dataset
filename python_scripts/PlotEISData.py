"""
Nyquist Analysis Script - PlotEISData
==========================================================================
Summary: Loads impedance data from the CSV files in an EIS folder and
         generates Nyquist diagrams for the different State of Charge (SoC)
         conditions contained in each '*_impedanceData.csv'.

Python counterpart of matlab_scripts/PlotEISData.m (todo #110). Full rewrite
2026-08-25: the previous version scanned `3_Characterization/<cell>/EIS/`
(a nested-per-cell folder layout for characterization-vs-temperature EIS
data), which no longer matches the current MATLAB source. The current
MATLAB script instead scans ONE flat ageing-EIS stage folder directly
(`4_Ageing/EIS_data/<stage>_EIS/*_impedanceData.csv`, default stage =
`3_EOL_EIS`), with an override hook so verification tooling can re-run it
per stage (BOL/MOL/EOL). This rewrite matches that current behavior.

Usage: run with no arguments (uses the default 3_EOL_EIS folder), or call
       main(eis_folder_override=...) to target a different stage folder,
       mirroring MATLAB's eisFolderOverride variable-injection hook.

Produces: one '<fileBaseName>_NyquistPlot.png' per impedance CSV found,
          saved to JournalScripts/pngs/ (R-022; never back into the
          read-only ZenodoRoot tree, R-001).

Author: Robinson Medina, Feye Hoekstra; Python port by GitHub Copilot
Date: 2026-01-22 (created)  Last synced: 2026-08-25
==========================================================================
"""

import os
import sys
from pathlib import Path

import pandas as pd

# Make the shared plot_nyquist_diagram() helper importable.
_SCRIPT_DIR = Path(__file__).resolve().parent
_FUNCTIONS_CANDIDATES = (_SCRIPT_DIR.parent.parent / "Functions", _SCRIPT_DIR.parent / "Functions")
for _FUNCTIONS_DIR in _FUNCTIONS_CANDIDATES:
    if _FUNCTIONS_DIR.exists():
        if str(_FUNCTIONS_DIR) not in sys.path:
            sys.path.append(str(_FUNCTIONS_DIR))
        break
else:
    raise FileNotFoundError(f"Shared Functions folder not found from {_SCRIPT_DIR}")

from plotNyquistDiagram import plot_nyquist_diagram  # noqa: E402
from get_figure_output_dir import get_figure_output_dir  # noqa: E402

# Single configurable dataset root (Zenodo layout). Read-only (R-001).
DATA_ROOT = Path(r"\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot")
DEFAULT_EIS_FOLDER = DATA_ROOT / "4_Ageing" / "EIS_data" / "3_EOL_EIS"
# Primary publication output location (R-022).
PNGS_DIR = get_figure_output_dir("PlotEISData")


def main(eis_folder_override=None):
    """
    Generate a Nyquist diagram PNG for every '*_impedanceData.csv' in one
    EIS stage folder.

    Parameters
    ----------
    eis_folder_override : str or Path, optional
        EIS stage folder to scan instead of the default 3_EOL_EIS folder.
        Mirrors MATLAB's `eisFolderOverride` variable-injection hook (used
        by the BOL/MOL/EOL verification-run drivers to re-run this script
        per life stage).
    """

    print("\n" + "=" * 40)
    print("Nyquist Analysis Script")
    print("=" * 40)

    eis_folder = Path(eis_folder_override) if eis_folder_override else DEFAULT_EIS_FOLDER
    PNGS_DIR.mkdir(parents=True, exist_ok=True)

    print("\n" + "#" * 40)
    print(f"Checking folder  {eis_folder}")

    if not eis_folder.is_dir():
        print(f"No EIS folder found in {eis_folder}, skipping...")
        return

    print(f"EIS folder found! Processing: {eis_folder}")
    print("#" * 40)

    csv_files = sorted(eis_folder.glob("*_impedanceData.csv"))
    if not csv_files:
        print(f"No impedance data files found (*_impedanceData.csv) in EIS folder: {eis_folder}")
        return

    print(f"Found {len(csv_files)} impedance data file(s) to process")

    for file_idx, filepath in enumerate(csv_files):
        filename = filepath.name

        print("\n" + "=" * 40)
        print(f"Processing file {file_idx + 1}/{len(csv_files)}: {filename}")
        print("=" * 40)

        try:
            print(f"Loading impedance data from: {filename}")
            data = pd.read_csv(filepath)
            print(f"Data loaded successfully. Size: {data.shape[0]} rows x {data.shape[1]} columns")

            col_names = data.columns.tolist()
            has_impedance_data = any("R_real_ohm_SoC" in col for col in col_names)
            if not has_impedance_data:
                print("File does not contain expected impedance data (R_real_ohm_SoC columns), skipping...")
                continue

            file_base_name = filepath.stem
            fig_title = f"Nyquist Diagram: - {file_base_name}"

            # R-022: save to JournalScripts/pngs/, never back into the read-only EIS data folder.
            save_filename = PNGS_DIR / f"{file_base_name}_NyquistPlot.png"

            plot_nyquist_diagram(data, fig_title, str(save_filename), max_freq=12000)
            print("Nyquist diagram generated and saved")

        except Exception as exc:  # noqa: BLE001 - mirrors MATLAB's per-file try/continue
            print(f"Error processing file {filename}: {exc}")
            continue

    print("\n" + "#" * 40)
    print("Nyquist analysis complete!")
    print(f"Processed EIS folder: {eis_folder}")
    print(f"Nyquist diagrams saved to {PNGS_DIR}")
    print("#" * 40)


if __name__ == "__main__":
    # Wave 8 override: run one EIS stage folder per subprocess (parity with RunWave8.m).
    main(eis_folder_override=os.environ.get('WAVE8_EIS_FOLDER'))
