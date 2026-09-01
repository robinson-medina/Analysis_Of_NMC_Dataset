%% PlotReferencePerformanceCycleFigure_Cell68.m
% Summary: Reproduces the Reference Performance Cycle figure for Cell_68. The
%          driver loads and preprocesses the cell's cyclic-ageing CSV, selects
%          the April 2024 reference-cycle window, and delegates plotting to the
%          shared RPC figure function.
%
% Usage: Set DataRoot if needed, then run this script with no arguments. The
%        cell and reference-cycle window are fixed for this figure.
%
% Outputs: NextBMS_ReferencePerformanceCycle.png and
%          NextBMS_ReferencePerformanceCycle.pdf in this script's R-022 output
%          directory.
%
% Authors: GitHub Copilot.
% Dependency files: Functions/loadAndPreprocessAgeingCsv.m,
%                   Functions/getCellLabel.m, Functions/getFigureOutputDir.m,
%                   Functions/plotReferencePerformanceCycle.m.
% Last documented: 2026-09-01

clear; close all; clc;

%% Configuration
% Resolve the shared Functions folder relative to this script so it works from
% any current directory (same pattern as ExtractAgeingData.m).
scriptDir = fileparts(mfilename('fullpath'));
functionsDir = fullfile(scriptDir, '..', '..', 'Functions');
if ~exist(functionsDir, 'dir')
    functionsDir = fullfile(scriptDir, '..', 'Functions');
end
if exist(functionsDir, 'dir')
    addpath(functionsDir);
else
    error('Shared Functions folder not found from %s.', scriptDir);
end

% The RPC figure and every hard-coded zone/annotation timestamp inside
% plotReferencePerformanceCycle.m are specific to this cell and window - do not
% change the cell without also updating those timestamps in the plotting function.
cellNum       = 'Cell_68';
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
    cumulative_integral, cellNum, cellLabel, referenceCycleStartTime, referenceCycleEndTime, ...
    getFigureOutputDir('PlotReferencePerformanceCycleFigure_Cell68'));

fprintf('Reference Performance Cycle figure generated for %s.\n', cellNum);
