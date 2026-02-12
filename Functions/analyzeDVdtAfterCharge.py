"""
analyzeDVdtAfterCharge - Analyze voltage relaxation rate after fast charge

This module analyzes dV/dt during discharge segments after fast charge
to examine voltage relaxation behavior.

Author: Converted from MATLAB to Python
Date: November 25, 2025
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch
import time
from findSegmentsMinMax import find_segments_min_max


def analyze_dvdt_after_charge(selected_time, selected_voltage, selected_current, 
                              selected_time_s, constant_current_value, cell_num):
    """
    Analyze voltage relaxation rate after fast charge by examining dV/dt.
    
    Parameters
    ----------
    selected_time : numpy.ndarray
        Datetime array for selected time range
    selected_voltage : numpy.ndarray
        Voltage array for selected range (Volts)
    selected_current : numpy.ndarray
        Current array for selected range (Amperes)
    selected_time_s : numpy.ndarray
        Time array in seconds for selected range
    constant_current_value : float
        Target current value to find (A)
    cell_num : str
        Cell identifier string for plot title
    
    Returns
    -------
    plotted_segments : list of dict
        List of dictionaries containing segment information
    dvdt_data : list of dict
        List of dictionaries containing dV/dt data for each segment
    """
    
    # Parameters
    tolerance = 0.1
    constant_current_indices = np.abs(selected_current - constant_current_value) <= tolerance
    
    # Filter for segments of appropriate length (900-1500 points)
    min_segment_length = 900
    max_segment_length = 1500
    
    # Find segments meeting criteria
    segments = find_segments_min_max(constant_current_indices, min_segment_length, max_segment_length)
    
    # Check if segments were found
    if len(segments) == 0:
        print('\n*** No detectable discharge cycles found. ***')
        print('*** This is probably calendar ageing data. ***\n')
        return [], []
    
    # Initialize figure with voltage overview and dV/dt analysis
    fig = plt.figure(figsize=(12, 10))
    
    # Upper subplot: voltage overview with arrow indicator
    ax1 = plt.subplot(2, 1, 1)
    ax1.plot(selected_time, selected_voltage)
    ax1.set_xlabel('Time')
    ax1.set_ylabel('Voltage [V]')
    ax1.set_ylim([2.75, 4.35])
    ax1.set_xlim([selected_time[0], selected_time[-1]])
    x_limits = ax1.get_xlim()
    
    # Lower subplot: dV/dt analysis
    ax2 = plt.subplot(2, 1, 2)
    
    # Select 5 segments distributed equally over time
    num_segments_to_plot = min(5, len(segments))
    segment_indices = np.round(np.linspace(0, len(segments) - 1, num_segments_to_plot)).astype(int)
    
    # Initialize output arrays
    plotted_segments = []
    dvdt_data = []
    legend_entries = []
    
    for idx in range(num_segments_to_plot):
        i = segment_indices[idx]
        segment_idx = segments[i]
        segment_voltage = selected_voltage[segment_idx]
        segment_time = selected_time[segment_idx]
        segment_time_s = selected_time_s[segment_idx]
        segment_time_s = segment_time_s - segment_time_s[0]  # Normalize to start at 0
        
        # Calculate smoothed dV/dt
        window_size = 50
        dv = np.gradient(segment_voltage)
        dt = np.gradient(segment_time_s)
        gradient_ratio = dv / dt
        mov_mean_gradient_ratio = pd.Series(gradient_ratio).rolling(
            window=window_size, center=True, min_periods=1).mean().values
        
        # Calculate color for this segment
        segment_color = [i/len(segments), 0, 1-i/len(segments)]
        
        # Create arrow annotation for current segment (new arrow each iteration)
        # Convert datetime to matplotlib date number for positioning
        time_start_mpl = pd.Timestamp(segment_time[0]).value / 1e9  # Convert to seconds
        time_limits_mpl = [pd.Timestamp(t).value / 1e9 for t in [selected_time[0], selected_time[-1]]]
        x_norm = (time_start_mpl - time_limits_mpl[0]) / (time_limits_mpl[1] - time_limits_mpl[0])
        x_norm = max(0, min(1, x_norm)) * 0.75 + 0.140
        
        # Add arrow in figure coordinates
        arrow = FancyArrowPatch((x_norm, 0.6), (x_norm, 0.9),
                               transform=fig.transFigure,
                               color=segment_color, linewidth=2,
                               arrowstyle='->', mutation_scale=20)
        fig.add_artist(arrow)
        plt.draw()
        plt.pause(0.001)
        
        # Plot dV/dt with color gradient
        dvdt = mov_mean_gradient_ratio
        ax2.plot(segment_time_s, dvdt, color=segment_color)
        ax2.set_ylim([-0.002, 0])
        ax2.set_xlim([0, 500])
        ax2.set_xlabel('Time [s]')
        ax2.set_ylabel('dV/dt [V/s]')
        
        # Store legend entry with date
        time_str = pd.Timestamp(segment_time[0]).strftime('%d-%b-%Y %H:%M')
        legend_entries.append(time_str)
        
        # Store segment data and dV/dt
        plotted_segments.append({
            'indices': segment_idx,
            'time': segment_time,
            'timeS': segment_time_s,
            'voltage': segment_voltage
        })
        dvdt_data.append({
            'timeS': segment_time_s,
            'dvdt': dvdt
        })
        

        plt.pause(0.01)
    
    # Add legend to lower subplot
    ax2.legend(legend_entries, loc='best')
    
    # Add title to figure
    fig.suptitle(f'dV/dt in discharge After Fast Charge {cell_num}', fontsize=14)
    plt.tight_layout()
    plt.draw()
    plt.pause(0.001)
    
    return plotted_segments, dvdt_data


# For compatibility with import statement in main script
__all__ = ['analyze_dvdt_after_charge']
