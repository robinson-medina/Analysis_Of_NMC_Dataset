%% PlotCapacityDegradation_detailed.m
% Summary: Generates detailed capacity-degradation comparison figures for the
%          ageing dataset. The plots group cells by depth of discharge,
%          temperature, C-rate, average SoC, voltage window, storage profile,
%          and calendar-ageing condition.
%
% Usage: Set DataRoot if needed, then run this script with no arguments. The
%        script reads overview capacity tables from the cyclic and calendar
%        ageing data folders.
%
% Outputs: Capacity comparison PNG and PDF figures in this script's R-022 output
%          directory. Relative capacity is reported as current capacity divided
%          by initial capacity.
%
% Authors: Tim Meulenbreuks, Róbinson Medina, NEXTBMS Team.
% Dependency files: Functions/getFigureOutputDir.m,
%                   Functions/plotCapacityDegradationTile.m.
% Last documented: 2026-09-01

clear; close all; clc;

%% Set input/output folder
% Single configurable dataset root. Read-only (R-001).
DataRoot = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
io_folder_cyclic   = fullfile(DataRoot, '4_Ageing', 'Cyclic_ageing_data');
io_folder_calendar = fullfile(DataRoot, '4_Ageing', 'Calendar_ageing_data');
% Primary publication output location (R-022).
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
pngsDir = getFigureOutputDir('PlotCapacityDegradation_detailed');
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
% plotCapacityDegradation is used by the dedicated publication exports (Plot 5, Plot 9);
% plotCapacityDegradationTile (Functions/) is used by the combined tiled figures below.

fprintf('--- PlotCapacityDegradation_detailed: starting figure generation ---\n');

%% Plot 1: All cells overview - skipped (superseded by the comparison plots below).
fprintf('Skipping Plot 1 (All Cells Overview).\n');

%% Plot 2+3: Effect of DoD (col 1) and Effect of Temperature (col 2), combined 2x2 tiles.
fprintf('Generating Plot 2+3: Effect of DoD + Effect of Temperature (combined)...\n');
cell_plot_list_dod = {"Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_27", "Cell_30", "Cell_16"};
colormap_list_dod = {'b', 'r', 'g', [1 0.5 0], [0.5 0 0.5], [0.6 0.3 0], [1 0.75 0.8]};
Marker_list_dod = repmat({'-'}, 1, length(cell_plot_list_dod));

cell_plot_list_temp = {"Cell_60", "Cell_12", "Cell_56", "Cell_89", "Cell_93", "Cell_29"};
colormap_list_temp = {'b', [1 0.5 0], [1 0.5 0], [1 0.5 0], [1 0.5 0], 'r'};
LineStyleList_temp = {'-','--',':','-.','-','-'};

figure('Position', [100, 100, 1400, 900]);
% Tile index = (row-1)*cols + col for a 2x2 layout: col 1 = tiles 1 & 3, col 2 = tiles 2 & 4.
tDoDTemp = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
plotCapacityDegradationTile(nexttile(tDoDTemp, 1), nexttile(tDoDTemp, 3), combined_df_cyclic, cell_list, ...
    cell_plot_list_dod, colormap_list_dod, Marker_list_dod, 'Effect of Depth of Discharge (DoD)');
plotCapacityDegradationTile(nexttile(tDoDTemp, 2), nexttile(tDoDTemp, 4), combined_df_cyclic, cell_list, ...
    cell_plot_list_temp, colormap_list_temp, LineStyleList_temp, 'Effect of Temperature');

output_file = fullfile(pngsDir, 'RelativeCapacityVsTime_DoD_Temperature_.png');
exportgraphics(gcf, output_file, 'Resolution', 300);

%% Plot 4+6: C-rate effect at 0°C (col 1), 25°C (col 2), 45°C (col 3), combined 3x2 tiles.
fprintf('Generating Plot 4+6: C-rate effect at 0°C / 25°C / 45°C (combined)...\n');
cell_plot_list_0C = {"Cell_63", "Cell_60", "Cell_66", "Cell_68"};
colormap_list_0C = {'b', 'r', 'g', [1 0.5 0]};
Marker_list_0C = repmat({'-'}, 1, length(cell_plot_list_0C));

cell_plot_list_25C = {"Cell_12", "Cell_23", "Cell_34", "Cell_35"};
% Reuse the project publication palette (R-017) - same highlighted cells as fig. 5's dedicated export below.
colormap_list_25C = {[12 195 82]./255, [1 17 181]./255, [255 0 0]./255, [255 0 255]./255};
Marker_list_25C = repmat({'-'}, 1, length(cell_plot_list_25C));

cell_plot_list_45C = {"Cell_29", "Cell_8", "Cell_9", "Cell_47"};
colormap_list_45C = {'b', 'r', 'g', [1 0.5 0]};
Marker_list_45C = repmat({'-'}, 1, length(cell_plot_list_45C));

figure('Position', [100, 100, 1600, 900]);
% Tile index = (row-1)*cols + col for a 2x3 layout: cols = 0°C/25°C/45°C, rows = Time/FEC.
tCrate = tiledlayout(2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
plotCapacityDegradationTile(nexttile(tCrate, 1), nexttile(tCrate, 4), combined_df_cyclic, cell_list, ...
    cell_plot_list_0C, colormap_list_0C, Marker_list_0C, 'Effect of C-rate at 0°C');
plotCapacityDegradationTile(nexttile(tCrate, 2), nexttile(tCrate, 5), combined_df_cyclic, cell_list, ...
    cell_plot_list_25C, colormap_list_25C, Marker_list_25C, 'Effect of C-rate at 25°C');
plotCapacityDegradationTile(nexttile(tCrate, 3), nexttile(tCrate, 6), combined_df_cyclic, cell_list, ...
    cell_plot_list_45C, colormap_list_45C, Marker_list_45C, 'Effect of C-rate at 45°C');

output_file = fullfile(pngsDir, 'RelativeCapacityVsTime_CrateComparison_.png');
exportgraphics(gcf, output_file, 'Resolution', 300);

%% Plot 5: Effect of C-rate at 25°C (dedicated journal publication export, fig. 5 - kept standalone).
fprintf('Generating Plot 5: Effect of C-rate at 25°C (publication export)...\n');
cell_plot_list = {"Cell_12", "Cell_23", "Cell_34", "Cell_35"};
label_list = {"Cell_12 - C/2 - C/2", "Cell_23 - 1C - C/2", "Cell_34 - 3C/2 - C/2", "Cell_35 - 2C - C/2"};
% Use the project publication palette (R-017) for the highlighted cyclic cells.
colormap_list = {[12 195 82]./255, [1 17 181]./255, [255 0 0]./255, [255 0 255]./255};
Marker_list = repmat({'-'}, 1, length(cell_plot_list));
output_file = fullfile(pngsDir, 'RelativeCapacityVsTime_VsCrate25DegC_.png');
output_file_pdf = fullfile(pngsDir, 'RelativeCapacityVsTime_VsCrate25DegC_.pdf');
yLabel_plot5 = '$\tilde{C}_{RPT}\,[-]$';   % latex interpreter (no precomposed C-with-tilde glyph exists for tex/Times)
plotCapacityDegradationPublicationFECOnly(combined_df_cyclic, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, ...
    output_file, output_file_pdf, '', 'southeast', yLabel_plot5);

%% Plot 7+8: Effect of Average SoC (col 1) and Effect of High Voltage (col 2), combined 2x2 tiles.
fprintf('Generating Plot 7+8: Effect of Average SoC + Effect of High Voltage (combined)...\n');
cell_plot_list_soc = {"Cell_40", "Cell_1", "Cell_3"};
colormap_list_soc = {'b', 'r', 'g'};
Marker_list_soc = repmat({'-'}, 1, length(cell_plot_list_soc));

cell_plot_list_highv = {"Cell_9", "Cell_5", "Cell_22"};
colormap_list_highv = {'b', 'r', 'g'};
Marker_list_highv = repmat({'-'}, 1, length(cell_plot_list_highv));

figure('Position', [100, 100, 1400, 900]);
% Tile index = (row-1)*cols + col for a 2x2 layout: col 1 = tiles 1 & 3, col 2 = tiles 2 & 4.
tSoCHighV = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
plotCapacityDegradationTile(nexttile(tSoCHighV, 1), nexttile(tSoCHighV, 3), combined_df_cyclic, cell_list, ...
    cell_plot_list_soc, colormap_list_soc, Marker_list_soc, 'Effect of Average SoC');
plotCapacityDegradationTile(nexttile(tSoCHighV, 2), nexttile(tSoCHighV, 4), combined_df_cyclic, cell_list, ...
    cell_plot_list_highv, colormap_list_highv, Marker_list_highv, 'Effect of High Voltage');

output_file = fullfile(pngsDir, 'RelativeCapacityVsTime_AvgSoC_HighV_.png');
exportgraphics(gcf, output_file, 'Resolution', 300);

%% Plot 10+11: Stationary storage cycle (col 1) and Drive cycle (col 2), combined 2x2 tiles.
fprintf('Generating Plot 10+11: Stationary storage cycle + Drive cycle (combined)...\n');
cell_plot_list_stat = {"Cell_74", "Cell_46", "Cell_17", "Cell_53"};
colormap_list_stat = {'b', 'r', 'g', [0.5 0.5 0.5]};
Marker_list_stat = repmat({'-'}, 1, length(cell_plot_list_stat));

cell_plot_list_drive = {"Cell_72", "Cell_42", "Cell_25", "Cell_49"};
colormap_list_drive = {'b', 'r', 'g', [0.5 0 0.5]};
Marker_list_drive = repmat({'-'}, 1, length(cell_plot_list_drive));

figure('Position', [100, 100, 1400, 900]);
% Tile index = (row-1)*cols + col for a 2x2 layout: col 1 = tiles 1 & 3, col 2 = tiles 2 & 4.
tStatDrive = tiledlayout(2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
plotCapacityDegradationTile(nexttile(tStatDrive, 1), nexttile(tStatDrive, 3), combined_df_cyclic, cell_list, ...
    cell_plot_list_stat, colormap_list_stat, Marker_list_stat, 'Stationary storage cycle');
plotCapacityDegradationTile(nexttile(tStatDrive, 2), nexttile(tStatDrive, 4), combined_df_cyclic, cell_list, ...
    cell_plot_list_drive, colormap_list_drive, Marker_list_drive, 'Drive cycle');

output_file = fullfile(pngsDir, 'RelativeCapacityVsTime_StationaryStorage_DriveCycle_.png');
exportgraphics(gcf, output_file, 'Resolution', 300);

%% Plot 9: Calendar Ageing Effect (highlighted cells)
fprintf('Generating Plot 9: Calendar Ageing Effect (publication export)...\n');
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
yLabel_fig11 = '$\tilde{C}_{RPT}\,[-]$';   % latex interpreter (no precomposed C-with-tilde glyph exists for tex/Times)
% Set consistent x-limits and y-limits for publication figure
calendarXLim = [0, 400];
calendarYLim = [0.90, 1.05];
plotCapacityDegradationPublication(combined_df_calendar, cell_list_calendar, cell_plot_list_calendar, label_list_calendar, colormap_list_calendar, Marker_list_calendar, ...
    output_file_calendar, output_file_calendar_pdf, calendar_label, false, 'southwest', calendarXLim, calendarYLim, yLabel_fig11);

fprintf('--- PlotCapacityDegradation_detailed: figure generation complete ---\n');
disp('All plots generated successfully!');

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
        cellLegendLabel = regexp(label_list{idx}, 'Cell_\d+', 'match', 'once');
        if isempty(cellLegendLabel)
            cellLegendLabel = label_list{idx};
        end
        legend_labels{end+1} = cellLegendLabel;
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
    % Legend intentionally omitted per publication request.
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
        cellLegendLabel = regexp(label_list{idx}, 'Cell_\d+', 'match', 'once');
        if isempty(cellLegendLabel)
            cellLegendLabel = label_list{idx};
        end
        legend_labels{end+1} = cellLegendLabel;
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
    % Legend intentionally omitted per publication request.
    hold off;
    % Save figure to .png
    exportgraphics(gcf, filename, 'Resolution', 300);
end

function plotCapacityDegradationPublication(combined_df, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, pngFilename, pdfFilename, plot_title, includeFEC, legendLocation, xLimits, yLimits, yAxisLabel)
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
        yLimits = [0.90, 1.05];
    end
    if nargin < 14 || isempty(yAxisLabel)
        yAxisLabel = '\hat{C}_{RPT} [-]';
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
    pubLegendFontSize = pubFontSize;
    if includeFEC
        figHeight = 8.8;
    else
        figHeight = 3.5190;
    end
    figPub = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2, 2, 8.0962, figHeight]);
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
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1);
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
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1);
        h = plot(axTop, time_days, rel_capacity, 'LineWidth', 1.0, 'Color', colormap_list{idx}, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h]; %#ok<AGROW>
        cellLegendLabel = regexp(label_list{idx}, 'Cell_\d+', 'match', 'once');
        if isempty(cellLegendLabel)
            cellLegendLabel = label_list{idx};
        end
        legend_labels{end+1} = cellLegendLabel; %#ok<AGROW>
    end

    grid(axTop, 'on'); box(axTop, 'on');
    xlim(axTop, xLimits);
    ylim(axTop, yLimits);
    xticks(axTop, unique(sort([xticks(axTop), xLimits(1), xLimits(2)])));
    yticks(axTop, unique(sort([yticks(axTop), yLimits(1), yLimits(2)])));
    axTop.YTickLabel = arrayfun(@(v) sprintf('%.2f', v), axTop.YTick, 'UniformOutput', false);
    % Ensure clean formatting - remove minor ticks for publication-quality appearance
    set(axTop, 'YMinorTick', 'off');
    if ~isempty(plot_title)
        title(axTop, [plot_title ' (vs Time)'], 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    end
    xlabel(axTop, 'Time [days]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    ylabel(axTop, yAxisLabel, 'FontName', 'Times New Roman', 'FontSize', pubFontSize, 'Interpreter', 'latex');
    set(axTop, 'FontName', 'Times New Roman', 'FontSize', pubFontSize, 'LineWidth', 0.8);
    axTop.LabelFontSizeMultiplier = 1.0;
    axTop.TitleFontSizeMultiplier = 1.0;
    % Legend intentionally omitted per publication request.

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
            rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1);
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
            rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1);
            h = plot(axBottom, current_cell.CheckupCapacityFEC, rel_capacity, 'LineWidth', 1.0, 'Color', colormap_list{idx}, 'LineStyle', Marker_list{idx});
            legend_handles = [legend_handles, h]; %#ok<AGROW>
            cellLegendLabel = regexp(label_list{idx}, 'Cell_\d+', 'match', 'once');
            if isempty(cellLegendLabel)
                cellLegendLabel = label_list{idx};
            end
            legend_labels{end+1} = cellLegendLabel; %#ok<AGROW>
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
        axBottom.YTickLabel = arrayfun(@(v) sprintf('%.2f', v), axBottom.YTick, 'UniformOutput', false);
        if ~isempty(plot_title)
            title(axBottom, [plot_title ' (vs FEC)'], 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
        end
        xlabel(axBottom, 'Full Equivalent Cycles [cycles]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
        ylabel(axBottom, yAxisLabel, 'FontName', 'Times New Roman', 'FontSize', pubFontSize, 'Interpreter', 'latex');
        set(axBottom, 'FontName', 'Times New Roman', 'FontSize', pubFontSize, 'LineWidth', 0.8);
        axBottom.LabelFontSizeMultiplier = 1.0;
        axBottom.TitleFontSizeMultiplier = 1.0;
        % Legend intentionally omitted per publication request.
    end

    % Export publication files as PNG and vector PDF.
    exportgraphics(figPub, pngFilename, 'Resolution', 300);
    exportgraphics(figPub, pdfFilename, 'ContentType', 'vector');
    fprintf('Publication PDF saved: %s\n', pdfFilename);
end

function plotCapacityDegradationPublicationFECOnly(combined_df, cell_list, cell_plot_list, label_list, colormap_list, Marker_list, pngFilename, pdfFilename, plot_title, legendLocation, yAxisLabel)
    % PLOTCAPACITYDEGRADATIONPUBLICATIONFECONLY Creates a publication figure with only the FEC subplot.

    if nargin < 10 || isempty(legendLocation)
        legendLocation = 'southwest';
    end
    if nargin < 11 || isempty(yAxisLabel)
        yAxisLabel = '\hat{C}_{RPT} [-]';
    end

    nHighlight = min([numel(cell_plot_list), numel(label_list), numel(colormap_list), numel(Marker_list)]);
    if nHighlight < numel(cell_plot_list)
        warning('Publication plot (FEC only): list lengths differ, using first %d highlighted cells.', nHighlight);
    end

    % Match the GITT/OCP publication figure: axis labels and tick labels at 8 pt.
    % The legend renders visually larger than the axes text in tiledlayout figures,
    % so it is set to 6 pt to match the 8 pt axis text (balanced like the GITT figure).
    pubFontSize = 8;
    pubLegendFontSize = pubFontSize;
    figPub = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2, 2, 8.0962, 3.5190]);
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
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1);
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
        rel_capacity = current_cell.("Capacity [Ah]") / current_cell.("Capacity [Ah]")(1);
        h = plot(axBottom, current_cell.CheckupCapacityFEC, rel_capacity, 'LineWidth', 1.0, 'Color', colormap_list{idx}, 'LineStyle', Marker_list{idx});
        legend_handles = [legend_handles, h]; %#ok<AGROW>
        cellLegendLabel = regexp(label_list{idx}, 'Cell_\d+', 'match', 'once');
        if isempty(cellLegendLabel)
            cellLegendLabel = label_list{idx};
        end
        legend_labels{end+1} = cellLegendLabel; %#ok<AGROW>
        if ~isempty(current_cell.CheckupCapacityFEC)
            maxFEC_highlight = max(maxFEC_highlight, max(current_cell.CheckupCapacityFEC));
        end
    end

    if maxFEC_highlight <= 0
        maxFEC_highlight = maxFEC;
    end

    grid(axBottom, 'on'); box(axBottom, 'on');
    % Dimensionless capacity axis: 0.90 to 1.05.
    ylim(axBottom, [0.90, 1.05]);
    yticks(axBottom, unique(sort([yticks(axBottom), 0.90, 1.05])));
    axBottom.YTickLabel = arrayfun(@(v) sprintf('%.2f', v), axBottom.YTick, 'UniformOutput', false);
    xlim(axBottom, [0, maxFEC_highlight]);
    if ~isempty(plot_title)
        title(axBottom, plot_title, 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    end
    xlabel(axBottom, 'Full Equivalent Cycles [cycles]', 'FontName', 'Times New Roman', 'FontSize', pubFontSize);
    ylabel(axBottom, yAxisLabel, 'FontName', 'Times New Roman', 'FontSize', pubFontSize, 'Interpreter', 'latex');
    set(axBottom, 'FontName', 'Times New Roman', 'FontSize', pubFontSize, 'LineWidth', 0.8);
    axBottom.LabelFontSizeMultiplier = 1.0;
    axBottom.TitleFontSizeMultiplier = 1.0;
    % Legend intentionally omitted per publication request.

    exportgraphics(figPub, pngFilename, 'Resolution', 300);
    exportgraphics(figPub, pdfFilename, 'ContentType', 'vector');
    fprintf('Publication PDF saved: %s\n', pdfFilename);
end
