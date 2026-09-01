%% Summary: Standalone driver that reproduces the Reference Performance Cycle
% (RPC) publication figure by loading + preprocessing the cyclic-ageing CSV of
% cell A1.05_Cell_68 and calling the plotReferencePerformanceCycle plotting
% function. The RPC zone timings and inset annotations inside that function are
% hard-coded for this specific cell and its April-2024 reference cycle, so this
% driver is intentionally cell-specific.
%
% NOTE ON THE FILE NAME: this driver is deliberately NOT named
% plotReferencePerformanceCycle.m. A second file with that name (Windows is
% case-insensitive) would shadow Functions/plotReferencePerformanceCycle.m on
% the MATLAB path, so the call below would resolve to this script instead of the
% plotting function and error. The plotting function keeps its name; this runner
% has a distinct one.
%
% Usage:   Run the script (no arguments); paths + cell id are configured below.
% Author: GitHub Copilot
% Date:   2026-08-04
% Inputs:  none (paths + cell id are configured below)
% Outputs: the RPC figure window and pngs/NextBMS_ReferencePerformanceCycle.pdf
%          (the PDF is written by plotReferencePerformanceCycle itself)

clear; close all; clc;

%% Configuration
% Resolve the shared Functions folder relative to this script so it works from
% any current directory (same pattern as ExtractAgeingData.m).
scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, '..', '..', 'Functions'));

% The RPC figure and every hard-coded zone/annotation timestamp inside
% plotReferencePerformanceCycle.m are specific to this cell and window - do not
% change the cell without also updating those timestamps in the plotting function.
cellNum       = 'A1.05_Cell_68';
% DataRoot: single switch to the dataset root holding 1_Teardown/2_HalfCell/
% 3_Characterization/4_Ageing. Change this one line to retarget the script.
DataRoot      = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
DesiredFolder = fullfile(DataRoot, '4_Ageing', 'Cyclic_ageing_data');

% Publication zoom window for the Reference Performance Cycle view (identical to
% the window used in ExtractAgeingData.m for this cell).
referenceCycleStartTime = datetime(2024, 4, 23, 5, 51, 16);
referenceCycleEndTime   = datetime(2024, 4, 30, 4, 55, 12);

%% Load + preprocess the cell CSV via the shared ingestion helper
% loadAndPreprocessAgeingCsv reproduces the exact ingestion pipeline used by
% ExtractAgeingData.m (read + time-vector reconstruction + NaN-gap insertion +
% cumulative-charge integral), so the figure matches the one that script produces.
loadName  = fullfile(DesiredFolder, cellNum, [cellNum '.csv']);
cellLabel = getCellLabel(cellNum);
fprintf('Loading and preprocessing %s ...\n', cellNum);
[timeWithGaps, timeS, voltage, current, cellTemp, chamberTemp, cumulative_integral] = ...
    loadAndPreprocessAgeingCsv(loadName);  %#ok<ASGLU>  timeS is unused by the RPC plot

%% Produce the Reference Performance Cycle figure (and its vector PDF)
% plotReferencePerformanceCycle builds the 3-panel figure, the zone arrows, the
% voltage/current zoom insets and exports NextBMS_ReferencePerformanceCycle.pdf.
plotReferencePerformanceCycle(timeWithGaps, current, voltage, cellTemp, chamberTemp, ...
    cumulative_integral, cellNum, cellLabel, referenceCycleStartTime, referenceCycleEndTime);

fprintf('Reference Performance Cycle figure generated for %s.\n', cellNum);
