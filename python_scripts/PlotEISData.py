"""
Nyquist Analysis Script

This script loads impedance data from CSV files and generates Nyquist diagrams
for different State of Charge (SoC) conditions.

Author: Converted from Matlab using Github copilot
Updated: February 12, 2026
"""

import os
import sys
from pathlib import Path
import pandas as pd

# Add functions directory to path (check both locations)
# Original location: one folder up
functions_dir_parent = Path(__file__).parent.parent / 'Functions'
# New location: same folder as script
functions_dir_local = Path(__file__).parent / 'Functions'

if functions_dir_local.exists():
    sys.path.append(str(functions_dir_local))
elif functions_dir_parent.exists():
    sys.path.append(str(functions_dir_parent))
else:
    raise ImportError("Functions directory not found in either location")

from plotNyquistDiagram import plot_nyquist_diagram


def main():
    """Main analysis workflow for EIS data."""
    
    print('\n' + '='*40)
    print('Nyquist Analysis Script')
    print('='*40)
    
    # Configuration
    # DataRoot: single switch to the dataset root holding 1_Teardown/2_HalfCell/
    # 3_Characterization/4_Ageing.
    data_root = r'\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot'
    # Parent folder containing the per-cell characterisation folders (with EIS data)
    data_folder = os.path.join(data_root, '3_Characterization')
    
    # Get all subfolders in the directory
    print(f'Scanning main folder: {data_folder}')
    
    try:
        subfolders = [f for f in os.listdir(data_folder) 
                      if os.path.isdir(os.path.join(data_folder, f))]
    except FileNotFoundError:
        print(f'Error: Directory not found: {data_folder}')
        return
    
    if not subfolders:
        print(f'No subfolders found in the specified directory: {data_folder}')
        return
    
    print(f'Found {len(subfolders)} subfolder(s) to scan for EIS data')
    
    # Process Each Subfolder That Contains EIS Data
    for folder_idx, subfolder_name in enumerate(subfolders):
        current_folder = os.path.join(data_folder, subfolder_name)
        eis_folder = os.path.join(current_folder, 'EIS')
        
        print('\n' + '#'*40)
        print(f'Checking subfolder {folder_idx + 1}/{len(subfolders)}: {subfolder_name}')
        
        # Check if EIS folder exists
        if not os.path.isdir(eis_folder):
            print(f'No EIS folder found in {subfolder_name}, skipping...')
            continue
        
        print(f'EIS folder found! Processing: {eis_folder}')
        print('#'*40)
        
        # Get all impedance CSV files directly from the EIS folder
        csv_files = [f for f in os.listdir(eis_folder) 
                     if f.endswith('_impedanceData.csv')]
        
        if not csv_files:
            print(f'No impedance data files found (*_impedanceData.csv) in EIS folder: {eis_folder}')
            continue
        
        print(f'Found {len(csv_files)} impedance data file(s) to process')
        
        # Process Each Impedance Data File in EIS Folder
        for file_idx, filename in enumerate(csv_files):
            filepath = os.path.join(eis_folder, filename)
            
            print('\n' + '='*40)
            print(f'Processing file {file_idx + 1}/{len(csv_files)}: {filename}')
            print('='*40)
            
            try:
                # Load Data
                print(f'Loading impedance data from: {filename}')
                
                # Read the CSV file
                data = pd.read_csv(filepath)
                
                print(f'Data loaded successfully. Size: {data.shape[0]} rows x {data.shape[1]} columns')
                
                # Check if this file contains impedance data
                col_names = data.columns.tolist()
                has_impedance_data = any('R_real_ohm_SoC' in col for col in col_names)
                
                if not has_impedance_data:
                    print('File does not contain expected impedance data (R_real_ohm_SoC columns), skipping...')
                    continue
                
                # Generate Nyquist Diagram
                file_base_name = os.path.splitext(filename)[0]
                fig_title = f'Nyquist Diagram: {subfolder_name} - {file_base_name}'
                
                # Create save path for the Nyquist diagram (save in EIS folder)
                save_filename = os.path.join(eis_folder, f'{file_base_name}_NyquistPlot.png')
                
                # Call the plotNyquistDiagram function
                fig = plot_nyquist_diagram(data, fig_title, save_filename, max_freq=12000)
                
                print('Nyquist diagram generated and saved')
                
            except Exception as e:
                print(f'Error processing file {filename}: {str(e)}')
                continue
    
    # Summary
    print('\n' + '#'*40)
    print('Nyquist analysis complete!')
    print('Processed subfolders with EIS data')
    print('Nyquist diagrams saved to respective EIS folders')
    print('#'*40)
    
    # Show all figures
    import matplotlib.pyplot as plt
    plt.show()


if __name__ == '__main__':
    main()
