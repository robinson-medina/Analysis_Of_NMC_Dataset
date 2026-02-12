"""
insertNaNAtGaps - Insert NaN values at data gaps

This function detects and inserts NaN values at data gaps to prevent
continuous lines in plots across discontinuous data segments.
"""

import numpy as np
import pandas as pd
import time


def insert_nan_at_gaps(time_yy_mm_dd, dwell_time_s, voltage_v, current_a, cell_temp_c, chamber_temp_c):
    """
    Insert NaN values at data gaps.
    
    Parameters
    ----------
    time_yy_mm_dd : numpy.ndarray
        Datetime array of timestamps (datetime64)
    dwell_time_s : numpy.ndarray
        Dwell time in seconds
    voltage_v : numpy.ndarray
        Cell voltage in Volts
    current_a : numpy.ndarray
        Cell current in Amperes
    cell_temp_c : numpy.ndarray
        Cell surface temperature in Celsius
    chamber_temp_c : numpy.ndarray
        Chamber ambient temperature in Celsius
    
    Returns
    -------
    time_with_gaps : numpy.ndarray
        Datetime array with NaT inserted at gaps
    time_s : numpy.ndarray
        Time in seconds with NaN at gaps
    voltage : numpy.ndarray
        Voltage with NaN at gaps
    current : numpy.ndarray
        Current with NaN at gaps
    cell_temp : numpy.ndarray
        Cell temperature with NaN at gaps
    chamber_temp : numpy.ndarray
        Chamber temperature with NaN at gaps
    """
    
    print('Detecting and processing data gaps...')
    start_time = time.time()
    
    # Calculate the time differences between consecutive data points
    time_diff = np.diff(pd.to_datetime(time_yy_mm_dd))
    
    # Find indices where the gap is longer than 1 minute
    gap_indices = np.where(time_diff > pd.Timedelta(minutes=1))[0] + 1  # +1 to get position after gap
    gap_indices = gap_indices.tolist()
    
    # Find periods where current is zero for certain amount of samples and voltage lower than threshold
    voltage_threshold = 3.3  # minimum voltage with zero current
    rest_samples = 60  # minimum number of samples to detect with 0 current
    count_time_samples = 0
    current_state = 1
    
    for i in range(len(dwell_time_s)):
        if (current_a[i] == 0) and (voltage_v[i] < voltage_threshold):
            count_time_samples += 1
            if (count_time_samples >= rest_samples) and current_state:
                gap_indices.append(i)
                current_state = 0
        else:
            count_time_samples = 0
            current_state = 1
    
    gap_indices = sorted(gap_indices)
    print(f'Found {len(gap_indices)} data gaps. Inserting NaN values...')
    start_time = time.time()
    
    # Pre-allocate arrays with final size (much faster than repeated concatenation)
    num_gaps = len(gap_indices)
    original_length = len(time_yy_mm_dd)
    final_length = original_length + num_gaps
    
    # Pre-allocate with appropriate types - match the dtype of the input time array
    time_with_gaps = np.full(final_length, np.datetime64('NaT'), dtype=time_yy_mm_dd.dtype)
    dwell_time_with_gaps = np.full(final_length, np.nan)
    voltage_with_gaps = np.full(final_length, np.nan)
    current_with_gaps = np.full(final_length, np.nan)
    cell_temp_with_gaps = np.full(final_length, np.nan)
    chamber_temp_with_gaps = np.full(final_length, np.nan)
    
    # Fill in the data with gaps
    source_idx = 0
    dest_idx = 0
    
    for i, gap_pos in enumerate(gap_indices):
        # Copy data up to the gap
        chunk_size = gap_pos - source_idx
        if chunk_size > 0:
            time_with_gaps[dest_idx:dest_idx+chunk_size] = time_yy_mm_dd[source_idx:gap_pos]
            dwell_time_with_gaps[dest_idx:dest_idx+chunk_size] = dwell_time_s[source_idx:gap_pos]
            voltage_with_gaps[dest_idx:dest_idx+chunk_size] = voltage_v[source_idx:gap_pos]
            current_with_gaps[dest_idx:dest_idx+chunk_size] = current_a[source_idx:gap_pos]
            cell_temp_with_gaps[dest_idx:dest_idx+chunk_size] = cell_temp_c[source_idx:gap_pos]
            chamber_temp_with_gaps[dest_idx:dest_idx+chunk_size] = chamber_temp_c[source_idx:gap_pos]
            dest_idx += chunk_size
        
        # NaN is already in place from pre-allocation
        dest_idx += 1  # Skip the NaN position
        source_idx = gap_pos
        
        # Show progress every 5%
        if i % max(1, round(num_gaps * 0.05)) == 0:
            percent_complete = round(i / num_gaps * 100)
            print(f'  Progress: {percent_complete}% ({i}/{num_gaps} gaps processed)')
    
    # Copy remaining data after last gap
    if source_idx < original_length:
        remaining_size = original_length - source_idx
        time_with_gaps[dest_idx:dest_idx+remaining_size] = time_yy_mm_dd[source_idx:]
        dwell_time_with_gaps[dest_idx:dest_idx+remaining_size] = dwell_time_s[source_idx:]
        voltage_with_gaps[dest_idx:dest_idx+remaining_size] = voltage_v[source_idx:]
        current_with_gaps[dest_idx:dest_idx+remaining_size] = current_a[source_idx:]
        cell_temp_with_gaps[dest_idx:dest_idx+remaining_size] = cell_temp_c[source_idx:]
        chamber_temp_with_gaps[dest_idx:dest_idx+remaining_size] = chamber_temp_c[source_idx:]
    
    print(f'NaN insertion complete. (Elapsed: {time.time() - start_time:.2f} s)')
    
    # Assign to output variable names
    time_s = dwell_time_with_gaps
    voltage = voltage_with_gaps
    current = current_with_gaps
    cell_temp = cell_temp_with_gaps
    chamber_temp = chamber_temp_with_gaps
    
    return time_with_gaps, time_s, voltage, current, cell_temp, chamber_temp
