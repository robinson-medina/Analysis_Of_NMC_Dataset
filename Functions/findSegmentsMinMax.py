"""
findSegmentsMinMax - Find continuous segments within min/max length constraints

Author: Converted from MATLAB to Python
Date: November 25, 2025
"""

import numpy as np


def find_segments_min_max(logical_array, min_length, max_length):
    """
    Find continuous True segments in a logical array with length constraints.
    
    Parameters
    ----------
    logical_array : numpy.ndarray
        Boolean array where True indicates segment membership
    min_length : int
        Minimum segment length (inclusive)
    max_length : int
        Maximum segment length (inclusive)
    
    Returns
    -------
    list of numpy.ndarray
        List of index arrays for each valid segment
    """
    
    # Find transitions
    padded = np.concatenate([[False], logical_array, [False]])
    diff = np.diff(padded.astype(int))
    starts = np.where(diff == 1)[0]
    ends = np.where(diff == -1)[0]
    
    # Filter by length constraints
    segments = []
    for start, end in zip(starts, ends):
        length = end - start
        if min_length <= length <= max_length:
            segments.append(np.arange(start - 1, end + 2))  # Extend by 1 on each side
    
    return segments


__all__ = ['find_segments_min_max']
