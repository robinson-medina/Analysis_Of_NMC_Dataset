"""
loadAndPreprocessAgeingCsv - Load a cyclic/calendar ageing CSV and run the
shared preprocessing pipeline (time reconstruction, NaN-gap insertion, and
cumulative-charge integral).

This is the Python counterpart of Functions/loadAndPreprocessAgeingCsv.m
(todo #020). It centralises the data-ingestion preamble that was previously
duplicated inline inside python_scripts/ExtractAgeingData.py, so both that
driver and any future PlotCellSummary.py port share one authoritative
implementation.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24

Compliance: R-001 (read-only), R-004 (Python 3.9+), R-012 (commented).
"""

import sys
from pathlib import Path

import numpy as np
import pandas as pd

# Make sibling Functions/ modules importable regardless of caller's sys.path.
_THIS_DIR = Path(__file__).resolve().parent
if str(_THIS_DIR) not in sys.path:
    sys.path.append(str(_THIS_DIR))

from insertNaNAtGaps import insert_nan_at_gaps  # noqa: E402
from computeCumulativeCharge import compute_cumulative_charge  # noqa: E402


def load_and_preprocess_ageing_csv(csv_path):
    """
    Load a cell's ageing CSV and run the shared preprocessing pipeline.

    Parameters
    ----------
    csv_path : str or Path
        Full path to the cell's ageing CSV (Time, Voltage_V_, Current_A_,
        CellTemp__C_, ChamberTemp__C_ columns), following the same column
        convention produced by ConvertMat4Journal_ageing.m.

    Returns
    -------
    time_with_gaps : numpy.ndarray of datetime64
        Datetime array with NaT inserted at data gaps.
    time_s : numpy.ndarray
        Seconds-since-start array (NaN at gaps).
    voltage : numpy.ndarray
        Cell voltage [V] (NaN at gaps).
    current : numpy.ndarray
        Cell current [A] (NaN at gaps).
    cell_temp : numpy.ndarray
        Cell temperature [degC] (NaN at gaps).
    chamber_temp : numpy.ndarray
        Chamber temperature [degC] (NaN at gaps).
    cumulative_integral : numpy.ndarray
        Cumulative charge (capacity) integral of current [Ah].
    """

    # Read the CSV with the first column (Time) forced to string, matching the
    # MATLAB detectImportOptions/readtable convention (header on row 1, data
    # starting on row 2).
    df = pd.read_csv(csv_path, dtype={0: str}, header=0)

    # Reconstruct the absolute time vector. The first Time entry is an
    # absolute timestamp; every subsequent entry is an inter-sample dwell
    # time in seconds that must be cumulatively summed onto the first
    # timestamp to obtain the absolute time of each sample.
    time_yy_mm_dd_str = df.iloc[:, 0].values
    time_yy_mm_dd = pd.Series([pd.NaT] * len(time_yy_mm_dd_str), dtype='datetime64[ns]')
    time_yy_mm_dd.iloc[0] = pd.to_datetime(time_yy_mm_dd_str[0], format='%d-%b-%Y %H:%M:%S.%f')
    if len(time_yy_mm_dd_str) > 1:
        increase_s = np.cumsum(pd.to_numeric(time_yy_mm_dd_str[1:], errors='coerce'))
        time_yy_mm_dd.iloc[1:] = time_yy_mm_dd.iloc[0] + pd.to_timedelta(increase_s, unit='s')

    # Extract the measured channels using the fixed column names (MATLAB
    # readtable sanitizes header symbols into underscores); fall back to
    # positional indexing if the sanitized names are not present.
    try:
        voltage_v = df['Voltage_V_'].values
        current_a = df['Current_A_'].values
        cell_temp_c = df['CellTemp__C_'].values
        chamber_temp_c = df['ChamberTemp__C_'].values
    except KeyError:
        voltage_v = df.iloc[:, 1].values
        current_a = df.iloc[:, 2].values
        cell_temp_c = df.iloc[:, 3].values
        chamber_temp_c = df.iloc[:, 4].values

    # Seconds elapsed since the first sample (used for gap detection/plots).
    dwell_time_s = (time_yy_mm_dd - time_yy_mm_dd.iloc[0]).dt.total_seconds().values

    del df, time_yy_mm_dd_str  # release the (large) raw table/strings

    # Insert NaN/NaT at gaps > 1 minute so plotted lines are not drawn across
    # discontinuous data segments (shared helper).
    (time_with_gaps, time_s, voltage, current, cell_temp, chamber_temp) = insert_nan_at_gaps(
        time_yy_mm_dd, dwell_time_s, voltage_v, current_a, cell_temp_c, chamber_temp_c
    )

    # Cumulative charge (capacity) integral of current over time (shared
    # helper), computed per continuous (gap-separated) segment.
    cumulative_integral = compute_cumulative_charge(time_s, current)

    return time_with_gaps, time_s, voltage, current, cell_temp, chamber_temp, cumulative_integral


__all__ = ['load_and_preprocess_ageing_csv']
