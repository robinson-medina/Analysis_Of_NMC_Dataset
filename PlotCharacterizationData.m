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
            figTitle = sprintf('Characterization Data: %s - %s', subfolders(folderIdx).name, fileBaseName);
            
            % Number of data columns (excluding time)
            numDataCols = width(data) - 1;
            
            % Calculate subplot layout
            numCols = min(2, numDataCols);  % Maximum 2 columns
            numRows = ceil(numDataCols / numCols);
            
            % Create figure
            fig = figure('Name', figTitle, 'Position', [100, 100, 1200, 800]);
            sgtitle(figTitle, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
            
            %% Create Subplots
            for colIdx = 2:width(data)  % Start from column 2 (skip time column)
                subplotIdx = colIdx - 1;
                
                % Create subplot
                subplot(numRows, numCols, subplotIdx);
                
                % Get column data and name
                colData = data{:, colIdx};
                colName = data.Properties.VariableNames{colIdx};
                
                % Clean column name for display (remove underscores, etc.)
                displayName = strrep(colName, '_', ' ');
                
                % Plot data

                plot(timeData, colData, 'b-', 'LineWidth', 1);


                % Format subplot
                xlabel(timeLabel);
                ylabel(displayName);
                title(displayName, 'FontWeight', 'bold');
                grid on;
                
                % Format x-axis for datetime
                if isdatetime(timeData)
                    % Rotate x-axis labels for better readability
                    xtickangle(45);
                    
                    % Auto-format datetime axis
                end
                
                % Tight layout
                axis tight;
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