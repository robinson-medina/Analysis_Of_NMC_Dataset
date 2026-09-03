"""
extractResistanceValues - Calculate internal resistance from current pulses

This module identifies high-current pulse segments and calculates DC
resistance from the voltage drop during pulses using Ohm's law.

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
import time
import warnings
import re

from cellNumberToGroupChannel import cell_number_to_group_channel


def extract_resistance_values(time_with_gaps, voltage, current, time_s, 
                              start_time, end_time, cell_num, cell_label=''):
    """
    Calculate internal resistance from current pulses.
    
    This function identifies high-current pulse segments and calculates DC
    resistance from the voltage drop during pulses using Ohm's law.
    
    Parameters
    ----------
    time_with_gaps : numpy.ndarray
        Datetime array with timestamps (may contain NaT)
    voltage : numpy.ndarray
        Voltage array in Volts
    current : numpy.ndarray
        Current array in Amperes
    time_s : numpy.ndarray
        Time array in seconds (may contain NaN values)
    start_time : datetime or np.datetime64
        Start datetime for analysis range
    end_time : datetime or np.datetime64
        End datetime for analysis range
    cell_num : str
        Cell identifier string for plot title
    cell_label : str, optional
        Descriptive label from test plan (default: '')
    
    Returns
    -------
    checkup_resistance_timestamp : numpy.ndarray
        Datetime array of resistance measurement timestamps
    checkup_resistance : numpy.ndarray
        Array of measured DC resistance values (Ω)
    checkup_resistance_fec : numpy.ndarray
        Array of FEC values at resistance measurements
    """
    
    print('\nExtracting resistance values from current pulses...')
    tic = time.time()
    
    # Select data within the specified datetime range
    selected_indices = (time_with_gaps >= start_time) & (time_with_gaps <= end_time)
    selected_time = time_with_gaps[selected_indices]
    selected_voltage = voltage[selected_indices]
    selected_current = current[selected_indices]
    selected_time_s = time_s[selected_indices]
    
    # Identify high-current pulse segments
    constant_current_value = -58  # Target current in Amperes
    tolerance = 0.4               # Tolerance in Amperes
    constant_current_indices = np.abs(selected_current - constant_current_value) <= tolerance
    average_length = 5  # Number of samples to average V and I
    
    # Filter for pulse segments by time duration (typically ~30s duration)
    min_segment_time_s = 29
    max_segment_time_s = 31
    
    # Find segments meeting duration criteria
    segments = _find_segments_min_max(constant_current_indices, average_length, 
                                       selected_time, min_segment_time_s, max_segment_time_s)
    
    elapsed = time.time() - tic
    print(f'Found {len(segments)} current pulse segments. (Elapsed: {elapsed:.2f} s)')
    
    # Return empty arrays if no segments found
    if len(segments) == 0:
        warnings.warn('no segments found')
        return np.array([]), np.array([]), np.array([])
    
    # Calculate Full Equivalent Cycles using cumtrapz over time (to match MATLAB)
    # Use the already time-range-filtered selected_current/selected_time_s (matches
    # MATLAB's FullEquivalentCycles = cumtrapz(selectedTimeS, abs(selectedCurrent))/...);
    # using the raw, unfiltered time_s here would propagate NaN gap markers through
    # the whole cumulative integral once cumtrapz crosses the first gap.
    battery_capacity_ah = 58
    selected_time_s = np.asarray(selected_time_s)
    abs_current = np.abs(np.nan_to_num(selected_current))
    full_equivalent_cycles = np.concatenate(([0], cumtrapz(abs_current, selected_time_s))) / battery_capacity_ah / 3600 / 2
    
    # Initialize output arrays
    checkup_resistance_timestamp = []
    checkup_resistance = []
    checkup_resistance_fec = []
    
    # Initialize figure for resistance analysis (half screen width, full height)
    fig, (ax1, ax2) = plt.subplots(2, 1)
    # Get screen size and set figure to half width, full height
    fig_manager = plt.get_current_fig_manager()
    try:
        # Try to set window geometry (works with TkAgg, Qt backends)
        screen_width = fig.canvas.manager.window.winfo_screenwidth()
        screen_height = fig.canvas.manager.window.winfo_screenheight()
        fig_manager.window.geometry(f'{screen_width//2}x{screen_height}+0+0')
    except AttributeError:
        try:
            # For Qt backend
            fig_manager.window.setGeometry(0, 0, 
                                           fig_manager.window.screen().size().width() // 2,
                                           fig_manager.window.screen().size().height())
        except AttributeError:
            # Fallback: use figure size in inches
            fig.set_size_inches(10, 12)
    
    # Define line styles for plot variation
    line_styles = ['-', '--', ':', '-.']

    # Determine whether this cell belongs to the A3 (45 degC) or A4 (0-45 degC)
    # campaign, via the cell-number crosswalk (R-025: cell_num no longer carries
    # the campaign letter as a substring, so it can't be string-matched anymore).
    cell_digits = re.search(r'Cell_(\d+)', cell_num)
    is_campaign_a3_or_a4 = False
    if cell_digits:
        temp_group, _ = cell_number_to_group_channel(int(cell_digits.group(1)))
        is_campaign_a3_or_a4 = temp_group in (3, 4)

    # Loop through each pulse segment and calculate resistance
    for i, segment_indices in enumerate(segments):
        # Skip the first test for cell A3 and A4
        if is_campaign_a3_or_a4:
            if i == 0:
                continue
        
        # Select line style for this iteration
        line_idx = i % len(line_styles)
        current_line_style = line_styles[line_idx]
        
        # Include one point before pulse to capture voltage drop
        segment_indices = np.concatenate([[segment_indices[0] - 1], segment_indices])
        
        segment_voltage = selected_voltage[segment_indices]
        segment_current = selected_current[segment_indices]
        segment_time = selected_time[segment_indices]
        segment_time_s_local = selected_time_s[segment_indices].copy()
        segment_time_s_local = segment_time_s_local - segment_time_s_local[0]  # Normalize to start at 0
        
        # Fix for artificial delay introduced during data concatenation
        check_idx = average_length * 2 + 1
        if len(segment_time_s_local) > check_idx + 1:
            if segment_time_s_local[check_idx + 1] - segment_time_s_local[check_idx] > 2:
                sampling_time_s = segment_time_s_local[2] - segment_time_s_local[1]
                delta_time_s = segment_time_s_local[check_idx + 1] - segment_time_s_local[check_idx]
                segment_time_s_local[check_idx + 1:] = segment_time_s_local[check_idx + 1:] - delta_time_s + sampling_time_s
                warnings.warn(f'At time {segment_time[0]}, the algorithm corrected a delay created by concatenating multiple files of the original test data')
        
        # Color based on segment position (gradient from blue to red)
        num_segments = len(segments)
        color = [i / num_segments, 0, 1 - i / num_segments]
        
        # Plot voltage response to pulse
        ax1.plot(segment_time_s_local, segment_voltage,
                linestyle=current_line_style, linewidth=1.5, color=color)
        
        # Plot current pulse
        ax2.plot(segment_time_s_local, segment_current,
                linestyle=current_line_style, linewidth=1.5, color=color)
        
        # Calculate DC resistance from Ohm's law: R = ΔV / ΔI
        # Use averaged values at start and end of segment
        checkup_resistance_timestamp.append(segment_time[0])
        delta_v = np.mean(segment_voltage[-average_length:]) - np.mean(segment_voltage[:average_length])
        delta_i = np.mean(segment_current[-average_length:]) - np.mean(segment_current[:average_length])
        resistance = delta_v / delta_i if delta_i != 0 else np.nan
        checkup_resistance.append(resistance)
        checkup_resistance_fec.append(full_equivalent_cycles[segment_indices[0]])
    
    # Format subplot 1
    ax1.set_xlabel('Time [s]')
    ax1.set_ylabel('Voltage [V]')
    ax1.grid(True, alpha=0.3)
    
    # Format subplot 2
    ax2.set_xlabel('Time [s]')
    ax2.set_ylabel('Current [A]')
    ax2.grid(True, alpha=0.3)
    
    # Add title to figure
    if cell_label:
        fig.suptitle(f'30s Resistance Analysis - V Response to I Pulses {cell_num} - {cell_label}')
    else:
        fig.suptitle(f'30s Resistance Analysis - V Response to I Pulses {cell_num}')
    
    # Add legend with timestamps
    if len(checkup_resistance_timestamp) > 0:
        legend_labels = [str(ts) for ts in checkup_resistance_timestamp]
        ax1.legend(legend_labels, fontsize=8, loc='best')
    
    plt.tight_layout()
    plt.show(block=False)
    plt.pause(0.001)  # Brief pause to ensure plot renders
    
    elapsed = time.time() - tic
    print(f'Resistance extraction complete. (Elapsed: {elapsed:.2f} s)')
    
    # Convert lists to numpy arrays
    checkup_resistance_timestamp = np.array(checkup_resistance_timestamp)
    checkup_resistance = np.array(checkup_resistance)
    checkup_resistance_fec = np.array(checkup_resistance_fec)
    
    # Remove NaT entries from output arrays
    valid_idx = pd.notna(checkup_resistance_timestamp)
    checkup_resistance_timestamp = checkup_resistance_timestamp[valid_idx]
    checkup_resistance = checkup_resistance[valid_idx]
    checkup_resistance_fec = checkup_resistance_fec[valid_idx]
    
    return checkup_resistance_timestamp, checkup_resistance, checkup_resistance_fec


def _find_segments_min_max(indices, average_length, selected_time, min_duration_s, max_duration_s):
    """
    Find continuous segments where indices are True, with duration constraints.
    
    Parameters
    ----------
    indices : numpy.ndarray
        Boolean array indicating which points meet criteria
    average_length : int
        Number of samples to include before segment for averaging
    selected_time : numpy.ndarray
        Datetime array for duration calculation
    min_duration_s : float
        Minimum segment duration in seconds
    max_duration_s : float
        Maximum segment duration in seconds
    
    Returns
    -------
    segments : list of numpy.ndarray
        List where each element contains index ranges (as arrays)
    """
    
    segments = []
    
    # Find first True index
    true_indices = np.where(indices)[0]
    if len(true_indices) == 0:
        return segments
    
    start_idx = true_indices[0]
    
    while start_idx is not None:
        # Find where the segment ends
        remaining = indices[start_idx:]
        false_positions = np.where(~remaining)[0]
        
        if len(false_positions) == 0:
            end_idx = len(indices) - 1
        else:
            end_idx = false_positions[0] + start_idx - 1
        
        # Calculate segment duration
        segment_time = selected_time[start_idx:end_idx + 1]
        if len(segment_time) > 0:
            # Handle datetime64 or datetime objects
            try:
                duration = segment_time.max() - segment_time.min()
                # Convert to seconds if timedelta
                if hasattr(duration, 'total_seconds'):
                    duration_s = duration.total_seconds()
                else:
                    # numpy timedelta64
                    duration_s = duration / np.timedelta64(1, 's')
            except:
                duration_s = 0
            
            # Only keep segments within duration bounds
            if min_duration_s <= duration_s <= max_duration_s:
                # Include average_length*2 points before segment
                segment_start = max(0, start_idx - average_length * 2)
                segments.append(np.arange(segment_start, end_idx + 1))
        
        # Find next segment start
        remaining_after = indices[end_idx + 1:]
        next_true = np.where(remaining_after)[0]
        
        if len(next_true) == 0:
            start_idx = None
        else:
            start_idx = next_true[0] + end_idx + 1
    
    return segments


# For compatibility with import statement in main script
__all__ = ['extract_resistance_values']