%% PlotEISData.m
% Summary: Loads impedance CSV files from one ageing EIS stage folder and builds
%          Nyquist diagrams for the available SoC conditions in each file.
%
% Usage: Set DataRoot and eisFolder in the Configuration block, then run this
%        script. External drivers may set eisFolderOverride before calling
%        run(...) to process a selected BoL, MoL, or EoL EIS folder.
%
% Outputs: Stage-qualified Nyquist PNG files in this script's R-022 output
%          directory.
%
% Authors: Róbinson Medina.
% Dependency files: Functions/getFigureOutputDir.m, Functions/plotNyquistDiagram.m.
% Last documented: 2026-09-01

%% Instructions
% update the variable 'eisFolder' with the path to the EIS experiments

% Allow an external driver to preselect the stage folder via
% eisFolderOverride before run(...); the guard survives the clear below
% for batch verification.
if exist('eisFolderOverride', 'var'); keepEisFolderOverride = eisFolderOverride; end
clearvars -except keepEisFolderOverride;
close all;
clc;
% Resolve the current script folder so path setup is independent of cwd.
scriptDir = fileparts(mfilename('fullpath'));
% Build the absolute path to the shared Functions folder from this script location.
functionsDir = fullfile(scriptDir, '..', '..', 'Functions');
if ~exist(functionsDir, 'dir')
    functionsDir = fullfile(scriptDir, '..', 'Functions');
end
if exist(functionsDir, 'dir')
    addpath(functionsDir)
else
    error('Shared Functions folder not found from %s.', scriptDir);
end
%% Configuration
% DataRoot: single switch to the dataset root holding 1_Teardown/2_HalfCell/
% 3_Characterization/4_Ageing. Change this one line to retarget the script.
DataRoot  = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
eisFolder = fullfile(DataRoot, '4_Ageing', 'EIS_data', '3_EOL_EIS');
if exist('keepEisFolderOverride', 'var'); eisFolder = keepEisFolderOverride; end
% Publication figures never write into the read-only ZenodoRoot tree (R-001);
% Nyquist PNGs go to this entry script's R-022 output directory.
pngsDir = getFigureOutputDir('PlotEISData');



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
    % Use the life-stage folder as part of the display title and filename so
    % repeated cell files at BoL, MoL, and EoL cannot overwrite each other.
    [~, stageName] = fileparts(eisFolder);
    figTitle = sprintf('Nyquist Diagram: - %s (%s)', fileBaseName, stageName);

    % Save in the R-022 script-owned directory, never in the read-only EIS data folder.
    saveFilename = fullfile(pngsDir, [stageName '_' fileBaseName '_NyquistPlot.png']);

    % Call the plotNyquistDiagram function
    fig = plotNyquistDiagram(data, figTitle, saveFilename, 12000);

    fprintf('Nyquist diagram generated and saved\n');


end
% end

%% Summary
fprintf('\n########################################\n');
fprintf('Nyquist analysis complete!\n');
fprintf('Processed subfolders with EIS data\n');
fprintf('Nyquist diagrams saved to: %s\n', pngsDir);
fprintf('########################################\n');
