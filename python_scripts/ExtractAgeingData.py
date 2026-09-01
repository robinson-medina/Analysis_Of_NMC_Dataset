"""
Battery Test Data Analysis and Visualization

This script loads battery cell test data, processes time gaps, calculates
cumulative charge capacity, and performs various diagnostic analyses including
checkup capacity measurements, resistance calculations, and dV/dt analysis.


Updated: November 25, 2025
Converted to Python from MATLAB
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import importlib
import time
import sys
import os
from pathlib import Path

# Add functions directory to path (check both locations)
# Original location: Functions/ lives at BatteryTestHardware_ChromaAgeing/Functions,
# i.e. one level above JournalScripts (sibling of JournalScripts), not inside it.
functions_dir_parent = Path(__file__).parent.parent.parent / 'Functions'
# New location: same folder as script
functions_dir_local = Path(__file__).parent / 'Functions'

def load_helpers() -> dict[str, callable]:
    """Load required helper functions dynamically and report missing modules clearly."""

    for functions_dir in [functions_dir_local, functions_dir_parent]:
        if functions_dir.exists() and str(functions_dir) not in sys.path:
            sys.path.append(str(functions_dir))

    required_helpers = {
        "loadAndPreprocessAgeingCsv": "load_and_preprocess_ageing_csv",
        "plotOverviewData": "plot_overview_data",
        "findCheckupSegments": "find_checkup_segments",
        "analyzeCheckupDischarge": "analyze_checkup_discharge",
        "extractResistanceValues": "extract_resistance_values",
        "plotCapacityAndResistanceTrending": "plot_capacity_and_resistance_trending",
        "analyzeDVdtAfterCharge": "analyze_dvdt_after_charge",
        "getCellLabel": "get_cell_label",
        "exportOCPDischarge": "export_ocp_discharge",
    }

    loaded_helpers: dict[str, callable] = {}
    missing_helpers: list[str] = []
    for module_name, function_name in required_helpers.items():
        try:
            module = importlib.import_module(module_name)
            loaded_helpers[function_name] = getattr(module, function_name)
        except Exception:
            missing_helpers.append(f"{module_name}.{function_name}")

    if missing_helpers:
        print("Missing helper modules/functions required for full ExtractAgeingData parity:")
        for missing_helper in missing_helpers:
            print(f"  - {missing_helper}")
        print("Expected helper directory locations:")
        print(f"  - {functions_dir_local}")
        print(f"  - {functions_dir_parent}")
        return {}

    return loaded_helpers

def main():
    """Main analysis workflow for battery test data."""
    
    print('\n' + '='*40)
    print('Battery Test Data Analysis for NextBMS journal')
    print('='*40)

    helpers = load_helpers()
    if not helpers:
        print('Stopping execution because required helper modules are not available in this workspace.')
        return

    # Import after load_helpers() has registered the shared Functions directory.
    # The resolver assigns this entry script its isolated R-022 output folder.
    from get_figure_output_dir import get_figure_output_dir
    
    # DataRoot: single switch to the dataset root that holds the four top-level
    # folders (1_Teardown, 2_HalfCell, 3_Characterization, 4_Ageing).
    data_root = r'\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot'
    # Default to the cyclic ageing data under 4_Ageing (can be changed as needed).
    desired_folder = os.path.join(data_root, '4_Ageing', 'Cyclic_ageing_data')
    # Wave 8 override: a runner can target one cell/folder via env vars
    # (subprocess-per-cell parity with RunWave8.m's folderOverride/cellNumOverride).
    desired_folder = os.environ.get('WAVE8_FOLDER', desired_folder)

    # MATLAB parity: when cell_num is set, process only that cell.
    cell_num = os.environ.get('WAVE8_CELL', 'Cell_35')

    # Get all folders in the directory matching Cell_* (R-025 plain form)
    all_folders = [
        f for f in os.listdir(desired_folder)
        if os.path.isdir(os.path.join(desired_folder, f)) and f.startswith('Cell_')
    ]
    if cell_num:
        if cell_num not in all_folders:
            print(f'Configured cell was not found: {cell_num}')
            return
        folders = [cell_num]
    else:
        folders = all_folders

    # Initialize lists to accumulate data from all cells
    all_resistance_data = []
    all_capacity_data = []
    # all_dvdt_data = []
    # all_dqdv_data = []

    # Process each cell folder
    for cell_num in folders:
        plt.close('all')  # Close all figures before processing a new cell

        # Generate descriptive label for cell based on ageing test plan
        cell_label = helpers['get_cell_label'](cell_num)

        print('\n' + '='*40)
        print(f'Battery Test Data Analysis for NextBMS journal')
        print('='*40)

        load_name = os.path.join(desired_folder, cell_num, f'{cell_num}.csv')
        print(f'Loading data for cell: {cell_num}...')

        # Keep figures and derived CSVs out of the read-only ZenodoRoot tree (R-001).
        # Resolve the isolated R-022 folder once per entry-script workflow, so cleanup
        # cannot remove outputs belonging to MATLAB or another Python writer.
        save_path = str(get_figure_output_dir('ExtractAgeingData'))
        print(f'Figures will be saved to: {save_path}')

        start_time = time.time()

        try:
            # Load + preprocess via the shared helper (single source of the
            # ingestion pipeline, matching Functions/loadAndPreprocessAgeingCsv.m
            # used by the MATLAB driver): readtable-equivalent CSV load, time-
            # vector reconstruction, NaN-gap insertion, cumulative-charge
            # integral. Todo #020 (2026-08-24): replaces the previously
            # inlined preamble so both drivers share one implementation.
            print(f'Loading {cell_num}')
            (time_with_gaps, time_s, voltage, current, cell_temp, chamber_temp,
             cumulative_integral) = helpers['load_and_preprocess_ageing_csv'](load_name)
            print(f'Data loaded and preprocessed. (Elapsed: {time.time() - start_time:.2f} s)')

            # Plot Overview Data
            helpers['plot_overview_data'](
                time_with_gaps,
                current,
                voltage,
                cell_temp,
                chamber_temp,
                cumulative_integral,
                cell_num,
                cell_label,
            )
            fig_overview = plt.gcf()

            # Checkup Capacity Analysis
            start_time_analysis = time_with_gaps[0]
            end_time_analysis = time_with_gaps[-20]

            # Find constant-current discharge segments for checkup analysis
            segments = helpers['find_checkup_segments'](
                time_with_gaps,
                voltage,
                current,
                time_s,
                start_time_analysis,
                end_time_analysis,
            )

            # Select data within the specified datetime range for plotting
            selected_indices = (time_with_gaps >= start_time_analysis) & (time_with_gaps <= end_time_analysis)
            selected_time = time_with_gaps[selected_indices]
            selected_voltage = voltage[selected_indices]
            selected_current = current[selected_indices]
            selected_time_s = time_s[selected_indices]

            # Window for moving average in dQ/dV calculation
            window_size = 5000

            # Analyze discharge curves and calculate checkup capacity
            (
                checkup_capacity_timestamp,
                checkup_capacity_ah,
                checkup_capacity_fec,
                legends,
                checkup_ocv_v,
                dqdv_apervs,
                segment_capacity_ah,
                checkup_soc,
            ) = helpers['analyze_checkup_discharge'](
                segments,
                selected_time,
                selected_voltage,
                selected_current,
                selected_time_s,
                window_size,
                cell_num,
                cell_label,
            )
            fig_checkup_discharge = plt.gcf()

            helpers['export_ocp_discharge'](
                save_path,
                cell_num,
                checkup_soc,
                checkup_ocv_v,
                checkup_capacity_ah,
                checkup_capacity_timestamp,
            )

            # Extract Resistance Values
            (checkup_resistance_timestamp, 
             checkup_resistance_ohm,
             checkup_resistance_fec) = helpers['extract_resistance_values'](
                time_with_gaps, voltage, current, time_s, 
                start_time_analysis, end_time_analysis, cell_num, cell_label)
            fig_resistance = plt.gcf()

            # Plot Capacity and Resistance Trending
            helpers['plot_capacity_and_resistance_trending'](
                checkup_capacity_timestamp, checkup_capacity_ah, checkup_capacity_fec,
                checkup_resistance_timestamp, checkup_resistance_ohm, checkup_resistance_fec,
                cell_num, cell_label)
            fig_cap_res_trend = plt.gcf()

            # dV/dt Analysis
            constant_current_value_a = -11.6

            # Perform dV/dt analysis
            (plotted_segments, dvdt_data) = helpers['analyze_dvdt_after_charge'](
                selected_time, selected_voltage, selected_current, 
                selected_time_s, constant_current_value_a, cell_num, cell_label)
            fig_dvdt = plt.gcf()

            # Save All Figures. Do NOT blanket-delete PNGs here: this folder is a
            # shared per-script owner (Figures/python/ExtractAgeingData) holding every
            # cell's images, and the Wave 8 runner clears it once before the first run.
            # Matching ExtractAgeingData.m, each cell only writes its own {cell}_*.png.
            print('\nSaving figures...')
            figures = [
                (fig_overview, f'{cell_num}_Overview.png'),
                (fig_checkup_discharge, f'{cell_num}_CheckupDischarge.png'),
                (fig_resistance, f'{cell_num}_Resistance.png'),
                (fig_cap_res_trend, f'{cell_num}_CapacityResistanceTrend.png'),
                (fig_dvdt, f'{cell_num}_dVdtAnalysis.png'),
            ]
            for fig, fig_name in figures:
                fig.savefig(os.path.join(save_path, fig_name))

            print('\n' + '='*40)
            print(f'All figures saved to: {save_path}')
            print('='*40)

            # Accumulate resistance data (skip NaT timestamps)
            for i in range(len(checkup_resistance_timestamp)):
                if pd.notna(checkup_resistance_timestamp[i]):
                    all_resistance_data.append([
                        cell_num,
                        cell_label,
                        checkup_resistance_timestamp[i],
                        checkup_resistance_ohm[i],
                        checkup_resistance_fec[i] if i < len(checkup_resistance_fec) else None
                    ])

            # Accumulate capacity data (skip NaT timestamps)
            for i in range(len(checkup_capacity_timestamp)):
                if pd.notna(checkup_capacity_timestamp[i]):
                    all_capacity_data.append([
                        cell_num,
                        cell_label,
                        checkup_capacity_timestamp[i],
                        checkup_capacity_ah[i],
                        checkup_capacity_fec[i] if i < len(checkup_capacity_fec) else None
                    ])

        except Exception as e:
            print(f'Error processing cell {cell_num}: {str(e)}')
            raise

    # Save All Tables to CSV (with Ncell naming)
    print('\n' + '='*40)
    print('Saving data tables to CSV files...')
    print('='*40)

    n_cells = len(folders)

    # Create and save the resistance table in this script's R-022 output directory.
    if all_resistance_data:
        resistance_df = pd.DataFrame(all_resistance_data, columns=['CellNum', 'CellLabel', 'CheckupResistanceTimeStamp', 'CheckupResistance_Ohm', 'CheckupResistanceFEC'])
        resistance_path = os.path.join(save_path, f'OverviewResistanceData_{n_cells}cell.csv')
        resistance_df.to_csv(resistance_path, index=False)
        print(f'Resistance data saved to: {resistance_path}')

    # Create and save the capacity table in this script's R-022 output directory.
    if all_capacity_data:
        capacity_df = pd.DataFrame(all_capacity_data, columns=['CellNum', 'CellLabel', 'CheckupCapacityTimeStamp', 'CheckupCapacity_Ah', 'CheckupCapacityFEC'])
        capacity_path = os.path.join(save_path, f'OverviewCapacityData_{n_cells}cell.csv')
        capacity_df.to_csv(capacity_path, index=False)
        print(f'Capacity data saved to: {capacity_path}')

    print('\n' + '='*40)
    print(f'All tables saved to: {save_path}')
    print('='*40)

    # Keep figures open for interactive viewing
    plt.show()


if __name__ == '__main__':
    main()
