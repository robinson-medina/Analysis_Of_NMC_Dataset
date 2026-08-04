%% Capacity Degradation Overview - NEXTBMS Plotting Data
% =========================================================================
% Summary: Generates 8 publication-quality plots showing battery capacity 
%          degradation over time under various test conditions (DoD, 
%          temperature, C-rate, SoC, voltage limits).
%
% Usage:   Set 'io_folder_cyclic' / 'io_folder_calendar' to the ageing data
%          folders (they must contain the Overview*Data capacity CSVs exported
%          by ExtractAgeingData.m) and run the script (no arguments).
%
% Produces: PNG + vector PDF figures in ../pngs (R-022).
%
% Author: Tim Meulenbreuks, Róbinson Medina, NEXTBMS Team
% Date: 2026-02-24   (created)
% Last documented: 2026-08-04
%
% Data Source: OverviewCapacityData_36cell.csv
%   - Contains capacity checkup measurements from battery ageing tests
%   - Columns: CellNum, CellLabel, CheckupCapacityTimeStamp, 
%              CheckupCapacity_Ah, CheckupCapacityFEC
%
% Outputs: 8 PNG figures at 300 DPI
%   1. All cells overview (grey background)
%   2. Effect of Depth of Discharge (DoD): 10%, 40%, 70%, 100%
%   3. Effect of Temperature: 0°C, 25°C, 45°C
%   4. Effect of C-rate at 0°C: C/4 to 1C charging
%   5. Effect of C-rate at 25°C: C/2 to 2C charging/discharging
%   6. Effect of C-rate at 45°C: C/2 to 1C charging/discharging
%   7. Effect of Average SoC: 25%, 50%, 75% at 50% DoD
%   8. Effect of High Voltage: 4.35V vs 4.45V cutoff, CC vs CCCV
%
% Note: Relative capacity = (Current capacity / Initial capacity) × 100%
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
% Reading the .csv file (new format with different column names)
input_csv_cyclic = fullfile(io_folder_cyclic, 'OverviewCapacityData_36cell.csv');
input_csv_calendar = fullfile(io_folder_calendar, 'OverviewCapacityData_5cell.csv');
%% Load and preprocess data

combined_df_cyclic = readtable(input_csv_cyclic, 'VariableNamingRule', 'preserve');

% Rename columns to match expected names
combined_df_cyclic.Properties.VariableNames{'CellNum'} = 'cell_number';
combined_df_cyclic.Properties.VariableNames{'CheckupCapacityTimeStamp'} = 'Timestamp';
combined_df_cyclic.Properties.VariableNames{'CheckupCapacity_Ah'} = 'Capacity [Ah]';

% Extract "Cell_XX" from "A1.02_Cell_XX" format
combined_df_cyclic.("cell_number") = regexp(combined_df_cyclic.("cell_number"), 'Cell_\d+', 'match', 'once');

% Create a list of all cell_numbers contained in the .csv file
cell_list = unique(combined_df_cyclic.("cell_number"));


% Convert timestamps to datetime (format: "24-Feb-2024 01:39:27")
combined_df_cyclic.("Timestamp") = datetime(combined_df_cyclic.("Timestamp"), 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');

% -------------------------------------------------------------------------
% Load and preprocess CALENDAR ageing data
% -------------------------------------------------------------------------
combined_df_calendar = readtable(input_csv_calendar, 'VariableNamingRule', 'preserve');
% Rename columns to match expected names for downstream processing
combined_df_calendar.Properties.VariableNames{'CellNum'} = 'cell_number';
combined_df_calendar.Properties.VariableNames{'CheckupCapacityTimeStamp'} = 'Timestamp';
combined_df_calendar.Properties.VariableNames{'CheckupCapacity_Ah'} = 'Capacity [Ah]';
% Extract only the "Cell_XX" part from cell_number strings
combined_df_calendar.("cell_number") = regexp(combined_df_calendar.("cell_number"), 'Cell_\d+', 'match', 'once');
% List all unique cell numbers in the calendar dataset
cell_list_calendar = unique(combined_df_calendar.("cell_number"));

% Convert timestamp strings to MATLAB datetime objects
combined_df_calendar.("Timestamp") = datetime(combined_df_calendar.("Timestamp"), 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');

%% Helper function for plotting (defined at end of file)
% plotCapacityDegradation is used for plots 2-8

%% Plot 1: All cells overview
figure('Position', [100, 100, 1000, 900]); % Larger for subplots
% --- Subplot 1: Time vs Relative Capacity ---
subplot(2,1,1);
hold on;
for i = 1:length(cell_list)
    cell_name = cell_list{i};
    mask = strcmp(combined_df_cyclic.("cell_number"), cell_name);
    current_cell = combined_df_cyclic(mask, :);
    % Calculate time in days from first measurement
    time_days = days(current_cell.("Timestamp") - current_cell.("Timestamp")(1));
    rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
    plot(time_days, rel_capacity, 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2]);
end
grid on;
set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.6);
xlabel('Time [days]', 'FontSize', 18);
ylabel('Relative Capacity [%]', 'FontSize', 18);
title('All Cells Overview (vs Time)', 'FontSize', 20);
set(gca, 'FontSize', 14);
xlim([0, 425]);
ylim([78, 103]);
hold off;
% --- Subplot 2: FEC vs Relative Capacity ---
subplot(2,1,2);
hold on;
maxFEC = 0;

legend_handles = [];
legend_labels = {};
maxFEC_highlight = 0;

for i = 1:length(cell_list)
    cell_name = cell_list{i};
    mask = strcmp(combined_df_cyclic.("cell_number"), cell_name);
    current_cell = combined_df_cyclic(mask, :);
    rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
    h = plot(current_cell.CheckupCapacityFEC, rel_capacity, 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2], 'HandleVisibility', 'off');
    if ~isempty(current_cell.CheckupCapacityFEC)
        maxFEC = max([maxFEC; max(current_cell.CheckupCapacityFEC)]);
%         legend_handles = [legend_handles, h];
%         legend_labels{end+1} = label_list{idx};

    end
end

for idx = 1:length(cell_list)
    cell_name = cell_list{idx};
    mask = strcmp(combined_df_cyclic.("cell_number"), cell_name);
    current_cell = combined_df_cyclic(mask, :);
    if isempty(current_cell)
        continue;
    end
%     rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
%     h = plot(current_cell.CheckupCapacityFEC, rel_capacity, '-o', 'LineWidth', 2, 'Color', colormap_list{idx}, ...
%         'MarkerFaceColor', colormap_list{idx}, 'MarkerSize', 4, 'LineStyle', Marker_list{idx});

end
grid on;
set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.6);
xlabel('Full Equivalent Cycles (FEC)', 'FontSize', 18);
ylabel('Relative Capacity [%]', 'FontSize', 18);
title('All Cells Overview (vs FEC)', 'FontSize', 20);
set(gca, 'FontSize', 14);
ylim([78, 103]);
xlim([0, maxFEC]);
% if ~isempty(legend_handles)
%     legend(legend_handles, legend_labels, 'FontSize', 12, 'Location', 'best', 'Interpreter', 'none');
% end
hold off;
% Save figure to .png
output_file = fullfile(io_folder_figures, 'RelativeCapacityVsTime_.png');
exportgraphics(gcf, output_file, 'Resolution', 300);

%% Plot 2: Effect of Depth of Discharge (DoD)
CheckupCapacityFEC = combined_df_cyclic.CheckupCapacityFEC;
% Compares cells cycled at different DoD levels (100%, 70%, 40%, 10%)
% All cells at 25°C with C/2 charge and discharge rates
cell_plot_list = {"Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_27", "Cell_30", "Cell_16"};
label_list = {"Cell_12 - 100% DoD", "Cell_56 - 100% DoD", "Cell_89 - 100% DoD", "Cell_93 - 100% DoD", "Cell_27 - 70% DoD", "Cell_30 - 40% DoD", "Cell_16 - 10% DoD"};
colormap_list = {'b', 'r', 'g', [1 0.5 0], [0.5 0 0.5], [0.6 0.3 0], [1 0.75 0.8]};  % Different colors for each cell
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_figures, 'RelativeCapacityVsTime_VsDoD_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Effect of Depth of Discharge (DoD)', CheckupCapacityFEC);

%% Plot 3: Effect of Temperature
% Compares cells cycled at different temperatures (0°C, 25°C, 45°C)
% All cells at 100% DoD with C/2 charge and discharge rates
cell_plot_list = {"Cell_60", "Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_29"};
label_list = {"Cell_60 - 0°C", "Cell_12 - 25°C", "Cell_56 - 25°C", "Cell_89 - 25°C", "Cell_93 - 25°C", "Cell_29 - 45°C"};
colormap_list = {'b', [1 0.5 0], [1 0.5 0], [1 0.5 0], [1 0.5 0], 'r'};  % Blue=cold, Orange=ambient, Red=hot
LinteStyleList = {'-','--',':','-.','-','-'};
output_file = fullfile(io_folder_figures, 'RelativeCapacityVsTime_VsTemperature_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, LinteStyleList, ...
    output_file, 'Effect of Temperature', CheckupCapacityFEC);

%% Plot 4: Effect of C-rate at 0°C
% Compares different charge rates at 0°C (cold temperature stress)
% Label format: "Charge rate - Discharge rate - Temperature"
cell_plot_list = {"Cell_63", "Cell_60", "Cell_66", "Cell_68"};
label_list = {"Cell_63 - C/4 - C/2 - 0°C", "Cell_60 - C/2 - C/2 - 0°C", "Cell_66 - 3C/4 - C/2 - 0°C", "Cell_68 - 1C - C/2 - 0°C"};
colormap_list = {'b', 'r', 'g', [1 0.5 0]};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_figures, 'RelativeCapacityVsTime_VsCrate0DegC_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Effect of C-rate at 0°C', CheckupCapacityFEC);

%% Plot 5: Effect of C-rate at 25°C
% Compares different charge/discharge rates at room temperature
% Label format: "Charge rate - Discharge rate - Temperature"
cell_plot_list = {"Cell_12", "Cell_23", "Cell_34", "Cell_35"};
label_list = {"Cell_12 - C/2 - C/2", "Cell_23 - 1C - C/2", "Cell_34 - 3C/2 - C/2", "Cell_35 - 2C - C/2"};
% Use the project publication palette (R-017) for the highlighted cyclic cells.
colormap_list = {[12 195 82]./255, [1 17 181]./255, [255 0 0]./255, [255 0 255]./255};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(pngsDir, 'RelativeCapacityVsTime_VsCrate25DegC_.png');
output_file_pdf = fullfile(pngsDir, 'RelativeCapacityVsTime_VsCrate25DegC_.pdf');
plotCapacityDegradationPublicationFECOnly(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, output_file_pdf, '', 'southeast');

%% Plot 6: Effect of C-rate at 45°C
% Compares different charge/discharge rates at elevated temperature
% Label format: "Charge rate - Discharge rate - Temperature"
cell_plot_list = {"Cell_29", "Cell_8", "Cell_9", "Cell_47"};
label_list = {"Cell_29 - C/2 - C/2 - 45°C", "Cell_8 - C/2 - 1C - 45°C", "Cell_9 - 1C - C/2 - 45°C", "Cell_47 - 1C - 1C - 45°C"};
colormap_list = {'b', 'r', 'g', [1 0.5 0]};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_figures, 'RelativeCapacityVsTime_VsCrate45DegC_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Effect of C-rate at 45°C', CheckupCapacityFEC);

%% Plot 7: Effect of Average SoC
% Compares cells cycled around different average state of charge levels
% All at 50% DoD but centered at different SoC (25%, 50%, 75%)
cell_plot_list = {"Cell_40", "Cell_1", "Cell_3"};
label_list = {"Cell_40 - 75% avg SoC - 50% DoD", "Cell_1 - 50% avg SoC - 50% DoD", "Cell_3 - 25% avg SoC - 50% DoD"};
colormap_list = {'b', 'r', 'g'};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_figures, 'RelativeCapacityVsTime_AvgSoC_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Effect of Average SoC', CheckupCapacityFEC);

%% Plot 8: Effect of High Voltage
% Compares cells cycled to different upper voltage limits and charging methods
% CC = Constant Current, CCCV = Constant Current Constant Voltage
cell_plot_list = {"Cell_9", "Cell_5", "Cell_22"};
label_list = {"Cell_9 - 2.75V-4.35V - CC - CC", "Cell_5 - 2.75V-4.45V - CC - CC", "Cell_22 - 2.75V-4.45V - CCCV - CC"};
colormap_list = {'b', 'r', 'g'};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_figures, 'RelativeCapacityVsTime_HighVEffect_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Effect of High Voltage', CheckupCapacityFEC);

disp('All plots generated successfully!');
%% Plot 10: Stationary storage cycle
% Compares cells under drive cycle 1 at various temperatures
cell_plot_list = {"Cell_74", "Cell_46", "Cell_17", "Cell_53"};
label_list = {"Cell_74 - 0 degrees", "Cell_46 - 25 degrees", "Cell_17 - 45 degrees", "Cell_53 - dynamic temperatures"};
colormap_list = {'b', 'r', 'g', [0.5 0.5 0.5]}; % Example colors: blue, red, green, gray
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_figures, 'RelativeCapacityVsTime_StationaryStorage_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Stationary storage cycle', CheckupCapacityFEC);

    %% Plot 11: Drive cycle
% Compares cells under drive cycle at various temperatures
cell_plot_list = {"Cell_72", "Cell_42", "Cell_25", "Cell_49"};
label_list = {"Cell_72 - 0 degrees", "Cell_42 - 25 degrees", "Cell_14 - 45 degrees", "Cell_49 - dynamic temperatures"};
colormap_list = {'b', 'r', 'g', [0.5 0 0.5]}; % Example colors: blue, red, green, purple
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_figures, 'RelativeCapacityVsTime_DriveCycle_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Drive cycle', CheckupCapacityFEC);
    
%% Plot 9: Calendar Ageing Effect (highlighted cells)
% Highlight all 5 calendar cells so no un-labeled gray trajectory remains
% (the 5th cell, Cell_28, was previously drawn only as a gray background line).
cell_plot_list_calendar = {"Cell_57", "Cell_11", "Cell_45", "Cell_26", "Cell_28"};
% Per-cell average SoC values from Ageing Test Plan:
avg_soc_calendar_cells = [1, 1, 0.1, 0.5, 1]; % Cell_57, Cell_11, Cell_45, Cell_26, Cell_28
label_list_calendar = { ...
    sprintf("Cell_57 | 0°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(1)*100), ...
    sprintf("Cell_11 | 25°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(2)*100), ...
    sprintf("Cell_45 | 45°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(3)*100), ...
    sprintf("Cell_26 | 45°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(4)*100), ...
    sprintf("Cell_28 | 45°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(5)*100) ...
};
% Use the project publication palette (R-017) for calendar figure highlights.
% Keep one explicit color per highlighted cell so legend and trace order stay deterministic.
green_pub = [12 195 82] ./ 255;
darkblue_pub = [1 17 181] ./ 255;
red_pub = [255 0 0] ./ 255;
magenta_pub = [255 0 255] ./ 255;
black_pub = [0 0 0];
colormap_list_calendar = {green_pub, darkblue_pub, red_pub, magenta_pub, black_pub};
Marker_list_calendar = repmat({'-'}, 1, length(cell_plot_list_calendar));
output_file_calendar = fullfile(pngsDir, 'RelativeCapacityVsTime_CalendarAgeingEffect_.png');
output_file_calendar_pdf = fullfile(pngsDir, 'RelativeCapacityVsTime_CalendarAgeingEffect_.pdf');
CheckupCapacityFEC_calendar = combined_df_calendar.CheckupCapacityFEC;
calendar_label = '';
% Set consistent x-limits and y-limits for publication figure
calendarXLim = [0, 400];
calendarYLim = [78, 105];
plotCapacityDegradationPublication(combined_df_calendar, cell_list_calendar, cell_plot_list_calendar, label_list_calendar, colormap_list_calendar, Marker_list_calendar, ...
    output_file_calendar, output_file_calendar_pdf, calendar_label, false, 'southwest', calendarXLim, calendarYLim);


%% Helper function
function plotCapacityDegradation(combined_df, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, filename, plot_title, CheckupCapacityFEC)
    % PLOTCAPACITYDEGRADATION Creates a capacity degradation plot with two subplots
    %
    % Top: Time vs Relative Capacity (existing)
    % Bottom: FEC vs Relative Capacity
    %
    % Inputs:
    %   combined_df     - Table with columns: cell_number, Timestamp, Capacity [Ah]
    %   cell_list       - Cell array of all unique cell names in data
    %   cell_plot_list  - Cell array of cell names to highlight
    %   label_list      - Cell array of legend labels for highlighted cells
    %   colormap_list   - Cell array of colors (strings or RGB triplets)
    %   filename        - Output PNG filename
    %   plot_title      - Title of the plot
    %   CheckupCapacityFEC - Array of FEC values (same length as combined_df)
    %
    % Output:
    %   PNG figure saved at 300 DPI
    if nargin < 9
        CheckupCapacityFEC = [];
    end
    figure('Position', [100, 100, 1000, 900]);  % Larger figure for subplots
    % --- Subplot 1: Time vs Relative Capacity ---
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
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        plot(time_days, rel_capacity, 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2], 'HandleVisibility', 'off');
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
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        h = plot(time_days, rel_capacity, '-o', 'LineWidth', 2, 'Color', colormap_list{idx}, ...
            'MarkerFaceColor', colormap_list{idx}, 'MarkerSize', 4, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h];
        legend_labels{end+1} = label_list{idx};
    end
    grid on;
    set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.6);
    xlabel('Time [days]', 'FontSize', 18);
    ylabel('Relative Capacity [%]', 'FontSize', 18);
    if ~isempty(plot_title)
        title([plot_title ' (vs Time)'], 'FontSize', 20);
    end
    xlim([0, 425]);
    ylim([78, 103]);
    if ~isempty(legend_handles)
        legend(legend_handles, legend_labels, 'FontSize', 12, 'Location', 'best', 'Interpreter', 'none');
    end
    hold off;
    % --- Subplot 2: FEC vs Relative Capacity ---
    subplot(2,1,2);
    hold on;
    maxFEC = 0;
    for i = 1:length(cell_list)
        cell_name = cell_list{i};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        plot(current_cell.CheckupCapacityFEC, rel_capacity, 'LineWidth', 2, 'Color', [0.5 0.5 0.5 0.2], 'HandleVisibility', 'off');
        if ~isempty(current_cell.CheckupCapacityFEC)
            maxFEC = max([maxFEC; max(current_cell.CheckupCapacityFEC)]);
        end
    end
    legend_handles = [];
    legend_labels = {};
    maxFEC_highlight = 0;
    for idx = 1:length(cell_plot_list)
        cell_name = cell_plot_list{idx};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        h = plot(current_cell.CheckupCapacityFEC, rel_capacity, '-o', 'LineWidth', 2, 'Color', colormap_list{idx}, ...
            'MarkerFaceColor', colormap_list{idx}, 'MarkerSize', 4, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h];
        legend_labels{end+1} = label_list{idx};
        if ~isempty(current_cell.CheckupCapacityFEC)
            maxFEC_highlight = max([maxFEC_highlight; max(current_cell.CheckupCapacityFEC)]);
        end
    end
    grid on;
    set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.6);
    xlabel('Full Equivalent Cycles (FEC)', 'FontSize', 18);
    ylabel('Relative Capacity [%]', 'FontSize', 18);
    if ~isempty(plot_title)
        title([plot_title ' (vs FEC)'], 'FontSize', 20);
    end
    ylim([78, 103]);
    xlim([0, maxFEC_highlight]);
    if ~isempty(legend_handles)
        legend(legend_handles, legend_labels, 'FontSize', 12, 'Location', 'best', 'Interpreter', 'none');
    end
    hold off;
    % Save figure to .png
    exportgraphics(gcf, filename, 'Resolution', 300);
end

function plotCapacityDegradationPublication(combined_df, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, pngFilename, pdfFilename, plot_title, includeFEC, legendLocation, xLimits, yLimits)
    % PLOTCAPACITYDEGRADATIONPUBLICATION Creates publication-ready capacity plots.
    %
    % includeFEC = true  -> two subplots (time + FEC)
    % includeFEC = false -> single subplot (time only)

    % Use southwest by default; callers can override (e.g., southeast for Figure 5).
    if nargin < 11 || isempty(legendLocation)
        legendLocation = 'southwest';
    end
    % Set default x and y limits if not provided
    if nargin < 12 || isempty(xLimits)
        xLimits = [0, 425];
    end
    if nargin < 13 || isempty(yLimits)
        yLimits = [78, 103];
    end

    % Guard against list-length mismatches to avoid index errors.
    nHighlight = min([numel(cell_plot_list), numel(label_list), numel(colormap_list), numel(Marker_list)]);
    if nHighlight < numel(cell_plot_list)
        warning('Publication plot: list lengths differ, using first %d highlighted cells.', nHighlight);
    end

    % Set compact one-column journal sizes in centimeters.
    % Match the GITT/OCP publication figure: use ONE uniform font size for
    % axis labels, tick labels and legend so the x/y labels do not appear
    % larger than the rest of the text (mirrors extractOCPLines.m pubFontSizePt).
    pubFontSize = 8;
    % In these tiledlayout figures the legend renders visually larger than the
    % axes/tick text at the same nominal pt size; set it to 6 pt so it matches
    % the 8 pt axis text (keeps the balanced look of the GITT figure).
    pubLegendFontSize = 6;
    if includeFEC
        figHeight = 8.8;
    else
        figHeight = 5.0;
    end
    figPub = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2, 2, 7.85, figHeight]);
    figPub.PaperPositionMode = 'auto';

    if includeFEC
        t = tiledlayout(figPub, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    else
        t = tiledlayout(figPub, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
    end

    % -----------------------------
    % Top panel: Time vs Capacity
    % -----------------------------
    axTop = nexttile(t);
    hold(axTop, 'on');

    % Draw all cells in the background as light gray trajectories.
    for i = 1:length(cell_list)
        cell_name = cell_list{i};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            continue;
        end
        time_days = days(current_cell.("Timestamp") - current_cell.("Timestamp")(1));
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        plot(axTop, time_days, rel_capacity, 'LineWidth', 1.0, 'Color', [0.75 0.75 0.75], 'HandleVisibility', 'off');
    end

    % Draw highlighted cells with labels intended for the legend.
    legend_handles = [];
    legend_labels = {};
    for idx = 1:nHighlight
        cell_name = cell_plot_list{idx};
        mask = strcmp(combined_df.("cell_number"), cell_name);
        current_cell = combined_df(mask, :);
        if isempty(current_cell)
            warning('Cell %s not found in data', cell_name);
            continue;
        end
        time_days = days(current_cell.("Timestamp") - current_cell.("Timestamp")(1));
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        h = plot(axTop, time_days, rel_capacity, 'LineWidth', 1.2, 'Color', colormap_list{idx}, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h]; %#ok<AGROW>
        legend_labels{end+1} = label_list{idx}; %#ok<AGROW>
    end

    grid(axTop, 'on'); box(axTop, 'on');
    xlim(axTop, xLimits);
    ylim(axTop, yLimits);
    xticks(axTop, unique(sort([xticks(axTop), xLimits(1), xLimits(2)])));
    yticks(axTop, unique(sort([yticks(axTop), yLimits(1), yLimits(2)])));
    % Ensure clean formatting - remove minor ticks for publication-quality appearance
    set(axTop, 'YMinorTick', 'off');
    if ~isempty(plot_title)
        title(axTop, [plot_title ' (vs Time)'], 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    end
    xlabel(axTop, 'Time [days]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    ylabel(axTop, 'Relative Capacity [%]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    set(axTop, 'FontName', 'Times New Roman', 'FontSize', pubFontSize, 'LineWidth', 0.8);
    axTop.LabelFontSizeMultiplier = 1.0;
    axTop.TitleFontSizeMultiplier = 1.0;
    if ~isempty(legend_handles)
        legend(axTop, legend_handles, legend_labels, 'Interpreter', 'none', 'Location', legendLocation, 'Box', 'off', ...
            'FontName', 'Times New Roman', 'FontSize', pubLegendFontSize);
    end

    % ---------------------------------
    % Optional bottom panel: FEC plot
    % ---------------------------------
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
            rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
            plot(axBottom, current_cell.CheckupCapacityFEC, rel_capacity, 'LineWidth', 1.0, 'Color', [0.75 0.75 0.75], 'HandleVisibility', 'off');
            if ~isempty(current_cell.CheckupCapacityFEC)
                maxFEC = max(maxFEC, max(current_cell.CheckupCapacityFEC));
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
            rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
            h = plot(axBottom, current_cell.CheckupCapacityFEC, rel_capacity, 'LineWidth', 1.2, 'Color', colormap_list{idx}, 'LineStyle', Marker_list{idx});
            legend_handles = [legend_handles, h]; %#ok<AGROW>
            legend_labels{end+1} = label_list{idx}; %#ok<AGROW>
            if ~isempty(current_cell.CheckupCapacityFEC)
                maxFEC_highlight = max(maxFEC_highlight, max(current_cell.CheckupCapacityFEC));
            end
        end

        if maxFEC_highlight <= 0
            maxFEC_highlight = maxFEC;
        end

        grid(axBottom, 'on'); box(axBottom, 'on');
        ylim(axBottom, yLimits);
        xlim(axBottom, [0, maxFEC_highlight]);
        yticks(axBottom, unique(sort([yticks(axBottom), yLimits(1), yLimits(2)])));
        if ~isempty(plot_title)
            title(axBottom, [plot_title ' (vs FEC)'], 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
        end
        xlabel(axBottom, 'Full Equivalent Cycles [cycles]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
        ylabel(axBottom, 'Relative Capacity [%]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
        set(axBottom, 'FontName', 'Times New Roman', 'FontSize', pubFontSize, 'LineWidth', 0.8);
        axBottom.LabelFontSizeMultiplier = 1.0;
        axBottom.TitleFontSizeMultiplier = 1.0;
        if ~isempty(legend_handles)
            legend(axBottom, legend_handles, legend_labels, 'Interpreter', 'none', 'Location', legendLocation, 'Box', 'off', ...
                'FontName', 'Times New Roman', 'FontSize', pubLegendFontSize);
        end
    end

    % Export publication files as PNG and vector PDF.
    exportgraphics(figPub, pngFilename, 'Resolution', 300);
    exportgraphics(figPub, pdfFilename, 'ContentType', 'vector');
    fprintf('Publication PDF saved: %s\n', pdfFilename);
end

function plotCapacityDegradationPublicationFECOnly(combined_df, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, pngFilename, pdfFilename, plot_title, legendLocation)
    % PLOTCAPACITYDEGRADATIONPUBLICATIONFECONLY Creates a publication figure with only the FEC subplot.

    if nargin < 10 || isempty(legendLocation)
        legendLocation = 'southwest';
    end

    nHighlight = min([numel(cell_plot_list), numel(label_list), numel(colormap_list), numel(Marker_list)]);
    if nHighlight < numel(cell_plot_list)
        warning('Publication plot (FEC only): list lengths differ, using first %d highlighted cells.', nHighlight);
    end

    % Match the GITT/OCP publication figure: axis labels and tick labels at 8 pt.
    % The legend renders visually larger than the axes text in tiledlayout figures,
    % so it is set to 6 pt to match the 8 pt axis text (balanced like the GITT figure).
    pubFontSize = 8;
    pubLegendFontSize = 6;
    figPub = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2, 2, 8.00, 5.0]);
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
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        plot(axBottom, current_cell.CheckupCapacityFEC, rel_capacity, 'LineWidth', 1.0, 'Color', [0.75 0.75 0.75], 'HandleVisibility', 'off');
        if ~isempty(current_cell.CheckupCapacityFEC)
            maxFEC = max(maxFEC, max(current_cell.CheckupCapacityFEC));
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
            warning('Cell %s not found in data', cell_name);
            continue;
        end
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1) * 100;
        h = plot(axBottom, current_cell.CheckupCapacityFEC, rel_capacity, 'LineWidth', 1.2, 'Color', colormap_list{idx}, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h]; %#ok<AGROW>
        legend_labels{end+1} = label_list{idx}; %#ok<AGROW>
        if ~isempty(current_cell.CheckupCapacityFEC)
            maxFEC_highlight = max(maxFEC_highlight, max(current_cell.CheckupCapacityFEC));
        end
    end

    if maxFEC_highlight <= 0
        maxFEC_highlight = maxFEC;
    end

    grid(axBottom, 'on'); box(axBottom, 'on');
    % Extend the relative-capacity axis to 105% and ensure 105 (and 78) are shown as tick labels.
    ylim(axBottom, [78, 105]);
    yticks(axBottom, unique(sort([yticks(axBottom), 78, 105])));
    xlim(axBottom, [0, maxFEC_highlight]);
    if ~isempty(plot_title)
        title(axBottom, plot_title, 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    end
    xlabel(axBottom, 'Full Equivalent Cycles [cycles]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    ylabel(axBottom, 'Relative Capacity [%]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
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
end
