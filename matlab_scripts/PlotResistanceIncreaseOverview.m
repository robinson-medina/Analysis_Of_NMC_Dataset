%% Resistance Increase Overview - NEXTBMS Plotting Data
% =========================================================================
% Summary: Generates publication-quality plots showing battery resistance
%          increase over time under various test conditions (DoD,
%          temperature, C-rate, SoC, voltage limits).
%
% Usage:   Set 'io_folder_cyclic' / 'io_folder_calendar' to the ageing data
%          folders (they must contain the Overview*Data resistance CSVs exported
%          by ExtractAgeingData.m) and run the script (no arguments).
%
% Produces: PNG + vector PDF figures in ../pngs (R-022).
%
% Author: Tim Meulenbreuks, Róbinson Medina, NEXTBMS Team
% Date: 2026-03-05   (created)
% Last documented: 2026-08-04
%
% Data Source:
%   - Cyclic:   OverviewResistanceData_36cell.csv
%   - Calendar: AllCells_ResistanceData.csv
%   - Columns:  CellNum, CellLabel, CheckupResistanceTimeStamp,
%               CheckupResistance_Ohm, CheckupResistanceFEC
%
% Outputs: PNG figures at 300 DPI
% =========================================================================

clear; close all; clc;

%% Set input/output folder
io_folder_cyclic = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot\Cyclic_ageing_data';
io_folder_calendar = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot\Calendar_ageing_data';
% Temporary export location for manuscript figure assets.
io_folder_figures = 'C:\Repositories\DataPaper\Figures\Ageing';
if ~exist(io_folder_figures, 'dir'); mkdir(io_folder_figures); end
% Primary publication output location (R-022).
scriptDir = fileparts(mfilename('fullpath'));
pngsDir = fullfile(scriptDir, '..', 'pngs');
if ~exist(pngsDir, 'dir'); mkdir(pngsDir); end

input_csv_cyclic = fullfile(io_folder_cyclic, 'OverviewResistanceData_36cell.csv');
input_csv_calendar = fullfile(io_folder_calendar, 'OverviewResistanceData_5cell.csv');

%% Load and preprocess CYCLIC ageing data
combined_df_cyclic = readtable(input_csv_cyclic, 'VariableNamingRule', 'preserve');
combined_df_cyclic = renameColumnIfExists(combined_df_cyclic, 'CellNum', 'cell_number');
combined_df_cyclic = renameColumnIfExists(combined_df_cyclic, 'CheckupResistanceTimeStamp', 'Timestamp');
combined_df_cyclic = renameColumnIfExists(combined_df_cyclic, 'CheckupResistance_Ohm', 'Resistance [Ohm]');

combined_df_cyclic.("cell_number") = regexp(string(combined_df_cyclic.("cell_number")), 'Cell_\d+', 'match', 'once');
cell_list = unique(combined_df_cyclic.("cell_number"));
combined_df_cyclic.("Timestamp") = datetime(combined_df_cyclic.("Timestamp"), 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');

%% Load and preprocess CALENDAR ageing data
combined_df_calendar = readtable(input_csv_calendar, 'VariableNamingRule', 'preserve');
combined_df_calendar = renameColumnIfExists(combined_df_calendar, 'CellNum', 'cell_number');
combined_df_calendar = renameColumnIfExists(combined_df_calendar, 'CheckupResistanceTimeStamp', 'Timestamp');
combined_df_calendar = renameColumnIfExists(combined_df_calendar, 'CheckupResistance_Ohm', 'Resistance [Ohm]');

combined_df_calendar.("cell_number") = regexp(string(combined_df_calendar.("cell_number")), 'Cell_\d+', 'match', 'once');
cell_list_calendar = unique(combined_df_calendar.("cell_number"));
combined_df_calendar.("Timestamp") = datetime(combined_df_calendar.("Timestamp"), 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');

%% Plot 1: All cells overview
figure('Position', [100, 100, 1000, 900]);

% --- Subplot 1: Time vs Resistance ---
subplot(2,1,1);
hold on;
for i = 1:length(cell_list)
    cell_name = cell_list{i};
    mask = strcmp(combined_df_cyclic.("cell_number"), cell_name);
    current_cell = combined_df_cyclic(mask, :);
    if isempty(current_cell)
        continue;
    end
    time_days = days(current_cell.("Timestamp") - current_cell.("Timestamp")(1));
    plot(time_days, current_cell.("Resistance [Ohm]"), 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2]);
end
grid on;
set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.6);
xlabel('Time [days]', 'FontSize', 18);
ylabel('Checkup Resistance [\Omega]', 'FontSize', 18);
title('All Cells Overview (Resistance vs Time)', 'FontSize', 20);
set(gca, 'FontSize', 14);
hold off;

% --- Subplot 2: FEC vs Resistance ---
subplot(2,1,2);
hold on;
maxFEC = 0;
for i = 1:length(cell_list)
    cell_name = cell_list{i};
    mask = strcmp(combined_df_cyclic.("cell_number"), cell_name);
    current_cell = combined_df_cyclic(mask, :);
    if isempty(current_cell)
        continue;
    end
    plot(current_cell.CheckupResistanceFEC, current_cell.("Resistance [Ohm]"), 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2], 'HandleVisibility', 'off');
    if ~isempty(current_cell.CheckupResistanceFEC)
        maxFEC = max([maxFEC; max(current_cell.CheckupResistanceFEC)]);
    end
end
grid on;
set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.6);
xlabel('Full Equivalent Cycles (FEC)', 'FontSize', 18);
ylabel('Checkup Resistance [\Omega]', 'FontSize', 18);
title('All Cells Overview (Resistance vs FEC)', 'FontSize', 20);
set(gca, 'FontSize', 14);
xlim([0, maxFEC]);
hold off;

output_file = fullfile(io_folder_cyclic, 'CheckupResistanceVsTime_AllCells_.png');
exportgraphics(gcf, output_file, 'Resolution', 300);

%% Plot 2: Effect of Depth of Discharge (DoD)
cell_plot_list = {"Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_27", "Cell_30", "Cell_16"};
label_list = {"Cell_12 - 100% DoD", "Cell_56 - 100% DoD", "Cell_89 - 100% DoD", "Cell_93 - 100% DoD", "Cell_27 - 70% DoD", "Cell_30 - 40% DoD", "Cell_16 - 10% DoD"};
colormap_list = {'b', 'r', 'g', [1 0.5 0], [0.5 0 0.5], [0.6 0.3 0], [1 0.75 0.8]};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'CheckupResistanceVsTime_VsDoD_.png');
plotResistanceIncrease(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, output_file, 'Effect of Depth of Discharge (DoD)');

%% Plot 3: Effect of Temperature
cell_plot_list = {"Cell_60", "Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_29"};
label_list = {"Cell_60 - 0°C", "Cell_12 - 25°C", "Cell_56 - 25°C", "Cell_89 - 25°C", "Cell_93 - 25°C", "Cell_29 - 45°C"};
colormap_list = {'b', [1 0.5 0], [1 0.5 0], [1 0.5 0], [1 0.5 0], 'r'};
LineStyleList = {'-','--',':','-.','-','-'};
output_file = fullfile(io_folder_cyclic, 'CheckupResistanceVsTime_VsTemperature_.png');
plotResistanceIncrease(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, LineStyleList, output_file, 'Effect of Temperature');

%% Plot 4: Effect of C-rate at 0°C
cell_plot_list = {"Cell_63", "Cell_60", "Cell_66", "Cell_68"};
label_list = {"Cell_63 - C/4 - C/2 - 0°C", "Cell_60 - C/2 - C/2 - 0°C", "Cell_66 - 3C/4 - C/2 - 0°C", "Cell_68 - 1C - C/2 - 0°C"};
colormap_list = {'b', 'r', 'g', [1 0.5 0]};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'CheckupResistanceVsTime_VsCrate0DegC_.png');
plotResistanceIncrease(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, output_file, 'Effect of C-rate at 0°C');

%% Plot 5: Effect of C-rate at 25°C
cell_plot_list = {"Cell_12", "Cell_23", "Cell_34", "Cell_35"};
label_list = {"Cell_12 - C/2 - C/2", "Cell_23 - 1C - C/2", "Cell_34 - 3C/2 - C/2", "Cell_35 - 2C - C/2"};
% Use the project publication palette (R-017) for the highlighted cyclic cells.
colormap_list = {[12 195 82]./255, [1 17 181]./255, [255 0 0]./255, [255 0 255]./255};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(pngsDir, 'CheckupResistanceVsTime_VsCrate25DegC_.png');
output_file_pdf = fullfile(pngsDir, 'CheckupResistanceVsTime_VsCrate25DegC_.pdf');
% Plot 5: C-rate at 25°C with resistance in milliohms
resistanceScale_plot5 = 1000; % convert Ohm to mOhm
resistanceLabel_plot5 = 'Checkup Resistance [m\Omega]';
plotResistanceIncreasePublicationFECOnly(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, output_file_pdf, '', 'northwest', resistanceScale_plot5, resistanceLabel_plot5);

%% Plot 6: Effect of C-rate at 45°C
cell_plot_list = {"Cell_29", "Cell_8", "Cell_9", "Cell_47"};
label_list = {"Cell_29 - C/2 - C/2 - 45°C", "Cell_8 - C/2 - 1C - 45°C", "Cell_9 - 1C - C/2 - 45°C", "Cell_47 - 1C - 1C - 45°C"};
colormap_list = {'b', 'r', 'g', [1 0.5 0]};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'CheckupResistanceVsTime_VsCrate45DegC_.png');
plotResistanceIncrease(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, output_file, 'Effect of C-rate at 45°C');

%% Plot 7: Effect of Average SoC
cell_plot_list = {"Cell_40", "Cell_1", "Cell_3"};
label_list = {"Cell_40 - 75% avg SoC - 50% DoD", "Cell_1 - 50% avg SoC - 50% DoD", "Cell_3 - 25% avg SoC - 50% DoD"};
colormap_list = {'b', 'r', 'g'};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'CheckupResistanceVsTime_AvgSoC_.png');
plotResistanceIncrease(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, output_file, 'Effect of Average SoC');

%% Plot 8: Effect of High Voltage
cell_plot_list = {"Cell_9", "Cell_5", "Cell_22"};
label_list = {"Cell_9 - 2.75V-4.35V - CC - CC", "Cell_5 - 2.75V-4.45V - CC - CC", "Cell_22 - 2.75V-4.45V - CCCV - CC"};
colormap_list = {'b', 'r', 'g'};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'CheckupResistanceVsTime_HighVEffect_.png');
plotResistanceIncrease(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, output_file, 'Effect of High Voltage');

%% Plot 10: Stationary storage cycle
cell_plot_list = {"Cell_74", "Cell_46", "Cell_17", "Cell_53"};
label_list = {"Cell_74 - 0 degrees", "Cell_46 - 25 degrees", "Cell_17 - 45 degrees", "Cell_53 - dynamic temperatures"};
colormap_list = {'b', 'r', 'g', [0.5 0.5 0.5]};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'CheckupResistanceVsTime_StationaryStorage_.png');
plotResistanceIncrease(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, output_file, 'Stationary storage cycle');

%% Plot 11: Drive cycle
cell_plot_list = {"Cell_72", "Cell_42", "Cell_25", "Cell_49"};
label_list = {"Cell_72 - 0 degrees", "Cell_42 - 25 degrees", "Cell_14 - 45 degrees", "Cell_49 - dynamic temperatures"};
colormap_list = {'b', 'r', 'g', [0.5 0.5 0.5]};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'CheckupResistanceVsTime_DriveCycle_.png');
plotResistanceIncrease(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, output_file, 'Drive cycle');

%% Plot 9: Calendar Ageing Effect (highlighted cells)
% Keep the same 5 highlighted calendar cells as the paired capacity figure
% so subplot (a) and (b) are directly comparable and no un-labeled gray line remains.
cell_plot_list_calendar = {"Cell_57", "Cell_11", "Cell_45", "Cell_26", "Cell_28"};
avg_soc_calendar_cells = [1, 1, 0.1, 0.5, 1];
label_list_calendar = { ...
    sprintf("Cell_57 | 0°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(1)*100), ...
    sprintf("Cell_11 | 25°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(2)*100), ...
    sprintf("Cell_45 | 45°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(3)*100), ...
    sprintf("Cell_26 | 45°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(4)*100), ...
    sprintf("Cell_28 | 45°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(5)*100) ...
};

% Use the project publication palette (R-017) for calendar figure highlights.
green_pub = [12 195 82] ./ 255;
darkblue_pub = [1 17 181] ./ 255;
red_pub = [255 0 0] ./ 255;
magenta_pub = [255 0 255] ./ 255;
black_pub = [0 0 0];
colormap_list_calendar = {green_pub, darkblue_pub, red_pub, magenta_pub, black_pub};
Marker_list_calendar = repmat({'-'}, 1, length(cell_plot_list_calendar));
output_file_calendar = fullfile(pngsDir, 'CheckupResistanceVsTime_CalendarAgeingEffect_.png');
output_file_calendar_pdf = fullfile(pngsDir, 'CheckupResistanceVsTime_CalendarAgeingEffect_.pdf');
calendar_label = '';
resistanceScale = 1000; % convert Ohm to mOhm for publication display
resistanceLabel = 'Checkup Resistance [m\Omega]';
calendarYLim = [1.5 6]*1e-3*resistanceScale; % requested base range, adapted to displayed units
calendarXLim = [0, 400]; % consistent x-range for publication figures
calendarPlainTitle = true; % remove '(vs Time)' from this publication figure title
plotResistanceIncreasePublication(combined_df_calendar, cell_list_calendar, cell_plot_list_calendar, label_list_calendar, colormap_list_calendar, Marker_list_calendar, ...
    output_file_calendar, output_file_calendar_pdf, calendar_label, false, 'northwest', resistanceScale, resistanceLabel, calendarYLim, calendarPlainTitle, calendarXLim);

disp('All resistance plots generated successfully!');

%% Helper functions
function combined_df = renameColumnIfExists(combined_df, old_name, new_name)
    if any(strcmp(combined_df.Properties.VariableNames, old_name))
        combined_df.Properties.VariableNames{old_name} = new_name;
    end
end

function plotResistanceIncrease(combined_df, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, filename, plot_title)
    figure('Position', [100, 100, 1000, 900]);

    % --- Subplot 1: Time vs Resistance ---
    subplot(2,1,1);
    hold on;
    for i = 1:length(cell_list)
        cell_name = cell_list{i};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        time_days = days(current_cell.("Timestamp") - current_cell.("Timestamp")(1));
        plot(time_days, current_cell.("Resistance [Ohm]"), 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2], 'HandleVisibility', 'off');
    end

    legend_handles = [];
    legend_labels = {};
    for idx = 1:length(cell_plot_list)
        cell_name = cell_plot_list{idx};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            warning('Cell %s not found in data', cell_name);
            continue;
        end
        time_days = days(current_cell.("Timestamp") - current_cell.("Timestamp")(1));
        h = plot(time_days, current_cell.("Resistance [Ohm]"), '-o', 'LineWidth', 2, 'Color', colormap_list{idx}, ...
            'MarkerFaceColor', colormap_list{idx}, 'MarkerSize', 4, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h];
        legend_labels{end+1} = label_list{idx};
    end

    grid on;
    set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.6);
    xlabel('Time [days]', 'FontSize', 11);
    ylabel('Checkup Resistance [\Omega]', 'FontSize', 11);
    if ~isempty(plot_title)
        title([plot_title ' (vs Time)'], 'FontSize', 11);
    end
    if ~isempty(legend_handles)
        legend(legend_handles, legend_labels, 'FontSize', 11, 'Location', 'best', 'Interpreter', 'none');
    end
    hold off;

    % --- Subplot 2: FEC vs Resistance ---
    subplot(2,1,2);
    hold on;
    maxFEC_highlight = 0;

    for i = 1:length(cell_list)
        cell_name = cell_list{i};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        plot(current_cell.CheckupResistanceFEC, current_cell.("Resistance [Ohm]"), 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2], 'HandleVisibility', 'off');
    end

    legend_handles = [];
    legend_labels = {};
    for idx = 1:length(cell_plot_list)
        cell_name = cell_plot_list{idx};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        h = plot(current_cell.CheckupResistanceFEC, current_cell.("Resistance [Ohm]"), '-o', 'LineWidth', 2, 'Color', colormap_list{idx}, ...
            'MarkerFaceColor', colormap_list{idx}, 'MarkerSize', 4, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h];
        legend_labels{end+1} = label_list{idx};
        if ~isempty(current_cell.CheckupResistanceFEC)
            maxFEC_highlight = max([maxFEC_highlight; max(current_cell.CheckupResistanceFEC)]);
        end
    end

    grid on;
    set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.6);
    xlabel('Full Equivalent Cycles (FEC)', 'FontSize', 11);
    ylabel('Checkup Resistance [\Omega]', 'FontSize', 11);
    if ~isempty(plot_title)
        title([plot_title ' (vs FEC)'], 'FontSize', 11);
    end
    if maxFEC_highlight > 0
        xlim([0, maxFEC_highlight]);
    end
    if ~isempty(legend_handles)
        legend(legend_handles, legend_labels, 'FontSize', 11, 'Location', 'best', 'Interpreter', 'none');
    end
    hold off;

    exportgraphics(gcf, filename, 'Resolution', 300);
end

function plotResistanceIncreasePublication(combined_df, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, pngFilename, pdfFilename, plot_title, includeFEC, legendLocation, resistanceScale, resistanceLabel, yLimits, usePlainTopTitle, xLimits)
    % PLOTRESISTANCEINCREASEPUBLICATION Creates publication-ready resistance plots.

    if nargin < 11 || isempty(legendLocation)
        legendLocation = 'southwest';
    end
    if nargin < 12 || isempty(resistanceScale)
        resistanceScale = 1;
    end
    if nargin < 13 || isempty(resistanceLabel)
        resistanceLabel = 'Checkup Resistance [\Omega]';
    end
    if nargin < 14
        yLimits = [];
    end
    if nargin < 15 || isempty(usePlainTopTitle)
        usePlainTopTitle = false;
    end
    % Set default x-limits if not provided
    if nargin < 16 || isempty(xLimits)
        xLimits = [];
    end

    nHighlight = min([numel(cell_plot_list), numel(label_list), numel(colormap_list), numel(Marker_list)]);
    if nHighlight < numel(cell_plot_list)
        warning('Publication plot: list lengths differ, using first %d highlighted cells.', nHighlight);
    end

    % Match the GITT/OCP publication figure: axis labels and tick labels at 8 pt.
    % The legend renders visually larger than the axes text in tiledlayout figures,
    % so it is set to 6 pt to match the 8 pt axis text (balanced like the GITT figure).
    pubFontSize = 8;
    pubLegendFontSize = 6;
    if includeFEC
        figHeight = 8.8;
    else
        figHeight = 5.0;
    end
    figPub = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2, 2, 7.90, figHeight]);
    figPub.PaperPositionMode = 'auto';

    if includeFEC
        t = tiledlayout(figPub, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    else
        t = tiledlayout(figPub, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    end

    axTop = nexttile(t);
    hold(axTop, 'on');
    for i = 1:length(cell_list)
        cell_name = cell_list{i};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        time_days = days(current_cell.("Timestamp") - current_cell.("Timestamp")(1));
        plot(axTop, time_days, current_cell.("Resistance [Ohm]") * resistanceScale, 'LineWidth', 1.0, 'Color', [0.75 0.75 0.75], 'HandleVisibility', 'off');
    end

    legend_handles = [];
    legend_labels = {};
    for idx = 1:nHighlight
        cell_name = cell_plot_list{idx};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        time_days = days(current_cell.("Timestamp") - current_cell.("Timestamp")(1));
        h = plot(axTop, time_days, current_cell.("Resistance [Ohm]") * resistanceScale, 'LineWidth', 1.2, 'Color', colormap_list{idx}, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h]; %#ok<AGROW>
        legend_labels{end+1} = label_list{idx}; %#ok<AGROW>
    end

    grid(axTop, 'on'); box(axTop, 'on');
    if ~isempty(xLimits)
        xlim(axTop, xLimits);
        xticks(axTop, unique(sort([xticks(axTop), xLimits(1), xLimits(2)])));
    end
    if ~isempty(plot_title)
        if usePlainTopTitle
            title(axTop, plot_title, 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
        else
            title(axTop, [plot_title ' (vs Time)'], 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
        end
    end
    xlabel(axTop, 'Time [days]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    ylabel(axTop, resistanceLabel, 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    if ~isempty(yLimits)
        ylim(axTop, yLimits);
        yticks(axTop, unique(sort([yticks(axTop), yLimits(1), yLimits(2)])));
        % Ensure clean formatting for publication-quality appearance
        set(axTop, 'YMinorTick', 'off');
    end
    set(axTop, 'FontName', 'Times New Roman', 'FontSize', pubFontSize, 'LineWidth', 0.8);
    axTop.LabelFontSizeMultiplier = 1.0;
    axTop.TitleFontSizeMultiplier = 1.0;
    if ~isempty(legend_handles)
        legend(axTop, legend_handles, legend_labels, 'Interpreter', 'none', 'Location', legendLocation, 'Box', 'off', ...
            'FontName', 'Times New Roman', 'FontSize', pubLegendFontSize);
    end

    if includeFEC
        axBottom = nexttile(t);
        hold(axBottom, 'on');

        maxFEC = 0;
        for i = 1:length(cell_list)
            cell_name = cell_list{i};
            mask = strcmp(combined_df.("cell_number"), cell_name);
            current_cell = combined_df(mask, :);
            if isempty(current_cell)
                continue;
            end
            plot(axBottom, current_cell.CheckupResistanceFEC, current_cell.("Resistance [Ohm]") * resistanceScale, 'LineWidth', 1.0, 'Color', [0.75 0.75 0.75], 'HandleVisibility', 'off');
            if ~isempty(current_cell.CheckupResistanceFEC)
                maxFEC = max(maxFEC, max(current_cell.CheckupResistanceFEC));
            end
        end

        legend_handles = [];
        legend_labels = {};
        maxFEC_highlight = 0;
        for idx = 1:nHighlight
            cell_name = cell_plot_list{idx};
            mask = strcmp(combined_df.("cell_number"), cell_name);
            current_cell = combined_df(mask, :);
            if isempty(current_cell)
                continue;
            end
            h = plot(axBottom, current_cell.CheckupResistanceFEC, current_cell.("Resistance [Ohm]") * resistanceScale, 'LineWidth', 1.2, 'Color', colormap_list{idx}, 'LineStyle', Marker_list{idx});
            legend_handles = [legend_handles, h]; %#ok<AGROW>
            legend_labels{end+1} = label_list{idx}; %#ok<AGROW>
            if ~isempty(current_cell.CheckupResistanceFEC)
                maxFEC_highlight = max(maxFEC_highlight, max(current_cell.CheckupResistanceFEC));
            end
        end

        if maxFEC_highlight <= 0
            maxFEC_highlight = maxFEC;
        end

        grid(axBottom, 'on'); box(axBottom, 'on');
        if maxFEC_highlight > 0
            xlim(axBottom, [0, maxFEC_highlight]);
        end
        if ~isempty(plot_title)
            title(axBottom, [plot_title ' (vs FEC)'], 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
        end
        xlabel(axBottom, 'Full Equivalent Cycles [cycles]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
        ylabel(axBottom, resistanceLabel, 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
        if ~isempty(yLimits)
            ylim(axBottom, yLimits);
            yticks(axBottom, unique(sort([yticks(axBottom), yLimits(1), yLimits(2)])));
        end
        set(axBottom, 'FontName', 'Times New Roman', 'FontSize', pubFontSize, 'LineWidth', 0.8);
        axBottom.LabelFontSizeMultiplier = 1.0;
        axBottom.TitleFontSizeMultiplier = 1.0;
        if ~isempty(legend_handles)
            legend(axBottom, legend_handles, legend_labels, 'Interpreter', 'none', 'Location', legendLocation, 'Box', 'off', ...
                'FontName', 'Times New Roman', 'FontSize', pubLegendFontSize);
        end
    end

    exportgraphics(figPub, pngFilename, 'Resolution', 300);
    exportgraphics(figPub, pdfFilename, 'ContentType', 'vector');
    fprintf('Publication PDF saved: %s\n', pdfFilename);

    % [pdfFolder, pdfBase, ~] = fileparts(pdfFilename);
    % figFilename = fullfile(pdfFolder, [pdfBase, '.fig']);
    % savefig(figPub, figFilename);
    % fprintf('Publication FIG saved: %s\n', figFilename);
end

function plotResistanceIncreasePublicationFECOnly(combined_df, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, pngFilename, pdfFilename, plot_title, legendLocation, resistanceScale, resistanceLabel)
    % PLOTRESISTANCEINCREASEPUBLICATIONFECONLY Creates a publication figure with only the FEC subplot.

    if nargin < 10 || isempty(legendLocation)
        legendLocation = 'southwest';
    end
    % Set default resistance scaling (no scaling) if not provided
    if nargin < 11 || isempty(resistanceScale)
        resistanceScale = 1;
    end
    if nargin < 12 || isempty(resistanceLabel)
        resistanceLabel = 'Checkup Resistance [\Omega]';
    end

    nHighlight = min([numel(cell_plot_list), numel(label_list), numel(colormap_list), numel(Marker_list)]);
    if nHighlight < numel(cell_plot_list)
        warning('Publication plot (FEC only): list lengths differ, using first %d highlighted cells.', nHighlight);
    end

    % Legend renders visually larger than the axes text in tiledlayout figures,
    % so it is set to 6 pt to match the 8 pt axis text (balanced like the GITT figure).
    pubFontSize = 8;
    pubLegendFontSize = 6;
    figPub = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2, 2, 8.10, 5.0]);
    figPub.PaperPositionMode = 'auto';
    t = tiledlayout(figPub, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    axBottom = nexttile(t);
    hold(axBottom, 'on');

    maxFEC = 0;
    for i = 1:length(cell_list)
        cell_name = cell_list{i};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        plot(axBottom, current_cell.CheckupResistanceFEC, current_cell.("Resistance [Ohm]") * resistanceScale, 'LineWidth', 1.0, 'Color', [0.75 0.75 0.75], 'HandleVisibility', 'off');
        if ~isempty(current_cell.CheckupResistanceFEC)
            maxFEC = max(maxFEC, max(current_cell.CheckupResistanceFEC));
        end
    end

    legend_handles = [];
    legend_labels = {};
    maxFEC_highlight = 0;
    for idx = 1:nHighlight
        cell_name = cell_plot_list{idx};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        h = plot(axBottom, current_cell.CheckupResistanceFEC, current_cell.("Resistance [Ohm]") * resistanceScale, 'LineWidth', 1.2, 'Color', colormap_list{idx}, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h]; %#ok<AGROW>
        legend_labels{end+1} = label_list{idx}; %#ok<AGROW>
        if ~isempty(current_cell.CheckupResistanceFEC)
            maxFEC_highlight = max(maxFEC_highlight, max(current_cell.CheckupResistanceFEC));
        end
    end

    if maxFEC_highlight <= 0
        maxFEC_highlight = maxFEC;
    end

    grid(axBottom, 'on'); box(axBottom, 'on');
    if maxFEC_highlight > 0
        xlim(axBottom, [0, maxFEC_highlight]);
    end
    % Ensure clean axis formatting
    set(axBottom, 'YMinorTick', 'off');
    if ~isempty(plot_title)
        title(axBottom, plot_title, 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    end
    xlabel(axBottom, 'Full Equivalent Cycles [cycles]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    ylabel(axBottom, resistanceLabel, 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    set(axBottom, 'FontName', 'Times New Roman', 'FontSize', pubFontSize, 'LineWidth', 0.8);
    axBottom.LabelFontSizeMultiplier = 1.0;
    axBottom.TitleFontSizeMultiplier = 1.0;
    if ~isempty(legend_handles)
        legend(axBottom, legend_handles, legend_labels, 'Interpreter', 'none', 'Location', legendLocation, 'Box', 'off', ...
            'FontName', 'Times New Roman', 'FontSize', pubLegendFontSize);
    end

    exportgraphics(figPub, pngFilename, 'Resolution', 300);
    exportgraphics(figPub, pdfFilename, 'ContentType', 'vector');
    fprintf('Publication PDF saved: %s\n', pdfFilename);

    % [pdfFolder, pdfBase, ~] = fileparts(pdfFilename);
    % figFilename = fullfile(pdfFolder, [pdfBase, '.fig']);
    % savefig(figPub, figFilename);
    % fprintf('Publication FIG saved: %s\n', figFilename);
end
