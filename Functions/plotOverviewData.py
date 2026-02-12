"""
plotOverviewData - Create multi-panel overview plot

This function creates a comprehensive 4-panel plot showing current,
voltage, temperature, and cumulative capacity over time for battery
test data visualization.
"""

import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import pandas as pd
import numpy as np
import time


def plot_overview_data(time_with_gaps, current, voltage, cell_temp, chamber_temp, cumulative_integral, cell_num):
    """
    Create multi-panel overview plot.
    
    Parameters
    ----------
    time_with_gaps : numpy.ndarray
        Datetime array with timestamps (may contain NaT)
    current : numpy.ndarray
        Current array in Amperes
    voltage : numpy.ndarray
        Voltage array in Volts
    cell_temp : numpy.ndarray
        Cell surface temperature in Celsius
    chamber_temp : numpy.ndarray
        Chamber ambient temperature in Celsius
    cumulative_integral : numpy.ndarray
        Cumulative charge in Ampere-seconds (As)
    cell_num : str
        Cell identifier string for plot title
    """
    
    print('Creating overview plots...')
    start_time = time.time()
    
    # Convert time to pandas datetime for better plotting
    time_pd = pd.to_datetime(time_with_gaps)
    
    # Debug: print time range info
    valid_times = time_pd[~time_pd.isna()]
    if len(valid_times) > 0:
        print(f'Time range: {valid_times.min()} to {valid_times.max()}')
        print(f'Total data points: {len(time_pd)}, Valid timestamps: {len(valid_times)}, NaT values: {time_pd.isna().sum()}')
    
    # Create figure with 4 subplots
    fig, (ax1, ax2, ax3, ax4) = plt.subplots(4, 1, figsize=(14, 11), sharex=True)
    
    # Current plot
    ax1.plot(time_pd, current, linewidth=0.5)
    ax1.grid(True, alpha=0.3)
    ax1.set_ylabel('Current [A]')
    
    # Voltage plot
    ax2.plot(time_pd, voltage, linewidth=0.5)
    ax2.grid(True, alpha=0.3)
    ax2.set_ylabel('Voltage [V]')
    
    # Temperature plot (cell surface and chamber ambient)
    ax3.plot(time_pd, cell_temp, label='surface', linewidth=0.5)
    ax3.plot(time_pd, chamber_temp, label='ambient', linewidth=0.5)
    ax3.grid(True, alpha=0.3)
    ax3.set_ylabel('Temperature [°C]')
    ax3.legend(loc='lower left')
    
    # Cumulative capacity plot (convert from As to Ah by dividing by 3600)
    ax4.plot(time_pd, cumulative_integral / 3600, linewidth=0.5)
    ax4.grid(True, alpha=0.3)
    ax4.set_xlabel('Date')
    ax4.set_ylabel('Capacity [Ah]')
    
    # Format x-axis to show dates nicely
    ax4.xaxis.set_major_formatter(mdates.DateFormatter('%Y-%m-%d'))
    ax4.xaxis.set_major_locator(mdates.AutoDateLocator())
    fig.autofmt_xdate()  # Rotate date labels
    
    # Set title
    fig.suptitle(f'Data overview file {cell_num}', fontsize=14)
    
    # Adjust layout to prevent overlap
    plt.tight_layout()
    plt.show(block=False)
    plt.pause(0.001)  # Brief pause to ensure plot renders
    
    print(f'Overview plots created. (Elapsed: {time.time() - start_time:.2f} s)')
    
    # Show the plot
    return fig
