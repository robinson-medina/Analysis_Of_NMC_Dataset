"""
Characterization Data Visualization Script

This script plots data from CSV files in the specified characterization folder.
Each file generates one figure with multiple subplots (one per data column).

Author: Robinson Medina (MATLAB), Copilot (Python parity update)
Updated: 2026-04-14
"""

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates


def reconstruct_time_vector(time_col: pd.Series) -> pd.Series:
    """Reconstruct MATLAB-style time axis where row 1 is datetime and next rows are delta-seconds."""

    time_data = pd.Series([pd.NaT] * len(time_col), dtype="datetime64[ns]")
    time_data.iloc[0] = pd.to_datetime(time_col.iloc[0], format="%d-%b-%Y %H:%M:%S.%f")

    if len(time_col) > 1:
        increase_s = np.cumsum(pd.to_numeric(time_col.iloc[1:], errors="coerce"))
        time_data.iloc[1:] = time_data.iloc[0] + pd.to_timedelta(increase_s, unit="s")

    return time_data


def categorize_columns(column_names: list[str]) -> tuple[list[int], list[int], list[int], list[int]]:
    """Return indices ordered as current, voltage, other, and temperature columns."""

    current_indices: list[int] = []
    voltage_indices: list[int] = []
    temp_indices: list[int] = []
    other_indices: list[int] = []

    for col_idx, col_name in enumerate(column_names, start=1):
        col_name_lower = col_name.lower()
        if "current" in col_name_lower or "curr" in col_name_lower:
            current_indices.append(col_idx)
        elif "voltage" in col_name_lower or "volt" in col_name_lower:
            voltage_indices.append(col_idx)
        elif "temperature" in col_name_lower or "temp" in col_name_lower:
            temp_indices.append(col_idx)
        else:
            other_indices.append(col_idx)

    return current_indices, voltage_indices, temp_indices, other_indices


def add_edge_ticks_datetime(ax: plt.Axes, time_data: pd.Series) -> None:
    """Ensure the datetime axis always includes the start and end timestamps."""

    existing_ticks = ax.get_xticks()
    start_num = mdates.date2num(time_data.iloc[0].to_pydatetime())
    end_num = mdates.date2num(time_data.iloc[-1].to_pydatetime())
    merged_ticks = np.unique(np.concatenate([existing_ticks, np.array([start_num, end_num])]))
    ax.set_xticks(merged_ticks)


def strip_trailing_unit_words(display_name: str) -> str:
    """Match MATLAB label cleanup that removes trailing standalone unit words."""

    cleaned = display_name
    cleaned = cleaned.rstrip()
    for suffix in [" A", " a", " V", " v"]:
        if cleaned.endswith(suffix):
            cleaned = cleaned[: -len(suffix)]
            cleaned = cleaned.rstrip()
    return cleaned


def style_x_axis(ax: plt.Axes, subplot_idx: int, num_rows: int, time_data: pd.Series) -> None:
    """Apply MATLAB-like x-axis behavior across stacked subplots."""

    add_edge_ticks_datetime(ax, time_data)
    if subplot_idx == num_rows - 1:
        ax.set_xlabel("Time")
        ax.xaxis.set_major_formatter(mdates.DateFormatter("%d-%b-%y"))
        ax.tick_params(axis="x", rotation=45)
    elif subplot_idx in (0, 1):
        ax.set_xlabel("")
        ax.set_xticklabels(["" for _ in ax.get_xticks()])
    else:
        ax.set_xlabel("")
        ax.set_xticks([])


def main():
    """Main analysis workflow for characterization data with MATLAB-parity plotting order."""
    
    print('\n' + '='*40)
    print('Characterization Data Visualization Script')
    print('='*40)
    
    # Configuration
    # DataRoot: single switch to the dataset root holding 1_Teardown/2_HalfCell/
    # 3_Characterization/4_Ageing.
    data_root = r'\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot'
    # Folder containing the characterization data files (per-cell folders live
    # directly under 3_Characterization in the reorganised dataset).
    data_folder = os.path.join(data_root, '3_Characterization')
    
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
                print(f'Loading data from: {filename}')

                data = pd.read_csv(filepath, dtype={0: str})

                print(f'Data loaded successfully. Size: {data.shape[0]} rows x {data.shape[1]} columns')

                time_col = data.iloc[:, 0]
                time_data = reconstruct_time_vector(time_col)

                file_base_name = os.path.splitext(filename)[0]
                fig_title = f'Characterization Data: {file_base_name}'

                if data.shape[1] <= 1:
                    print('No data columns found (only time column), skipping...')
                    continue

                data_columns = list(data.columns[1:])
                current_cols, voltage_cols, temp_cols, other_cols = categorize_columns(data_columns)

                num_subplots = len(current_cols) + len(voltage_cols) + len(other_cols)
                if temp_cols:
                    num_subplots += 1

                if num_subplots == 0:
                    print('No plottable columns detected, skipping...')
                    continue

                fig_height = max(8.0, 2.2 * num_subplots)
                fig, axes = plt.subplots(num_subplots, 1, figsize=(8, fig_height), squeeze=False)
                axes_list = axes.flatten().tolist()
                fig.suptitle(fig_title, fontsize=14, fontweight='bold')

                subplot_idx = 0

                # 1) Current columns
                for col_idx in current_cols:
                    ax = axes_list[subplot_idx]
                    col_name = data.columns[col_idx]
                    col_data = pd.to_numeric(data.iloc[:, col_idx], errors='coerce')
                    display_name = strip_trailing_unit_words(col_name.replace('_', ' '))
                    ax.plot(time_data, col_data, 'b-', linewidth=1)
                    ax.set_ylabel(f'{display_name} [A]')
                    ax.grid(True)
                    style_x_axis(ax, subplot_idx, num_subplots, time_data)
                    ax.margins(x=0)
                    subplot_idx += 1

                # 2) Voltage columns
                for col_idx in voltage_cols:
                    ax = axes_list[subplot_idx]
                    col_name = data.columns[col_idx]
                    col_data = pd.to_numeric(data.iloc[:, col_idx], errors='coerce')
                    display_name = strip_trailing_unit_words(col_name.replace('_', ' '))
                    ax.plot(time_data, col_data, 'b-', linewidth=1)
                    ax.set_ylabel(f'{display_name} [V]')
                    ax.grid(True)
                    style_x_axis(ax, subplot_idx, num_subplots, time_data)
                    ax.margins(x=0)
                    subplot_idx += 1

                # 3) Other columns
                for col_idx in other_cols:
                    ax = axes_list[subplot_idx]
                    col_name = data.columns[col_idx]
                    col_data = pd.to_numeric(data.iloc[:, col_idx], errors='coerce')
                    display_name = col_name.replace('_', ' ')
                    ax.plot(time_data, col_data, 'b-', linewidth=1)
                    ax.set_ylabel(f'{display_name} [unit]')
                    ax.grid(True)
                    style_x_axis(ax, subplot_idx, num_subplots, time_data)
                    ax.margins(x=0)
                    subplot_idx += 1

                # 4) Temperature columns in one combined subplot
                if temp_cols:
                    ax = axes_list[subplot_idx]
                    colors = plt.cm.tab10(np.linspace(0, 1, len(temp_cols)))
                    legend_entries: list[str] = []
                    for i, col_idx in enumerate(temp_cols):
                        col_name = data.columns[col_idx]
                        col_data = pd.to_numeric(data.iloc[:, col_idx], errors='coerce')
                        legend_name = col_name.replace('_', ' ')
                        if 'CellTemp' in legend_name:
                            legend_name = 'Cell Temperature'
                        elif 'ChamberTemp' in legend_name:
                            legend_name = 'Chamber Temperature'
                        ax.plot(time_data, col_data, '-', linewidth=1.5, color=colors[i])
                        legend_entries.append(legend_name.strip())

                    ax.set_ylabel('Temperature [°C]')
                    ax.legend(legend_entries, loc='best')
                    ax.grid(True)
                    style_x_axis(ax, subplot_idx, num_subplots, time_data)
                    ax.margins(x=0)

                plt.tight_layout()

                save_filename = os.path.join(current_folder, f'{file_base_name}_CharacterizationPlot.png')

                fig.savefig(save_filename, dpi=150, bbox_inches='tight', format='png')
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
