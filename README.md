# Analysis of NMC Dataset

This repository contains Python and MATLAB scripts for analyzing and visualizing battery test data from NMC (Nickel Manganese Cobalt) cells for the NextBMS project.

## Overview

The scripts enable analysis of:
- **Cyclic ageing data** - Battery degradation during charge/discharge cycles
- **Calendar ageing data** - Battery degradation over time during storage
- **Characterization data** - Initial battery characterization measurements
- **EIS (Electrochemical Impedance Spectroscopy) data** - Nyquist diagram visualization

## Repository Structure

```
├── README.md                     # This file
├── ageing_test_plan.md           # Complete test matrix and configurations
├── requirements.txt              # Python dependencies
├── fileDependencies.txt          # List of function dependencies
│
├── matlab_scripts/               # MATLAB analysis scripts
│   ├── PlotAgeingData.m          # Main ageing data analysis
│   ├── PlotCharacterizationData.m # Characterization data visualization
│   ├── PlotEISData.m             # EIS Nyquist diagram plotting
│   ├── ExtractAgeingData.m        # Data extraction and processing
│   ├── PlotCapacityDegradationOverview.m  # Capacity degradation trends
│   ├── PlotResistanceIncreaseOverview.m   # Resistance trends
│   ├── ConvertMat4Journal_ageing.m        # MAT file conversion
│   └── extractOCPLines.m         # OCP line extraction
│
├── python_scripts/               # Python analysis scripts
│   ├── PlotAgeingData.py         # Python version of ageing analysis
│   ├── PlotCharacterizationData.py # Python characterization visualization
│   ├── PlotEISData.py            # Python EIS visualization
│   ├── ExtractAgeingData.py      # Python data extraction
│   ├── PlotCapacityDegradationOverview.py # Python capacity trends
│   └── extractOCPLines.py        # Python OCP line extraction
│
├── docs/                         # Documentation and project tracking
│   ├── rules.md                  # Business rules and constraints
│   ├── done.md                   # Completed work log
│   ├── todo.md                   # Task backlog and ideas
│   ├── assumptions.md            # Analysis assumptions
│   └── figures/                  # Generated figures (publication-ready)
│
└── pngs/                         # PNG output directory
```

## Ageing Test Plan

See [ageing_test_plan.md](ageing_test_plan.md) for the complete test matrix including:
- **0°C** - 8 cells testing temperature effects, C-rate variations, and validation cycles
- **25°C** - 11 cells testing DoD effects, C-rate effects, and validation cycles  
- **45°C** - 14 cells testing SOC effects, average SoC, high voltage, C-rate, and validation cycles
- **0°C – 45°C (Dynamic)** - 5 cells with dynamic temperature profiles for validation

## Requirements

### Python
- Python 3.9+
- NumPy
- Pandas
- Matplotlib
- SciPy

### MATLAB
- MATLAB R2022a or later

## Usage

### Python

```bash
# Navigate to python_scripts directory
cd python_scripts

# Run ageing data analysis
python PlotAgeingData.py

# Run characterization data visualization
python PlotCharacterizationData.py

# Run EIS data visualization
python PlotEISData.py

# Run OCP line extraction
python extractOCPLines.py
```

### MATLAB

```matlab
% Add paths (from MATLAB command window)
addpath(genpath('..\'));  % Add current project to path

% Run ageing data analysis
cd matlab_scripts
PlotAgeingData

% Run characterization data visualization
PlotCharacterizationData

% Run EIS data visualization
PlotEISData

% Run OCP line extraction
extractOCPLines
```

## Main Scripts

### `plotAgeingData`
Loads battery cell test data, processes time gaps, calculates cumulative charge capacity, and performs diagnostic analyses including:
- Checkup capacity measurements
- Resistance calculations
- dV/dt analysis after charging

### `PlotCharacterizationData`
Visualizes initial characterization data from CSV files. Generates figures with multiple subplots for each data column.

### `PlotEISData`
Loads impedance data from CSV files and generates Nyquist diagrams for different State of Charge (SoC) conditions.

### `extractOCPLines`
Builds anode and cathode OCP-like lookup curves from GITT pulse data, creates diagnostic plots for the detected pulse boundaries, and saves publication-ready PNG figures.

## Data Format

The scripts expect CSV files organized in the following structure:
- `Cyclic_ageing_data/` - Cyclic ageing test data
- `Calendar_ageing_data/` - Calendar ageing test data
- `Characterization_data/` - Initial characterization data
  - Each cell folder may contain an `EIS/` subfolder with `*_impedanceData.csv` files

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Authors

Róbinson Medina, Feye Hoekstra

## Acknowledgments

This work is part of the NextBMS project for battery management system research.
