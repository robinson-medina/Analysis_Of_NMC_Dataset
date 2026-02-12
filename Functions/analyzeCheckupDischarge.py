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
from scipy.integrate import cumtrapz
import time


def analyze_checkup_discharge(segments, selected_time, selected_voltage, 
                              selected_current, selected_time_s, 
                              window_size, cell_num):
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
    
    Returns
    -------
    checkup_capacity_timestamp : numpy.ndarray
        Datetime array of checkup timestamps
    checkup_capacity : numpy.ndarray
        Array of measured discharge capacities (Ah)
    legends : list of str
        List of legend strings
    """
    
    # Initialize output arrays
    checkup_capacity_timestamp = []
    checkup_capacity = []
    legends = []
    
    # Create figure for plotting
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 10))
    
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
        
        # Only process complete discharge cycles (ending below 2.76V)
        if segment_voltage[-1] < 2.76:
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
            
            # Create legend entry
            time_str = pd.Timestamp(segment_time[0]).strftime('%Y-%m-%d %H:%M:%S')
            legends.append(f'Check up time {time_str}')
    
    # Format subplot 1
    ax1.set_xlabel('Discharge Capacity [Ah]')
    ax1.set_ylabel('Voltage [V]')
    ax1.grid(True, alpha=0.3)
    ax1.legend(legends, fontsize=8, loc='best')
    
    # Format subplot 2
    ax2.set_xlabel('Cell Voltage [V]')
    ax2.set_ylabel('dQ/dV')
    ax2.grid(True, alpha=0.3)
    
    # Add title to figure
    fig.suptitle(f'Checkup Analysis {cell_num}', fontsize=14)
    plt.tight_layout()
    plt.show(block=False)
    plt.pause(0.001)  # Brief pause to ensure plot renders
    
    elapsed = time.time() - tic
    print(f'\nCheckup capacity analysis complete. (Elapsed: {elapsed:.2f} s)')
    
    # Convert lists to numpy arrays
    checkup_capacity_timestamp = np.array(checkup_capacity_timestamp)
    checkup_capacity = np.array(checkup_capacity)
    
    return checkup_capacity_timestamp, checkup_capacity, legends


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
