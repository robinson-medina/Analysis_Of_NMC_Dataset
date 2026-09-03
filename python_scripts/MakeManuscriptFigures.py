"""
MakeManuscriptFigures - one-shot orchestrator that runs every manuscript
figure generator in sequence and prints a PASS/FAIL summary.

Python counterpart of matlab_scripts/MakeManuscriptFigures.m (todo #104).

Figure -> generator map (mirrors the MATLAB orchestrator):
    characterization_combined.pdf      -> PlotCharacterizationData_Cell15.py (see NOTE below)
    NextBMS_ReferencePerformanceCycle  -> PlotReferencePerformanceCycleFigure_Cell68.py
    LiStrippingMethods.pdf             -> PlotLiStrippingMethods_Cell35.py
    Anode.pdf / Cathode.pdf            -> extractOCPLines.py
    <cell>_CharacterizationOCV/EIS.pdf -> PlotCharacterizationResults.py (Cell_4/Cell_6/Cell_15)
    CyclicAgeing.pdf / CalendarAgeing  -> PlotAgeingCombinedOverview.py
    <cell>_Summary.pdf                 -> PlotCellSummary.py (example cell)

NOTE (documented decision): `python_scripts/PlotCharacterizationData_Cell15.py` is a
generic per-file debug plotter (todo #006) and does NOT yet reproduce the
`characterization_combined.pdf` figure that the MATLAB
`PlotCharacterizationData_Cell15.m` produces (arrows, journal styling,
single 5-phase combined figure). It is still called here for parity of
orchestration order, but this stage is expected to produce different
(debug-only) output until #006 is completed - flagged as PARTIAL below.

Author: GitHub Copilot (for Robinson Medina / Feye Hoekstra)
Date: 2026-08-24

Compliance: R-001, R-013, R-016, R-022.
"""

import importlib
import shutil
import sys
import time
import traceback
from pathlib import Path

_SCRIPT_DIR = Path(__file__).resolve().parent
if str(_SCRIPT_DIR) not in sys.path:
    sys.path.append(str(_SCRIPT_DIR))

_FUNCTIONS_DIR = _SCRIPT_DIR.parent / 'Functions'
if not _FUNCTIONS_DIR.exists():
    _FUNCTIONS_DIR = _SCRIPT_DIR.parent.parent / 'Functions'
if str(_FUNCTIONS_DIR) not in sys.path:
    sys.path.append(str(_FUNCTIONS_DIR))
from get_figure_output_dir import get_figure_output_dir  # noqa: E402

# Own R-022 folder that collects every manuscript figure this driver produces.
_MANUSCRIPT_DIR = get_figure_output_dir('MakeManuscriptFigures')
_FIGURES_PYTHON_ROOT = _MANUSCRIPT_DIR.parent


def _consolidate(stems, since_ts):
    """Copy files each generator stem produced/updated during this stage into the
    MakeManuscriptFigures folder, so the manuscript figures live in one place."""

    for stem in stems:
        src_dir = _FIGURES_PYTHON_ROOT / stem
        if not src_dir.is_dir():
            continue
        for src in src_dir.iterdir():
            if not src.is_file() or src.suffix.lower() not in ('.pdf', '.png'):
                continue
            if src.stat().st_mtime + 1e-3 < since_ts:
                continue  # untouched by this stage
            try:
                shutil.copy2(src, _MANUSCRIPT_DIR / src.name)
            except OSError as copy_exc:  # noqa: PERF203 - report, do not abort
                print(f'[WARN] could not copy {src.name}: {copy_exc}')


def _run_stage(label, fn, *args, stems=(), **kwargs):
    """Run one stage, catching and reporting failures without stopping the run."""

    print('\n' + '#' * 60)
    print(f'STAGE: {label}')
    print('#' * 60)
    since_ts = time.time()
    try:
        fn(*args, **kwargs)
        _consolidate(stems, since_ts)
        return True, None
    except Exception as exc:  # noqa: BLE001 - mirrors MATLAB's per-stage try/catch
        print(f'[FAIL] {label}: {exc}')
        traceback.print_exc()
        return False, str(exc)


def main():
    """Run every manuscript-figure generator in sequence."""

    results = []

    ok, err = _run_stage(
        'PlotCharacterizationData_Cell15 (characterization_combined.pdf - PARTIAL, see #006)',
        lambda: importlib.import_module('PlotCharacterizationData_Cell15').main(),
        stems=('PlotCharacterizationData_Cell15',))
    results.append(('PlotCharacterizationData_Cell15', ok, err))

    ok, err = _run_stage(
        'PlotReferencePerformanceCycleFigure_Cell68 (NextBMS_ReferencePerformanceCycle.pdf)',
        lambda: importlib.import_module('PlotReferencePerformanceCycleFigure_Cell68').main(),
        stems=('PlotReferencePerformanceCycleFigure_Cell68',))
    results.append(('PlotReferencePerformanceCycleFigure_Cell68', ok, err))

    ok, err = _run_stage(
        'PlotLiStrippingMethods_Cell35 (LiStrippingMethods.pdf)',
        lambda: importlib.import_module('PlotLiStrippingMethods_Cell35').main(),
        stems=('PlotLiStrippingMethods_Cell35',))
    results.append(('PlotLiStrippingMethods_Cell35', ok, err))

    ok, err = _run_stage(
        'extractOCPLines (Anode.pdf / Cathode.pdf)',
        lambda: importlib.import_module('extractOCPLines').main(),
        stems=('extractOCPLines',))
    results.append(('extractOCPLines', ok, err))

    ok, err = _run_stage(
        'PlotCharacterizationResults (<cell>_CharacterizationOCV/EIS.pdf x3)',
        lambda: [importlib.import_module('PlotCharacterizationResults').main(cell_num=c)
                 for c in ('Cell_4', 'Cell_6', 'Cell_15')],
        stems=('PlotCharacterizationResults',))
    results.append(('PlotCharacterizationResults', ok, err))

    ok, err = _run_stage(
        'PlotAgeingCombinedOverview (CyclicAgeing.pdf / CalendarAgeing.pdf)',
        lambda: importlib.import_module('PlotAgeingCombinedOverview').main(),
        stems=('PlotAgeingCombinedOverview',))
    results.append(('PlotAgeingCombinedOverview', ok, err))

    ok, err = _run_stage(
        'PlotCellSummary (example cell: Cell_35_Summary.pdf)',
        lambda: importlib.import_module('PlotCellSummary').main(cell_num='Cell_35'),
        stems=('PlotCellSummary',))
    results.append(('PlotCellSummary', ok, err))

    print('\n' + '=' * 60)
    print('MakeManuscriptFigures: summary')
    print('=' * 60)
    n_pass = sum(1 for _, ok, _ in results if ok)
    for name, ok, err in results:
        status = 'PASS' if ok else f'FAIL ({err})'
        print(f'  {name:<45s} {status}')
    print(f'\n{n_pass}/{len(results)} stages passed.')
    print(f'Manuscript figures collected in: {_MANUSCRIPT_DIR}')


if __name__ == '__main__':
    main()
