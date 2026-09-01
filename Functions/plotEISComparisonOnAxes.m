function plottedCount = plotEISComparisonOnAxes(ax, eisRootFolder, targetSoC_pct, maxFreq, cellNum, stageColors, stageMarkers, showTitle)
% plotEISComparisonOnAxes - plot BoL/MoL/EoL Nyquist traces at one SoC on
% a provided axes using publication styling and fixed axis limits.
%
% Overlays whichever life-stage impedance files exist for the selected cell
% (campaign stage folders 1_BOL_EIS / 2_MOL_EIS / 3_EOL_EIS), each holding
% <cellID>_impedanceData.csv. Missing stages are skipped gracefully. This
% is the single drawing routine shared by the in-figure EIS tile and the
% standalone EIS publication export (generateEISComparisonFromPlotEISData).
%
% Inputs:
%   ax            - target axes handle to draw on
%   eisRootFolder - EIS root folder holding the stage subfolders
%   targetSoC_pct - SoC (%) to plot (e.g. 50)
%   maxFreq       - upper frequency limit [Hz] for plotted points
%   cellNum       - cell identifier (selects <cellNum>_impedanceData.csv)
%   stageColors   - 3x3 RGB, one row per stage (BoL, MoL, EoL)
%   stageMarkers  - 1x3 cell of marker specs, one per stage
%   showTitle     - logical; add an "EIS comparison" title when true
%
% Output:
%   plottedCount  - number of stage traces actually drawn
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-07-28 (extracted from PlotCellSummary.m into a shared helper)

stageFolders = {'1_BOL_EIS', '2_MOL_EIS', '3_EOL_EIS'};
stageLabels  = {'BoL', 'MoL', 'EoL'};

hold(ax, 'on');
grid(ax, 'on');
grid(ax, 'minor');
box(ax, 'on');

legendHandles = gobjects(0);
legendLabels  = {};
plottedCount  = 0;

if ~exist(eisRootFolder, 'dir')
    text(ax, 0.5, 0.5, 'EIS root folder not found', ...
        'Units','normalized', 'HorizontalAlignment','center');
    return
end

for stageIdx = 1:numel(stageFolders)
    stageFolder = fullfile(eisRootFolder, stageFolders{stageIdx});
    if ~exist(stageFolder, 'dir')
        continue
    end

    stageCsv = fullfile(stageFolder, [cellNum '_impedanceData.csv']);
    if ~exist(stageCsv, 'file')
        continue
    end

    opts = detectImportOptions(stageCsv);
    opts.DataLines = [2 Inf];
    opts.VariableNamesLine = 1;
    data = readtable(stageCsv, opts);
    colNames = data.Properties.VariableNames;

    rRealCol = '';
    for c = 1:numel(colNames)
        thisCol = colNames{c};
        tok = regexp(thisCol, '^R_real_ohm_SoC(\d+)$', 'tokens', 'once');
        if isempty(tok)
            continue
        end
        thisSoC = str2double(tok{1});
        if isfinite(thisSoC) && abs(thisSoC - targetSoC_pct) < 1e-9
            rRealCol = thisCol;
            break
        end
    end
    if isempty(rRealCol)
        continue
    end

    socSuffix = extractAfter(rRealCol, 'R_real_ohm_SoC');
    rImgCol   = ['R_img_ohm_SoC' socSuffix];
    freqCol   = ['Freq_Hz_SoC'   socSuffix];
    if ~ismember(rImgCol, colNames)
        continue
    end

    rReal = data.(rRealCol);
    rImg  = data.(rImgCol);
    if ismember(freqCol, colNames)
        freq = data.(freqCol);
        validIdx = ~isnan(rReal) & ~isnan(rImg) & ~isnan(freq) & (freq <= maxFreq);
    else
        validIdx = ~isnan(rReal) & ~isnan(rImg);
    end
    rReal = rReal(validIdx);
    rImg  = rImg(validIdx);
    if isempty(rReal)
        continue
    end

    h = plot(ax, rReal, -rImg, '-', ...
        'Color', stageColors(stageIdx,:), ...
        'LineWidth', 1.2, ...
        'Marker', stageMarkers{stageIdx}, ...
        'MarkerSize', 5, ...
        'MarkerFaceColor', stageColors(stageIdx,:), ...
        'MarkerEdgeColor', stageColors(stageIdx,:));

    plottedCount = plottedCount + 1;
    legendHandles(end+1,1) = h; %#ok<AGROW>
    legendLabels{end+1,1} = sprintf('%s (SoC %.0f%%)', stageLabels{stageIdx}, targetSoC_pct); %#ok<AGROW>
end

xlabel(ax, 'R_{real} [\Omega]');
ylabel(ax, '-R_{img} [\Omega]');
xlim(ax, [0.7 3] * 1e-3);
ylim(ax, [-0.4 0.3] * 1e-3);
axis(ax, 'equal');
xlim(ax, [0.7 3] * 1e-3);
ylim(ax, [-0.4 0.3] * 1e-3);
if showTitle
    title(ax, sprintf('EIS comparison (SoC %.0f%%)', targetSoC_pct), 'FontWeight','normal');
end

if ~isempty(legendHandles)
    legend(ax, legendHandles, legendLabels, 'Location', 'best', 'Box', 'off');
else
    text(ax, 0.5, 0.5, sprintf('No EIS traces at SoC %.0f%%', targetSoC_pct), ...
        'Units','normalized', 'HorizontalAlignment','center');
end
end
