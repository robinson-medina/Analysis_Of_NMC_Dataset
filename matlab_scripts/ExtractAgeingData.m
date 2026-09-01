%% ExtractAgeingData.m
% Summary: Runs the per-cell ageing analysis pipeline. It loads one ageing CSV,
%          reconstructs the time axis, computes cumulative charge, extracts
%          checkup capacity and pulse-resistance metrics, runs dV/dt analysis,
%          and writes the overview tables used by the ageing summary figures.
%
% Usage: Set DataRoot, DesiredFolder, and cellNum in the Configuration block,
%        then run this script. External drivers may set cellNumOverride and
%        folderOverride before calling run(...) to process a selected cell.
%
% Outputs: Per-cell diagnostic PNG figures and overview CSV tables in this
%          script's R-022 output directory. The source data tree is read-only.
%
% Authors: Feye Hoekstra, Róbinson Medina.
% Dependency files: Functions/loadAndPreprocessAgeingCsv.m,
%                   Functions/getCellLabel.m, Functions/getFigureOutputDir.m,
%                   Functions/findCheckupSegments.m,
%                   Functions/analyzeCheckupDischarge.m,
%                   Functions/extractResistanceValues.m,
%                   Functions/analyzeDVdtAfterCharge.m,
%                   Functions/exportOCPDischarge.m,
%                   Functions/plotOverviewData.m,
%                   Functions/plotCapacityAndResistanceTrending.m,
%                   Functions/plotReferencePerformanceCycle.m.
% Last documented: 2026-09-01
%% Instructions
% 1a To run the script in all cells, update the variable 'DesiredFolder' with the path to the all the cyclic
% or calendar ageing experiments
% 1b To run the script on a particular cell, update the variable 'cellNum'
% and the location 'DesiredFolder' and comment the main for loop and the
% line '    cellNum = Folders(celNumIndx).name;' inside the foor loop

% Allow an external driver to preselect the cell/folder via
% cellNumOverride/folderOverride before run(...); the guards survive the clear below.
if exist('cellNumOverride', 'var'); keepCellOverride = cellNumOverride; end
if exist('folderOverride', 'var'); keepFolderOverride = folderOverride; end
clearvars -except keepCellOverride keepFolderOverride;
% close all;
clc;
% Resolve Functions path relative to this script so it works from any cwd in
% either the JournalScripts staging layout or the public repository layout.
scriptDir = fileparts(mfilename('fullpath'));
functionsDir = fullfile(scriptDir, '..', '..', 'Functions');
if ~exist(functionsDir, 'dir')
    functionsDir = fullfile(scriptDir, '..', 'Functions');
end
if exist(functionsDir, 'dir')
    addpath(functionsDir)
else
    error('Shared Functions folder not found from %s.', scriptDir);
end
% Publication outputs never write into the read-only ZenodoRoot tree (R-001);
% Keep generated diagnostic artifacts together in this entry script's R-022 directory.
journalPngsDir = getFigureOutputDir('ExtractAgeingData');


%% Configuration
% Single configurable dataset root. All reads are
% relative to DataRoot; the script never writes into the data tree (R-001).
DataRoot = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
DesiredFolder = fullfile(DataRoot, '4_Ageing', 'Cyclic_ageing_data');
% DesiredFolder = fullfile(DataRoot, '4_Ageing', 'Calendar_ageing_data');
if exist('keepFolderOverride', 'var'); DesiredFolder = keepFolderOverride; end
Folders = dir([DesiredFolder '\Cell_*']);
% cellNum = 'Cell_17';
 % cellNum = 'Cell_8'; % ligth A3 file
% cellNum = 'Cell_47';
 cellNum = 'Cell_35'; % light A2 file
% cellNum = 'Cell_56'; % light A2 file
% cellNum = 'Cell_34';
cellNum = 'Cell_68';
if exist('keepCellOverride', 'var'); cellNum = keepCellOverride; end

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

    % %% Extract Reference Performance Cycle (RPC) only valid for cell Cell_68
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

    % Export OCP discharge data (SoC-OCV-capacity) to CSV (R-022: pngs/, not
    % back into the read-only source folder `savePath` would point to).
    exportOCPDischarge(journalPngsDir, cellNum, CheckUpSoC, CheckUpOCV_V, checkupCapacity_Ah, checkupCapacityTimeStamp);

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
    % Save all figures at the end of the loop iteration.
    % (The data folders are read-only per R-001; nothing is deleted or
    % written there. Outputs go to JournalScripts/pngs/ per R-022.)
    fprintf('\nSaving figures...\n');
    % Save all figures to JournalScripts/pngs/ so they are co-located with
    % the other journal publication figures rather than in the data folders.
    saveas(figOverview,        fullfile(journalPngsDir, [cellNum '_Overview.png']));
    saveas(figCheckupDischarge,fullfile(journalPngsDir, [cellNum '_CheckupDischarge.png']));
    saveas(figResistance,      fullfile(journalPngsDir, [cellNum '_Resistance.png']));
    saveas(figCapResTrend,     fullfile(journalPngsDir, [cellNum '_CapacityResistanceTrend.png']));
    saveas(figDVdt,            fullfile(journalPngsDir, [cellNum '_dVdtAnalysis.png']));


    fprintf('\n========================================\n');
    fprintf('All figures saved to: %s\n', journalPngsDir);
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

% The Overview CSVs are written to JournalScripts/pngs/ (R-001: the data tree
% is read-only). The copies shipped inside the dataset
% (4_Ageing/*_ageing_data/Overview*Data_*.csv) are dataset content, consumed
% by the overview plotters; refresh them by DELIBERATELY copying the newly
% generated tables from pngs/ after review.

% Create and save Resistance table
if ~isempty(allResistanceData)
    resistanceTable = cell2table(allResistanceData, 'VariableNames', {'CellNum', 'CellLabel', 'CheckupResistanceTimeStamp', 'CheckupResistance_Ohm', 'CheckupResistanceFEC'});
    writetable(resistanceTable, fullfile(journalPngsDir, ['OverviewResistanceData_' num2str(celNumIndx) 'cell.csv']));
    fprintf('Resistance data saved to: %s\n', fullfile(journalPngsDir, ['OverviewResistanceData_' num2str(celNumIndx) 'cell.csv']));
end


% Create and save Capacity table
if ~isempty(allCapacityData)
    capacityTable = cell2table(allCapacityData, 'VariableNames', {'CellNum', 'CellLabel', 'CheckupCapacityTimeStamp', 'CheckupCapacity_Ah', 'CheckupCapacityFEC'});
    writetable(capacityTable, fullfile(journalPngsDir, ['OverviewCapacityData_' num2str(celNumIndx) 'cell.csv']));
    fprintf('Capacity data saved to: %s\n', fullfile(journalPngsDir, ['OverviewCapacityData_' num2str(celNumIndx) 'cell.csv']));
end



fprintf('\n========================================\n');
fprintf('All tables saved to: %s\n', journalPngsDir);
fprintf('========================================\n');