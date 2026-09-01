%% PlotCharacterizationData_Cell15.m
% Summary: Builds the combined Cell_15 characterisation figure from the Zenodo
%          characterisation CSV files. The figure covers Initialization, GITT,
%          CC cycles, dynamic cycle, and HPPC phases with one subplot per data
%          column.
%
% Usage: Set DataRoot if needed, then run this script with no arguments. The
%        script processes the Cell_15 characterisation folder.
%
% Outputs: characterization_combined.png and characterization_combined.pdf in
%          this script's R-022 output directory.
%
% Authors: Róbinson Medina.
% Dependency files: Functions/getFigureOutputDir.m.
% Last documented: 2026-09-01
%% Instructions
% just update the variable 'dataFolder' with the path to the data and run. 
clear;
close all;
clc;
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

%% Configuration
% DataRoot: single switch to the dataset root holding 1_Teardown/2_HalfCell/
% 3_Characterization/4_Ageing. Change this one line to retarget the script.
DataRoot = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
% Folder containing the characterization data files (per-cell folders live
% directly under 3_Characterization in the reorganised dataset).
dataFolder = fullfile(DataRoot, '3_Characterization');

% Get all subfolders in the directory
fprintf('Scanning main folder: %s\n', dataFolder);
subfolders = dir(dataFolder);
subfolders = subfolders([subfolders.isdir] & ~ismember({subfolders.name}, {'.', '..'}));

if isempty(subfolders)
    error('No subfolders found in the specified directory: %s', dataFolder);
end

fprintf('Found %d subfolder(s) to process\n', length(subfolders));

%% Process Each Subfolder
for folderIdx = 1:1%length(subfolders)
    close all;  % Close all figures before processing a new subfolder
    currentFolder = fullfile(dataFolder, subfolders(folderIdx).name);
    
    fprintf('\n########################################\n');
    fprintf('Processing subfolder %d/%d: %s\n', folderIdx, length(subfolders), subfolders(folderIdx).name);
    fprintf('########################################\n');
    
    % Get all CSV files in the current subfolder
    csvFiles = dir(fullfile(currentFolder, '*.csv'));
    
    if isempty(csvFiles)
        fprintf('No CSV files found in subfolder: %s\n', currentFolder);
        continue;
    end
    
    fprintf('Found %d CSV file(s) in this subfolder\n', length(csvFiles));

    %% Process Each File in Current Subfolder
    for fileIdx = 1:length(csvFiles)
        filename = csvFiles(fileIdx).name;
        filepath = fullfile(currentFolder, filename);
        
        fprintf('\n========================================\n');
        fprintf('Processing file %d/%d: %s\n', fileIdx, length(csvFiles), filename);
        fprintf('========================================\n');
        
        try
            %% Load Data
            fprintf('Loading data from: %s\n', filename);
            
            % Set up import options
            opts = detectImportOptions(filepath);
            opts.VariableTypes{1} = 'string';
            opts.DataLines = [2 Inf];
            opts.VariableNamesLine = 1;
            
            % Read the table
            data = readtable(filepath, opts);
            
            fprintf('Data loaded successfully. Size: %d rows x %d columns\n', ...
                    height(data), width(data));
            
            %% Process Time Column
            % Reconstruct time vector: first value is datetime, subsequent values are delta seconds
            timeCol = data{:, 1};  % First column is time (now always string)
            
            % Reconstruct time vector
            timeYYMMDD = NaT(size(timeCol));
            timeYYMMDD(1) = datetime(timeCol(1), 'Format','dd-MMM-yyyy HH:mm:ss.SSS');
            Increase_s = cumsum(seconds(double(timeCol(2:end))));
            timeYYMMDD(2:end) = Increase_s + timeYYMMDD(1);
            timeData = timeYYMMDD;
            timeLabel = 'Time';

            %% Create Figure with Subplots
            [~, fileBaseName, ~] = fileparts(filename);
            figTitle = sprintf('Characterization Data: %s', fileBaseName);
            
            % Identify columns by type
            colNames = data.Properties.VariableNames(2:end);  % Exclude time column
            currentColIndices = [];
            voltageColIndices = [];
            tempColIndices = [];
            otherColIndices = [];
            
            for colIdx = 2:width(data)
                colName = data.Properties.VariableNames{colIdx};
                colNameLower = lower(colName);
                
                % Categorize columns
                if contains(colNameLower, 'current') || contains(colNameLower, 'curr')
                    currentColIndices = [currentColIndices, colIdx];
                elseif contains(colNameLower, 'voltage') || contains(colNameLower, 'volt')
                    voltageColIndices = [voltageColIndices, colIdx];
                elseif contains(colNameLower, 'temperature') || contains(colNameLower, 'temp')
                    tempColIndices = [tempColIndices, colIdx];
                else
                    otherColIndices = [otherColIndices, colIdx];
                end
            end
            
            % Calculate number of subplots needed (current, voltage, other, temp combined)
            numSubplots = length(currentColIndices) + length(voltageColIndices) + length(otherColIndices);
            if ~isempty(tempColIndices)
                numSubplots = numSubplots + 1;  % One combined subplot for all temperatures
            end
            
            % Single column layout
            numCols = 1;
            numRows = numSubplots;
            
            % Create figure with adjusted height
            figHeight = max(800, 200 * numRows);
            fig = figure('Name', figTitle, 'Position', [100, 100, 800, figHeight]);
            sgtitle(figTitle, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
            
            %% Create Subplots
            subplotIdx = 1;
            
            % 1. Plot current columns first
            for i = 1:length(currentColIndices)
                colIdx = currentColIndices(i);
                
                subplot(numRows, numCols, subplotIdx);
                
                colData = data{:, colIdx};
                colName = data.Properties.VariableNames{colIdx};
                displayName = strrep(colName, '_', ' ');
                % Remove trailing unit words (e.g., 'Current A' -> 'Current')
                displayName = regexprep(displayName, '\s+[Aa]\s*$', '');
                displayName = regexprep(displayName, '\s+[Vv]\s*$', '');
                displayName = strtrim(displayName);
                yLabelStr = [displayName ' [A]'];
                plot(timeData, colData, 'b-', 'LineWidth', 1);
                % Always include start and end date in XTick
                xt = get(gca, 'XTick');
                if isempty(xt)
                    xt = [];
                end
                xt = unique([xt(:); timeData(1); timeData(end)]); % ensure start and end
                if subplotIdx == numRows
                    xlabel(timeLabel);
                    set(gca, 'XTick', xt);
                    % Include year in the bottom subplot's date format
                    datetick('x', 'dd-mmm-yy', 'keepticks');
                elseif subplotIdx == 1 || subplotIdx == 2
                    xlabel('');
                    set(gca, 'XTick', xt, 'XTickLabel', repmat({' '}, size(xt)));
                else
                    xlabel('');
                    set(gca, 'XTick', [], 'XTickLabel', []);
                end
                ylabel(yLabelStr);
                % No subplot title
                grid on;
                if isdatetime(timeData)
                    xtickangle(45);
                end
                axis tight;
                subplotIdx = subplotIdx + 1;
            end
            
            % 2. Plot voltage columns second
            for i = 1:length(voltageColIndices)
                colIdx = voltageColIndices(i);
                
                subplot(numRows, numCols, subplotIdx);
                
                colData = data{:, colIdx};
                colName = data.Properties.VariableNames{colIdx};
                displayName = strrep(colName, '_', ' ');
                % Remove trailing unit words (e.g., 'Voltage V' -> 'Voltage')
                displayName = regexprep(displayName, '\s+[Vv]\s*$', '');
                displayName = regexprep(displayName, '\s+[Aa]\s*$', '');
                displayName = strtrim(displayName);
                yLabelStr = [displayName ' [V]'];
                plot(timeData, colData, 'b-', 'LineWidth', 1);
                % Always include start and end date in XTick
                xt = get(gca, 'XTick');
                if isempty(xt)
                    xt = [];
                end
                xt = unique([xt(:); timeData(1); timeData(end)]); % ensure start and end
                if subplotIdx == numRows
                    xlabel(timeLabel);
                    set(gca, 'XTick', xt);
                    datetick('x', 'dd-mmm-yy', 'keepticks');
                elseif subplotIdx == 1 || subplotIdx == 2
                    xlabel('');
                    set(gca, 'XTick', xt, 'XTickLabel', repmat({' '}, size(xt)));
                else
                    xlabel('');
                    set(gca, 'XTick', [], 'XTickLabel', []);
                end
                ylabel(yLabelStr);
                % No subplot title
                grid on;
                if isdatetime(timeData)
                    xtickangle(45);
                end
                axis tight;
                subplotIdx = subplotIdx + 1;
            end
            
            % 3. Plot other columns
            for i = 1:length(otherColIndices)
                colIdx = otherColIndices(i);
                
                subplot(numRows, numCols, subplotIdx);
                
                colData = data{:, colIdx};
                colName = data.Properties.VariableNames{colIdx};
                displayName = strrep(colName, '_', ' ');
                % Add generic unit for other columns
                yLabelStr = [displayName ' [unit]'];
                plot(timeData, colData, 'b-', 'LineWidth', 1);
                % Always include start and end date in XTick
                xt = get(gca, 'XTick');
                if isempty(xt)
                    xt = [];
                end
                xt = unique([xt(:); timeData(1); timeData(end)]); % ensure start and end
                if subplotIdx == numRows
                    xlabel(timeLabel);
                    set(gca, 'XTick', xt);
                    datetick('x', 'dd-mmm-yy', 'keepticks');
                elseif subplotIdx == 1 || subplotIdx == 2
                    xlabel('');
                    set(gca, 'XTick', xt, 'XTickLabel', repmat({' '}, size(xt)));
                else
                    xlabel('');
                    set(gca, 'XTick', [], 'XTickLabel', []);
                end
                ylabel(yLabelStr);
                % No subplot title
                grid on;
                if isdatetime(timeData)
                    xtickangle(45);
                end
                axis tight;
                subplotIdx = subplotIdx + 1;
            end
            
            % 4. Plot temperature columns together last
            if ~isempty(tempColIndices)
                subplot(numRows, numCols, subplotIdx);
                hold on;
                % Define colors for different temperature traces
                colors = lines(length(tempColIndices));
                legendEntries = {};
                for i = 1:length(tempColIndices)
                    colIdx = tempColIndices(i);
                    colData = data{:, colIdx};
                    colName = data.Properties.VariableNames{colIdx};
                    displayName = strrep(colName, '_', ' ');
                    % Remove anything in square brackets (units) from legend entry
                    legendName = regexprep(displayName, '\\s*\[.*?\]', '');
                    % Custom legend names for temperature columns
                    if contains(legendName, 'CellTemp')
                        legendName = 'Cell Temperature';
                    elseif contains(legendName, 'ChamberTemp')
                        legendName = 'Chamber Temperature';
                    end
                    plot(timeData, colData, '-', 'LineWidth', 1.5, 'Color', colors(i,:));
                    legendEntries{i} = strtrim(legendName);
                end
                hold off;
                % Always include start and end date in XTick
                xt = get(gca, 'XTick');
                if isempty(xt)
                    xt = [];
                end
                xt = unique([xt(:); timeData(1); timeData(end)]); % ensure start and end
                if subplotIdx == numRows
                    xlabel(timeLabel);
                    set(gca, 'XTick', xt);
                    datetick('x', 'dd-mmm-yy', 'keepticks');
                elseif subplotIdx == 1 || subplotIdx == 2
                    xlabel('');
                    set(gca, 'XTick', xt, 'XTickLabel', repmat({' '}, size(xt)));
                else
                    xlabel('');
                    set(gca, 'XTick', [], 'XTickLabel', []);
                end
                ylabel('Temperature [°C]');
                % No subplot title
                legend(legendEntries, 'Location', 'best');
                grid on;
                if isdatetime(timeData)
                    xtickangle(45);
                end
                axis tight;
                subplotIdx = subplotIdx + 1;
            end
            
            %% Save Figure
            % Save in this entry script's R-022 output directory.
            scriptDir_cd = fileparts(mfilename('fullpath'));
            pngsDir_cd = getFigureOutputDir('PlotCharacterizationData_Cell15');
            saveFilename = fullfile(pngsDir_cd, [fileBaseName '_CharacterizationPlot.png']);

            % Save with high resolution, explicitly specifying PNG format
            saveas(fig, saveFilename, 'png');
            fprintf('Figure saved as: %s\n', saveFilename);
            

            
        catch ME
            fprintf('Error processing file %s: %s\n', filename, ME.message);
            continue;  % Skip to next file
        end
    end
end

%% ====================================================================
%% COMBINED CHARACTERIZATION FIGURE (5 Phases in 1 Publication Figure)
%% ====================================================================
% This section combines the 5 characterization phases (Formation, GITT,
% CC cycles, Dynamic cycles, HPPC) into a single publication-quality figure
% with synchronized time axis (in DAYS) and phase boundaries marked.
%
% Author: Robinson Medina
% Date: 2026-05-21

%% Configuration: Phase File Paths and Labels
% Define the 5 characterization phase files in chronological order
% All five phases live in one per-cell folder under dataFolder (DataRoot-derived).
charCell    = 'Cell_6';
charCellDir = fullfile(dataFolder, charCell);
phaseConfigs = struct( ...
    'filepath', { ...
        fullfile(charCellDir, [charCell '_1-Formation.csv']), ...
        fullfile(charCellDir, [charCell '_2-GITT.csv']), ...
        fullfile(charCellDir, [charCell '_3-CC_cycles.csv']), ...
        fullfile(charCellDir, [charCell '_4-DynamicCycles.csv']), ...
        fullfile(charCellDir, [charCell '_5-HPPC.csv']) ...
    }, ...
    'label', { ...
        'Initialization', 'GITT', 'CC cycles', 'Dynamic', 'HPPC' ...
    } ...
);

numPhases = length(phaseConfigs);

%% Load and Concatenate Data from All 5 Phases
fprintf('\n========================================\n');
fprintf('Building combined characterization figure...\n');
fprintf('Loading %d phases...\n', numPhases);
fprintf('========================================\n');

% Initialize concatenated data arrays
timeTotal_s = [];     % Time in seconds (cumulative across all phases)
currentTotal = [];    % Current [A] (concatenated)
voltageTotal = [];    % Voltage [V] (concatenated)
cellTempTotal = [];   % Cell temperature [°C] (concatenated)
chamberTempTotal = []; % Chamber temperature [°C] (concatenated)

% Store phase boundary times (in days) for later annotation
phaseBoundaries_days = [0];
phaseStartEnd_days = zeros(numPhases, 2); % [start_day, end_day] for each phase

% Load and process each phase
for phaseIdx = 1:numPhases
    phaseFile = phaseConfigs(phaseIdx).filepath;
    phaseLabel = phaseConfigs(phaseIdx).label;
    
    fprintf('Loading phase %d/%d (%s): %s\n', phaseIdx, numPhases, phaseLabel, phaseFile);
    
    % Set up import options (same as in main loop)
    opts = detectImportOptions(phaseFile);
    opts.VariableTypes{1} = 'string';
    opts.DataLines = [2 Inf];
    opts.VariableNamesLine = 1;
    
    % Read the table
    dataPhase = readtable(phaseFile, opts);
    
    % Reconstruct time vector (first column contains time data)
    timeCol = dataPhase{:, 1};
    timeYYMMDD = NaT(size(timeCol));
    timeYYMMDD(1) = datetime(timeCol(1), 'Format','dd-MMM-yyyy HH:mm:ss.SSS');
    Increase_s = cumsum(seconds(double(timeCol(2:end))));
    timeYYMMDD(2:end) = Increase_s + timeYYMMDD(1);
    
    % Convert phase time to seconds elapsed from start of phase
    timePhase_s = seconds(timeYYMMDD - timeYYMMDD(1));
    
    % Extract data columns using property names from CSV
    % Handle potential encoding issues with degree symbol
    voltagePhase = dataPhase{:, 2};  % Voltage [V]
    currentPhase = dataPhase{:, 3};  % Current [A]
    
    % Get temperature columns (handle possible encoding variations)
    colNames = dataPhase.Properties.VariableNames;
    cellTempIdx = find(contains(colNames, 'Cell temp', 'IgnoreCase', true), 1);
    chamberTempIdx = find(contains(colNames, 'Chamber temp', 'IgnoreCase', true), 1);
    
    if isempty(cellTempIdx)
        cellTempIdx = 4; % Default fallback
    end
    if isempty(chamberTempIdx)
        chamberTempIdx = 5; % Default fallback
    end
    
    cellTempPhase = dataPhase{:, cellTempIdx};
    chamberTempPhase = dataPhase{:, chamberTempIdx};
    
    % Calculate the time offset for this phase (cumulative end time from previous phases)
    if phaseIdx == 1
        % First phase starts at t=0
        timeOffset_s = 0;
        phaseStart_days = 0;
    else
        % Append NaN row separator between phases
        timeTotal_s = [timeTotal_s; NaN];
        currentTotal = [currentTotal; NaN];
        voltageTotal = [voltageTotal; NaN];
        cellTempTotal = [cellTempTotal; NaN];
        chamberTempTotal = [chamberTempTotal; NaN];
        
        % Offset is the last non-NaN time value
        timeOffset_s = timeTotal_s(end-1);
        phaseStart_days = timeOffset_s / (24*3600);
    end
    phaseStartEnd_days(phaseIdx, 1) = phaseStart_days;
    
    % Concatenate phase data with cumulative time offset
    timeTotal_s = [timeTotal_s; timeOffset_s + timePhase_s];
    currentTotal = [currentTotal; currentPhase];
    voltageTotal = [voltageTotal; voltagePhase];
    cellTempTotal = [cellTempTotal; cellTempPhase];
    chamberTempTotal = [chamberTempTotal; chamberTempPhase];
    
    % Record end time in days for this phase
    phaseEnd_days = timeTotal_s(end) / (24*3600);
    phaseStartEnd_days(phaseIdx, 2) = phaseEnd_days;
    
    % Store phase boundary for vertical line annotation
    if phaseIdx < numPhases
        phaseBoundaries_days = [phaseBoundaries_days; phaseEnd_days];
    end
    
    fprintf('  Phase %d loaded: %.2f to %.2f days\n', phaseIdx, phaseStartEnd_days(phaseIdx,1), phaseStartEnd_days(phaseIdx,2));
end

% Convert final time vector from seconds to days
timeTotal_days = timeTotal_s / (24*3600);

fprintf('Combined data ready. Total duration: %.2f days\n', timeTotal_days(end));

%% Build Combined Figure
% --- Journal publication formatting (rules R-017 through R-022) ---
% R-021 requires the exported PDF to be imported by LaTeX at natural size.
% The caption-size text target is therefore set directly to 8 pt, while the
% authored width/height are scaled together to target 97% of the 522 pt
% double-column text width after exportgraphics applies its tight crop
% Figure width is tuned for the target column span after tight cropping.
PUB_FONTSIZE = 8;
FIG_W_CM = 18.82;
FIG_H_CM = 12.98;
fig = figure('Units','centimeters','Position',[2 2 FIG_W_CM FIG_H_CM]);
% Lock paper position to the figure size in centimeters so exportgraphics does
% not rescale the figure (and therefore the fonts) on export.
set(fig, 'PaperUnits', 'centimeters', 'PaperPositionMode', 'auto');
tl = tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
% Reserve ~10% of the figure height ABOVE the tiled layout so the phase span
% arrows and phase labels we add later (which live above the top subplot in
% data coordinates with Clipping='off') stay inside the figure window and
% are therefore actually rendered/exported. Without this, the labels are
% drawn above y=1 in figure-normalized coordinates and get clipped away.
tl.Units = 'normalized';
tl.OuterPosition = [0 0 1 0.90];

% --- Preferred color palette for publication figures (rule R-017) ---
% These RGB triplets are the project standard for journal-quality plots.
green    = [12  195  82] ./ 255;  %#ok<NASGU> % kept for future use
darkblue = [ 1   17 181] ./ 255;  % primary line color (current, voltage, cell temp)
red      = [255   0   0] ./ 255;  % secondary line color (chamber temp)
magenta  = [255   0 255] ./ 255;  %#ok<NASGU> % kept for future use
black    = [  0   0   0];         % annotations / arrow shafts and heads
% Backwards-compat alias so the rest of the script (which used darkBlue) keeps
% working without further refactoring.
darkBlue  = darkblue;
lightGrey = [0.55 0.55 0.55];

% ---- SUBPLOT 1: Current ----
ax1 = nexttile;
plot(timeTotal_days, currentTotal, '-', 'Color', darkBlue, 'LineWidth', 1.0);
grid on; box on;
% Use 'tex' interpreter (not 'latex') so the FontName setting below is honored
% by every text element. Italic variable names are produced with {\it X}.
ylabel('Current {\it I} [A]', 'Interpreter', 'tex', 'FontSize', PUB_FONTSIZE, 'FontName', 'Times New Roman');
% Put axes ticks/grid/box on top so background patches added later cannot cover them.
% FontName set to 'Times New Roman' to comply with rule R-019 (publication font).
set(ax1, 'FontName', 'Times New Roman', 'FontSize', PUB_FONTSIZE, ...
    'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1, 'LineWidth', 0.8, ...
    'TickLabelInterpreter', 'tex', 'TickDir', 'out', 'Layer', 'top');
% Set symmetric y-limits around zero
absMax = max(abs(currentTotal(~isnan(currentTotal))));
yLim1 = [-absMax*1.1, absMax*1.1];
ylim(yLim1);
xlim([0 timeTotal_days(end)]);
set(ax1, 'XTickLabel', []);

% ---- SUBPLOT 2: Voltage ----
ax2 = nexttile;
plot(timeTotal_days, voltageTotal, '-', 'Color', darkBlue, 'LineWidth', 1.0);
grid on; box on;
% Switched from 'latex' to 'tex' interpreter so FontName 'Times New Roman' is applied (rule R-019).
ylabel('Voltage {\it V} [V]', 'Interpreter', 'tex', 'FontSize', PUB_FONTSIZE, 'FontName', 'Times New Roman');
% Put axes ticks/grid/box on top so background patches added later cannot cover them.
set(ax2, 'FontName', 'Times New Roman', 'FontSize', PUB_FONTSIZE, ...
    'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1, 'LineWidth', 0.8, ...
    'TickLabelInterpreter', 'tex', 'TickDir', 'out', 'Layer', 'top');
% Set y-limits with headroom
vMin = min(voltageTotal, [], 'omitnan'); % base MATLAB (nanmin needs Statistics Toolbox; #072 portability fix)
vMax = max(voltageTotal, [], 'omitnan');
yLim2 = [vMin - 0.1, vMax + 0.1];
ylim(yLim2);
xlim([0 timeTotal_days(end)]);
set(ax2, 'XTickLabel', []);

% ---- SUBPLOT 3: Temperature (Cell + Chamber) ----
ax3 = nexttile;
hold on;
% Chamber first (red, drawn underneath), then Cell (dark blue, on top).
% Kept consistent with the re-plot block below the background patches.
% Initial pass uses the project palette colors (rule R-017).
plot(timeTotal_days, chamberTempTotal, '-', 'Color', red,      'LineWidth', 1.0, 'DisplayName', 'Chamber');
plot(timeTotal_days, cellTempTotal,    '-', 'Color', darkBlue, 'LineWidth', 1.0, 'DisplayName', 'Cell');
hold off;
grid on; box on;
% Switched from 'latex' to 'tex' interpreter so FontName 'Times New Roman' is applied (rule R-019).
ylabel('Temperature {\it T} [°C]', 'Interpreter', 'tex', 'FontSize', PUB_FONTSIZE, 'FontName', 'Times New Roman');
xlabel('Time [d]',          'Interpreter', 'tex', 'FontSize', PUB_FONTSIZE, 'FontName', 'Times New Roman');
% Put axes ticks/grid/box on top so background patches added later cannot cover them.
set(ax3, 'FontName', 'Times New Roman', 'FontSize', PUB_FONTSIZE, ...
    'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1, 'LineWidth', 0.8, ...
    'TickLabelInterpreter', 'tex', 'TickDir', 'out', 'Layer', 'top');
% Set y-limits with headroom
tMin = min([cellTempTotal; chamberTempTotal], [], 'omitnan'); % base MATLAB (#072 portability fix)
tMax = max([cellTempTotal; chamberTempTotal], [], 'omitnan');
yLim3 = [tMin - 1, tMax + 1];
ylim(yLim3);
xlim([0 timeTotal_days(end)]);
% NOTE: legend is intentionally deferred until AFTER the data is re-plotted on top
% of the background patches (see end of next section). Creating it here would
% bind it to line handles that are later overdrawn, which makes MATLAB fall back
% to the generic 'data1','data2' labels in the rendered figure.

% Link x-axes
linkaxes([ax1, ax2, ax3], 'x');

%% Add Phase Boundary Lines and Labels
% Add vertical dashed lines at phase boundaries on all three axes
for boundaryIdx = 1:length(phaseBoundaries_days)-1
    boundaryDay = phaseBoundaries_days(boundaryIdx+1);
    xline(ax1, boundaryDay, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off', 'LineWidth', 0.75);
    xline(ax2, boundaryDay, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off', 'LineWidth', 0.75);
    xline(ax3, boundaryDay, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off', 'LineWidth', 0.75);
end

% Add shaded background regions to delimit phases on all three subplots
shadeColor = [0.95 0.95 0.95];  % Light grey for alternating shading
for phaseIdx = 1:numPhases
    phaseStart = phaseStartEnd_days(phaseIdx, 1);
    phaseEnd = phaseStartEnd_days(phaseIdx, 2);
    
    % Only shade every other phase for visual distinction
    if mod(phaseIdx, 2) == 0
        % Add shaded rectangle for even-indexed phases
        yLim1 = ylim(ax1);
        patch(ax1, [phaseStart, phaseEnd, phaseEnd, phaseStart], [yLim1(1), yLim1(1), yLim1(2), yLim1(2)], ...
            shadeColor, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        
        yLim2 = ylim(ax2);
        patch(ax2, [phaseStart, phaseEnd, phaseEnd, phaseStart], [yLim2(1), yLim2(1), yLim2(2), yLim2(2)], ...
            shadeColor, 'EdgeColor', 'none', 'HandleVisibility', 'off');
        
        yLim3 = ylim(ax3);
        patch(ax3, [phaseStart, phaseEnd, phaseEnd, phaseStart], [yLim3(1), yLim3(1), yLim3(2), yLim3(2)], ...
            shadeColor, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
end

% Re-plot data on top of shading to ensure visibility.
% IMPORTANT 1: enable hold on every axes BEFORE replotting so the patches/xlines
% we just added are preserved (a bare plot() call would otherwise reset the axes
% and wipe them). Hold must also stay on so the arrow shafts and arrowhead
% markers added later do not erase one another.
% IMPORTANT 2: keep handles to the temperature line objects so we can attach a
% legend later with correct DisplayNames (otherwise MATLAB would auto-label them
% 'data1', 'data2' once the originals are overdrawn).
hold(ax1, 'on');
hold(ax2, 'on');
hold(ax3, 'on');
plot(ax1, timeTotal_days, currentTotal, '-', 'Color', darkBlue, 'LineWidth', 1.0, 'HandleVisibility', 'off');
plot(ax2, timeTotal_days, voltageTotal, '-', 'Color', darkBlue, 'LineWidth', 1.0, 'HandleVisibility', 'off');
% Plot CHAMBER first (red) so it sits underneath, then CELL (dark blue) on top.
% Order matters both for visual stacking and for legend entry order.
% Use the project's preferred 'red' from the publication palette (rule R-017)
% instead of the previous custom chamberRed, so the figure is consistent with
% all other publication figures in this repo.
chamberRed = red;
hChamber = plot(ax3, timeTotal_days, chamberTempTotal, '-', 'Color', chamberRed, 'LineWidth', 1.0, 'DisplayName', 'Chamber');
hCell    = plot(ax3, timeTotal_days, cellTempTotal,    '-', 'Color', darkBlue,   'LineWidth', 1.0, 'DisplayName', 'Cell');

% Re-assert grid on every axes: adding patches/replotting can sometimes leave the
% grid hidden depending on render order, so we force it back on after all overlays.
grid(ax1, 'on'); grid(ax2, 'on'); grid(ax3, 'on');


% --- Phase labels and double-headed span arrows above the current subplot ---
% Geometry: arrows sit just above the top subplot, labels sit above the arrows.
% Heights are expressed as fractions of the current subplot's y-range so they
% scale automatically with the data limits.
yLim1        = ylim(ax1);                 % current axis limits after all overlays
yLim1_range  = yLim1(2) - yLim1(1);
yPos_arrow   = yLim1(2) + 0.06 * yLim1_range;  % vertical position of the arrow line
yPos_label   = yLim1(2) + 0.14 * yLim1_range;  % vertical position of the text label
xPadFrac     = 0.01;                            % small inset so arrows don't touch the boundary lines
xRange_total = timeTotal_days(end);
arrowInset   = xPadFrac * xRange_total;

for phaseIdx = 1:numPhases
    % Span of this phase along the time axis (in days)
    phaseStart = phaseStartEnd_days(phaseIdx, 1);
    phaseEnd   = phaseStartEnd_days(phaseIdx, 2);
    phaseMid_days = (phaseStart + phaseEnd) / 2;

    % Insets keep the arrow heads inside the phase span (avoid overlap with xline)
    xL = phaseStart + arrowInset;
    xR = phaseEnd   - arrowInset;
    if xR <= xL
        % Phase too narrow for inset arrow; fall back to the raw span
        xL = phaseStart;
        xR = phaseEnd;
    end

    % Draw the horizontal shaft of the double-headed arrow.
    % Clipping is disabled so the arrow can sit above the axes area.
    % Uses the 'black' color from the publication palette (rule R-017).
    line(ax1, [xL xR], [yPos_arrow yPos_arrow], ...
        'Color', black, 'LineWidth', 0.75, ...
        'Clipping', 'off', 'HandleVisibility', 'off');

    % Left-pointing arrow head at the start of the phase span.
    plot(ax1, xL, yPos_arrow, '<', ...
        'MarkerSize', 5, 'MarkerEdgeColor', black, 'MarkerFaceColor', black, ...
        'Clipping', 'off', 'HandleVisibility', 'off');

    % Right-pointing arrow head at the end of the phase span.
    plot(ax1, xR, yPos_arrow, '>', ...
        'MarkerSize', 5, 'MarkerEdgeColor', black, 'MarkerFaceColor', black, ...
        'Clipping', 'off', 'HandleVisibility', 'off');

    % Phase name centered above the arrow.
    % Use the same caption-size font as the axes so natural-size LaTeX import
    % preserves a consistent 8 pt typography throughout the figure (R-021).
    text(ax1, phaseMid_days, yPos_label, phaseConfigs(phaseIdx).label, ...
        'Units', 'data', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', ...
        'Interpreter', 'tex', ...
        'FontName', 'Times New Roman', ...
        'FontSize', PUB_FONTSIZE, ...
        'Clipping', 'off');
end

% Build the temperature legend NOW that the line handles we want it to track
% are the ones currently on top of the patches. Using explicit handles guarantees
% the legend labels are 'Cell' and 'Chamber' rather than the default fallback.
% Place the legend INSIDE the temperature axes, horizontally, near the top and
% centered around days 30-40 as requested.
lgd = legend(ax3, [hChamber, hCell], {'Chamber', 'Cell'}, ...
    'Location', 'none', 'Orientation', 'horizontal', ...
    'Interpreter', 'tex', 'Box', 'off', 'FontSize', PUB_FONTSIZE, 'FontName', 'Times New Roman');

% Convert desired x-position (days 30-40 midpoint) into AXES-normalized space
% and then map it into FIGURE-normalized space, because legend Position is
% interpreted in figure coordinates.
xLim3 = xlim(ax3);
desiredCenterDay = 35;
xCenterNorm = (desiredCenterDay - xLim3(1)) / (xLim3(2) - xLim3(1));
xCenterNorm = max(0.10, min(0.90, xCenterNorm));

% Axes position in figure-normalized coordinates: [left bottom width height].
ax3PosFig = ax3.Position;

% Legend size as fractions of ax3 size (keeps it proportional to subplot 3).
legendWidthAxFrac  = 0.34;
legendHeightAxFrac = 0.10;

% Horizontal center at requested day location, clamped to stay inside ax3.
legendLeftAx = xCenterNorm - legendWidthAxFrac/2;
legendLeftAx = max(0.02, min(0.98 - legendWidthAxFrac, legendLeftAx));

% Vertical placement near top of ax3, with a small inset from the top edge.
legendBottomAx = 0.98 - legendHeightAxFrac;

% Map from axes fractions to figure-normalized coordinates.
legendLeftFig   = ax3PosFig(1) + legendLeftAx   * ax3PosFig(3);
legendBottomFig = ax3PosFig(2) + legendBottomAx * ax3PosFig(4);
legendWidthFig  = legendWidthAxFrac  * ax3PosFig(3);
legendHeightFig = legendHeightAxFrac * ax3PosFig(4);

lgd.Units = 'normalized';
lgd.Position = [legendLeftFig legendBottomFig legendWidthFig legendHeightFig];

% Force a screen render before exporting so that what we save matches what is
% shown on-screen (otherwise late additions like the arrows/legend can be
% missing from the exported PDF/PNG on some MATLAB releases).
drawnow;

%% Export Figure
fprintf('\nExporting combined characterization figure...\n');
% Save into this entry script's R-022 output directory.
scriptDir = fileparts(mfilename('fullpath'));
saveDir   = getFigureOutputDir('PlotCharacterizationData_Cell15');

% Export as PDF (vector) for publication use.
% Rule R-018: figures flagged for journal publication must be exported as PDF
% into pngs/ while PRESERVING the on-screen font sizes. Using exportgraphics
% with ContentType='vector' (and PaperPositionMode='auto' set above) preserves
% the tuned physical size and 8 pt text for natural-size LaTeX import.
pdfFile = fullfile(saveDir, 'characterization_combined.pdf');
exportgraphics(fig, pdfFile, 'ContentType', 'vector');
fprintf('PDF saved: %s\n', pdfFile);

% Export as MATLAB .fig (editable native format) instead of a rasterised PNG.
figFile = fullfile(saveDir, 'characterization_combined.fig');
savefig(fig, figFile);
fprintf('FIG saved: %s\n', figFile);

fprintf('Combined characterization figure complete!\n');

%% Summary
fprintf('\n########################################\n');
fprintf('Processing complete!\n');
fprintf('Processed %d subfolder(s)\n', length(subfolders));
fprintf('Figures saved to respective subfolders\n');
fprintf('========================================\n');
fprintf('Combined figure exported to:\n');
fprintf('  PDF: %s\n', pdfFile);
fprintf('  FIG: %s\n', figFile);
fprintf('########################################\n');