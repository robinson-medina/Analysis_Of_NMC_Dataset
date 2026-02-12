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
├── plotAgeingData.py/.m          # Main ageing data analysis script
├── PlotCharacterizationData.py/.m # Characterization data visualization
├── PlotEISData.py/.m             # EIS Nyquist diagram plotting
├── fileDependencies.txt          # List of function dependencies
├── LICENSE                       # MIT License
├── README.md                     # This file
└── Functions/                    # Helper functions
    ├── analyzeCheckupDischarge   # Analyze discharge curves for checkup cycles
    ├── analyzeDVdtAfterCharge    # Analyze dV/dt after charging
    ├── computeCumulativeCharge   # Compute cumulative charge capacity
    ├── extractResistanceValues   # Extract resistance from data
    ├── findCheckupSegments       # Identify checkup segments in data
    ├── insertNaNAtGaps           # Handle data gaps
    ├── plotCapacityAndResistanceTrending  # Plot capacity/resistance trends
    ├── plotNyquistDiagram        # Generate Nyquist diagrams
    └── plotOverviewData          # Generate data overview plots
```

## Requirements

### Python
- Python 3.x
- NumPy
- Pandas
- Matplotlib
- SciPy

### MATLAB
- MATLAB R2020a or later (recommended)

## Usage

### Python

```bash
# Run ageing data analysis
python plotAgeingData.py

# Run characterization data visualization
python PlotCharacterizationData.py

# Run EIS data visualization
python PlotEISData.py
```

### MATLAB

```matlab
% Run ageing data analysis
plotAgeingData

% Run characterization data visualization
PlotCharacterizationData

% Run EIS data visualization
PlotEISData
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

## Data Format

The scripts expect CSV files organized in the following structure:
- `Cyclic_ageing_data/` - Cyclic ageing test data
- `Calendar_ageing_data/` - Calendar ageing test data
- `Characterization_data/` - Initial characterization data
  - Each cell folder may contain an `EIS/` subfolder with `*_impedanceData.csv` files

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Róbinson Medina, Feye Hoekstra

## Acknowledgments

This work is part of the NextBMS project for battery management system research.
