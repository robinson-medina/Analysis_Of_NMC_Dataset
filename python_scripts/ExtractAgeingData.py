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
# Original location: one folder up
functions_dir_parent = Path(__file__).parent.parent / 'Functions'
# New location: same folder as script
functions_dir_local = Path(__file__).parent / 'Functions'

def load_helpers() -> dict[str, callable]:
    """Load required helper functions dynamically and report missing modules clearly."""

    for functions_dir in [functions_dir_local, functions_dir_parent]:
        if functions_dir.exists() and str(functions_dir) not in sys.path:
            sys.path.append(str(functions_dir))

    required_helpers = {
        "insertNaNAtGaps": "insert_nan_at_gaps",
        "computeCumulativeCharge": "compute_cumulative_charge",
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
    
    # Configuration: set default folder to Cyclic_ageing_data (can be changed as needed)
    desired_folder = r'\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot\Cyclic_ageing_data'

    # MATLAB parity: when cell_num is set, process only that cell.
    cell_num = 'A2.02_Cell_56'

    # Get all folders in the directory matching *_Cell_*
    all_folders = [
        f for f in os.listdir(desired_folder)
        if os.path.isdir(os.path.join(desired_folder, f)) and '_Cell_' in f
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

        # Extract save path for figures from load_name
        save_path = os.path.dirname(load_name)
        print(f'Figures will be saved to: {save_path}')

        start_time = time.time()

        try:
            # Load data with specific options to match MATLAB behavior
            print(f'Loading {cell_num}')

            # Read CSV with first column as string (time column)
            df = pd.read_csv(load_name, dtype={0: str}, header=0)

            print(f'Data loaded successfully. (Elapsed: {time.time() - start_time:.2f} s)')

            # Reconstruct time vector
            time_yy_mm_dd_str = df.iloc[:, 0].values  # First column is time
            time_yy_mm_dd = pd.Series([pd.NaT] * len(time_yy_mm_dd_str), dtype='datetime64[ns]')

            # Parse first timestamp
            time_yy_mm_dd.iloc[0] = pd.to_datetime(time_yy_mm_dd_str[0], format='%d-%b-%Y %H:%M:%S.%f')

            # Convert subsequent values to cumulative seconds and add to base time
            increase_s = None
            if len(time_yy_mm_dd_str) > 1:
                increase_s = np.cumsum(pd.to_numeric(time_yy_mm_dd_str[1:], errors='coerce'))
                time_yy_mm_dd.iloc[1:] = time_yy_mm_dd.iloc[0] + pd.to_timedelta(increase_s, unit='s')

            # Extract other variables - using column names to match MATLAB behavior
            try:
                # MATLAB readtable sanitizes column names by replacing symbols with underscores.
                voltage_v = df['Voltage_V_'].values
                current_a = df['Current_A_'].values
                cell_temp_c = df['CellTemp__C_'].values
                chamber_temp_c = df['ChamberTemp__C_'].values
            except KeyError:
                # Fallback to positional indexing if unsanitized headers are present.
                voltage_v = df.iloc[:, 1].values
                current_a = df.iloc[:, 2].values
                cell_temp_c = df.iloc[:, 3].values
                chamber_temp_c = df.iloc[:, 4].values

            dwell_time_s = (time_yy_mm_dd - time_yy_mm_dd.iloc[0]).dt.total_seconds().values

            # Clear memory
            del df, time_yy_mm_dd_str
            if increase_s is not None:
                del increase_s
            print(f'Data extraction complete. (Elapsed: {time.time() - start_time:.2f} s)')

            # Insert NaN Values at Data Gaps
            (time_with_gaps, time_s, voltage, current, 
                 cell_temp, chamber_temp) = helpers['insert_nan_at_gaps'](
                time_yy_mm_dd, dwell_time_s, voltage_v, current_a, 
                cell_temp_c, chamber_temp_c)

            # Clear original arrays to free memory
            del time_yy_mm_dd, dwell_time_s, voltage_v, current_a, cell_temp_c, chamber_temp_c

            # Compute Cumulative Charge Integral
            cumulative_integral = helpers['compute_cumulative_charge'](time_s, current)

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

            # MATLAB parity: delete old PNG files immediately before saving new figures.
            for fname in os.listdir(save_path):
                if fname.endswith('.png'):
                    try:
                        os.remove(os.path.join(save_path, fname))
                    except Exception as e:
                        print(f'Could not delete {fname}: {e}')

            # Save All Figures
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

    # Create and save Resistance table
    if all_resistance_data:
        resistance_df = pd.DataFrame(all_resistance_data, columns=['CellNum', 'CellLabel', 'CheckupResistanceTimeStamp', 'CheckupResistance_Ohm', 'CheckupResistanceFEC'])
        resistance_path = os.path.join(desired_folder, f'OverviewResistanceData_{n_cells}cell.csv')
        resistance_df.to_csv(resistance_path, index=False)
        print(f'Resistance data saved to: {resistance_path}')

    # Create and save Capacity table
    if all_capacity_data:
        capacity_df = pd.DataFrame(all_capacity_data, columns=['CellNum', 'CellLabel', 'CheckupCapacityTimeStamp', 'CheckupCapacity_Ah', 'CheckupCapacityFEC'])
        capacity_path = os.path.join(desired_folder, f'OverviewCapacityData_{n_cells}cell.csv')
        capacity_df.to_csv(capacity_path, index=False)
        print(f'Capacity data saved to: {capacity_path}')

    print('\n' + '='*40)
    print(f'All tables saved to: {desired_folder}')
    print('='*40)

    # Keep figures open for interactive viewing
    plt.show()


if __name__ == '__main__':
    main()
