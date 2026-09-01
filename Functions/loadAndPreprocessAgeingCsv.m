function [timeWithGaps, timeS, voltage, current, cellTemp, chamberTemp, cumulative_integral] = ...
    loadAndPreprocessAgeingCsv(csvPath)
% loadAndPreprocessAgeingCsv - Load a cyclic/calendar ageing CSV and run the
% shared preprocessing pipeline (time reconstruction, NaN-gap insertion, and
% cumulative-charge integral).
%
% This helper centralises the data-ingestion preamble that was previously
% copy-pasted verbatim in both ExtractAgeingData.m and PlotCellSummary.m, so
% the two drivers now share a single, authoritative implementation.
%
% Inputs:
%   csvPath  - Full path to the cell's ageing CSV (Time, Voltage_V_,
%              Current_A_, CellTemp__C_, ChamberTemp__C_ columns), following
%              the same column convention produced by ConvertMat4Journal_ageing.m
%
% Outputs:
%   timeWithGaps        - datetime array with NaT inserted at data gaps
%   timeS               - seconds-since-start array (NaN at gaps)
%   voltage             - cell voltage [V] (NaN at gaps)
%   current             - cell current [A] (NaN at gaps)
%   cellTemp            - cell temperature [degC] (NaN at gaps)
%   chamberTemp         - chamber temperature [degC] (NaN at gaps)
%   cumulative_integral - cumulative charge (capacity) integral of current [Ah]
%
% Author: GitHub Copilot (for Róbinson Medina / Feye Hoekstra)
% Date:   2026-07-28
%
% Notes:
%   - Reuses the shared helpers insertNaNAtGaps and computeCumulativeCharge
%     (same Functions/ folder). R-001 compliant: reads only, never writes the
%     raw file. R-003 compliant: no post-R2022a features used.

% Import options match both drivers exactly: first column (Time) read as a
% string, data starting on line 2, header on line 1.
opts = detectImportOptions(csvPath);
opts.VariableTypes{1}   = 'string';
opts.DataLines          = [2 Inf];
opts.VariableNamesLine  = 1;
TableData = readtable(csvPath, opts);

% Reconstruct the absolute time vector. The first Time entry is an absolute
% timestamp; subsequent entries are inter-sample dwell times in seconds that
% are cumulatively summed onto the first timestamp.
timeYYMMDDstr = TableData.Time;                                   % raw Time column (string)
timeYYMMDD    = NaT(size(timeYYMMDDstr));                         % preallocate datetime vector
timeYYMMDD(1) = datetime(timeYYMMDDstr(1), 'Format', 'dd-MMM-yyyy HH:mm:ss.SSS'); % absolute start
Increase_s    = cumsum(seconds(double(timeYYMMDDstr(2:end))));    % cumulative dwell time [s]
timeYYMMDD(2:end) = Increase_s + timeYYMMDD(1);                   % absolute time for every sample

% Extract the measured channels using the fixed column names.
voltageV     = TableData.Voltage_V_;        % cell voltage [V]
currentA     = TableData.Current_A_;         % cell current [A]
cellTempC    = TableData.CellTemp__C_;       % cell temperature [degC]
chamberTempC = TableData.ChamberTemp__C_;    % chamber temperature [degC]
dwellTimeS   = seconds(timeYYMMDD - timeYYMMDD(1)); % seconds since start

clear TableData timeYYMMDDstr Increase_s     % release the (large) raw table

% Insert NaN/NaT at gaps > 1 minute so plotted lines are not drawn across
% discontinuous data segments (shared helper).
[timeWithGaps, timeS, voltage, current, cellTemp, chamberTemp] = ...
    insertNaNAtGaps(timeYYMMDD, dwellTimeS, voltageV, currentA, cellTempC, chamberTempC);

% Cumulative charge (capacity) integral of current over time (shared helper),
% computed per continuous (gap-separated) segment.
cumulative_integral = computeCumulativeCharge(timeS, current);

end
