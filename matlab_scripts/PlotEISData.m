%% Nyquist Analysis Script
% Summary: Loads impedance data from the CSV files in an EIS folder and
% generates Nyquist diagrams for the different State of Charge (SoC) conditions
% contained in each '*_impedanceData.csv'.
%
% Usage:   Update the variable 'eisFolder' with the path to the EIS experiments
%          and run the script (no arguments).
%
% Produces: Nyquist diagram figures; any saved image/vector outputs are written
%           to ../pngs (R-022).
%
% Author: Robinson Medina
% Date: 2026-01-22   (created)
% Last documented: 2026-08-04

%% Instructions
% update the variable 'eisFolder' with the path to the EIS experiments

clear;
close all;
clc;
% Resolve the current script folder so path setup is independent of cwd.
scriptDir = fileparts(mfilename('fullpath'));
% Build the absolute path to the shared Functions folder from this script location.
functionsDir = fullfile(scriptDir, '..', '..', 'Functions');
% Add Functions only when the folder exists to avoid path warnings.
if exist(functionsDir, 'dir')
    addpath(functionsDir)
end
%% Configuration
% DataRoot: single switch to the dataset root holding 1_Teardown/2_HalfCell/
% 3_Characterization/4_Ageing. Change this one line to retarget the script.
DataRoot  = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
eisFolder = fullfile(DataRoot, '4_Ageing', 'EIS_data', '3_EOL_EIS');



%% Process Each Subfolder That Contains EIS Data
% for folderIdx = 1:length(subfolders)
close all


fprintf('\n########################################\n');
fprintf('Checking folder  %s\n', eisFolder);

% Check if EIS folder exists
if ~exist(eisFolder, 'dir')
    fprintf('No EIS folder found in %s, skipping...\n', subfolders(folderIdx).name);
    %         continue;
end

fprintf('EIS folder found! Processing: %s\n', eisFolder);
fprintf('########################################\n');

% Get all impedance CSV files directly from the EIS folder
csvFiles = dir(fullfile(eisFolder, '*_impedanceData.csv'));

if isempty(csvFiles)
    fprintf('No impedance data files found (*_impedanceData.csv) in EIS folder: %s\n', eisFolder);
    %         continue;
end

fprintf('Found %d impedance data file(s) to process\n', length(csvFiles));

%% Process Each Impedance Data File in EIS Folder
for fileIdx = 1:length(csvFiles)
    filename = csvFiles(fileIdx).name;
    filepath = fullfile(eisFolder, filename);

    fprintf('\n========================================\n');
    fprintf('Processing file %d/%d: %s\n', fileIdx, length(csvFiles), filename);
    fprintf('========================================\n');

    %         try
    %% Load Data
    fprintf('Loading impedance data from: %s\n', filename);

    % Set up import options for impedance data
    opts = detectImportOptions(filepath);
    opts.DataLines = [2 Inf];  % Skip header row
    opts.VariableNamesLine = 1;

    % Read the table
    data = readtable(filepath, opts);

    fprintf('Data loaded successfully. Size: %d rows x %d columns\n', ...
        height(data), width(data));

    %% Check if this file contains impedance data
    colNames = data.Properties.VariableNames;
    hasImpedanceData = any(contains(colNames, 'R_real_ohm_SoC'));

    if ~hasImpedanceData
        fprintf('File does not contain expected impedance data (R_real_ohm_SoC columns), skipping...\n');
        continue;
    end

    %% Generate Nyquist Diagram
    [~, fileBaseName, ~] = fileparts(filename);
    figTitle = sprintf('Nyquist Diagram: - %s', fileBaseName);

    % Create save path for the Nyquist diagram (save in EIS folder)
    saveFilename = fullfile(eisFolder, [fileBaseName '_NyquistPlot.png']);

    % Call the plotNyquistDiagram function
    fig = plotNyquistDiagram(data, figTitle, saveFilename, 12000);

    fprintf('Nyquist diagram generated and saved\n');


end
% end

%% Summary
fprintf('\n########################################\n');
fprintf('Nyquist analysis complete!\n');
fprintf('Processed subfolders with EIS data\n');
fprintf('Nyquist diagrams saved to respective EIS folders\n');
fprintf('########################################\n');
