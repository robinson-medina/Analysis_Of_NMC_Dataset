%% Battery Test Data Analysis and Visualization (ExtractAgeingData.m)
% Summary: Main per-cell ageing pipeline. Loads battery cell test data,
% reconstructs and processes time gaps, calculates cumulative charge capacity,
% and performs diagnostic analyses including checkup capacity measurements,
% 30 s DC-pulse resistance, dV/dt (Li-stripping) analysis and the Reference
% Performance Cycle figure. It also accumulates the cross-cell overview tables.
%
% Usage:   See the Instructions block below (run over all cells, or a single
%          cell by setting 'cellNum').
%
% Produces: Per-cell diagnostic figures (PNG + vector PDF in ../pngs, R-022) and
% the cross-cell CSV tables 'OverviewResistanceData_<N>cell.csv' /
% 'OverviewCapacityData_<N>cell.csv' (consumed by the overview plotters).
%
% Inputs:  cyclic/calendar ageing CSVs under DesiredFolder.
% Outputs: figures in ../pngs and Overview*Data_*.csv next to the data.
%
% Author: Feye Hoekstra, Róbinson Medina 
% Updated: 2025-11-25
% Last documented: 2026-08-04
%% Instructions
% 1a To run the script in all cells, update the variable 'DesiredFolder' with the path to the all the cyclic
% or calendar ageing experiments
% 1b To run the script on a particular cell, update the variable 'cellNum'
% and the location 'DesiredFolder' and comment the main for loop and the
% line '    cellNum = Folders(celNumIndx).name;' inside the foor loop

clear;
% close all;
clc;
% Resolve Functions path relative to this script so it works from any cwd.
scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, '..', '..', 'Functions'))


%% Configuration
DesiredFolder = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot\Cyclic_ageing_data';
% DesiredFolder = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot\Calendar_ageing_data';
Folders = dir([DesiredFolder '\*_Cell_*']);
% cellNum = 'A3.13_Cell_17';
 % cellNum = 'A3.11_Cell_8'; % ligth A3 file
% cellNum = 'A3.12_Cell_47';
 cellNum = 'A2.08_Cell_35'; % light A2 file
% cellNum = 'A2.02_Cell_56'; % light A2 file
% cellNum = 'A2.07_Cell_34';
cellNum = 'A1.05_Cell_68';

% Load processed battery test data from .mat file

% Initialize cell arrays to accumulate data from all cells
allResistanceData = {};
allDVdtData = {};
allCapacityData = {};
allDQdVData = {};celNumIndx=1;

% for celNumIndx = 1:length(Folders)
%     cellNum = Folders(celNumIndx).name;
    close all
    
    % Generate descriptive label for cell based on ageing test plan
    cellLabel = getCellLabel(cellNum);
  
    fprintf('\n========================================\n');
    fprintf('Battery Test Data Analysis for NextBMS journal\n');
    fprintf('========================================\n');
    % loadName = ['\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\Data\', cellNum, '\processed\full\' cellNum '.csv'];
    loadName = [DesiredFolder,  '\',cellNum, '\', cellNum '.csv'];
    fprintf('Loading data for cell: %s...\n', cellNum);

    % Extract save path for figures from loadName
    [savePath, ~, ~] = fileparts(loadName);
    fprintf('Figures will be saved to: %s\n', savePath);


    tic;  % Restart timer


    fprintf('Loading %s \n',cellNum)
    tic;  % Start timer

    %% Load + preprocess via shared helper (single source of the ingestion pipeline)
    % loadAndPreprocessAgeingCsv performs the readtable + time-vector
    % reconstruction + NaN-gap insertion + cumulative-charge integral that is
    % shared with PlotCellSummary.m, so the ingestion code lives in one place.
    [timeWithGaps, timeS, voltage, current, cellTemp, chamberTemp, cumulative_integral] = ...
        loadAndPreprocessAgeingCsv(loadName);
    fprintf('Data loaded and preprocessed. (Elapsed: %.2f s)\n', toc);

    %% Plot Overview Data
    % Create a multi-panel plot showing current, voltage, temperature, and capacity
    plotOverviewData(timeWithGaps, current, voltage, cellTemp, chamberTemp, cumulative_integral, cellNum, cellLabel);
    figOverview = gcf;

    % %% Extract Reference Performance Cycle (RPC) only valid for cell A1.05_Cell_68
    % % Define the publication zoom window for the Reference Performance Cycle view
    % referenceCycleStartTime = datetime(2024, 4, 23, 5, 51, 16);
    % referenceCycleEndTime = datetime(2024, 4, 30, 04, 55, 12);
 
    % % Plot publication-formatted overview data restricted to the selected time window
    % plotReferencePerformanceCycle(timeWithGaps, current, voltage, cellTemp, chamberTemp, cumulative_integral, cellNum, cellLabel, referenceCycleStartTime, referenceCycleEndTime);
    % figReferencePerformanceCycle = gcf;


    %% Checkup Capacity Analysis
    % Analyze discharge curves during checkup cycles to measure capacity degradation
    % over time by identifying constant-current discharge segments

    % Define time range for analysis
    startTime = datetime(timeWithGaps(1));
    endTime = datetime(timeWithGaps(end-20));

    % Find constant-current discharge segments for checkup analysis
    segments = findCheckupSegments(timeWithGaps, voltage, current, timeS, startTime, endTime);

    % Select data within the specified datetime range for plotting
    selectedIndices = (timeWithGaps >= startTime) & (timeWithGaps <= endTime);
    selectedTime = timeWithGaps(selectedIndices);
    selectedVoltage = voltage(selectedIndices);
    selectedCurrent = current(selectedIndices);
    selectedTimeS = timeS(selectedIndices);

    % Window for moving average in dQ/dV calculation
    windowSize = 5000;

    % Analyze discharge curves and calculate checkup capacity
    [checkupCapacityTimeStamp, checkupCapacity_Ah,checkupCapacityFEC,legends,CheckUpOCV_V,dQdV_AperVs,SegmentCapacity_Ah,CheckUpSoC] = analyzeCheckupDischarge(segments, selectedTime, selectedVoltage, selectedCurrent, selectedTimeS, windowSize, cellNum, cellLabel);
    figCheckupDischarge = gcf;

    % Export OCP discharge data (SoC-OCV-capacity) to CSV
    exportOCPDischarge(savePath, cellNum, CheckUpSoC, CheckUpOCV_V, checkupCapacity_Ah, checkupCapacityTimeStamp);

    %% Extract Resistance Values
    % Calculate internal resistance from voltage drop during current pulses
    % Uses high-current (-58 A) pulses with 30s duration to measure DC resistance
    [checkupResistanceTimeStamp, checkupResistance_Ohm,checkupResistenceFEC] = extractResistanceValues(timeWithGaps, voltage, current, timeS, startTime, endTime, cellNum, cellLabel);
    figResistance = gcf;

    %% Plot Capacity and Resistance Trending
    % Display capacity fade and resistance growth over time

    plotCapacityAndResistanceTrending(checkupCapacityTimeStamp, checkupCapacity_Ah, checkupCapacityFEC, checkupResistanceTimeStamp, checkupResistance_Ohm, checkupResistenceFEC, cellNum, cellLabel);
    figCapResTrend = gcf;



    %% dV/dt Analysis
    % Identify discharge segments after fast charge
    constantCurrentValue_A = -11.6;

    % Perform dV/dt analysis
    [plottedSegments, dVdtData] = analyzeDVdtAfterCharge(selectedTime, selectedVoltage, selectedCurrent, selectedTimeS, constantCurrentValue_A, cellNum, cellLabel);
    figDVdt = gcf;

    %% Save All Figures
    % Save all figures at the end of the loop iteration
    PNGFiles = dir([DesiredFolder,  '\',cellNum, '\*.png']);% deletes current files
    for FileIndx = 1:length(PNGFiles)
        FileToDelete = [DesiredFolder,  '\',cellNum, '\', PNGFiles(FileIndx).name];
        delete(FileToDelete);
    end
    fprintf('\nSaving figures...\n');
    % Save all figures to JournalScripts/pngs/ so they are co-located with
    % the other journal publication figures rather than in the data folders.
    scriptDir_ext = fileparts(mfilename('fullpath'));
    journalPngsDir = fullfile(scriptDir_ext, '..', 'pngs');
    if ~exist(journalPngsDir, 'dir'); mkdir(journalPngsDir); end
    saveas(figOverview,        fullfile(journalPngsDir, [cellNum '_Overview.png']));
    saveas(figCheckupDischarge,fullfile(journalPngsDir, [cellNum '_CheckupDischarge.png']));
    saveas(figResistance,      fullfile(journalPngsDir, [cellNum '_Resistance.png']));
    saveas(figCapResTrend,     fullfile(journalPngsDir, [cellNum '_CapacityResistanceTrend.png']));
    saveas(figDVdt,            fullfile(journalPngsDir, [cellNum '_dVdtAnalysis.png']));


    fprintf('\n========================================\n');
    fprintf('All figures saved to: %s\n', savePath);
    fprintf('========================================\n');

    % Accumulate resistance data (skip NaN timestamps)
    numResistancePoints = length(checkupResistanceTimeStamp);
    for i = 1:numResistancePoints
        if ~isnat(checkupResistanceTimeStamp(i))
            allResistanceData{end+1, 1} = cellNum;
            allResistanceData{end, 2} = cellLabel;
            allResistanceData{end, 3} = checkupResistanceTimeStamp(i);
            allResistanceData{end, 4} = checkupResistance_Ohm(i);
            allResistanceData{end, 5} = checkupResistenceFEC(i);
        end
    end



    % Accumulate capacity data (skip NaN timestamps)
    numCapacityPoints = length(checkupCapacityTimeStamp);
    for i = 1:numCapacityPoints
        if ~isnat(checkupCapacityTimeStamp(i))
            allCapacityData{end+1, 1} = cellNum;
            allCapacityData{end, 2} = cellLabel;
            allCapacityData{end, 3} = checkupCapacityTimeStamp(i);
            allCapacityData{end, 4} = checkupCapacity_Ah(i);
            allCapacityData{end, 5} = checkupCapacityFEC(i);
        end
    end

% end

%% Save All Tables to CSV
fprintf('\n========================================\n');
fprintf('Saving data tables to CSV files...\n');
fprintf('========================================\n');

% Create and save Resistance table
if ~isempty(allResistanceData)
    resistanceTable = cell2table(allResistanceData, 'VariableNames', {'CellNum', 'CellLabel', 'CheckupResistanceTimeStamp', 'CheckupResistance_Ohm', 'CheckupResistanceFEC'});
    writetable(resistanceTable, fullfile(DesiredFolder, ['OverviewResistanceData_' num2str(celNumIndx) 'cell.csv']));
    fprintf('Resistance data saved to: %s\n', fullfile(DesiredFolder, ['OverviewResistanceData_' num2str(celNumIndx) 'cell.csv']));
end


% Create and save Capacity table
if ~isempty(allCapacityData)
    capacityTable = cell2table(allCapacityData, 'VariableNames', {'CellNum', 'CellLabel', 'CheckupCapacityTimeStamp', 'CheckupCapacity_Ah', 'CheckupCapacityFEC'});
    writetable(capacityTable, fullfile(DesiredFolder, ['OverviewCapacityData_' num2str(celNumIndx) 'cell.csv']));
    fprintf('Capacity data saved to: %s\n', fullfile(DesiredFolder, ['OverviewCapacityData_' num2str(celNumIndx) 'cell.csv']));
end



fprintf('\n========================================\n');
fprintf('All tables saved to: %s\n', DesiredFolder);
fprintf('========================================\n');