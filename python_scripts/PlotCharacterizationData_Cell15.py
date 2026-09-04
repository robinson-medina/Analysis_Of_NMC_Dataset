"""
Characterization Data Visualization Script

This script plots data from CSV files in the specified characterization folder.
Each file generates one figure with multiple subplots (one per data column).

Author: Robinson Medina (MATLAB), Copilot (Python parity update)
Updated: 2026-04-14
"""

import os
import sys
from pathlib import Path
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.dates as mdates

_SCRIPT_DIR = Path(__file__).resolve().parent
_FUNCTIONS_CANDIDATES = (_SCRIPT_DIR.parent.parent / 'Functions', _SCRIPT_DIR.parent / 'Functions')
for _FUNCTIONS_DIR in _FUNCTIONS_CANDIDATES:
    if (_FUNCTIONS_DIR / "get_figure_output_dir.py").exists():
        if str(_FUNCTIONS_DIR) not in sys.path:
            sys.path.append(str(_FUNCTIONS_DIR))
        break
else:
    raise FileNotFoundError(f"Shared Functions folder not found from {_SCRIPT_DIR}")

from get_figure_output_dir import get_figure_output_dir  # noqa: E402


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


def _load_phase_data(filepath: str) -> pd.DataFrame:
    """Read one characterization-phase CSV (header row 1, data from row 2, col 0 as string)."""

    return pd.read_csv(filepath, dtype={0: str})


def _find_temp_column(column_names: list[str], name_fragment: str, fallback_idx: int) -> int:
    """Find a temperature column by case-insensitive name fragment, else use the MATLAB fallback index."""

    for idx, name in enumerate(column_names):
        if name_fragment in name.lower():
            return idx
    return fallback_idx


def _style_combined_axes(ax: plt.Axes, pub_fontsize: int) -> None:
    """Apply the shared R-017/R-019/R-021 styling to one combined-figure axes."""

    ax.set_axisbelow(False)  # MATLAB Layer='top': grid/ticks render above shading and data.
    ax.tick_params(axis='both', direction='out', labelsize=pub_fontsize)
    for label in ax.get_xticklabels() + ax.get_yticklabels():
        label.set_fontname('Times New Roman')
    for spine in ax.spines.values():
        spine.set_linewidth(0.8)
    ax.grid(True)


def build_combined_characterization_figure(data_folder: str, pngs_dir: str) -> None:
    """
    Build the 5-phase combined characterization publication figure
    (Initialization, GITT, CC cycles, Dynamic, HPPC).

    Python counterpart of the "COMBINED CHARACTERIZATION FIGURE" section at
    the bottom of matlab_scripts/PlotCharacterizationData_Cell15.m (todo #006).
    Concatenates the 5 phase CSVs (with a NaN separator between phases) onto
    one time-in-days axis, then renders a 3-panel (current/voltage/temperature)
    publication figure with phase-boundary lines, alternating phase shading,
    phase-span arrows + labels above the top panel, and a Chamber/Cell legend.
    """

    print('\n' + '=' * 40)
    print('Building combined characterization figure...')
    print('=' * 40)

    # Config: 5 characterization phases in chronological order, all under the
    # Cell_15 folder processed by this fixed-cell script.
    char_cell = 'Cell_15'
    char_cell_dir = os.path.join(data_folder, char_cell)
    phase_configs = [
        {'filepath': os.path.join(char_cell_dir, f'{char_cell}_1-Formation.csv'), 'label': 'Initialization'},
        {'filepath': os.path.join(char_cell_dir, f'{char_cell}_2-GITT.csv'), 'label': 'GITT'},
        {'filepath': os.path.join(char_cell_dir, f'{char_cell}_3-CC_cycles.csv'), 'label': 'CC cycles'},
        {'filepath': os.path.join(char_cell_dir, f'{char_cell}_4-DynamicCycles.csv'), 'label': 'Dynamic'},
        {'filepath': os.path.join(char_cell_dir, f'{char_cell}_5-HPPC.csv'), 'label': 'HPPC'},
    ]
    num_phases = len(phase_configs)

    # Load and concatenate data from all 5 phases, with a NaN row inserted
    # between phases (matches MATLAB - keeps plotted lines visually broken
    # at phase boundaries instead of connecting across the time-offset jump).
    time_total_s: list[float] = []
    current_total: list[float] = []
    voltage_total: list[float] = []
    cell_temp_total: list[float] = []
    chamber_temp_total: list[float] = []
    phase_boundaries_days = [0.0]
    phase_start_end_days = [(0.0, 0.0)] * num_phases

    for phase_idx, phase_config in enumerate(phase_configs):
        phase_file = phase_config['filepath']
        phase_label = phase_config['label']
        print(f"Loading phase {phase_idx + 1}/{num_phases} ({phase_label}): {phase_file}")

        data_phase = _load_phase_data(phase_file)
        time_col = data_phase.iloc[:, 0]
        time_yymmdd = reconstruct_time_vector(time_col)
        time_phase_s = (time_yymmdd - time_yymmdd.iloc[0]).dt.total_seconds().to_numpy()

        # Positional column access (matches MATLAB: col 2 = voltage, col 3 = current),
        # regardless of the column header text.
        voltage_phase = pd.to_numeric(data_phase.iloc[:, 1], errors='coerce').to_numpy()
        current_phase = pd.to_numeric(data_phase.iloc[:, 2], errors='coerce').to_numpy()

        column_names = list(data_phase.columns)
        cell_temp_idx = _find_temp_column(column_names, 'cell temp', fallback_idx=3)
        chamber_temp_idx = _find_temp_column(column_names, 'chamber temp', fallback_idx=4)
        cell_temp_phase = pd.to_numeric(data_phase.iloc[:, cell_temp_idx], errors='coerce').to_numpy()
        chamber_temp_phase = pd.to_numeric(data_phase.iloc[:, chamber_temp_idx], errors='coerce').to_numpy()

        if phase_idx == 0:
            time_offset_s = 0.0
            phase_start_days = 0.0
        else:
            time_total_s.append(np.nan)
            current_total.append(np.nan)
            voltage_total.append(np.nan)
            cell_temp_total.append(np.nan)
            chamber_temp_total.append(np.nan)
            # Offset is the last non-NaN time value (the element just before the
            # separator we appended above), matching MATLAB's timeTotal_s(end-1).
            time_offset_s = time_total_s[-2]
            phase_start_days = time_offset_s / 86400.0

        time_total_s.extend((time_offset_s + time_phase_s).tolist())
        current_total.extend(current_phase.tolist())
        voltage_total.extend(voltage_phase.tolist())
        cell_temp_total.extend(cell_temp_phase.tolist())
        chamber_temp_total.extend(chamber_temp_phase.tolist())

        phase_end_days = time_total_s[-1] / 86400.0
        phase_start_end_days[phase_idx] = (phase_start_days, phase_end_days)
        if phase_idx < num_phases - 1:
            phase_boundaries_days.append(phase_end_days)

        print(f'  Phase {phase_idx + 1} loaded: {phase_start_days:.2f} to {phase_end_days:.2f} days')

    time_total_days = np.array(time_total_s) / 86400.0
    current_total = np.array(current_total)
    voltage_total = np.array(voltage_total)
    cell_temp_total = np.array(cell_temp_total)
    chamber_temp_total = np.array(chamber_temp_total)

    print(f'Combined data ready. Total duration: {time_total_days[-1]:.2f} days')

    # --- Journal publication formatting (rules R-017 through R-022) ---
    pub_fontsize = 8
    fig_w_cm, fig_h_cm = 18.82, 12.98
    dark_blue = (1 / 255, 17 / 255, 181 / 255)
    red = (1.0, 0.0, 0.0)
    black = (0.0, 0.0, 0.0)

    fig, (ax1, ax2, ax3) = plt.subplots(3, 1, figsize=(fig_w_cm / 2.54, fig_h_cm / 2.54), sharex=True)
    # Reserve headroom above ax1 for the phase-span arrows/labels drawn later
    # with clip_on=False (mirrors MATLAB's tiledlayout OuterPosition = [0 0 1 0.90]).
    fig.subplots_adjust(top=0.86, hspace=0.08)

    # ---- SUBPLOT 1: Current ----
    ax1.plot(time_total_days, current_total, '-', color=dark_blue, linewidth=1.0)
    ax1.set_ylabel('Current $I$ [A]', fontsize=pub_fontsize, fontname='Times New Roman')
    abs_max = np.nanmax(np.abs(current_total))
    ax1.set_ylim(-abs_max * 1.1, abs_max * 1.1)
    ax1.set_xlim(0, time_total_days[-1])

    # ---- SUBPLOT 2: Voltage ----
    ax2.plot(time_total_days, voltage_total, '-', color=dark_blue, linewidth=1.0)
    ax2.set_ylabel('Voltage $V$ [V]', fontsize=pub_fontsize, fontname='Times New Roman')
    v_min, v_max = np.nanmin(voltage_total), np.nanmax(voltage_total)
    ax2.set_ylim(v_min - 0.1, v_max + 0.1)

    # ---- SUBPLOT 3: Temperature (Cell + Chamber) ----
    # Chamber first (drawn underneath), then Cell on top - kept consistent with legend order.
    h_chamber, = ax3.plot(time_total_days, chamber_temp_total, '-', color=red, linewidth=1.0, label='Chamber')
    h_cell, = ax3.plot(time_total_days, cell_temp_total, '-', color=dark_blue, linewidth=1.0, label='Cell')
    ax3.set_ylabel('Temperature $T$ [$\\degree$C]', fontsize=pub_fontsize, fontname='Times New Roman')
    ax3.set_xlabel('Time [d]', fontsize=pub_fontsize, fontname='Times New Roman')
    t_min = min(np.nanmin(cell_temp_total), np.nanmin(chamber_temp_total))
    t_max = max(np.nanmax(cell_temp_total), np.nanmax(chamber_temp_total))
    ax3.set_ylim(t_min - 1, t_max + 1)

    for ax in (ax1, ax2, ax3):
        _style_combined_axes(ax, pub_fontsize)
    ax1.tick_params(labelbottom=False)
    ax2.tick_params(labelbottom=False)

    # Add vertical dashed phase-boundary lines on all three axes.
    light_grey = (0.5, 0.5, 0.5)
    for boundary_day in phase_boundaries_days[1:]:
        for ax in (ax1, ax2, ax3):
            ax.axvline(boundary_day, linestyle='--', color=light_grey, linewidth=0.75)

    # Add alternating shaded background regions to delimit phases (every other
    # phase, matching MATLAB's mod(phaseIdx,2)==0 on its 1-based phase index).
    shade_color = (0.95, 0.95, 0.95)
    for phase_idx in range(num_phases):
        if (phase_idx + 1) % 2 == 0:
            phase_start, phase_end = phase_start_end_days[phase_idx]
            for ax in (ax1, ax2, ax3):
                ax.axvspan(phase_start, phase_end, color=shade_color, zorder=0)

    # Data lines already draw above the shading (matplotlib's default line
    # zorder is higher than axvspan's), and _style_combined_axes set
    # axisbelow=False so the grid/ticks render above everything too - this
    # achieves the same "data + grid stay visible over shading" result as
    # MATLAB's Layer='top' + redundant re-plot-on-top workaround, without the
    # extra redraw.

    # --- Phase labels and double-headed span arrows above the current subplot ---
    y_lim1 = ax1.get_ylim()
    y_lim1_range = y_lim1[1] - y_lim1[0]
    y_pos_arrow = y_lim1[1] + 0.06 * y_lim1_range
    y_pos_label = y_lim1[1] + 0.14 * y_lim1_range
    x_pad_frac = 0.01
    arrow_inset = x_pad_frac * time_total_days[-1]

    for phase_idx in range(num_phases):
        phase_start, phase_end = phase_start_end_days[phase_idx]
        phase_mid_days = (phase_start + phase_end) / 2

        x_left = phase_start + arrow_inset
        x_right = phase_end - arrow_inset
        if x_right <= x_left:
            x_left, x_right = phase_start, phase_end

        ax1.plot([x_left, x_right], [y_pos_arrow, y_pos_arrow], '-', color=black,
                 linewidth=0.75, clip_on=False)
        ax1.plot(x_left, y_pos_arrow, marker='<', markersize=5, color=black, clip_on=False)
        ax1.plot(x_right, y_pos_arrow, marker='>', markersize=5, color=black, clip_on=False)
        ax1.text(phase_mid_days, y_pos_label, phase_configs[phase_idx]['label'],
                  ha='center', va='bottom', fontsize=pub_fontsize, fontname='Times New Roman',
                  clip_on=False)

    # Temperature legend: horizontal, inside ax3, near the top, centered around day 35.
    x_lim3 = ax3.get_xlim()
    desired_center_day = 35
    x_center_norm = (desired_center_day - x_lim3[0]) / (x_lim3[1] - x_lim3[0])
    x_center_norm = max(0.10, min(0.90, x_center_norm))
    ax3.legend(handles=[h_chamber, h_cell], labels=['Chamber', 'Cell'], loc='upper center',
               bbox_to_anchor=(x_center_norm, 0.98), ncol=2, frameon=False,
               fontsize=pub_fontsize, prop={'family': 'Times New Roman'})

    # --- Export ---
    print('\nExporting combined characterization figure...')
    pdf_file = os.path.join(pngs_dir, 'characterization_combined.pdf')
    png_file = os.path.join(pngs_dir, 'characterization_combined.png')
    fig.savefig(pdf_file, bbox_inches='tight')
    print(f'PDF saved: {pdf_file}')
    # MATLAB only exports PDF + a native .fig here (no PNG); a PNG has no Python
    # equivalent to .fig and is added for convenience/QA, matching every other
    # figure-generating script in this repo (harmless, R-018/R-022 compliant).
    fig.savefig(png_file, dpi=300, bbox_inches='tight')
    print(f'PNG saved: {png_file}')
    print('Combined characterization figure complete!')


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

    # Publication outputs never write into the read-only ZenodoRoot tree (R-001).
    pngs_dir = str(get_figure_output_dir('PlotCharacterizationData_Cell15'))

    # Get all subfolders in the directory
    print(f'Scanning main folder: {data_folder}')

    try:
        subfolders = sorted(f for f in os.listdir(data_folder)
                             if os.path.isdir(os.path.join(data_folder, f)))
    except FileNotFoundError:
        print(f'Error: No subfolders found in the specified directory: {data_folder}')
        return
    
    if not subfolders:
        print(f'No subfolders found in the specified directory: {data_folder}')
        return
    
    print(f'Found {len(subfolders)} subfolder(s) total.')

    # MATLAB restricts this loop to folderIdx = 1:1 (the alphabetically-first
    # subfolder, "Cell_15" - see matlab_scripts/PlotCharacterizationData_Cell15.m
    # header, todo #083). Match that scope here rather than looping over every
    # characterization cell.
    for folder_idx, subfolder_name in enumerate(subfolders[:1]):
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

                save_filename = os.path.join(pngs_dir, f'{file_base_name}_CharacterizationPlot.png')

                fig.savefig(save_filename, dpi=150, bbox_inches='tight', format='png')
                print(f'Figure saved as: {save_filename}')
                
            except Exception as e:
                print(f'Error processing file {filename}: {str(e)}')
                continue
    
    # Summary
    print('\n' + '#'*40)
    print('Processing complete!')
    print(f'Processed {len(subfolders[:1])} subfolder(s)')
    print(f'Figures saved to {pngs_dir}')
    print('#'*40)

    # Combined 5-phase publication figure (Initialization, GITT, CC cycles,
    # Dynamic, HPPC) - independent of the per-file loop above (todo #006).
    build_combined_characterization_figure(data_folder, pngs_dir)

    # Show all figures
    plt.show()


if __name__ == '__main__':
    main()
