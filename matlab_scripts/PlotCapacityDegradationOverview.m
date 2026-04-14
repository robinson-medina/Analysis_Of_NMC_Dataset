%% Capacity Degradation Overview - NEXTBMS Plotting Data
% =========================================================================
% Summary: Generates 8 publication-quality plots showing battery capacity 
%          degradation over time under various test conditions (DoD, 
%          temperature, C-rate, SoC, voltage limits).
%
% Author: Tim Meulenbreuks, Róbinson Medina, NEXTBMS Team
% Date: 2026-02-24
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
output_file = fullfile(io_folder_cyclic, 'RelativeCapacityVsTime_.png');
exportgraphics(gcf, output_file, 'Resolution', 300);

%% Plot 2: Effect of Depth of Discharge (DoD)
CheckupCapacityFEC = combined_df_cyclic.CheckupCapacityFEC;
% Compares cells cycled at different DoD levels (100%, 70%, 40%, 10%)
% All cells at 25°C with C/2 charge and discharge rates
cell_plot_list = {"Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_27", "Cell_30", "Cell_16"};
cell_name_list = {"A02_02", "A2.02", "A2.02", "A2.02", "A02_05", "A02_04", "A02_03"}; % Cell names from Ageing Test Plan
label_list = {"A02_02 | Cell_12 - 100% DoD", "A2.02 | Cell_56 - 100% DoD", "A2.02 | Cell_89 - 100% DoD", "A2.02 | Cell_93 - 100% DoD", "A02_05 | Cell_27 - 70% DoD", "A02_04 | Cell_30 - 40% DoD", "A02_03 | Cell_16 - 10% DoD"};
colormap_list = {'b', 'r', 'g', [1 0.5 0], [0.5 0 0.5], [0.6 0.3 0], [1 0.75 0.8]};  % Different colors for each cell
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'RelativeCapacityVsTime_VsDoD_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Effect of Depth of Discharge (DoD)', CheckupCapacityFEC);

%% Plot 3: Effect of Temperature
% Compares cells cycled at different temperatures (0°C, 25°C, 45°C)
% All cells at 100% DoD with C/2 charge and discharge rates
cell_plot_list = {"Cell_60", "Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_29"};
cell_name_list = {"A01_02", "A02_02", "A2.02", "A2.02", "A2.02", "A03_04"}; % Cell names from Ageing Test Plan
label_list = {"A01_02 | Cell_60 - 0°C", "A02_02 | Cell_12 - 25°C", "A2.02 | Cell_56 - 25°C", "A2.02 | Cell_89 - 25°C", "A2.02 | Cell_93 - 25°C", "A03_04 | Cell_29 - 45°C"};
colormap_list = {'b', [1 0.5 0], [1 0.5 0], [1 0.5 0], [1 0.5 0], 'r'};  % Blue=cold, Orange=ambient, Red=hot
LinteStyleList = {'-','--',':','-.','-','-'};
output_file = fullfile(io_folder_cyclic, 'RelativeCapacityVsTime_VsTemperature_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, LinteStyleList, ...
    output_file, 'Effect of Temperature', CheckupCapacityFEC);

%% Plot 4: Effect of C-rate at 0°C
% Compares different charge rates at 0°C (cold temperature stress)
% Label format: "Charge rate - Discharge rate - Temperature"
cell_plot_list = {"Cell_63", "Cell_60", "Cell_66", "Cell_68"};
cell_name_list = {"A01_03", "A01_02", "A01_04", "A01_05"}; % Cell names from Ageing Test Plan
label_list = {"A01_03 | Cell_63 - C/4 - C/2 - 0°C", "A01_02 | Cell_60 - C/2 - C/2 - 0°C", "A01_04 | Cell_66 - 3C/4 - C/2 - 0°C", "A01_05 | Cell_68 - 1C - C/2 - 0°C"};
colormap_list = {'b', 'r', 'g', [1 0.5 0]};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'RelativeCapacityVsTime_VsCrate0DegC_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Effect of C-rate at 0°C', CheckupCapacityFEC);

%% Plot 5: Effect of C-rate at 25°C
% Compares different charge/discharge rates at room temperature
% Label format: "Charge rate - Discharge rate - Temperature"
cell_plot_list = {"Cell_12", "Cell_23", "Cell_34", "Cell_35", "Cell_43"};
cell_name_list = {"A02_02", "A02_06", "A02_07", "A02_08"}; % Cell names from Ageing Test Plan
label_list = {"A02_02 | Cell_12 - C/2 - C/2 - 25°C", "A02_06 | Cell_23 - 1C - C/2 - 25°C", "A02_07 | Cell_34 - 3C/2 - C/2 - 25°C", "A02_08 | Cell_35 - 2C - C/2 - 25°C};
colormap_list = {'b', 'r', 'g', [1 0.5 0], [0.5 0 0.5]};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'RelativeCapacityVsTime_VsCrate25DegC_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Effect of C-rate at 25°C', CheckupCapacityFEC);

%% Plot 6: Effect of C-rate at 45°C
% Compares different charge/discharge rates at elevated temperature
% Label format: "Charge rate - Discharge rate - Temperature"
cell_plot_list = {"Cell_29", "Cell_8", "Cell_9", "Cell_47"};
cell_name_list = {"A03_04", "A03_08", "A03_09", "A03_11"}; % Cell names from Ageing Test Plan
label_list = {"A03_04 | Cell_29 - C/2 - C/2 - 45°C", "A03_08 | Cell_8 - C/2 - 1C - 45°C", "A03_09 | Cell_9 - 1C - C/2 - 45°C", "A03_11 | Cell_47 - 1C - 1C - 45°C"};
colormap_list = {'b', 'r', 'g', [1 0.5 0]};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'RelativeCapacityVsTime_VsCrate45DegC_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Effect of C-rate at 45°C', CheckupCapacityFEC);

%% Plot 7: Effect of Average SoC
% Compares cells cycled around different average state of charge levels
% All at 50% DoD but centered at different SoC (25%, 50%, 75%)
cell_plot_list = {"Cell_40", "Cell_1", "Cell_3"};
cell_name_list = {"A03_05", "A03_06", "A03_07"}; % Cell names from Ageing Test Plan
label_list = {"A03_05 | Cell_40 - 75% avg SoC - 50% DoD", "A03_06 | Cell_1 - 50% avg SoC - 50% DoD", "A03_07 | Cell_3 - 25% avg SoC - 50% DoD"};
colormap_list = {'b', 'r', 'g'};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'RelativeCapacityVsTime_AvgSoC_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Effect of Average SoC', CheckupCapacityFEC);

%% Plot 8: Effect of High Voltage
% Compares cells cycled to different upper voltage limits and charging methods
% CC = Constant Current, CCCV = Constant Current Constant Voltage
cell_plot_list = {"Cell_9", "Cell_5", "Cell_22"};
cell_name_list = {"A03_09", "A03_12", "A03_10"}; % Cell names from Ageing Test Plan
label_list = {"A03_09 | Cell_9 - 2.75V-4.35V - CC - CC", "A03_12 | Cell_5 - 2.75V-4.45V - CC - CC", "A03_10 | Cell_22 - 2.75V-4.45V - CCCV - CC"};
colormap_list = {'b', 'r', 'g'};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'RelativeCapacityVsTime_HighVEffect_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Effect of High Voltage', CheckupCapacityFEC);

disp('All plots generated successfully!');
%% Plot 10: Stationary storage cycle
% Compares cells under drive cycle 1 at various temperatures
cell_plot_list = {"Cell_74", "Cell_46", "Cell_17", "Cell_53"};
label_list = {"Cell_74 - 0 degrees", "Cell_46 - 25 degrees", "Cell_17 - 45 degrees", "Cell_53 - dynamic temperatures"};
colormap_list = {'b', 'r', 'g', [0.5 0.5 0.5]}; % Example colors: blue, red, green, gray
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'RelativeCapacityVsTime_StationaryStorage_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Stationary storage cycle', CheckupCapacityFEC);

    %% Plot 11: Drive cycle
% Compares cells under drive cycle at various temperatures
cell_plot_list = {"Cell_72", "Cell_42", "Cell_25", "Cell_49"};
label_list = {"Cell_72 - 0 degrees", "Cell_42 - 25 degrees", "Cell_14 - 45 degrees", "Cell_49 - dynamic temperatures"};
colormap_list = {'b', 'r', 'g', [0.5 0.5 0.5]}; % Example colors: blue, red, green, gray
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(io_folder_cyclic, 'RelativeCapacityVsTime_DriveCycle_.png');
plotCapacityDegradation(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, 'Drive cycle', CheckupCapacityFEC);
    
%% Plot 9: Calendar Ageing Effect (highlighted cells)
cell_plot_list_calendar = {"Cell_57", "Cell_11", "Cell_45", "Cell_26", "Cell_28"};
% Per-cell average SoC values from Ageing Test Plan:
avg_soc_calendar_cells = [1, 1, 0.1, 0.5, 1]; % Cell_57, Cell_11, Cell_45, Cell_26, Cell_28
label_list_calendar = { ...
    sprintf("A01_01 | Cell_57 | 0°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(1)*100), ...
    sprintf("A02_01 | Cell_11 | 25°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(2)*100), ...
    sprintf("A03_01 | Cell_45 | 45°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(3)*100), ...
    sprintf("A03_02 | Cell_26 | 45°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(4)*100), ...
    sprintf("A03_03 | Cell_28 | 45°C | (Avg SoC = %.1f%%)", avg_soc_calendar_cells(5)*100) ...
};
colormap_list_calendar = {'b', 'r', 'g', [1 0.5 0], [0.5 0 0.5]}; % Example colors
Marker_list_calendar = repmat({'-'}, 1, length(cell_plot_list_calendar));
output_file_calendar = fullfile(io_folder_calendar, 'RelativeCapacityVsTime_CalendarAgeingEffect_.png');
CheckupCapacityFEC_calendar = combined_df_calendar.CheckupCapacityFEC;
calendar_label = 'Calendar Ageing Effect (per-cell Avg SoC shown)';
plotCapacityDegradation(combined_df_calendar, cell_list_calendar, cell_plot_list_calendar, label_list_calendar, colormap_list_calendar, Marker_list_calendar, ...
    output_file_calendar, calendar_label, CheckupCapacityFEC_calendar);


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
