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

def main():
    """Main analysis workflow for battery test data."""
    
    print('\n' + '='*40)
    print('Battery Test Data Analysis for NextBMS journal')
    print('='*40)
    
    # Configuration
    # desired_folder = '\\\\tsn.tno.nl\\RA-Data\\SV\\sv-072952\\BTS Data\\NEXTBMS\\ZenodoRoot\\Cyclic_ageing_data'
    desired_folder = '\\\\tsn.tno.nl\\RA-Data\\SV\\sv-072952\\BTS Data\\NEXTBMS\\ZenodoRoot\\Calendar_ageing_data'
    
    # Get all folders in the directory
    folders = [f for f in os.listdir(desired_folder) if os.path.isdir(os.path.join(desired_folder, f))]
    
    # Initialize lists to accumulate data from all cells
    all_resistance_data = []
    all_dvdt_data = []
    all_capacity_data = []
    all_dqdv_data = []
    
    # Process each cell
    for cell_num in folders[:1]:  # Process only the first folder
        plt.close('all')  # Close all figures before processing a new cell
        
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
            # MATLAB opts: VariableTypes{1}='string', DataLines=[2 Inf], VariableNamesLine=1
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
            # If column names are not as expected, fall back to positional indexing
            try:
                voltage_v = df['Voltage [V]'].values  # Voltage [V]
                current_a = df['Current [A]'].values  # Current [A]
                cell_temp_c = df['CellTemp [°C]'].values  # Cell temp [°C]
                chamber_temp_c = df['ChamberTemp [°C]'].values  # Chamber temp [°C]
            except KeyError:
                # Fall back to positional indexing if column names don't match
                voltage_v = df.iloc[:, 1].values  # Voltage [V]
                current_a = df.iloc[:, 2].values  # Current [A]
                cell_temp_c = df.iloc[:, 3].values  # Cell temp [°C]
                chamber_temp_c = df.iloc[:, 4].values  # Chamber temp [°C]
                
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
                              chamber_temp, cumulative_integral, cell_num)
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
            window_size = 500
            
            # Analyze discharge curves and calculate checkup capacity
            (checkup_capacity_timestamp, checkup_capacity_ah, legends) = analyze_checkup_discharge(
                segments, selected_time, selected_voltage, selected_current, 
                selected_time_s, window_size, cell_num)
            fig_checkup_discharge = plt.gcf()
            
            # Initialize empty values for the variables that aren't returned by the Python function
            segment_voltage_v = []
            dqdv_a_per_vs = []
            segment_capacity_ah = []
            
            # Extract Resistance Values
            (checkup_resistance_timestamp, 
             checkup_resistance_ohm) = extract_resistance_values(
                time_with_gaps, voltage, current, time_s, 
                start_time_analysis, end_time_analysis, cell_num)
            fig_resistance = plt.gcf()
            
            # Plot Capacity and Resistance Trending
            plot_capacity_and_resistance_trending(
                checkup_capacity_timestamp, checkup_capacity_ah,
                checkup_resistance_timestamp, checkup_resistance_ohm,
                cell_num)
            fig_cap_res_trend = plt.gcf()
            
            # dV/dt Analysis
            constant_current_value_a = -11.6
            
            # Perform dV/dt analysis
            (plotted_segments, dvdt_data) = analyze_dvdt_after_charge(
                selected_time, selected_voltage, selected_current, 
                selected_time_s, constant_current_value_a, cell_num)
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
            
            # Accumulate resistance data
            for i in range(len(checkup_resistance_timestamp)):
                all_resistance_data.append({
                    'CellNum': cell_num,
                    'CheckupResistanceTimeStamp': checkup_resistance_timestamp[i],
                    'CheckupResistance_Ohm': checkup_resistance_ohm[i]
                })
            
            # # Accumulate dV/dt data (expand struct arrays into rows)
            # num_dvdt_segments = len(plotted_segments)
            # for i in range(num_dvdt_segments):
            #     segment_num = plotted_segments[i]
            #     if isinstance(dvdt_data, list):
            #         seg_data = dvdt_data[i]
            #     else:
            #         seg_data = dvdt_data[i]
            #     # Each segment has timeS and dVdt_Vpers arrays
            #     num_points = len(seg_data.timeS)
            #     for j in range(num_points):
            #         all_dvdt_data.append({
            #             'CellNum': cell_num,
            #             'SegmentNum': segment_num,
            #             'timeS': seg_data.timeS[j],
            #             'dVdt_Vpers': seg_data.dVdt_Vpers[j]
            #         })
            
            # Accumulate capacity data
            for i in range(len(checkup_capacity_timestamp)):
                legend_val = legends[i] if i < len(legends) else ''
                all_capacity_data.append({
                    'CellNum': cell_num,
                    'CheckupCapacityTimeStamp': checkup_capacity_timestamp[i],
                    'CheckupCapacity_Ah': checkup_capacity_ah[i],
                    'Legends': legend_val
                })
            
            # # Accumulate dQ/dV data
            # num_dqdv_points = len(segment_voltage_v)
            # for i in range(num_dqdv_points):
            #     if isinstance(segment_voltage_v, list):
            #         all_dqdv_data.append({
            #             'CellNum': cell_num,
            #             'SegmentVoltage_V': segment_voltage_v[i],
            #             'dQdV_AperVs': dqdv_a_per_vs[i],
            #             'SegmentCapacity_Ah': segment_capacity_ah[i]
            #         })
            #     else:
            #         all_dqdv_data.append({
            #             'CellNum': cell_num,
            #             'SegmentVoltage_V': segment_voltage_v[i],
            #             'dQdV_AperVs': dqdv_a_per_vs[i],
            #             'SegmentCapacity_Ah': segment_capacity_ah[i]
            #         })
            
        except Exception as e:
            print(f'Error processing cell {cell_num}: {str(e)}')
            continue
    
    # Save All Tables to CSV
    print('\n' + '='*40)
    print('Saving data tables to CSV files...')
    print('='*40)
    
    # Create and save Resistance table
    if all_resistance_data:
        resistance_df = pd.DataFrame(all_resistance_data)
        resistance_path = os.path.join(desired_folder, 'AllCells_ResistanceData.csv')
        resistance_df.to_csv(resistance_path, index=False)
        print(f'Resistance data saved to: {resistance_path}')
    
    # # Create and save dV/dt table
    # if all_dvdt_data:
    #     dvdt_df = pd.DataFrame(all_dvdt_data)
    #     dvdt_path = os.path.join(desired_folder, 'AllCells_dVdtData.csv')
    #     dvdt_df.to_csv(dvdt_path, index=False)
    #     print(f'dV/dt data saved to: {dvdt_path}')
    
    # Create and save Capacity table
    if all_capacity_data:
        capacity_df = pd.DataFrame(all_capacity_data)
        capacity_path = os.path.join(desired_folder, 'AllCells_CapacityData.csv')
        capacity_df.to_csv(capacity_path, index=False)
        print(f'Capacity data saved to: {capacity_path}')
    
    # # Create and save dQ/dV table
    # if all_dqdv_data:
    #     dqdv_df = pd.DataFrame(all_dqdv_data)
    #     dqdv_path = os.path.join(desired_folder, 'AllCells_dQdVData.csv')
    #     dqdv_df.to_csv(dqdv_path, index=False)
    #     print(f'dQ/dV data saved to: {dqdv_path}')
    
    print('\n' + '='*40)
    print(f'All tables saved to: {desired_folder}')
    print('='*40)


if __name__ == '__main__':
    main()
