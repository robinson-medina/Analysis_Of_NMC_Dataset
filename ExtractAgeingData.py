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
from datetime import datetime, timedelta
import time
import sys
import os
from pathlib import Path

# Add functions directory to path (check both locations)
# Original location: one folder up
functions_dir_parent = Path(__file__).parent.parent / 'Functions'
# New location: same folder as script
functions_dir_local = Path(__file__).parent / 'Functions'

if functions_dir_local.exists():
    sys.path.append(str(functions_dir_local))
elif functions_dir_parent.exists():
    sys.path.append(str(functions_dir_parent))
else:
    raise ImportError("Functions directory not found in either location")

# Import functions
from insertNaNAtGaps import insert_nan_at_gaps
from computeCumulativeCharge import compute_cumulative_charge
from plotOverviewData import plot_overview_data
from findCheckupSegments import find_checkup_segments
from analyzeCheckupDischarge import analyze_checkup_discharge
from extractResistanceValues import extract_resistance_values
from plotCapacityAndResistanceTrending import plot_capacity_and_resistance_trending
from analyzeDVdtAfterCharge import analyze_dvdt_after_charge
from getCellLabel import get_cell_label

def main():
    """Main analysis workflow for battery test data."""
    
    print('\n' + '='*40)
    print('Battery Test Data Analysis for NextBMS journal')
    print('='*40)
    
    # Configuration: set default folder to Cyclic_ageing_data (can be changed as needed)
    desired_folder = r'\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot\Cyclic_ageing_data'

    # Get all folders in the directory matching *_Cell_*
    folders = [f for f in os.listdir(desired_folder) if os.path.isdir(os.path.join(desired_folder, f)) and '_Cell_' in f]

    # Initialize lists to accumulate data from all cells
    all_resistance_data = []
    all_capacity_data = []
    # all_dvdt_data = []
    # all_dqdv_data = []

    # Process each cell folder
    for cell_num in folders:
        plt.close('all')  # Close all figures before processing a new cell

        # Generate descriptive label for cell based on ageing test plan
        cell_label = get_cell_label(cell_num)

        print('\n' + '='*40)
        print(f'Battery Test Data Analysis for NextBMS journal')
        print('='*40)

        load_name = os.path.join(desired_folder, cell_num, f'{cell_num}.csv')
        print(f'Loading data for cell: {cell_num}...')

        # Extract save path for figures from load_name
        save_path = os.path.dirname(load_name)
        print(f'Figures will be saved to: {save_path}')

        # Remove existing PNG files in the cell folder before saving new ones
        for fname in os.listdir(save_path):
            if fname.endswith('.png'):
                try:
                    os.remove(os.path.join(save_path, fname))
                except Exception as e:
                    print(f'Could not delete {fname}: {e}')

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
            if len(time_yy_mm_dd_str) > 1:
                increase_s = np.cumsum(pd.to_numeric(time_yy_mm_dd_str[1:], errors='coerce'))
                time_yy_mm_dd.iloc[1:] = time_yy_mm_dd.iloc[0] + pd.to_timedelta(increase_s, unit='s')

            # Extract other variables - using column names to match MATLAB behavior
            try:
                voltage_v = df['Voltage [V]'].values
                current_a = df['Current [A]'].values
                cell_temp_c = df['CellTemp [°C]'].values
                chamber_temp_c = df['ChamberTemp [°C]'].values
            except KeyError:
                voltage_v = df.iloc[:, 1].values
                current_a = df.iloc[:, 2].values
                cell_temp_c = df.iloc[:, 3].values
                chamber_temp_c = df.iloc[:, 4].values

            dwell_time_s = (time_yy_mm_dd - time_yy_mm_dd.iloc[0]).dt.total_seconds().values

            # Clear memory
            del df, time_yy_mm_dd_str, increase_s
            print(f'Data extraction complete. (Elapsed: {time.time() - start_time:.2f} s)')

            # Insert NaN Values at Data Gaps
            (time_with_gaps, time_s, voltage, current, 
             cell_temp, chamber_temp) = insert_nan_at_gaps(
                time_yy_mm_dd, dwell_time_s, voltage_v, current_a, 
                cell_temp_c, chamber_temp_c)

            # Clear original arrays to free memory
            del time_yy_mm_dd, dwell_time_s, voltage_v, current_a, cell_temp_c, chamber_temp_c

            # Compute Cumulative Charge Integral
            cumulative_integral = compute_cumulative_charge(time_s, current)

            # Plot Overview Data
            plot_overview_data(time_with_gaps, current, voltage, cell_temp, 
                              chamber_temp, cumulative_integral, cell_num, cell_label)
            fig_overview = plt.gcf()

            # Checkup Capacity Analysis
            start_time_analysis = time_with_gaps[0]
            end_time_analysis = time_with_gaps[-20]

            # Find constant-current discharge segments for checkup analysis
            segments = find_checkup_segments(time_with_gaps, voltage, current, time_s, 
                                            start_time_analysis, end_time_analysis)

            # Select data within the specified datetime range for plotting
            selected_indices = (time_with_gaps >= start_time_analysis) & (time_with_gaps <= end_time_analysis)
            selected_time = time_with_gaps[selected_indices]
            selected_voltage = voltage[selected_indices]
            selected_current = current[selected_indices]
            selected_time_s = time_s[selected_indices]

            # Window for moving average in dQ/dV calculation
            window_size = 5000

            # Analyze discharge curves and calculate checkup capacity
            (checkup_capacity_timestamp, checkup_capacity_ah, checkup_capacity_fec, legends) = analyze_checkup_discharge(
                segments, selected_time, selected_voltage, selected_current, 
                selected_time_s, window_size, cell_num, cell_label)
            fig_checkup_discharge = plt.gcf()

            # Extract Resistance Values
            (checkup_resistance_timestamp, 
             checkup_resistance_ohm,
             checkup_resistance_fec) = extract_resistance_values(
                time_with_gaps, voltage, current, time_s, 
                start_time_analysis, end_time_analysis, cell_num, cell_label)
            fig_resistance = plt.gcf()

            # Plot Capacity and Resistance Trending
            plot_capacity_and_resistance_trending(
                checkup_capacity_timestamp, checkup_capacity_ah, checkup_capacity_fec,
                checkup_resistance_timestamp, checkup_resistance_ohm, checkup_resistance_fec,
                cell_num, cell_label)
            fig_cap_res_trend = plt.gcf()

            # dV/dt Analysis
            constant_current_value_a = -11.6

            # Perform dV/dt analysis
            (plotted_segments, dvdt_data) = analyze_dvdt_after_charge(
                selected_time, selected_voltage, selected_current, 
                selected_time_s, constant_current_value_a, cell_num, cell_label)
            fig_dvdt = plt.gcf()

            # Save All Figures
            print('\nSaving figures...')
            plt.figure(fig_overview.number)
            plt.savefig(os.path.join(save_path, f'{cell_num}_Overview.png'))
            plt.figure(fig_checkup_discharge.number)
            plt.savefig(os.path.join(save_path, f'{cell_num}_CheckupDischarge.png'))
            plt.figure(fig_resistance.number)
            plt.savefig(os.path.join(save_path, f'{cell_num}_Resistance.png'))
            plt.figure(fig_cap_res_trend.number)
            plt.savefig(os.path.join(save_path, f'{cell_num}_CapacityResistanceTrend.png'))
            plt.figure(fig_dvdt.number)
            plt.savefig(os.path.join(save_path, f'{cell_num}_dVdtAnalysis.png'))

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
            continue

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
