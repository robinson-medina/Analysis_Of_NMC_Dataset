# Analysis code for paper "Characterization, ageing and post-mortem dataset of commercial 58Ah prismatic NMC cells"

This repository contains the MATLAB and Python analysis code used to process and
visualise the data accompanying the publication *Characterization, ageing and
post-mortem dataset of commercial 58 Ah prismatic NMC cells*. The analyses cover
cyclic and calendar ageing, electrical characterisation, electrochemical
impedance spectroscopy (EIS), half-cell open-circuit potential (OCP)
measurements, and publication figures.

This is the **analysis-code repository**. The measurement data are distributed
separately and are required to run the scripts.

- **Analysis code:** [GitHub repository](https://github.com/robinson-medina/Analsys_Of_NMC_Dataset)
- **Public dataset:** Permanent repository URL or DOI pending publication

## Citation

If you use this dataset or its analysis code, please cite:

> Lodge, A. *et al.* **Data from "Characterization, ageing and post-mortem
> dataset of commercial 58Ah prismatic NMC cells"**. Zenodo. Permanent DOI
> pending publication.

## Repository contents

```text
.
|-- README.md
|-- ageing_test_plan.md
|-- requirements.txt
|-- Functions/                  Shared MATLAB and Python functions
|-- matlab_scripts/             MATLAB entry scripts
`-- python_scripts/             Python entry scripts
```

The separate dataset must retain this top-level directory structure:

```text
1_Teardown/
2_HalfCell/
3_Characterization/
4_Ageing/
|-- Calendar_ageing_data/
|-- Cyclic_ageing_data/
`-- EIS_data/
5_Documentation/
```

The included [ageing test plan](ageing_test_plan.md) applies only to the data in
`4_Ageing`. It documents that folder's test matrix and maps each `Cell_<n>`
identifier to its ageing conditions. The other top-level data folders use
different test plans; consult the README and supporting documentation within each
folder of the public dataset.

## Requirements

### MATLAB

- MATLAB R2022a or later
- Times New Roman installed for publication-matched figure typography

### Python

- Python 3.9 or later (the supported minimum for this repository)
- NumPy
- pandas
- Matplotlib
- SciPy
- Times New Roman installed for publication-matched figure typography

Install the Python dependencies from the repository root:

```bash
python -m pip install -r requirements.txt
```

## Setup

1. Obtain this analysis-code repository and the separately distributed dataset.
2. Keep `Functions/`, `matlab_scripts/`, and `python_scripts/` as sibling
   directories. The entry scripts import shared helpers from `Functions/` and
   will fail if that directory is moved or omitted.
3. Install the Python dependencies if you intend to use the Python scripts.
4. Configure the input data path as described below.

### Input data path

Each entry script contains a hardcoded default data location. Before running a
script, replace its `DataRoot`, `DATA_ROOT`, or `data_root` value with the path to
the downloaded dataset root, which is the directory containing `1_Teardown/`
through `5_Documentation/`.

MATLAB example:

```matlab
DataRoot = 'C:\Data\NEXTBMS';
```

Python example:

```python
data_root = r'C:\Data\NEXTBMS'
```

The master drivers call several generators, and those generators retain their
own data-root settings. Before using `MakeManuscriptFigures.m` or
`MakeManuscriptFigures.py`, update the data-root setting in the master driver and
in each generator it invokes. Searching `matlab_scripts/` and `python_scripts/`
for `ZenodoRoot` identifies every default that must be replaced. Do not rename or
reorganise the downloaded dataset folders.

### Figure output path

Generated files are kept outside the dataset. In this public-repository layout,
the default output root is the operating system's temporary directory:

```text
NEXTBMS_PublicRepositoryFigures/
|-- matlab/<script-name>/
`-- python/<script-name>/
```

Set the `NEXTBMS_FIGURE_ROOT` environment variable to choose another output root.
This variable controls **outputs only**; it does not change the input data path.
For example, in PowerShell:

```powershell
$env:NEXTBMS_FIGURE_ROOT = 'C:\NEXTBMS\Figures'
```

Each generator creates its own language-specific subdirectory. The MATLAB and
Python implementations therefore do not overwrite one another.

## Quick start

After installing the required software and updating the input paths, run one
generator before attempting the complete workflow. From the repository root:

```matlab
cd matlab_scripts
cellNumOverride = 'Cell_35';
PlotCellSummary
```

```bash
cd python_scripts
python -c "from PlotCellSummary import main; main(cell_num='Cell_35')"
```

These commands create the `Cell_35` summary in the corresponding
`PlotCellSummary/` output directory. They require the cyclic-ageing CSV for
`Cell_35`; EIS-dependent panels are populated only when the corresponding EIS
files are present.

## Reproduce the manuscript figures

The MATLAB scripts are the reviewed reference implementation used to produce the
journal figures. After configuring all input paths, run the complete workflow
from the repository root:

```matlab
cd matlab_scripts
MakeManuscriptFigures
```

For a headless run from a shell:

```bash
matlab -batch "cd('matlab_scripts'); MakeManuscriptFigures"
```

The MATLAB driver runs 11 stages. It produces the main manuscript figures first,
then performs the heavier all-cell ageing and EIS stages. Each stage reports
`PASS` or `FAIL`; a failed stage does not prevent later stages from running. The
driver collects refreshed manuscript PDFs and PNGs in
`matlab/MakeManuscriptFigures/` under the selected output root. Individual
generators also retain their outputs in their own subdirectories.

The Python compatibility implementation runs seven figure-generation stages:

```bash
cd python_scripts
python MakeManuscriptFigures.py
```

The Python characterisation stage produces per-file diagnostic plots rather than
MATLAB's combined publication panel. The Python workflow is therefore a
compatibility aid, not a second route for reproducing the exact journal figures.

## Maintained entry scripts

The public repository contains the following maintained MATLAB entry points:

| Script | Purpose |
| --- | --- |
| `MakeManuscriptFigures.m` | Run the complete MATLAB manuscript workflow. |
| `ExtractAgeingData.m` | Process per-cell ageing data and export diagnostics and overview tables. |
| `PlotCellSummary.m` | Create the A4 per-cell summary; the manuscript example is `Cell_35`. |
| `PlotAgeingCombinedOverview.m` | Compare cyclic and calendar ageing results. |
| `PlotCapacityDegradation_detailed.m` | Plot detailed capacity degradation trends. |
| `PlotResistanceIncrease_Detailed.m` | Plot detailed resistance increase trends. |
| `PlotCharacterizationData_Cell15.m` | Create the combined characterisation figure for `Cell_15`. |
| `PlotCharacterizationResults.m` | Create per-cell OCV and EIS characterisation results. |
| `PlotEISData.m` | Create BoL, MoL, and EoL ageing Nyquist plots. |
| `PlotLiStrippingDerivatives_Cell35.m` | Plot the lithium-stripping derivative analysis for `Cell_35`. |
| `PlotLiStrippingMethods_Cell35.m` | Create the lithium-stripping methods figure for `Cell_35`. |
| `PlotReferencePerformanceCycleFigure_Cell68.m` | Create the reference-performance-cycle figure for `Cell_68`. |
| `extractOCPLines.m` | Extract graphite-anode and NMC532-cathode OCP curves. |

The public repository also contains these Python compatibility entry points:

| Script | Purpose |
| --- | --- |
| `MakeManuscriptFigures.py` | Run the seven-stage Python orchestration workflow. |
| `ExtractAgeingData.py` | Process per-cell ageing data and export diagnostics and overview tables. |
| `PlotCellSummary.py` | Create the Python per-cell summary. |
| `PlotAgeingCombinedOverview.py` | Compare cyclic and calendar ageing results. |
| `PlotCapacityDegradation_detailed.py` | Plot detailed capacity degradation trends. |
| `PlotResistanceIncrease_Detailed.py` | Plot detailed resistance increase trends. |
| `PlotCharacterizationData_Cell15.py` | Create per-file characterisation diagnostics for `Cell_15`. |
| `PlotCharacterizationResults.py` | Create per-cell OCV and EIS characterisation results. |
| `PlotEISData.py` | Create ageing Nyquist plots. |
| `PlotLiStrippingMethods_Cell35.py` | Create the lithium-stripping methods figure for `Cell_35`. |
| `PlotReferencePerformanceCycleFigure_Cell68.py` | Create the reference-performance-cycle figure for `Cell_68`. |
| `extractOCPLines.py` | Extract graphite-anode and NMC532-cathode OCP curves. |

Run an individual entry point from its language directory. MATLAB scripts expose
configuration variables near the beginning of each file. Python interfaces are
not uniform: most files are executable scripts or importable modules, while
`extractOCPLines.py` additionally provides command-line options. Read the header
and configuration section of the selected entry point before running it.

## Main analysis outputs

`ExtractAgeingData` loads the cell test logs, reconstructs elapsed time, preserves
gaps in plotted traces, calculates cumulative charge, and evaluates check-up
capacity, 30 s DC-pulse resistance, and post-charge dV/dt behaviour. It exports
five diagnostic PNGs per cell:

```text
Cell_<n>_Overview.png
Cell_<n>_CheckupDischarge.png
Cell_<n>_Resistance.png
Cell_<n>_CapacityResistanceTrend.png
Cell_<n>_dVdtAnalysis.png
```

It also produces cross-cell capacity and resistance overview CSV files.

`PlotCellSummary` combines the full current, voltage, and temperature history with
capacity, resistance, lithium-stripping, dQ/dV, EIS, GITT/OCV, and C/50 OCP panels.
It exports `Cell_<n>_Summary.pdf` and `Cell_<n>_Summary.png`.

`PlotEISData` reads the impedance CSV files in the beginning-of-life (BoL),
middle-of-life (MoL), and end-of-life (EoL) EIS folders and exports
stage-qualified Nyquist plots for each available cell.

`extractOCPLines` processes the half-cell GITT measurements and exports the anode
and cathode OCP lookup curves and diagnostics.

## Code provenance

All code-generated figures shown in the journal paper were produced by the MATLAB
scripts. The MATLAB implementation and its figure outputs were carefully reviewed
by the authors and are the authoritative source for reproducing the paper.

The Python scripts were automatically generated with assistance from artificial
intelligence (AI). They are provided as a quick compatibility reference for
readers who prefer Python and use native Matplotlib rendering. They are not the
source of the figures in the journal paper. Review results obtained from the
Python implementation against the MATLAB reference before using them in further
scientific analysis; exact visual or numerical parity should not be assumed.

## Licensing

* **Data** - Creative Commons **CC BY-4.0**
* **Code snippets** - MIT

## Authors and contacts

- **Robinson Medina** - `robinson.medina@tno.nl`
- **Feye Hoekstra**

## Acknowledgements

This research has received funding from the European
Union’s Horizon 2020 research and innovation programme
under grant agreement No 101103898 under the title of
NEXTBMS (https://nextbms.eu)
