function fig = plotNyquistDiagram(data, plotTitle, savePath, maxFreq)
%PLOTNYQUISTDIAGRAM Plot Nyquist diagram from impedance data
%   fig = plotNyquistDiagram(data, plotTitle, savePath, maxFreq) plots a 
%   Nyquist diagram from the provided data table. The function automatically 
%   detects different SoC tests based on column naming convention (_SoC##) 
%   and creates separate legend entries.
%
%   Input:
%       data - Table containing R_real_ohm_SoC##, R_img_ohm_SoC##, and 
%              Freq_Hz_SoC## columns for different SoC values
%       plotTitle - Custom title for the plot
%       savePath - Path to save the figure (empty string to skip saving)
%       maxFreq - Maximum frequency for data inclusion (Hz)
%
%   Output:
%       fig - Figure handle
%
%   Example:
%       fig = plotNyquistDiagram(myData, 'My Nyquist Plot', '', 12000);

    % Set default values if not provided
    if nargin < 2 || isempty(plotTitle)
        plotTitle = 'Nyquist Diagram';
    end
    if nargin < 3
        savePath = '';
    end
    if nargin < 4 || isempty(maxFreq)
        maxFreq = 12000;
    end
    
    % Get column names
    colNames = data.Properties.VariableNames;
    
    % Find unique SoC values by parsing column names
    socValues = {};
    for i = 1:length(colNames)
        if contains(colNames{i}, 'R_real_ohm_SoC')
            % Extract SoC value from column name
            socStr = extractAfter(colNames{i}, 'SoC');
            if ~ismember(socStr, socValues)
                socValues{end+1} = socStr;
            end
        end
    end
    
    if isempty(socValues)
        error('No SoC data found. Expected columns with format R_real_ohm_SoC##');
    end
    
    fprintf('Found %d different SoC test(s): %s\n', length(socValues), strjoin(socValues, ', '));
    
    % Create figure
    fig = figure('Position', [100, 100, 800, 600]);
    hold on;
    grid on;
    
    % Define colors for different SoC values
    colors = lines(length(socValues));
    
    % Plot data for each SoC
    legendEntries = {};
    for i = 1:length(socValues)
        socVal = socValues{i};
        
        % Column names for this SoC
        rRealCol = ['R_real_ohm_SoC' socVal];
        rImgCol = ['R_img_ohm_SoC' socVal];
        freqCol = ['Freq_Hz_SoC' socVal];
        
        % Check if columns exist
        if ~ismember(rRealCol, colNames) || ~ismember(rImgCol, colNames)
            fprintf('Warning: Missing columns for SoC%s, skipping...\n', socVal);
            continue;
        end
        
        % Extract data
        rReal = data.(rRealCol);
        rImg = data.(rImgCol);
        
        % Get frequency data for filtering
        freq = [];
        if ismember(freqCol, colNames)
            freq = data.(freqCol);
        end
        
        % Remove NaN values and apply frequency filter
        if ~isempty(freq)
            validIdx = ~isnan(rReal) & ~isnan(rImg) & ~isnan(freq) & freq <= maxFreq;
        else
            validIdx = ~isnan(rReal) & ~isnan(rImg);
        end
        
        rReal = rReal(validIdx);
        rImg = rImg(validIdx);
        if ~isempty(freq)
            freq = freq(validIdx);
        end
        
        if isempty(rReal)
            fprintf('Warning: No valid data for SoC%s, skipping...\n', socVal);
            continue;
        end
        
        % Plot Nyquist curve
        h = plot(rReal, -rImg, 'o-', 'Color', colors(i,:), 'LineWidth', 1.5, ...
             'MarkerSize', 4, 'MarkerFaceColor', colors(i,:));
        
        % Add custom datatip with impedance labels
        h.DataTipTemplate.DataTipRows(1).Label = 'Real impedance';
        h.DataTipTemplate.DataTipRows(1).Value = rReal;
        h.DataTipTemplate.DataTipRows(2).Label = 'Imaginary impedance';
        h.DataTipTemplate.DataTipRows(2).Value = -rImg;
        % xlim([-0 4.5e-3]);
        % ylim([-4.5e-3 1.5e-3]);
        
        % Add frequency information if available
        if ismember(freqCol, colNames) && ~isempty(freq)
            row = dataTipTextRow('Frequency (Hz)', freq);
            h.DataTipTemplate.DataTipRows(end+1) = row;
        end
        
        % Add to legend
        legendEntries{end+1} = ['SoC ' socVal '%'];
    end
    
    % Format plot
    xlabel('R_{real} (\Omega)', 'FontSize', 12);
    ylabel('-R_{img} (\Omega)', 'FontSize', 12);
    title(plotTitle, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
    
    % Add legend
    if ~isempty(legendEntries)
        legend(legendEntries, 'Location', 'best', 'FontSize', 10);
    end
    
    % Make axes equal for proper Nyquist representation
    axis equal;
    
    % Add grid
    grid on;
    grid minor;
    
    % Improve appearance
    set(gca, 'FontSize', 10);
    box on;
    
    hold off;
    
    % Save figure if requested
    if ~isempty(savePath)
        saveas(fig, savePath, 'png');
        fprintf('Nyquist diagram saved as: %s\n', savePath);
    end
    
    fprintf('Nyquist diagram created successfully with %d SoC test(s)\n', length(legendEntries));
end
