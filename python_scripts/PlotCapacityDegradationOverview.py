"""
Capacity Degradation Overview - NEXTBMS Plotting Data
==========================================================================
Summary: Generates 8 publication-quality plots showing battery capacity 
         degradation over time under various test conditions (DoD, 
         temperature, C-rate, SoC, voltage limits).

Author: NEXTBMS Team
Date: 2026-02-24

Data Source: OverviewCapacityData_36cell.csv
  - Contains capacity checkup measurements from battery ageing tests
  - Columns: cell_number, Timestamp, Capacity [Ah]

Outputs: 8 PNG figures at 300 DPI
  1. All cells overview (grey background)
  2. Effect of Depth of Discharge (DoD): 10%, 40%, 70%, 100%
  3. Effect of Temperature: 0°C, 25°C, 45°C
  4. Effect of C-rate at 0°C: C/4 to 1C charging
  5. Effect of C-rate at 25°C: C/2 to 2C charging/discharging
  6. Effect of C-rate at 45°C: C/2 to 1C charging/discharging
  7. Effect of Average SoC: 25%, 50%, 75% at 50% DoD
  8. Effect of High Voltage: 4.35V vs 4.45V cutoff, CC vs CCCV

Note: Relative capacity = (Current capacity / Initial capacity) × 100%
==========================================================================
"""

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
from pathlib import Path
import re

# Set input/output folder
# DataRoot: single switch to the dataset root holding 1_Teardown/2_HalfCell/
# 3_Characterization/4_Ageing. The Overview*Data_*.csv tables live inside the
# ageing data folders under 4_Ageing.
DATA_ROOT = Path(r"\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot")
io_folder = DATA_ROOT / "4_Ageing" / "Cyclic_ageing_data"
input_csv = io_folder / 'OverviewCapacityData_36cell.csv'
ageing_test_plan_path = Path(__file__).with_name("ageing_test_plan.md")

# Enable non-blocking mode for all figures
plt.ion()

# Helper function for plotting
# (Handles background, highlighted cells, legend, and saving)
def plot_capacity_degradation(df, cell_list, cell_plot_list, label_list, colormap, marker_list, filename, plot_title):
    plt.figure(figsize=(10, 6))
    # Plot all cells in grey background
    for cell in cell_list:
        current_cell = df[df["cell_number"] == cell].reset_index(drop=True)
        if current_cell.empty:
            continue
        plt.plot((current_cell["Timestamp"] - current_cell.at[0, "Timestamp"]).dt.total_seconds() / 86400,
                 current_cell["Capacity [Ah]"] / current_cell.at[0, "Capacity [Ah]"] * 100,
                 linewidth=2, color='grey', alpha=0.2)
    # Plot selected cells
    for idx, cell in enumerate(cell_plot_list):
        current_cell = df[df["cell_number"] == cell].reset_index(drop=True)
        if current_cell.empty:
            continue
        plt.plot((current_cell["Timestamp"] - current_cell.at[0, "Timestamp"]).dt.total_seconds() / 86400,
                 current_cell["Capacity [Ah]"] / current_cell.at[0, "Capacity [Ah]"] * 100,
                 label=label_list[idx], linewidth=2, color=colormap[idx], marker='o', linestyle=marker_list[idx])
    plt.grid(True, linestyle="--", alpha=0.6)
    plt.xlabel("Time [days]", fontsize=18)
    plt.ylabel("Relative Capacity [%]", fontsize=18)
    plt.title(plot_title, fontsize=20)
    plt.xticks(fontsize=14)
    plt.yticks(fontsize=14)
    plt.xlim(0, 425)
    plt.ylim(78, 103)
    plt.legend(fontsize=12, loc='best', frameon=True, handletextpad=0.5)
    plt.savefig(io_folder / filename, dpi=300, bbox_inches="tight")
    # plt.close()  # Removed to keep figures open


def load_cell_name_map(test_plan_path):
    """Parse ageing_test_plan.md and return mapping: Cell_XX -> AYY_ZZ."""
    cell_name_map = {}
    row_pattern = re.compile(r'^\|\s*\d+\s*\|\s*([^|]+?)\s*\|\s*(Cell_\d+)\s*\|')

    with open(test_plan_path, "r", encoding="utf-8") as md_file:
        for line in md_file:
            match = row_pattern.match(line.strip())
            if not match:
                continue
            cell_name = match.group(1).strip()
            cell_number = match.group(2).strip()
            cell_name_map[cell_number] = cell_name

    return cell_name_map


def build_label_list(cell_plot_list, descriptor_list, cell_name_map):
    """Build labels as '<cell name> | <cell number> - <descriptor>' for legends."""
    labels = []
    for cell, descriptor in zip(cell_plot_list, descriptor_list):
        cell_name = cell_name_map.get(cell, "UnknownCellName")
        labels.append(f"{cell_name} | {cell} - {descriptor}")
    return labels

# Load and preprocess data
combined_df = pd.read_csv(input_csv)
combined_df.rename(columns={
    'CellNum': 'cell_number',
    'CheckupCapacityTimeStamp': 'Timestamp',
    'CheckupCapacity_Ah': 'Capacity [Ah]'
}, inplace=True)
# Extract "Cell_XX" from "A1.02_Cell_XX" format
combined_df["cell_number"] = combined_df["cell_number"].astype(str).str.extract(r'(Cell_\d+)')
cell_list = combined_df["cell_number"].dropna().unique()
combined_df = combined_df[combined_df["cell_number"].notna()]
combined_df["Timestamp"] = pd.to_datetime(combined_df["Timestamp"])
cell_name_map = load_cell_name_map(ageing_test_plan_path)

# Plot 1: All cells overview
plt.figure(figsize=(10, 6))
for cell in cell_list:
    current_cell = combined_df[combined_df["cell_number"] == cell].reset_index(drop=True)
    if current_cell.empty:
        continue
    plt.plot((current_cell["Timestamp"] - current_cell.at[0, "Timestamp"]).dt.total_seconds() / 86400,
             current_cell["Capacity [Ah]"] / current_cell.at[0, "Capacity [Ah]"] * 100,
             linewidth=2, color='grey', alpha=0.2)
plt.grid(True, linestyle="--", alpha=0.6)
plt.xlabel("Time [days]", fontsize=18)
plt.ylabel("Relative Capacity [%]", fontsize=18)
plt.title('All Cells Overview', fontsize=20)
plt.xticks(fontsize=14)
plt.yticks(fontsize=14)
plt.xlim(0, 425)
plt.ylim(78, 103)
plt.savefig(io_folder / 'RelativeCapacityVsTime_NEXTBMSDataset_matlab.png', dpi=300, bbox_inches="tight")
plt.close()

# Plot 2: Effect of Depth of Discharge (DoD)
cell_plot_list = ["Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_27", "Cell_30", "Cell_16"]
descriptor_list = ["100% DoD", "100% DoD", "100% DoD", "100% DoD", "70% DoD", "40% DoD", "10% DoD"]
label_list = build_label_list(cell_plot_list, descriptor_list, cell_name_map)
colormap = ["blue", "red", "green", "orange", "purple", "brown", "pink"]
marker_list = ['-'] * len(cell_plot_list)
plot_capacity_degradation(combined_df, cell_list, cell_plot_list, label_list, colormap, marker_list,
    'RelativeCapacityVsTime_VsDoD_NEXTBMSDataset_matlab.png', 'Effect of Depth of Discharge (DoD)')

# Plot 3: Effect of Temperature
cell_plot_list = ["Cell_60", "Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_29"]
descriptor_list = ["0°C", "25°C", "25°C", "25°C", "25°C", "45°C"]
label_list = build_label_list(cell_plot_list, descriptor_list, cell_name_map)
colormap = ["blue", "orange", "orange", "orange", "orange", "red"]
marker_list = ['-', '--', ':', '-.', '-', '-']
plot_capacity_degradation(combined_df, cell_list, cell_plot_list, label_list, colormap, marker_list,
    'RelativeCapacityVsTime_VsTemperature_NEXTBMSDataset_matlab.png', 'Effect of Temperature')

# Plot 4: Effect of C-rate at 0°C
cell_plot_list = ["Cell_63", "Cell_60", "Cell_66", "Cell_68"]
descriptor_list = ["C/4 - C/2 - 0°C", "C/2 - C/2 - 0°C", "3C/4 - C/2 - 0°C", "1C - C/2 - 0°C"]
label_list = build_label_list(cell_plot_list, descriptor_list, cell_name_map)
colormap = ["blue", "red", "green", "orange"]
marker_list = ['-'] * len(cell_plot_list)
plot_capacity_degradation(combined_df, cell_list, cell_plot_list, label_list, colormap, marker_list,
    'RelativeCapacityVsTime_VsCrate0DegC_NEXTBMSDataset_matlab.png', 'Effect of C-rate at 0°C')

# Plot 5: Effect of C-rate at 25°C
cell_plot_list = ["Cell_12", "Cell_23", "Cell_34", "Cell_35", "Cell_43"]
descriptor_list = ["C/2 - C/2 - 25°C", "1C - C/2 - 25°C", "3C/2 - C/2 - 25°C", "2C - C/2 - 25°C", "C/2 - 3C/2 - 25°C"]
label_list = build_label_list(cell_plot_list, descriptor_list, cell_name_map)
colormap = ["blue", "red", "green", "orange", "purple"]
marker_list = ['-'] * len(cell_plot_list)
plot_capacity_degradation(combined_df, cell_list, cell_plot_list, label_list, colormap, marker_list,
    'RelativeCapacityVsTime_VsCrate25DegC_NEXTBMSDataset_matlab.png', 'Effect of C-rate at 25°C')

# Plot 6: Effect of C-rate at 45°C
cell_plot_list = ["Cell_29", "Cell_8", "Cell_9", "Cell_47"]
descriptor_list = ["C/2 - C/2 - 45°C", "C/2 - 1C - 45°C", "1C - C/2 - 45°C", "1C - 1C - 45°C"]
label_list = build_label_list(cell_plot_list, descriptor_list, cell_name_map)
colormap = ["blue", "red", "green", "orange"]
marker_list = ['-'] * len(cell_plot_list)
plot_capacity_degradation(combined_df, cell_list, cell_plot_list, label_list, colormap, marker_list,
    'RelativeCapacityVsTime_VsCrate45DegC_NEXTBMSDataset_matlab.png', 'Effect of C-rate at 45°C')

# Plot 7: Effect of Average SoC
cell_plot_list = ["Cell_40", "Cell_1", "Cell_3"]
descriptor_list = ["75% avg SoC - 50% DoD", "50% avg SoC - 50% DoD", "25% avg SoC - 50% DoD"]
label_list = build_label_list(cell_plot_list, descriptor_list, cell_name_map)
colormap = ["blue", "red", "green"]
marker_list = ['-'] * len(cell_plot_list)
plot_capacity_degradation(combined_df, cell_list, cell_plot_list, label_list, colormap, marker_list,
    'RelativeCapacityVsTime_AvgSoC_NEXTBMSDataset_matlab.png', 'Effect of Average SoC')

# Plot 8: Effect of High Voltage
cell_plot_list = ["Cell_9", "Cell_5", "Cell_22"]
descriptor_list = ["2.75V-4.35V - CC - CC", "2.75V-4.45V - CC - CC", "2.75V-4.45V - CCCV - CC"]
label_list = build_label_list(cell_plot_list, descriptor_list, cell_name_map)
colormap = ["blue", "red", "green"]
marker_list = ['-'] * len(cell_plot_list)
plot_capacity_degradation(combined_df, cell_list, cell_plot_list, label_list, colormap, marker_list,
    'RelativeCapacityVsTime_HighVEffect_NEXTBMSDataset_matlab.png', 'Effect of High Voltage')

# Display all plots at once (non-blocking already handled by plt.ion())
plt.ioff()
plt.show()
