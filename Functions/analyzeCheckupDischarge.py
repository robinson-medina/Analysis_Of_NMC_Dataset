"""
analyzeCheckupDischarge - Analyze and plot discharge curves for checkup cycles

This module processes constant-current discharge segments to calculate
capacity and generate dQ/dV plots for battery checkup analysis.

Author: Converted from MATLAB to Python
Date: November 25, 2025
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
try:  # scipy >= 1.6 renamed cumtrapz; it was removed in newer releases.
    from scipy.integrate import cumulative_trapezoid as cumtrapz
except ImportError:
    from scipy.integrate import cumtrapz
from scipy.interpolate import interp1d
import time


def analyze_checkup_discharge(segments, selected_time, selected_voltage, 
                              selected_current, selected_time_s, 
                              window_size, cell_num, cell_label=''):
    """
    Analyze and plot discharge curves for checkup cycles.
    
    This function processes constant-current discharge segments to calculate
    capacity and generate dQ/dV plots for battery checkup analysis.
    
    Parameters
    ----------
    segments : list of numpy.ndarray
        List of segment index ranges
    selected_time : numpy.ndarray
        Datetime array for selected time range
    selected_voltage : numpy.ndarray
        Voltage array for selected range (Volts)
    selected_current : numpy.ndarray
        Current array for selected range (Amperes)
    selected_time_s : numpy.ndarray
        Time array in seconds for selected range
    window_size : int
        Window size for moving average in dQ/dV calculation
    cell_num : str
        Cell identifier string for plot title
    cell_label : str, optional
        Descriptive label from test plan (default: '')
    
    Returns
    -------
    checkup_capacity_timestamp : numpy.ndarray
        Datetime array of checkup timestamps
    checkup_capacity : numpy.ndarray
        Array of measured discharge capacities (Ah)
    checkup_capacity_fec : numpy.ndarray
        Array of FEC values at capacity measurements
    legends : list of str
        List of legend strings
    checkup_ocv_v : list of numpy.ndarray
        Per-checkup OCV curve interpolated onto a 100-point SoC axis (V)
    dqdv_apervs : list of numpy.ndarray
        Per-checkup smoothed dQ/dV vector (matches segment_voltage length)
    segment_capacity_ah : list of numpy.ndarray
        Per-checkup per-sample discharge-capacity vector (Ah)
    checkup_soc : list of numpy.ndarray
        Per-checkup 100-point SoC axis (%), paired with checkup_ocv_v
    """
    
    # Initialize output arrays
    checkup_capacity_timestamp = []
    checkup_capacity = []
    checkup_capacity_fec = []
    legends = []
    # MATLAB-parity extra outputs (per-segment cell arrays in analyzeCheckupDischarge.m):
    # per-segment OCV-vs-SoC curve, dQ/dV curve, discharge-capacity vector, SoC axis.
    checkup_ocv_v = []
    dqdv_apervs = []
    segment_capacity_ah = []
    checkup_soc = []
    
    # Create figure for plotting (3 rows: capacity-vs-V, dQ/dV-vs-V, SoC-vs-OCV - matches MATLAB)
    fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(10, 12))
    
    # Calculate Full Equivalent Cycles using cumtrapz over time (to match MATLAB)
    battery_capacity_ah = 58
    # Ensure selected_time_s is a numpy array
    selected_time_s = np.asarray(selected_time_s)
    abs_current = np.abs(np.nan_to_num(selected_current))
    # Use cumtrapz for integration over time
    full_equivalent_cycles = np.concatenate(([0], cumtrapz(abs_current, selected_time_s))) / battery_capacity_ah / 3600 / 2
    
    # Define line styles for plot variation
    line_styles = ['-', '--', ':', '-.']
    
    # Loop through each segment and analyze discharge curves
    print('Analyzing discharge curves: ', end='')
    tic = time.time()
    
    for i, segment_indices in enumerate(segments):
        if (i % 5 == 0) or (i == 0):
            print(f'{i+1}/{len(segments)} ', end='', flush=True)
        
        # Select line style for this iteration
        line_idx = i % len(line_styles)
        current_line_style = line_styles[line_idx]
        
        # Extract segment data
        segment_voltage = selected_voltage[segment_indices]
        segment_current = selected_current[segment_indices]
        segment_time = selected_time[segment_indices]
        segment_time_s = selected_time_s[segment_indices]
        segment_time_s = segment_time_s - segment_time_s[0]  # Normalize to start at 0
        segment_fec = full_equivalent_cycles[segment_indices]
        
        # Only process complete discharge cycles (ending below 2.76V and starting above 4.1V)
        if segment_voltage[-1] < 2.76 and segment_voltage[0] > 4.1:
            # Calculate discharge capacity
            discharge_capacity = -cumtrapz(segment_current, segment_time_s, initial=0) / 3600
            
            # Color based on segment position (gradient from blue to red)
            color = [i/len(segments), 0, 1-i/len(segments)]
            
            # Plot discharge capacity vs voltage
            ax1.plot(discharge_capacity, segment_voltage,
                    linestyle=current_line_style, linewidth=1.5, color=color)
            
            # Calculate smoothed dQ/dV
            smooth_current = _moving_average(segment_current, window_size)
            smooth_voltage = _moving_average(segment_voltage, window_size)
            
            # Calculate charge capacity for dQ/dV
            charge_capacity = cumtrapz(smooth_current, segment_time_s, initial=0)
            
            # Calculate gradients
            dQ = np.gradient(charge_capacity)
            dV = np.gradient(smooth_voltage)
            
            # Avoid division by zero
            dV[dV == 0] = np.nan
            dQdV = _moving_average(dQ / dV, window_size)
            
            # Plot differential capacity (dQ/dV) vs voltage
            ax2.plot(segment_voltage, dQdV,
                    linestyle=current_line_style, linewidth=1.5, color=color)
            
            # Store capacity and timestamp for trending
            checkup_capacity_timestamp.append(segment_time[0])
            checkup_capacity.append(np.max(discharge_capacity))
            checkup_capacity_fec.append(segment_fec[0])

            # Store the full per-sample vectors (MATLAB SegmentCapacity_Ah / dQdV_AperVs cell arrays)
            segment_capacity_ah.append(discharge_capacity)
            dqdv_apervs.append(dQdV)

            # SoC starts at 100% and decreases during discharge; capacity_ah is this
            # segment's scalar checkup capacity (matches MATLAB's thisCheckup.capacity_Ah).
            capacity_ah = np.max(discharge_capacity)
            soc_raw = 100 - (discharge_capacity / capacity_ah) * 100

            # Interpolate SoC (100 points, 100% down to the segment minimum) and the
            # matching OCV, mirroring MATLAB's sort-descend + unique('stable') + interp1 extrap.
            soc_vec = np.linspace(100, np.min(soc_raw), 100)
            sort_idx = np.argsort(soc_raw)[::-1]
            sorted_soc = soc_raw[sort_idx]
            sorted_voltage = segment_voltage[sort_idx]
            unique_soc, unique_idx = np.unique(sorted_soc, return_index=True)
            unique_voltage = sorted_voltage[unique_idx]
            ocv_interp = interp1d(unique_soc, unique_voltage, kind='linear', fill_value='extrapolate')
            ocv_vec = ocv_interp(soc_vec)
            checkup_soc.append(soc_vec)
            checkup_ocv_v.append(ocv_vec)

            # Plot SoC vs OCV (matches MATLAB's subplot(3,1,3))
            ax3.plot(soc_vec, ocv_vec,
                    linestyle=current_line_style, linewidth=1.5, color=color)
            
            # Create legend entry
            time_str = pd.Timestamp(segment_time[0]).strftime('%y-%m-%dT%H:%M')
            legends.append(f' {time_str}')
    
    # Format subplot 1
    ax1.set_xlabel('Discharge Capacity [Ah]')
    ax1.set_ylabel('Voltage [V]')
    ax1.grid(True, alpha=0.3)
    ax1.legend(legends, fontsize=8, loc='best')
    
    # Format subplot 2
    ax2.set_xlabel('Cell Voltage [V]')
    ax2.set_ylabel('dQ/dV')
    ax2.grid(True, alpha=0.3)
    
    # Format subplot 3
    ax3.set_xlabel('State of Charge [%]')
    ax3.set_ylabel('OCV [V]')
    ax3.grid(True, alpha=0.3)
    
    # Add title to figure
    if cell_label:
        fig.suptitle(f'Checkup Analysis {cell_num} - {cell_label}', fontsize=14)
    else:
        fig.suptitle(f'Checkup Analysis {cell_num}', fontsize=14)
    plt.tight_layout()
    plt.show(block=False)
    plt.pause(0.001)  # Brief pause to ensure plot renders
    
    elapsed = time.time() - tic
    print(f'\nCheckup capacity analysis complete. (Elapsed: {elapsed:.2f} s)')
    
    # Convert lists to numpy arrays
    checkup_capacity_timestamp = np.array(checkup_capacity_timestamp)
    checkup_capacity = np.array(checkup_capacity)
    checkup_capacity_fec = np.array(checkup_capacity_fec)
    
    # Remove NaT entries from output arrays
    valid_idx = pd.notna(checkup_capacity_timestamp)
    checkup_capacity_timestamp = checkup_capacity_timestamp[valid_idx]
    checkup_capacity = checkup_capacity[valid_idx]
    checkup_capacity_fec = checkup_capacity_fec[valid_idx]
    checkup_ocv_v = [v for v, keep in zip(checkup_ocv_v, valid_idx) if keep]
    dqdv_apervs = [v for v, keep in zip(dqdv_apervs, valid_idx) if keep]
    segment_capacity_ah = [v for v, keep in zip(segment_capacity_ah, valid_idx) if keep]
    checkup_soc = [v for v, keep in zip(checkup_soc, valid_idx) if keep]
    
    return (checkup_capacity_timestamp, checkup_capacity, checkup_capacity_fec, legends,
            checkup_ocv_v, dqdv_apervs, segment_capacity_ah, checkup_soc)


def _moving_average(data, window_size):
    """
    Calculate moving average of data using specified window size.
    
    Parameters
    ----------
    data : numpy.ndarray
        Input data array
    window_size : int
        Window size for moving average
    
    Returns
    -------
    numpy.ndarray
        Smoothed data array
    """
    # Use pandas for moving average (equivalent to MATLAB's movmean)
    return pd.Series(data).rolling(window=window_size, center=True, min_periods=1).mean().values


# For compatibility with import statement in main script
__all__ = ['analyze_checkup_discharge']
