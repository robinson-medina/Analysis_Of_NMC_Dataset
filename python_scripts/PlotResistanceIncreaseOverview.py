"""
Summary: Generate resistance-increase overview plots for cyclic and calendar
ageing datasets, mirroring MATLAB PlotResistanceIncreaseOverview behavior.
Author: Tim Meulenbreuks, Robinson Medina, NEXTBMS Team; Python port by Copilot
Date: 2026-04-14
Inputs/Outputs: Reads overview resistance CSV files and writes PNG figures.
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import pandas as pd


# DataRoot: single switch to the dataset root holding 1_Teardown/2_HalfCell/
# 3_Characterization/4_Ageing. The Overview*Data_*.csv tables live inside the
# ageing data folders under 4_Ageing.
DATA_ROOT = Path(r"\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot")
IO_FOLDER_CYCLIC = DATA_ROOT / "4_Ageing" / "Cyclic_ageing_data"
IO_FOLDER_CALENDAR = DATA_ROOT / "4_Ageing" / "Calendar_ageing_data"

INPUT_CSV_CYCLIC = IO_FOLDER_CYCLIC / "OverviewResistanceData_36cell.csv"
INPUT_CSV_CALENDAR = IO_FOLDER_CALENDAR / "OverviewResistanceData_5cell.csv"


def rename_column_if_exists(dataframe: pd.DataFrame, old_name: str, new_name: str) -> pd.DataFrame:
    """Rename a column only if it exists to support legacy CSV schemas."""

    if old_name in dataframe.columns:
        dataframe = dataframe.rename(columns={old_name: new_name})
    return dataframe


def load_and_preprocess(path: Path) -> tuple[pd.DataFrame, list[str]]:
    """Load overview resistance data and normalize key columns to shared names."""

    dataframe = pd.read_csv(path)
    dataframe = rename_column_if_exists(dataframe, "CellNum", "cell_number")
    dataframe = rename_column_if_exists(dataframe, "CheckupResistanceTimeStamp", "Timestamp")
    dataframe = rename_column_if_exists(dataframe, "CheckupResistance_Ohm", "Resistance [Ohm]")

    required = ["cell_number", "Timestamp", "Resistance [Ohm]", "CheckupResistanceFEC"]
    missing = [name for name in required if name not in dataframe.columns]
    if missing:
        raise ValueError(f"{path} is missing required columns: {', '.join(missing)}")

    dataframe["cell_number"] = (
        dataframe["cell_number"].astype(str).str.extract(r"(Cell_\d+)", expand=False)
    )
    dataframe = dataframe[dataframe["cell_number"].notna()].copy()
    dataframe["Timestamp"] = pd.to_datetime(dataframe["Timestamp"], errors="coerce")
    dataframe["CheckupResistanceFEC"] = pd.to_numeric(dataframe["CheckupResistanceFEC"], errors="coerce")
    dataframe["Resistance [Ohm]"] = pd.to_numeric(dataframe["Resistance [Ohm]"], errors="coerce")
    dataframe = dataframe.dropna(subset=["Timestamp", "Resistance [Ohm]"])

    cell_list = sorted(dataframe["cell_number"].dropna().unique().tolist())
    return dataframe, cell_list


def plot_resistance_increase(
    dataframe: pd.DataFrame,
    cell_list: list[str],
    cell_plot_list: list[str],
    label_list: list[str],
    color_list: list[object],
    linestyle_list: list[str],
    output_file: Path,
    plot_title: str,
) -> None:
    """Plot resistance against time and FEC with grey-background and highlighted cells."""

    fig, axes = plt.subplots(2, 1, figsize=(10, 9))

    # Subplot 1: Time vs Resistance
    ax = axes[0]
    for cell_name in cell_list:
        current_cell = dataframe[dataframe["cell_number"] == cell_name].copy()
        if current_cell.empty:
            continue
        current_cell = current_cell.sort_values("Timestamp")
        time_days = (current_cell["Timestamp"] - current_cell["Timestamp"].iloc[0]).dt.total_seconds() / 86400.0
        ax.plot(time_days, current_cell["Resistance [Ohm]"], linewidth=2, color=(0.5, 0.5, 0.5, 0.2))

    legend_handles = []
    legend_labels = []
    for idx, cell_name in enumerate(cell_plot_list):
        current_cell = dataframe[dataframe["cell_number"] == cell_name].copy()
        if current_cell.empty:
            print(f"Warning: Cell {cell_name} not found in data")
            continue
        current_cell = current_cell.sort_values("Timestamp")
        time_days = (current_cell["Timestamp"] - current_cell["Timestamp"].iloc[0]).dt.total_seconds() / 86400.0
        handle, = ax.plot(
            time_days,
            current_cell["Resistance [Ohm]"],
            "-o",
            linewidth=2,
            color=color_list[idx],
            markerfacecolor=color_list[idx],
            markersize=4,
            linestyle=linestyle_list[idx],
        )
        legend_handles.append(handle)
        legend_labels.append(label_list[idx])

    ax.grid(True, linestyle="--", alpha=0.6)
    ax.set_xlabel("Time [days]", fontsize=11)
    ax.set_ylabel("Checkup Resistance [Ohm]", fontsize=11)
    if plot_title:
        ax.set_title(f"{plot_title} (vs Time)", fontsize=11)
    if legend_handles:
        ax.legend(legend_handles, legend_labels, fontsize=11, loc="best")

    # Subplot 2: FEC vs Resistance
    ax = axes[1]
    for cell_name in cell_list:
        current_cell = dataframe[dataframe["cell_number"] == cell_name].copy()
        if current_cell.empty:
            continue
        current_cell = current_cell.sort_values("CheckupResistanceFEC")
        ax.plot(
            current_cell["CheckupResistanceFEC"],
            current_cell["Resistance [Ohm]"],
            linewidth=2,
            color=(0.5, 0.5, 0.5, 0.2),
        )

    legend_handles = []
    legend_labels = []
    max_fec_highlight = 0.0
    for idx, cell_name in enumerate(cell_plot_list):
        current_cell = dataframe[dataframe["cell_number"] == cell_name].copy()
        if current_cell.empty:
            continue
        current_cell = current_cell.sort_values("CheckupResistanceFEC")
        handle, = ax.plot(
            current_cell["CheckupResistanceFEC"],
            current_cell["Resistance [Ohm]"],
            "-o",
            linewidth=2,
            color=color_list[idx],
            markerfacecolor=color_list[idx],
            markersize=4,
            linestyle=linestyle_list[idx],
        )
        legend_handles.append(handle)
        legend_labels.append(label_list[idx])
        if current_cell["CheckupResistanceFEC"].notna().any():
            max_fec_highlight = max(max_fec_highlight, float(current_cell["CheckupResistanceFEC"].max()))

    ax.grid(True, linestyle="--", alpha=0.6)
    ax.set_xlabel("Full Equivalent Cycles (FEC)", fontsize=11)
    ax.set_ylabel("Checkup Resistance [Ohm]", fontsize=11)
    if plot_title:
        ax.set_title(f"{plot_title} (vs FEC)", fontsize=11)
    if max_fec_highlight > 0:
        ax.set_xlim(0, max_fec_highlight)
    if legend_handles:
        ax.legend(legend_handles, legend_labels, fontsize=11, loc="best")

    fig.tight_layout()
    output_file.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_file, dpi=300, bbox_inches="tight")
    plt.close(fig)


def plot_all_cells_overview(dataframe: pd.DataFrame, cell_list: list[str], output_file: Path) -> None:
    """Create the all-cells reference figure used as background context."""

    fig, axes = plt.subplots(2, 1, figsize=(10, 9))

    ax = axes[0]
    for cell_name in cell_list:
        current_cell = dataframe[dataframe["cell_number"] == cell_name].copy()
        if current_cell.empty:
            continue
        current_cell = current_cell.sort_values("Timestamp")
        time_days = (current_cell["Timestamp"] - current_cell["Timestamp"].iloc[0]).dt.total_seconds() / 86400.0
        ax.plot(time_days, current_cell["Resistance [Ohm]"], linewidth=2, color=(0.5, 0.5, 0.5, 0.2))

    ax.grid(True, linestyle="--", alpha=0.6)
    ax.set_xlabel("Time [days]", fontsize=18)
    ax.set_ylabel("Checkup Resistance [Ohm]", fontsize=18)
    ax.set_title("All Cells Overview (Resistance vs Time)", fontsize=20)
    ax.tick_params(axis="both", labelsize=14)

    ax = axes[1]
    max_fec = 0.0
    for cell_name in cell_list:
        current_cell = dataframe[dataframe["cell_number"] == cell_name].copy()
        if current_cell.empty:
            continue
        current_cell = current_cell.sort_values("CheckupResistanceFEC")
        ax.plot(
            current_cell["CheckupResistanceFEC"],
            current_cell["Resistance [Ohm]"],
            linewidth=2,
            color=(0.5, 0.5, 0.5, 0.2),
        )
        if current_cell["CheckupResistanceFEC"].notna().any():
            max_fec = max(max_fec, float(current_cell["CheckupResistanceFEC"].max()))

    ax.grid(True, linestyle="--", alpha=0.6)
    ax.set_xlabel("Full Equivalent Cycles (FEC)", fontsize=18)
    ax.set_ylabel("Checkup Resistance [Ohm]", fontsize=18)
    ax.set_title("All Cells Overview (Resistance vs FEC)", fontsize=20)
    ax.tick_params(axis="both", labelsize=14)
    if max_fec > 0:
        ax.set_xlim(0, max_fec)

    fig.tight_layout()
    output_file.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output_file, dpi=300, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    """Generate all resistance-overview figures for cyclic and calendar datasets."""

    combined_df_cyclic, cell_list_cyclic = load_and_preprocess(INPUT_CSV_CYCLIC)
    combined_df_calendar, cell_list_calendar = load_and_preprocess(INPUT_CSV_CALENDAR)

    plot_all_cells_overview(
        combined_df_cyclic,
        cell_list_cyclic,
        IO_FOLDER_CYCLIC / "CheckupResistanceVsTime_AllCells_.png",
    )

    plot_resistance_increase(
        combined_df_cyclic,
        cell_list_cyclic,
        ["Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_27", "Cell_30", "Cell_16"],
        [
            "A02_02 | Cell_12 - 100% DoD",
            "A2.02 | Cell_56 - 100% DoD",
            "A2.02 | Cell_89 - 100% DoD",
            "A2.02 | Cell_93 - 100% DoD",
            "A02_05 | Cell_27 - 70% DoD",
            "A02_04 | Cell_30 - 40% DoD",
            "A02_03 | Cell_16 - 10% DoD",
        ],
        ["b", "r", "g", (1, 0.5, 0), (0.5, 0, 0.5), (0.6, 0.3, 0), (1, 0.75, 0.8)],
        ["-"] * 7,
        IO_FOLDER_CYCLIC / "CheckupResistanceVsTime_VsDoD_.png",
        "Effect of Depth of Discharge (DoD)",
    )

    plot_resistance_increase(
        combined_df_cyclic,
        cell_list_cyclic,
        ["Cell_60", "Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_29"],
        [
            "A01_02 | Cell_60 - 0 degC",
            "A02_02 | Cell_12 - 25 degC",
            "A2.02 | Cell_56 - 25 degC",
            "A2.02 | Cell_89 - 25 degC",
            "A2.02 | Cell_93 - 25 degC",
            "A03_04 | Cell_29 - 45 degC",
        ],
        ["b", (1, 0.5, 0), (1, 0.5, 0), (1, 0.5, 0), (1, 0.5, 0), "r"],
        ["-", "--", ":", "-.", "-", "-"],
        IO_FOLDER_CYCLIC / "CheckupResistanceVsTime_VsTemperature_.png",
        "Effect of Temperature",
    )

    plot_resistance_increase(
        combined_df_cyclic,
        cell_list_cyclic,
        ["Cell_63", "Cell_60", "Cell_66", "Cell_68"],
        [
            "A01_03 | Cell_63 - C/4 - C/2 - 0 degC",
            "A01_02 | Cell_60 - C/2 - C/2 - 0 degC",
            "A01_04 | Cell_66 - 3C/4 - C/2 - 0 degC",
            "A01_05 | Cell_68 - 1C - C/2 - 0 degC",
        ],
        ["b", "r", "g", (1, 0.5, 0)],
        ["-"] * 4,
        IO_FOLDER_CYCLIC / "CheckupResistanceVsTime_VsCrate0DegC_.png",
        "Effect of C-rate at 0 degC",
    )

    plot_resistance_increase(
        combined_df_cyclic,
        cell_list_cyclic,
        ["Cell_12", "Cell_23", "Cell_34", "Cell_35"],
        [
            "A02_02 | Cell_12 - C/2 - C/2 - 25 degC",
            "A02_06 | Cell_23 - 1C - C/2 - 25 degC",
            "A02_07 | Cell_34 - 3C/2 - C/2 - 25 degC",
            "A02_08 | Cell_35 - 2C - C/2 - 25 degC",
        ],
        ["b", "r", "g", (1, 0.5, 0)],
        ["-"] * 4,
        IO_FOLDER_CYCLIC / "CheckupResistanceVsTime_VsCrate25DegC_.png",
        "Effect of C-rate at 25 degC",
    )

    plot_resistance_increase(
        combined_df_cyclic,
        cell_list_cyclic,
        ["Cell_29", "Cell_8", "Cell_9", "Cell_47"],
        [
            "A03_04 | Cell_29 - C/2 - C/2 - 45 degC",
            "A03_08 | Cell_8 - C/2 - 1C - 45 degC",
            "A03_09 | Cell_9 - 1C - C/2 - 45 degC",
            "A03_11 | Cell_47 - 1C - 1C - 45 degC",
        ],
        ["b", "r", "g", (1, 0.5, 0)],
        ["-"] * 4,
        IO_FOLDER_CYCLIC / "CheckupResistanceVsTime_VsCrate45DegC_.png",
        "Effect of C-rate at 45 degC",
    )

    plot_resistance_increase(
        combined_df_cyclic,
        cell_list_cyclic,
        ["Cell_40", "Cell_1", "Cell_3"],
        [
            "A03_05 | Cell_40 - 75% avg SoC - 50% DoD",
            "A03_06 | Cell_1 - 50% avg SoC - 50% DoD",
            "A03_07 | Cell_3 - 25% avg SoC - 50% DoD",
        ],
        ["b", "r", "g"],
        ["-"] * 3,
        IO_FOLDER_CYCLIC / "CheckupResistanceVsTime_AvgSoC_.png",
        "Effect of Average SoC",
    )

    plot_resistance_increase(
        combined_df_cyclic,
        cell_list_cyclic,
        ["Cell_9", "Cell_5", "Cell_22"],
        [
            "A03_09 | Cell_9 - 2.75V-4.35V - CC - CC",
            "A03_12 | Cell_5 - 2.75V-4.45V - CC - CC",
            "A03_10 | Cell_22 - 2.75V-4.45V - CCCV - CC",
        ],
        ["b", "r", "g"],
        ["-"] * 3,
        IO_FOLDER_CYCLIC / "CheckupResistanceVsTime_HighVEffect_.png",
        "Effect of High Voltage",
    )

    plot_resistance_increase(
        combined_df_cyclic,
        cell_list_cyclic,
        ["Cell_74", "Cell_46", "Cell_17", "Cell_53"],
        [
            "Cell_74 - 0 degrees",
            "Cell_46 - 25 degrees",
            "Cell_17 - 45 degrees",
            "Cell_53 - dynamic temperatures",
        ],
        ["b", "r", "g", (0.5, 0.5, 0.5)],
        ["-"] * 4,
        IO_FOLDER_CYCLIC / "CheckupResistanceVsTime_StationaryStorage_.png",
        "Stationary storage cycle",
    )

    plot_resistance_increase(
        combined_df_cyclic,
        cell_list_cyclic,
        ["Cell_72", "Cell_42", "Cell_25", "Cell_49"],
        [
            "Cell_72 - 0 degrees",
            "Cell_42 - 25 degrees",
            "Cell_14 - 45 degrees",
            "Cell_49 - dynamic temperatures",
        ],
        ["b", "r", "g", (0.5, 0.5, 0.5)],
        ["-"] * 4,
        IO_FOLDER_CYCLIC / "CheckupResistanceVsTime_DriveCycle_.png",
        "Drive cycle",
    )

    plot_resistance_increase(
        combined_df_calendar,
        cell_list_calendar,
        ["Cell_57", "Cell_11", "Cell_45", "Cell_26", "Cell_28"],
        [
            "A01_01 | Cell_57 | 0 degC | (Avg SoC = 100.0%)",
            "A02_01 | Cell_11 | 25 degC | (Avg SoC = 100.0%)",
            "A03_01 | Cell_45 | 45 degC | (Avg SoC = 10.0%)",
            "A03_02 | Cell_26 | 45 degC | (Avg SoC = 50.0%)",
            "A03_03 | Cell_28 | 45 degC | (Avg SoC = 100.0%)",
        ],
        ["b", "r", "g", (1, 0.5, 0), (0.5, 0, 0.5)],
        ["-"] * 5,
        IO_FOLDER_CALENDAR / "CheckupResistanceVsTime_CalendarAgeingEffect_.png",
        "Calendar Ageing Effect (per-cell Avg SoC shown)",
    )

    print("All resistance plots generated successfully!")


if __name__ == "__main__":
    main()
