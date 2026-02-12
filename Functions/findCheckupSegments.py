"""
findCheckupSegments - Find constant-current discharge segments for checkup analysis

This module identifies constant-current discharge segments within a
specified time range for battery checkup capacity analysis.

Author: Converted from MATLAB to Python
Date: November 25, 2025
"""

import numpy as np
import pandas as pd
import time


def find_checkup_segments(time_with_gaps, voltage, current, time_s, start_time, end_time):
    """
    Find constant-current discharge segments for checkup analysis.
    
    This function identifies constant-current discharge segments within a
    specified time range for battery checkup capacity analysis.
    
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
    
    Returns
    -------
    segments : list of numpy.ndarray
        List where each element contains index ranges of
        constant-current discharge segments
    """
    
    print('\nStarting checkup capacity analysis...')
    tic = time.time()  # Start timer
    
    # Select data within the specified datetime range
    selected_indices = (time_with_gaps >= start_time) & (time_with_gaps <= end_time)
    selected_time = time_with_gaps[selected_indices]
    selected_voltage = voltage[selected_indices]
    selected_current = current[selected_indices]
    selected_time_s = time_s[selected_indices]
    
    # Identify segments where current is constant (checkup discharge)
    # Target current: -1.16 A (58/50), tolerance: ±0.1 A
    constant_current_value = -58/50
    tolerance = 0.1
    constant_current_indices = np.abs(selected_current - constant_current_value) <= tolerance
    
    # Segment filtering parameters
    min_segment_length = 2000  # Minimum data points for valid checkup
    
    # Find constant-current segments that meet minimum length requirement
    segments = _find_segments(constant_current_indices, min_segment_length)
    
    elapsed = time.time() - tic
    print(f'Found {len(segments)} checkup discharge segments. (Elapsed: {elapsed:.2f} s)')
    
    return segments


def _find_segments(indices, min_length):
    """
    Find continuous segments where indices are True, with minimum length.
    
    Parameters
    ----------
    indices : numpy.ndarray
        Boolean array indicating which points meet criteria
    min_length : int
        Minimum number of consecutive True values to form a segment
    
    Returns
    -------
    segments : list of numpy.ndarray
        List where each element contains index ranges (as arrays)
    """
    
    segments = []
    
    # Find all indices where True values start
    diff_indices = np.diff(np.concatenate([[False], indices, [False]]).astype(int))
    start_indices = np.where(diff_indices == 1)[0]
    end_indices = np.where(diff_indices == -1)[0]
    
    # Filter segments by minimum length
    for start_idx, end_idx in zip(start_indices, end_indices):
        if (end_idx - start_idx) >= min_length:
            segments.append(np.arange(start_idx, end_idx))
    
    return segments


# For compatibility with import statement in main script
__all__ = ['find_checkup_segments']