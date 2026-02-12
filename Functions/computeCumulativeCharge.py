"""
computeCumulativeCharge - Calculate cumulative charge integral

This function calculates the cumulative charge (capacity) by integrating
current over time. It processes each continuous segment separately,
splitting by NaN gaps to maintain data integrity.
"""

import numpy as np
from scipy.integrate import cumtrapz
import time


def compute_cumulative_charge(time_s, current):
    """
    Calculate cumulative charge integral.
    
    Parameters
    ----------
    time_s : numpy.ndarray
        Time array in seconds (may contain NaN values to mark gaps)
    current : numpy.ndarray
        Current array in Amperes (corresponding to time_s)
    
    Returns
    -------
    cumulative_integral : numpy.ndarray
        Cumulative charge in Ampere-seconds (As)
        Contains NaN values at gap positions
    """
    
    print('Computing cumulative charge integral...')
    start_time = time.time()
    
    # Pre-allocate output array
    cumulative_integral = np.full(len(time_s), np.nan)
    
    # Find NaN positions
    nan_mask = np.isnan(time_s)
    
    # Find continuous segments (between NaNs)
    # Add sentinels at start and end
    boundaries = np.concatenate([[True], nan_mask, [True]])
    # Find transitions
    diff = np.diff(boundaries.astype(int))
    
    # Start indices are where we go from NaN (or start) to valid data
    start_indices = np.where(diff == -1)[0]
    # End indices are where we go from valid data to NaN (or end)
    end_indices = np.where(diff == 1)[0]
    
    # Process each segment
    for start_idx, end_idx in zip(start_indices, end_indices):
        if end_idx > start_idx:  # Valid segment
            segment_time = time_s[start_idx:end_idx]
            segment_current = current[start_idx:end_idx]
            
            # Use scipy's cumtrapz for efficient cumulative integration
            segment_cumulative = cumtrapz(segment_current, segment_time, initial=0)
            
            # Store in output array
            cumulative_integral[start_idx:end_idx] = segment_cumulative
    
    elapsed = time.time() - start_time
    print(f'Cumulative charge calculation complete. (Elapsed: {elapsed:.2f} s)')
    
    return cumulative_integral
