function liStrippingFigure(timeWithGaps, voltage, allSegs, stripMetric, params, cellNum, cellLabel, scriptDir, fontName, fontSize)
% liStrippingFigure - self-contained publication figure documenting the
% Li-stripping detection concept (A-002).
% Layout (2x2 tiled, top tile spans 2 columns):
%   Top  full width: full ageing V-trace, with a coloured vertical tick at
%                    the start time of every detected 15-min C/5 post-
%                    charge discharge segment (link to the time series).
%   Bottom-left:     V vs time per segment (time-zeroed), colour by age.
%   Bottom-right:    dV/dt vs time per segment, colour by age, with the
%                    metric window shaded. A smooth curve is roughly flat;
%                    a Li-stripping segment shows a clear bump whose
%                    peak-to-trough magnitude is the per-segment metric.
%
% Inputs:
%   timeWithGaps - datetime array (NaT at gaps)
%   voltage      - voltage array [V]
%   allSegs      - cell array of segment structs (from extractDVdtSegmentsAll)
%   stripMetric  - per-segment Li-stripping metric vector [V/s]
%   params       - struct with field metricWin_s = [t1 t2] (seconds)
%   cellNum      - cell identifier string
%   cellLabel    - descriptive label (may be empty)
%   scriptDir    - directory of the calling script (PNG saved to ../pngs)
%   fontName     - publication font (R-019)
%   fontSize     - base font size (R-017)
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-07-28 (extracted from PlotCellSummary.m into a shared helper)

nSeg = numel(allSegs);
if nSeg == 0
    fprintf('[liStrippingFigure] No segments to plot; figure skipped.\n');
    return
end

% Colour by chronological position (parula = perceptually uniform)
cols = parula(max(nSeg, 2));

% Figure: double-column A4 width (17.4 cm), height tuned for readability
fig = figure('Name', sprintf('Li-stripping [%s]', cellNum), ...
    'NumberTitle','off', 'Color','w', ...
    'Units','centimeters', 'Position',[2 2 17.4 14]);
fig.PaperPositionMode = 'auto';
tl = tiledlayout(fig, 2, 2, 'TileSpacing','compact','Padding','compact');
if isempty(cellLabel)
    title(tl, sprintf('Li-stripping diagnostic  -  %s', cellNum), ...
        'FontName', fontName, 'FontSize', fontSize+1, 'Interpreter','none');
else
    title(tl, sprintf('Li-stripping diagnostic  -  %s (%s)', cellNum, cellLabel), ...
        'FontName', fontName, 'FontSize', fontSize+1, 'Interpreter','none');
end

% --- Row 1 (full width): ageing V trace + segment tick markers ---
ax_top = nexttile(tl, 1, [1 2]);
plot(ax_top, timeWithGaps, voltage, '-', ...
    'Color', [0.4 0.4 0.4], 'LineWidth', 0.4);
hold(ax_top, 'on');
yl = [2.5 4.5];
ylim(ax_top, yl);
for i = 1:nSeg
    t0 = allSegs{i}.startTime;
    plot(ax_top, [t0 t0], yl, '-', ...
        'Color', cols(i,:), 'LineWidth', 0.8, 'HandleVisibility','off');
end
xlabel(ax_top, 'Date');
ylabel(ax_top, 'Voltage [V]');  % R-020
title(ax_top, sprintf('Full ageing trace  -  %d post-charge C/5 discharge segments detected', nSeg), ...
    'FontWeight','normal');
grid(ax_top, 'on'); box(ax_top, 'on');

% --- Row 2 left: V vs time (per segment, time-zeroed) ---
ax_V = nexttile(tl, 3);
hold(ax_V, 'on');
for i = 1:nSeg
    plot(ax_V, allSegs{i}.timeS_interp, allSegs{i}.voltage_interp, '-', ...
        'Color', cols(i,:), 'LineWidth', 0.6);
end
xlim(ax_V, [0 max(500, params.metricWin_s(2) + 50)]);
xlabel(ax_V, 'Time after charge end [s]');
ylabel(ax_V, 'Voltage [V]');  % R-020
title(ax_V, 'C/5 discharge after fast charge', 'FontWeight','normal');
grid(ax_V, 'on'); box(ax_V, 'on');

% --- Row 2 right: dV/dt vs time, with metric window shaded ---
% Clip the y-axis to the Li-stripping-relevant range so the bump is visible;
% the IR-drop transient in the first ~20 s is intentionally out of frame.
ax_dV = nexttile(tl, 4);
hold(ax_dV, 'on');
dVdtYRange = [-0.005, 0.0005];   % V/s, publication-relevant window
p = patch(ax_dV, ...
    'XData', [params.metricWin_s(1) params.metricWin_s(2) params.metricWin_s(2) params.metricWin_s(1)], ...
    'YData', [dVdtYRange(1) dVdtYRange(1) dVdtYRange(2) dVdtYRange(2)], ...
    'FaceColor', [1 0.85 0.2], 'FaceAlpha', 0.15, ...
    'EdgeColor','none', 'HandleVisibility','off');
uistack(p, 'bottom');
for i = 1:nSeg
    plot(ax_dV, allSegs{i}.timeS_interp, allSegs{i}.dVdt_Vpers, '-', ...
        'Color', cols(i,:), 'LineWidth', 0.6);
end
xlim(ax_dV, [0 max(500, params.metricWin_s(2) + 50)]);
ylim(ax_dV, dVdtYRange);
xlabel(ax_dV, 'Time after charge end [s]');
ylabel(ax_dV, 'dV/dt [V/s]');  % R-020
title(ax_dV, sprintf('dV/dt  -  metric = max-min over [%g, %g] s window', ...
    params.metricWin_s(1), params.metricWin_s(2)), 'FontWeight','normal');
grid(ax_dV, 'on'); box(ax_dV, 'on');

% Shared colourbar (date axis) so the reader can map any line back to a date
startDates = NaT(nSeg, 1);
for i = 1:nSeg; startDates(i) = allSegs{i}.startTime; end
cb = colorbar(ax_dV, 'eastoutside');
colormap(ax_dV, parula(max(nSeg, 2)));
if nSeg > 1
    caxis(ax_dV, [1 nSeg]);
    nTicks = min(5, nSeg);
    tickIdx = round(linspace(1, nSeg, nTicks));
    cb.Ticks = tickIdx;
    cb.TickLabels = arrayfun(@(k) datestr(startDates(k), 'yyyy-mm-dd'), tickIdx, ...
        'UniformOutput', false);
end
cb.Label.String = 'Segment date';
cb.Label.FontName = fontName;
cb.Label.FontSize = fontSize;

% Per-segment metric annotation (mean / min / max) on the V panel so it is
% not occluded by the colorbar attached to the dV/dt panel.
finiteMask = ~isnan(stripMetric);
if any(finiteMask)
    txt = sprintf('Metric: mean=%.3f mV/s, min=%.3f mV/s, max=%.3f mV/s', ...
        1000 * mean(stripMetric(finiteMask)), ...
        1000 * min(stripMetric(finiteMask)),  ...
        1000 * max(stripMetric(finiteMask)));
    text(ax_V, 0.02, 0.04, txt, 'Units','normalized', ...
        'VerticalAlignment','bottom', 'FontName', fontName, ...
        'FontSize', fontSize-1, 'Color',[0.2 0.2 0.2]);
end

% Apply publication font to every axis (defensive, R-017/R-019)
allAxes = findall(fig, 'Type','axes');
for k = 1:numel(allAxes)
    set(allAxes(k), 'FontName', fontName, 'FontSize', fontSize, ...
        'TickLabelInterpreter','tex');
end

% Save as PNG (300 dpi) in pngs/. Vector PDF export is currently disabled
% for this figure: with ~25 segments x dense per-segment curves it is far
% too heavy (large file, slow render). Re-enable once the segment data
% is decimated for the publication version. (A-002)
pngsDir = fullfile(scriptDir, '..', 'pngs');
if ~exist(pngsDir, 'dir'); mkdir(pngsDir); end
pngFile = fullfile(pngsDir, [cellNum '_LiStripping.png']);
drawnow;
exportgraphics(fig, pngFile, 'Resolution', 300);
% pdfFile = fullfile(pngsDir, [cellNum '_LiStripping.pdf']);
% exportgraphics(fig, pdfFile, 'ContentType', 'vector');
fprintf('Li-stripping figure saved:\n  %s\n', pngFile);
end
