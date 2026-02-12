"""
plotNyquistDiagram - Plot Nyquist diagram from impedance data

This function plots a Nyquist diagram from the provided data DataFrame.
It automatically detects different SoC tests based on column naming
convention (_SoC##) and creates separate legend entries.

Author: Róbinson Medina, Feye Hoekstra
Updated: February 12, 2026
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import re


def plot_nyquist_diagram(data, plot_title='Nyquist Diagram', save_path='', max_freq=12000):
    """
    Plot Nyquist diagram from impedance data.
    
    Parameters
    ----------
    data : pandas.DataFrame
        DataFrame containing R_real_ohm_SoC##, R_img_ohm_SoC##, and 
        Freq_Hz_SoC## columns for different SoC values
    plot_title : str, optional
        Custom title for the plot (default: 'Nyquist Diagram')
    save_path : str, optional
        Path to save the figure (empty string to skip saving)
    max_freq : float, optional
        Maximum frequency for data inclusion in Hz (default: 12000)
    
    Returns
    -------
    fig : matplotlib.figure.Figure
        Figure handle
    """
    
    # Get column names
    col_names = data.columns.tolist()
    
    # Find unique SoC values by parsing column names
    soc_values = []
    for col in col_names:
        if 'R_real_ohm_SoC' in col:
            # Extract SoC value from column name
            match = re.search(r'SoC(\d+)', col)
            if match:
                soc_str = match.group(1)
                if soc_str not in soc_values:
                    soc_values.append(soc_str)
    
    if not soc_values:
        raise ValueError('No SoC data found. Expected columns with format R_real_ohm_SoC##')
    
    print(f'Found {len(soc_values)} different SoC test(s): {", ".join(soc_values)}')
    
    # Create figure
    fig, ax = plt.subplots(figsize=(10, 8))
    
    # Define colors for different SoC values
    colors = plt.cm.tab10(np.linspace(0, 1, len(soc_values)))
    
    # Plot data for each SoC
    legend_entries = []
    for i, soc_val in enumerate(soc_values):
        # Column names for this SoC
        r_real_col = f'R_real_ohm_SoC{soc_val}'
        r_img_col = f'R_img_ohm_SoC{soc_val}'
        freq_col = f'Freq_Hz_SoC{soc_val}'
        
        # Check if columns exist
        if r_real_col not in col_names or r_img_col not in col_names:
            print(f'Warning: Missing columns for SoC{soc_val}, skipping...')
            continue
        
        # Extract data
        r_real = data[r_real_col].values
        r_img = data[r_img_col].values
        
        # Get frequency data for filtering
        freq = None
        if freq_col in col_names:
            freq = data[freq_col].values
        
        # Remove NaN values and apply frequency filter
        if freq is not None:
            valid_idx = ~np.isnan(r_real) & ~np.isnan(r_img) & ~np.isnan(freq) & (freq <= max_freq)
        else:
            valid_idx = ~np.isnan(r_real) & ~np.isnan(r_img)
        
        r_real = r_real[valid_idx]
        r_img = r_img[valid_idx]
        if freq is not None:
            freq = freq[valid_idx]
        
        if len(r_real) == 0:
            print(f'Warning: No valid data for SoC{soc_val}, skipping...')
            continue
        
        # Plot Nyquist curve (-r_img on y-axis for conventional Nyquist representation)
        ax.plot(r_real, -r_img, 'o-', color=colors[i], linewidth=1.5,
                markersize=4, markerfacecolor=colors[i], label=f'SoC {soc_val}%')
        
        legend_entries.append(f'SoC {soc_val}%')
    
    # Format plot
    ax.set_xlabel(r'$R_{real}$ ($\Omega$)', fontsize=12)
    ax.set_ylabel(r'$-R_{img}$ ($\Omega$)', fontsize=12)
    ax.set_title(plot_title, fontsize=14, fontweight='bold')
    
    # Add legend
    if legend_entries:
        ax.legend(loc='best', fontsize=10)
    
    # Make axes equal for proper Nyquist representation
    ax.set_aspect('equal', adjustable='box')
    
    # Add grid
    ax.grid(True, which='both', linestyle='-', alpha=0.7)
    ax.minorticks_on()
    ax.grid(True, which='minor', linestyle=':', alpha=0.4)
    
    # Improve appearance
    ax.tick_params(labelsize=10)
    
    plt.tight_layout()
    
    # Save figure if requested
    if save_path:
        fig.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f'Nyquist diagram saved as: {save_path}')
    
    print(f'Nyquist diagram created successfully with {len(legend_entries)} SoC test(s)')
    
    return fig
