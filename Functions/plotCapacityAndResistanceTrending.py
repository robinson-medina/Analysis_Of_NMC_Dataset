"""
Plot Capacity and Resistance Trending

This function creates trending plots for battery capacity degradation
and resistance growth over time.

Author: Róbinson
Created: November 25, 2025
"""

import matplotlib.pyplot as plt


def plot_capacity_and_resistance_trending(checkup_capacity_timestamp, checkup_capacity,
                                          checkup_resistance_timestamp, checkup_resistance,
                                          cell_num):
    """
    Plot capacity and resistance trending over time.
    
    Parameters:
    -----------
    checkup_capacity_timestamp : array-like
        Timestamps for capacity measurements
    checkup_capacity : array-like
        Discharge capacity values in Ah
    checkup_resistance_timestamp : array-like
        Timestamps for resistance measurements
    checkup_resistance : array-like
        Resistance values in Ω
    cell_num : str
        Cell identifier for plot titles
    """
    print('\nGenerating capacity and resistance trending plots...')
    
    fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 8))
    
    # Capacity degradation over time
    ax1.scatter(checkup_capacity_timestamp, checkup_capacity)
    ax1.set_ylim([20, 62])
    ax1.set_xlabel('Time')
    ax1.set_ylabel('Discharge Capacity [Ah]')
    ax1.set_title(f'Capacity Degradation Trending {cell_num}')
    ax1.grid(True)
    
    # Resistance growth over time
    ax2.scatter(checkup_resistance_timestamp, checkup_resistance)
    ax2.set_ylim([0.5e-3, 10e-3])
    ax2.set_xlabel('Time')
    ax2.set_ylabel('Resistance [Ω]')
    ax2.set_title(f'Resistance Growth (30s Pulse Method) {cell_num}')
    ax2.grid(True)
    
    plt.tight_layout()
    plt.show(block=False)
    plt.pause(0.001)  # Brief pause to ensure plot renders
    
    print('Trending plots created.')
