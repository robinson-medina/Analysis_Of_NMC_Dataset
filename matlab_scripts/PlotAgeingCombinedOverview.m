%% PlotAgeingCombinedOverview.m
% Summary: Builds the two combined ageing overview figures. Each figure stacks
%          capacity degradation above resistance increase for the same selected
%          cells, using full equivalent cycles for cyclic ageing and elapsed
%          days for calendar ageing.
%
% Usage: Set DataRoot if needed, then run this script with no arguments. The
%        required overview CSV tables are read from the cyclic and calendar
%        ageing data folders.
%
% Outputs: CyclicAgeing.png, CyclicAgeing.pdf, CalendarAgeing.png, and
%          CalendarAgeing.pdf in this script's R-022 output directory.
%
% Authors: NEXTBMS Team.
% Dependency files: Functions/getFigureOutputDir.m, Functions/plotAgeingPanel.m.
% Last documented: 2026-09-01

clear; close all; clc;

%% Paths
% Single configurable dataset root. Read-only (R-001).
DataRoot = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
io_folder_cyclic   = fullfile(DataRoot, '4_Ageing', 'Cyclic_ageing_data');
io_folder_calendar = fullfile(DataRoot, '4_Ageing', 'Calendar_ageing_data');
scriptDir = fileparts(mfilename('fullpath'));
functionsDir = fullfile(scriptDir, '..', '..', 'Functions');
if ~exist(fullfile(functionsDir, 'getFigureOutputDir.m'), 'file')
    functionsDir = fullfile(scriptDir, '..', 'Functions');
end
if exist(functionsDir, 'dir')
    addpath(functionsDir);
else
    error('Shared Functions folder not found from %s.', scriptDir);
end
pngsDir   = getFigureOutputDir('PlotAgeingCombinedOverview'); % R-022

%% Load + preprocess the four overview tables
capCyclic   = loadOverview(fullfile(io_folder_cyclic,   'OverviewCapacityData_36cell.csv'),   'capacity');
capCalendar = loadOverview(fullfile(io_folder_calendar, 'OverviewCapacityData_5cell.csv'),    'capacity');
resCyclic   = loadOverview(fullfile(io_folder_cyclic,   'OverviewResistanceData_36cell.csv'), 'resistance');
resCalendar = loadOverview(fullfile(io_folder_calendar, 'OverviewResistanceData_5cell.csv'),  'resistance');

%% Shared publication style (R-017/R-019/R-021)
PUB_FONT = 'Times New Roman';
PUB_FONTSIZE = 8;
LW_AXES = 0.8;
green    = [12 195 82]  ./ 255;
darkblue = [1  17 181]  ./ 255;
red      = [255 0   0]  ./ 255;
magenta  = [255 0 255]  ./ 255;
black    = [0 0 0];

RES_SCALE = 1000;                                  % Ohm -> mOhm
CAP_YLIM  = [0.90 1.05];
RES_YLIM  = [1.10 9.00];
CAP_YLABEL = '$\tilde{C}_{RPT}\,[-]$';
RES_YLABEL = '$\vphantom{\tilde{C}}R_{RPT}\,[\mathrm{m}\Omega]$';   % \vphantom matches C-tilde height

% Panel geometry: same format as the OCV figure (R-023: 3.5190 cm plot boxes).
W_CM = 9.35; H_CM = 9.6;   % width tuned for 97% of columnwidth after tight cropping; height keeps R-023 fixed panel boxes
PANEL_H_CM = 3.5190;
leftM = 1.45; rightM = 0.30; botM = 1.20; gap = 1.05;
plotW = W_CM - leftM - rightM;

%% Figure configurations (cyclic + calendar)
cfg = cell(1, 2);
cfg{1} = struct( ...
    'name',      'CyclicAgeing', ...
    'capDf',     capCyclic, 'resDf', resCyclic, ...
    'cellsHi',   {{'Cell_12', 'Cell_23', 'Cell_34', 'Cell_35'}}, ...
    'colors',    {{green, darkblue, red, magenta}}, ...
    'labels',    {{'Cell_12 - C/2 - C/2', 'Cell_23 - 1C - C/2', ...
                   'Cell_34 - 3C/2 - C/2', 'Cell_35 - 2C - C/2'}}, ...
    'xMode',     'fec', ...
    'xLabel',    'Full Equivalent Cycles [cycles]', ...
    'xLimFixed', [], ...
    'legendLoc', 'northeast');
cfg{2} = struct( ...
    'name',      'CalendarAgeing', ...
    'capDf',     capCalendar, 'resDf', resCalendar, ...
    'cellsHi',   {{'Cell_57', 'Cell_11', 'Cell_45', 'Cell_26', 'Cell_28'}}, ...
    'colors',    {{green, darkblue, red, magenta, black}}, ...
    'labels',    {{'Cell_57 | 0 degC | Avg SoC 100%', 'Cell_11 | 25 degC | Avg SoC 100%', ...
                   'Cell_45 | 45 degC | Avg SoC 10%', 'Cell_26 | 45 degC | Avg SoC 50%', ...
                   'Cell_28 | 45 degC | Avg SoC 100%'}}, ...
    'xMode',     'time', ...
    'xLabel',    'Time [days]', ...
    'xLimFixed', [0 400], ...
    'legendLoc', 'northwest');

styleAx = {'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE, 'LineWidth', LW_AXES, ...
    'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1};

fprintf('--- PlotAgeingCombinedOverview: starting figure generation ---\n');

%% Build both figures
for f = 1:numel(cfg)
    c = cfg{f};
    markers = repmat({'-'}, 1, numel(c.cellsHi));
    capCells = unique(c.capDf.('cell_number'));
    resCells = unique(c.resDf.('cell_number'));

    figH = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 W_CM H_CM]);

    % --- (a) capacity degradation (top) ---
    axCap = axes(figH, 'Units', 'centimeters', 'PositionConstraint', 'innerposition', ...
        'InnerPosition', [leftM, botM + PANEL_H_CM + gap, plotW, PANEL_H_CM]);
    [~, maxXcap] = plotAgeingPanel(axCap, c.capDf, capCells, c.cellsHi, c.colors, markers, ...
        c.xMode, 'capacity', 1);
    ylabel(axCap, CAP_YLABEL, 'Interpreter', 'latex');
    ylim(axCap, CAP_YLIM);
    yticks(axCap, unique(sort([yticks(axCap), CAP_YLIM])));
    axCap.YTickLabel = arrayfun(@(v) sprintf('%.2f', v), axCap.YTick, 'UniformOutput', false);
    set(axCap, 'YMinorTick', 'off'); grid(axCap, 'on'); box(axCap, 'on'); set(axCap, styleAx{:});
    text(axCap, 0.02, 0.93, '(a)', 'Units', 'normalized', 'FontName', PUB_FONT, ...
        'FontSize', PUB_FONTSIZE, 'FontWeight', 'bold');

    % --- (b) resistance increase (bottom) ---
    axRes = axes(figH, 'Units', 'centimeters', 'PositionConstraint', 'innerposition', ...
        'InnerPosition', [leftM, botM, plotW, PANEL_H_CM]);
    [hRes, maxXres] = plotAgeingPanel(axRes, c.resDf, resCells, c.cellsHi, c.colors, markers, ...
        c.xMode, 'resistance', RES_SCALE);
    ylabel(axRes, RES_YLABEL, 'Interpreter', 'latex');
    xlabel(axRes, c.xLabel);
    ylim(axRes, RES_YLIM);
    yticks(axRes, unique(sort([yticks(axRes), RES_YLIM])));
    axRes.YTickLabel = arrayfun(@(v) sprintf('%.2f', v), axRes.YTick, 'UniformOutput', false);
    set(axRes, 'YMinorTick', 'off'); grid(axRes, 'on'); box(axRes, 'on'); set(axRes, styleAx{:});
    text(axRes, 0.02, 0.93, '(b)', 'Units', 'normalized', 'FontName', PUB_FONT, ...
        'FontSize', PUB_FONTSIZE, 'FontWeight', 'bold');

    % Shared x-limits across both panels.
    if strcmp(c.xMode, 'fec')
        xm = max(maxXcap, maxXres);
        if xm <= 0; xm = 1; end
        xlim(axCap, [0 xm]); xlim(axRes, [0 xm]);
    else
        xlim(axCap, c.xLimFixed); xlim(axRes, c.xLimFixed);
        xticks(axCap, unique(sort([xticks(axCap), c.xLimFixed])));
        xticks(axRes, unique(sort([xticks(axRes), c.xLimFixed])));
    end

    % One shared legend, top of the bottom panel (more white space there;
    % same cells/colours apply to both panels).
    legend(axRes, hRes, c.labels, 'Interpreter', 'none', 'Location', c.legendLoc, ...
        'Box', 'off', 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE);

    % Vector PDF + PNG (R-018/R-022); disable axes toolbars to avoid raster artifact.
    figH.PaperPositionMode = 'auto';
    for ax = findall(figH, 'Type', 'axes')'
        if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar); ax.Toolbar.Visible = 'off'; end
    end
    pngFile = fullfile(pngsDir, sprintf('%s.png', c.name));
    pdfFile = fullfile(pngsDir, sprintf('%s.pdf', c.name));
    exportgraphics(figH, pngFile, 'Resolution', 300);
    exportgraphics(figH, pdfFile, 'ContentType', 'vector');
    fprintf('Wrote %s\n', pdfFile);
end

fprintf('--- PlotAgeingCombinedOverview: figure generation complete ---\n');

%% Local loader: read one overview CSV and normalise its column names
function df = loadOverview(csvPath, quantity)
    df = readtable(csvPath, 'VariableNamingRule', 'preserve');
    df = renameIfExists(df, 'CellNum', 'cell_number');
    switch lower(quantity)
        case 'capacity'
            df = renameIfExists(df, 'CheckupCapacityTimeStamp', 'Timestamp');
            df = renameIfExists(df, 'CheckupCapacity_Ah', 'Capacity [Ah]');
        case 'resistance'
            df = renameIfExists(df, 'CheckupResistanceTimeStamp', 'Timestamp');
            df = renameIfExists(df, 'CheckupResistance_Ohm', 'Resistance [Ohm]');
    end
    df.('cell_number') = regexp(string(df.('cell_number')), 'Cell_\d+', 'match', 'once');
    df.('Timestamp') = datetime(df.('Timestamp'), 'InputFormat', 'dd-MMM-yyyy HH:mm:ss');
end

function df = renameIfExists(df, oldName, newName)
    idx = strcmp(df.Properties.VariableNames, oldName);
    if any(idx); df.Properties.VariableNames{find(idx, 1)} = newName; end
end
