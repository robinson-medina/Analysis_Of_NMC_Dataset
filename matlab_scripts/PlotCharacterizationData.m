%% Characterization Data Visualization Script
% This script plots all the characterization data from CSV files in the specified characterization folder.
% Each file generates one figure with multiple subplots (one per data column).
%
% Author: Robinson Medina 
% Date: January 22, 2026
%
%% Instructions
% just update the variable 'dataFolder' with the path to the data and run. 
clear;
close all;
clc;

%% Configuration
% Folder containing the characterization data files
dataFolder = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot\Characterization_data';

% Get all subfolders in the directory
fprintf('Scanning main folder: %s\n', dataFolder);
subfolders = dir(dataFolder);
subfolders = subfolders([subfolders.isdir] & ~ismember({subfolders.name}, {'.', '..'}));

if isempty(subfolders)
    error('No subfolders found in the specified directory: %s', dataFolder);
end

fprintf('Found %d subfolder(s) to process\n', length(subfolders));

%% Process Each Subfolder
for folderIdx = 1:length(subfolders)
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
            % Create filename for saving (save in the same subfolder)
            saveFilename = fullfile(currentFolder, [fileBaseName '_CharacterizationPlot.png']);
            
            % Save with high resolution, explicitly specifying PNG format
            saveas(fig, saveFilename, 'png');
            fprintf('Figure saved as: %s\n', saveFilename);
            

            
        catch ME
            fprintf('Error processing file %s: %s\n', filename, ME.message);
            continue;  % Skip to next file
        end
    end
end

%% Summary
fprintf('\n########################################\n');
fprintf('Processing complete!\n');
fprintf('Processed %d subfolder(s)\n', length(subfolders));
fprintf('Figures saved to respective subfolders\n');
fprintf('########################################\n');