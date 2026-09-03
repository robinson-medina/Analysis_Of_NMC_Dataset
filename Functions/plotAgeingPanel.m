function [handles, maxXHighlight] = plotAgeingPanel(ax, df, cellListAll, cellPlotList, colorList, markerList, xMode, yMode, resistanceScale)
%PLOTAGEINGPANEL Draw one ageing-overview panel (capacity or resistance) into an axis.
%   Plots every cell in cellListAll as a faint grey background trace, then the
%   highlighted cells (cellPlotList) as coloured traces. Shared by the merged
%   capacity-degradation / resistance-increase ageing figures.
%
%   Inputs:
%     ax             target axes (already created/positioned by the caller)
%     df             preprocessed table (cell_number, Timestamp, quantity + FEC cols)
%     cellListAll    all cell names to draw faint in the background
%     cellPlotList   highlighted cell names (draw order == legend order)
%     colorList      cell array of RGB triplets, one per highlighted cell
%     markerList     cell array of line styles, one per highlighted cell
%     xMode          'time' -> days since first sample; 'fec' -> equivalent cycles
%     yMode          'capacity' -> C/C0 (dimensionless); 'resistance' -> Ohm*scale
%     resistanceScale multiplier for resistance (e.g. 1000 for mOhm); default 1
%
%   Outputs:
%     handles        highlighted line handles (for a shared legend)
%     maxXHighlight  max x across highlighted cells (for a common xlim)
%
% Author: NEXTBMS Team
% Date: 2026-08-12

    if nargin < 9 || isempty(resistanceScale); resistanceScale = 1; end

    switch lower(yMode)
        case 'capacity';   fecCol = 'CheckupCapacityFEC';
        case 'resistance'; fecCol = 'CheckupResistanceFEC';
        otherwise; error('plotAgeingPanel:yMode', 'yMode must be capacity or resistance.');
    end

    LW_DATA = 1.0;                 % R-017: data traces 1.0 pt
    greyCol = [0.75 0.75 0.75];    % faint background cells

    hold(ax, 'on');

    % Faint background: every cell in the dataset.
    for i = 1:numel(cellListAll)
        cur = df(strcmp(df.('cell_number'), cellListAll{i}), :);
        if isempty(cur); continue; end
        [x, y] = localXY(cur, xMode, yMode, fecCol, resistanceScale);
        plot(ax, x, y, '-', 'LineWidth', LW_DATA, 'Color', greyCol, 'HandleVisibility', 'off');
    end

    % Highlighted cells (deterministic colour/order for the shared legend).
    handles = gobjects(1, numel(cellPlotList));
    maxXHighlight = 0;
    for idx = 1:numel(cellPlotList)
        cur = df(strcmp(df.('cell_number'), cellPlotList{idx}), :);
        if isempty(cur)
            warning('plotAgeingPanel:missingCell', 'Cell %s not found.', cellPlotList{idx});
            continue;
        end
        [x, y] = localXY(cur, xMode, yMode, fecCol, resistanceScale);
        handles(idx) = plot(ax, x, y, markerList{idx}, 'LineWidth', LW_DATA, 'Color', colorList{idx});
        if ~isempty(x); maxXHighlight = max(maxXHighlight, max(x)); end
    end
    handles = handles(isgraphics(handles));
end

function [x, y] = localXY(cur, xMode, yMode, fecCol, resistanceScale)
    switch lower(xMode)
        case 'time'; x = days(cur.('Timestamp') - cur.('Timestamp')(1));
        case 'fec';  x = cur.(fecCol);
        otherwise; error('plotAgeingPanel:xMode', 'xMode must be time or fec.');
    end
    switch lower(yMode)
        case 'capacity';   y = cur.('Capacity [Ah]') / cur.('Capacity [Ah]')(1);
        case 'resistance'; y = cur.('Resistance [Ohm]') * resistanceScale;
    end
end
