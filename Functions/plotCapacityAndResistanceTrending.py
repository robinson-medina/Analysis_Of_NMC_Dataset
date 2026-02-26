"""
Plot Capacity and Resistance Trending

This function creates trending plots for battery capacity degradation
and resistance growth over time.
Capacity plot shows FEC as text labels at each point.
Resistance plot includes FEC values below date ticks.

Author: Róbinson
Created: November 25, 2025
"""

import matplotlib.pyplot as plt
import numpy as np


def plot_capacity_and_resistance_trending(checkup_capacity_timestamp, checkup_capacity,
                                          checkup_capacity_fec,
                                          checkup_resistance_timestamp, checkup_resistance,
                                          checkup_resistance_fec,
                                          cell_num, cell_label=''):
    """
    Plot capacity and resistance trending over time.
    
    Parameters:
    -----------
    checkup_capacity_timestamp : array-like
        Timestamps for capacity measurements
    checkup_capacity : array-like
        Discharge capacity values in Ah
    checkup_capacity_fec : array-like
        FEC values at capacity measurements
    checkup_resistance_timestamp : array-like
        Timestamps for resistance measurements
    checkup_resistance : array-like
        Resistance values in Ω
    checkup_resistance_fec : array-like
        FEC values at resistance measurements
    cell_num : str
        Cell identifier for plot titles
    cell_label : str, optional
        Descriptive label from test plan (default: '')
    """
    print('\nGenerating capacity and resistance trending plots...')
    
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))
    
    # Capacity degradation over time
    ax1.scatter(checkup_capacity_timestamp, checkup_capacity)
    ax1.set_ylim([20, 62])
    ax1.set_ylabel('Discharge Capacity [Ah]')
    if cell_label:
        ax1.set_title(f'Capacity Degradation Trending {cell_num} - {cell_label}')
    else:
        ax1.set_title(f'Capacity Degradation Trending {cell_num}')
    ax1.grid(True)
    
    # Add FEC values as text below each date tick label
    y_limits1 = ax1.get_ylim()
    y_offset1 = y_limits1[0] - 0.05 * (y_limits1[1] - y_limits1[0])
    for i, (ts, fec) in enumerate(zip(checkup_capacity_timestamp, checkup_capacity_fec)):
        ax1.text(ts, y_offset1, f'({int(round(fec))})', 
                ha='center', va='top', fontsize=8, clip_on=False)
    
    # Create two-line xlabel
    ax1.set_xlabel('Date\\n(FEC)')
    
    # Resistance growth over time
    ax2.scatter(checkup_resistance_timestamp, checkup_resistance)
    ax2.set_ylim([0.5e-3, 10e-3])
    ax2.set_ylabel('Resistance [Ω]')
    if cell_label:
        ax2.set_title(f'Resistance Growth (30s Pulse Method) {cell_num} - {cell_label}')
    else:
        ax2.set_title(f'Resistance Growth (30s Pulse Method) {cell_num}')
    ax2.grid(True)
    
    # Add FEC values as text below each date tick label
    y_limits2 = ax2.get_ylim()
    y_offset2 = y_limits2[0] - 0.05 * (y_limits2[1] - y_limits2[0])
    for i, (ts, fec) in enumerate(zip(checkup_resistance_timestamp, checkup_resistance_fec)):
        ax2.text(ts, y_offset2, f'({int(round(fec))})', 
                ha='center', va='top', fontsize=8, clip_on=False)
    
    # Create two-line xlabel
    ax2.set_xlabel('Date\\n(FEC)')
    
    plt.tight_layout()
    plt.show(block=False)
    plt.pause(0.001)  # Brief pause to ensure plot renders
    
    print('Trending plots created.')
