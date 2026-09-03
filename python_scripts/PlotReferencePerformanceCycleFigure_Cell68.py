"""
PlotReferencePerformanceCycleFigure_Cell68 - Standalone driver that reproduces
the Reference Performance Cycle (RPC) publication figure for Cell_68 without
running the full ExtractAgeingData pipeline.

Python counterpart of matlab_scripts/PlotReferencePerformanceCycleFigure_Cell68.m
(todo #029).

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24

Compliance: R-004, R-013, R-016.
"""

import os
import sys
from pathlib import Path

import pandas as pd

# Resolve Functions/ regardless of caller's cwd or repository layout.
_SCRIPT_DIR = Path(__file__).resolve().parent
_FUNCTIONS_CANDIDATES = (_SCRIPT_DIR.parent.parent / 'Functions', _SCRIPT_DIR.parent / 'Functions')
for _FUNCTIONS_DIR in _FUNCTIONS_CANDIDATES:
    if (_FUNCTIONS_DIR / "get_figure_output_dir.py").exists():
        if str(_FUNCTIONS_DIR) not in sys.path:
            sys.path.append(str(_FUNCTIONS_DIR))
        break
else:
    raise FileNotFoundError(f"Shared Functions folder not found from {_SCRIPT_DIR}")

from loadAndPreprocessAgeingCsv import load_and_preprocess_ageing_csv  # noqa: E402
from plotReferencePerformanceCycle import plot_reference_performance_cycle  # noqa: E402
from getCellLabel import get_cell_label  # noqa: E402
from get_figure_output_dir import get_figure_output_dir  # noqa: E402


def main():
    """Load Cell_68's cyclic-ageing CSV and render the RPC publication figure."""

    # Fixed single-cell scope by design (R-025 plain Cell_<n> form).
    cell_num = 'Cell_68'

    # DataRoot: single switch to the dataset root (todo #051/#041 convention).
    data_root = r'\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot'
    desired_folder = os.path.join(data_root, '4_Ageing', 'Cyclic_ageing_data')
    csv_path = os.path.join(desired_folder, cell_num, f'{cell_num}.csv')

    cell_label = get_cell_label(cell_num)

    print(f'Loading and preprocessing {cell_num}...')
    (time_with_gaps, _time_s, voltage, current, cell_temp, chamber_temp,
     cumulative_integral) = load_and_preprocess_ageing_csv(csv_path)

    # Fixed publication zoom window for the Reference Performance Cycle view.
    reference_cycle_start_time = pd.Timestamp(2024, 4, 23, 5, 51, 16)
    reference_cycle_end_time = pd.Timestamp(2024, 4, 30, 4, 55, 12)

    fig = plot_reference_performance_cycle(
        time_with_gaps, current, voltage, cell_temp, chamber_temp,
        cumulative_integral, cell_num, cell_label,
        reference_cycle_start_time, reference_cycle_end_time,
        get_figure_output_dir('PlotReferencePerformanceCycleFigure_Cell68'),
    )
    fig.show()


if __name__ == '__main__':
    main()
