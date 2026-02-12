"""
Characterization Data Visualization Script

This script plots data from CSV files in the specified characterization folder.
Each file generates one figure with multiple subplots (one per data column).

Author: Converted from Matlab usuing Github copilot
Updated: February 12, 2026
"""

import os
import sys
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from datetime import datetime, timedelta


def main():
    """Main analysis workflow for characterization data."""
    
    print('\n' + '='*40)
    print('Characterization Data Visualization Script')
    print('='*40)
    
    # Configuration
    # Folder containing the characterization data files
    data_folder = r'\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot\Characterization_data'
    
    # Get all subfolders in the directory
    print(f'Scanning main folder: {data_folder}')
    
    try:
        subfolders = [f for f in os.listdir(data_folder) 
                      if os.path.isdir(os.path.join(data_folder, f))]
    except FileNotFoundError:
        print(f'Error: No subfolders found in the specified directory: {data_folder}')
        return
    
    if not subfolders:
        print(f'No subfolders found in the specified directory: {data_folder}')
        return
    
    print(f'Found {len(subfolders)} subfolder(s) to process')
    
    # Process Each Subfolder
    for folder_idx, subfolder_name in enumerate(subfolders):
        current_folder = os.path.join(data_folder, subfolder_name)
        
        print('\n' + '#'*40)
        print(f'Processing subfolder {folder_idx + 1}/{len(subfolders)}: {subfolder_name}')
        print('#'*40)
        
        # Get all CSV files in the current subfolder (exclude EIS folder files)
        csv_files = [f for f in os.listdir(current_folder) 
                     if f.endswith('.csv') and os.path.isfile(os.path.join(current_folder, f))]
        
        if not csv_files:
            print(f'No CSV files found in subfolder: {current_folder}')
            continue
        
        print(f'Found {len(csv_files)} CSV file(s) in this subfolder')
        
        # Process Each File in Current Subfolder
        for file_idx, filename in enumerate(csv_files):
            filepath = os.path.join(current_folder, filename)
            
            print('\n' + '='*40)
            print(f'Processing file {file_idx + 1}/{len(csv_files)}: {filename}')
            print('='*40)
            
            try:
                # Load Data
                print(f'Loading data from: {filename}')
                
                # Read the CSV file with first column as string
                data = pd.read_csv(filepath, dtype={0: str})
                
                print(f'Data loaded successfully. Size: {data.shape[0]} rows x {data.shape[1]} columns')
                
                # Process Time Column
                # Reconstruct time vector: first value is datetime, subsequent values are delta seconds
                time_col = data.iloc[:, 0].values  # First column is time
                
                # Reconstruct time vector
                time_data = pd.Series([pd.NaT] * len(time_col), dtype='datetime64[ns]')
                
                # Parse first timestamp
                try:
                    time_data.iloc[0] = pd.to_datetime(time_col[0], format='%d-%b-%Y %H:%M:%S.%f')
                except:
                    try:
                        time_data.iloc[0] = pd.to_datetime(time_col[0])
                    except:
                        print(f'Warning: Could not parse datetime from first row, using index')
                        time_data = pd.Series(range(len(time_col)))
                
                # Convert subsequent values to cumulative seconds and add to base time
                if pd.notna(time_data.iloc[0]) and len(time_col) > 1:
                    try:
                        increase_s = np.cumsum(pd.to_numeric(time_col[1:], errors='coerce'))
                        time_data.iloc[1:] = time_data.iloc[0] + pd.to_timedelta(increase_s, unit='s')
                    except:
                        print(f'Warning: Could not reconstruct time vector, using index')
                        time_data = pd.Series(range(len(time_col)))
                
                time_label = 'Time'
                
                # Create Figure with Subplots
                file_base_name = os.path.splitext(filename)[0]
                fig_title = f'Characterization Data: {subfolder_name} - {file_base_name}'
                
                # Number of data columns (excluding time)
                num_data_cols = data.shape[1] - 1
                
                if num_data_cols == 0:
                    print('No data columns found (only time column), skipping...')
                    continue
                
                # Calculate subplot layout
                num_cols = min(2, num_data_cols)  # Maximum 2 columns
                num_rows = int(np.ceil(num_data_cols / num_cols))
                
                # Create figure
                fig, axes = plt.subplots(num_rows, num_cols, figsize=(14, 4 * num_rows))
                fig.suptitle(fig_title, fontsize=14, fontweight='bold')
                
                # Handle single subplot case
                if num_data_cols == 1:
                    axes = np.array([axes])
                axes = axes.flatten() if hasattr(axes, 'flatten') else [axes]
                
                # Create Subplots
                for col_idx in range(1, data.shape[1]):  # Start from column 1 (skip time column)
                    subplot_idx = col_idx - 1
                    
                    # Get column data and name
                    col_data = data.iloc[:, col_idx].values
                    col_name = data.columns[col_idx]
                    
                    # Clean column name for display (remove underscores, etc.)
                    display_name = col_name.replace('_', ' ')
                    
                    # Plot data
                    ax = axes[subplot_idx]
                    
                    # Convert time_data to numpy array for plotting
                    if isinstance(time_data, pd.Series):
                        time_plot = time_data.values
                    else:
                        time_plot = time_data
                    
                    ax.plot(time_plot, col_data, 'b-', linewidth=1)
                    
                    # Format subplot
                    ax.set_xlabel(time_label)
                    ax.set_ylabel(display_name)
                    ax.set_title(display_name, fontweight='bold')
                    ax.grid(True)
                    
                    # Rotate x-axis labels for better readability
                    if isinstance(time_data.iloc[0], pd.Timestamp):
                        plt.setp(ax.xaxis.get_majorticklabels(), rotation=45, ha='right')
                    
                    # Tight layout for each subplot
                    ax.autoscale(tight=True)
                
                # Hide any unused subplots
                for idx in range(num_data_cols, len(axes)):
                    axes[idx].set_visible(False)
                
                plt.tight_layout()
                
                # Save Figure
                # Create filename for saving (save in the same subfolder)
                save_filename = os.path.join(current_folder, f'{file_base_name}_CharacterizationPlot.png')
                
                # Save with high resolution
                fig.savefig(save_filename, dpi=150, bbox_inches='tight')
                print(f'Figure saved as: {save_filename}')
                
            except Exception as e:
                print(f'Error processing file {filename}: {str(e)}')
                continue
    
    # Summary
    print('\n' + '#'*40)
    print('Processing complete!')
    print(f'Processed {len(subfolders)} subfolder(s)')
    print('Figures saved to respective subfolders')
    print('#'*40)
    
    # Show all figures
    plt.show()


if __name__ == '__main__':
    main()
