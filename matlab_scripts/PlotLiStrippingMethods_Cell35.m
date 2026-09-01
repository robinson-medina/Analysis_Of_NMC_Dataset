%% PlotLiStrippingMethods_Cell35.m
% Summary: Builds the two-panel Li-stripping methods figure for Cell_35. The
%          figure compares a low-alpha segment with a clean diffusion-like
%          segment using voltage and dV/dt traces over the same analysis window.
%
% Usage: Set DataRoot if needed, then run this script with no arguments. The
%        segment selection is fixed to Cell_35.
%
% Outputs: LiStrippingMethods.png and LiStrippingMethods.pdf in this script's
%          R-022 output directory.
%
% Authors: Feye Hoekstra, GitHub Copilot.
% Dependency files: Functions/loadAndPreprocessAgeingCsv.m,
%                   Functions/extractDVdtSegmentsAll.m,
%                   Functions/getFigureOutputDir.m.
% Last documented: 2026-09-01

clear; close all; clc;

%% Configuration
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

% Single configurable dataset root (Zenodo layout, R-001 read-only), same
% convention as PlotCellSummary.m/ExtractAgeingData.m.
DataRoot      = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
DesiredFolder = fullfile(DataRoot, '4_Ageing', 'Cyclic_ageing_data');
cellNum       = 'Cell_35';    % fixed single-cell methods illustration
fastChargeI_A = -11.6;        % target post-charge C/5 discharge current (matches PlotCellSummary.m)
smoothWin  = 11;              % movmean window for this figure's dV/dt display (independent of the per-site strippingSmoothWin used in PlotCellSummary.m)
fitWin_s   = [30 400];        % analysis window [s]
alphaGrid  = 0.10:0.02:2.00;  % grid for the alpha grid search

% Segment-detection parameters for Functions/extractDVdtSegmentsAll.m (same
% criteria as PlotCellSummary.m's Li-stripping panel and the retired
% misc/EvaluateStrippingMetrics.m cache generator).
segParams = struct( ...
    'tolerance_A',      0.1, ...
    'minSegmentLength', 900, ...
    'maxSegmentLength', 1500, ...
    'smoothWin',        smoothWin);

% Publication palette / fonts (R-017, R-019)
COL_BLUE  = [0.10 0.30 0.70]; % "no stripping" / alpha ~ 1
COL_RED   = [0.78 0.20 0.15]; % "stripping"    / alpha << 1
COL_GREY  = [0.45 0.45 0.45];
COL_BAND  = [0.92 0.92 0.92];
PUB_FONT     = 'Times New Roman';
% POC sizing: the paper imports these PDFs at natural size (no \includegraphics
% width), so there is NO LaTeX scaling and the values below are the exact
% rendered size in the paper.
%   * PUB_FONTSIZE = paper caption font (elsarticle \footnotesize = 8 pt) ->
%     figure text matches the (sub)caption text 1:1.
%   * FIG_W_CM is tuned so the tight-cropped exported PDF width equals 97 % of
%     the column width (0.97 x 252 pt = 244.4 pt = 8.59 cm), R-021 (2026-08-12).
PUB_FONTSIZE = 8;
FIG_W_CM     = 9.29;   % tuned so exported width ~= 244.4 pt (97 % column)
FIG_H_CM     = 7.40;   % total height of the stacked two-panel figure
set(groot, 'defaultAxesFontName', PUB_FONT);
set(groot, 'defaultTextFontName', PUB_FONT);
set(groot, 'defaultLegendFontName', PUB_FONT);
set(groot, 'defaultColorbarFontName', PUB_FONT);
set(groot, 'defaultAxesFontSize', PUB_FONTSIZE);

%% Load Cell_35's CSV and extract raw segments (no cache; matches the Python port)
loadName = fullfile(DesiredFolder, cellNum, [cellNum '.csv']);
fprintf('Loading %s ... ', cellNum); tic;
[timeWithGaps, timeS, voltage, current] = loadAndPreprocessAgeingCsv(loadName);
fprintf('done (%.1f s)\n', toc);

% Analysis window: full trace minus the last 20 samples (matches
% PlotCellSummary.m/ExtractAgeingData.m convention).
startTime = datetime(timeWithGaps(1));
endTime   = datetime(timeWithGaps(end-20));
sel = (timeWithGaps >= startTime) & (timeWithGaps <= endTime);
selectedTime    = timeWithGaps(sel);
selectedVoltage = voltage(sel);
selectedCurrent = current(sel);
selectedTimeS   = timeS(sel);

rawSegs = extractDVdtSegmentsAll( ...
    selectedTime, selectedVoltage, selectedCurrent, selectedTimeS, ...
    fastChargeI_A, segParams);
nSeg    = numel(rawSegs);
fprintf('Extracted %d post-charge C/5 discharge segments.\n', nSeg);

alphas = NaN(nSeg, 1);
coefs  = NaN(nSeg, 2);
fprintf('Fitting alpha for every segment ... ');
for k = 1:nSeg
    seg = rawSegs{k};
    t = seg.timeS_interp;
    V = seg.voltage_interp;
    if numel(t) < 2; continue; end
    dVdt = movmean(gradient(V) ./ gradient(t), smoothWin);
    m = (t >= fitWin_s(1)) & (t <= fitWin_s(2)) & ~isnan(dVdt);
    if nnz(m) < 10; continue; end
    tw = t(m); yw = dVdt(m);
    bestRss = Inf;
    for a = alphaGrid
        A = [ones(numel(tw),1), tw.^(-a)];
        c = A \ yw;
        r = yw - A*c;
        rss = sum(r.^2);
        if rss < bestRss
            bestRss    = rss;
            alphas(k)  = a;
            coefs(k,:) = c(:).';
        end
    end
end
fprintf('done.\n');

%% Pick example segments: one with alpha << 1, one with alpha ~ 1
% Restrict candidates by chronological position:
%   * low-alpha example must come from the first quarter of the cell's life
%     (early-life plating regime, before mid-life impedance suppresses
%     plating).
%   * alpha~1 example must come from the middle half (steady mid-life).
earlyMask = false(nSeg,1); earlyMask(1:round(nSeg/4))    = true;
midMask   = false(nSeg,1); midMask(round(nSeg/4)+1:round(3*nSeg/4)) = true;

aEarly = alphas; aEarly(~earlyMask) = NaN;
[~, idxLow] = min(aEarly);
aMid = abs(alphas - 1); aMid(~midMask) = NaN;
[~, idxUnity] = min(aMid);

fprintf('Low-alpha example:   segment %d, alpha = %.2f, start = %s\n', ...
    idxLow, alphas(idxLow), datestr(rawSegs{idxLow}.startTime));
fprintf('Alpha-~1 example:    segment %d, alpha = %.2f, start = %s\n', ...
    idxUnity, alphas(idxUnity), datestr(rawSegs{idxUnity}.startTime));

%% Prepare display arrays for both example segments
[tL, VL, dL, tFitL, yFitL] = local_prepSegment(rawSegs{idxLow},   coefs(idxLow,:),   alphas(idxLow),   smoothWin, fitWin_s);
[tU, VU, dU, tFitU, yFitU] = local_prepSegment(rawSegs{idxUnity}, coefs(idxUnity,:), alphas(idxUnity), smoothWin, fitWin_s);

%% One two-panel figure: (a) V vs t on top, (b) dV/dt below (R-024)
fig = figure('Units','centimeters','Position',[2 2 FIG_W_CM FIG_H_CM], 'Color','w');
fig.PaperPositionMode = 'auto';
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

% ---- Panel (a): V vs t for both segments ----
ax_a = nexttile(tl);
hold(ax_a, 'on');
allV = [VL(:); VU(:)];
yl_a = [min(allV) max(allV)];
yl_a = yl_a + [-0.05 0.05] * (yl_a(2)-yl_a(1));
patch(ax_a, [fitWin_s(1) fitWin_s(2) fitWin_s(2) fitWin_s(1)], ...
            [yl_a(1) yl_a(1) yl_a(2) yl_a(2)], COL_BAND, ...
            'EdgeColor','none', 'HandleVisibility','off');
hU = plot(ax_a, tU, VU, 'Color', COL_BLUE, 'LineWidth', 1.0);
hL = plot(ax_a, tL, VL, 'Color', COL_RED,  'LineWidth', 1.0);
xlim(ax_a, [0 max(max(tL), max(tU))]);
ylim(ax_a, yl_a);
% Shared x quantity with panel (b): x-label on the bottom panel only (R-024).
ylabel(ax_a, 'Voltage [V]', 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE);
grid(ax_a, 'on'); box(ax_a, 'on');
legend(ax_a, [hU, hL], ...
    {sprintf('mid-life, \\alpha = %.2f (no stripping)', alphas(idxUnity)), ...
     sprintf('early life, \\alpha = %.2f (stripping)',  alphas(idxLow))}, ...
    'Location','northeast', 'Box','off', 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE);
text(ax_a, mean(fitWin_s), yl_a(1) + 0.04*(yl_a(2)-yl_a(1)), 'analysis window', ...
    'HorizontalAlignment','center', 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE-2, ...
    'FontAngle','italic', 'Color', COL_GREY);
text(ax_a, 0.02, 0.94, '(a)', 'Units','normalized', ...
    'HorizontalAlignment','left', 'VerticalAlignment','top', ...
    'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE);

% ---- Panel (b): dV/dt with power-law fits ----
ax_b = nexttile(tl);
hold(ax_b, 'on');
mL = (tL >= fitWin_s(1)) & (tL <= fitWin_s(2));
mU = (tU >= fitWin_s(1)) & (tU <= fitWin_s(2));
allD = [dL(mL); dU(mU)] * 1e3;
yl_b = [min(allD) max(allD)];
yl_b = yl_b + [-0.20 0.20] * (yl_b(2)-yl_b(1));
patch(ax_b, [fitWin_s(1) fitWin_s(2) fitWin_s(2) fitWin_s(1)], ...
            [yl_b(1) yl_b(1) yl_b(2) yl_b(2)], COL_BAND, ...
            'EdgeColor','none', 'HandleVisibility','off');
hUdat = plot(ax_b, tU, dU*1e3, '-',  'Color', COL_BLUE, 'LineWidth', 1.0);
hLdat = plot(ax_b, tL, dL*1e3, '-',  'Color', COL_RED,  'LineWidth', 1.0);
hUfit = plot(ax_b, tFitU, yFitU*1e3, '--', 'Color', COL_BLUE * 0.6, 'LineWidth', 0.8);
hLfit = plot(ax_b, tFitL, yFitL*1e3, '--', 'Color', COL_RED  * 0.6, 'LineWidth', 0.8);
xlim(ax_b, [0 max(max(tL), max(tU))]);
ylim(ax_b, yl_b);
xlabel(ax_b, 'Time since current step [s]', 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE);
ylabel(ax_b, 'dV/dt [mV/s]', 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE);
grid(ax_b, 'on'); box(ax_b, 'on');
legend(ax_b, [hUdat, hUfit, hLdat, hLfit], ...
    {'mid-life data', ...
     sprintf('fit, \\alpha = %.2f', alphas(idxUnity)), ...
     'early-life data', ...
     sprintf('fit, \\alpha = %.2f', alphas(idxLow))}, ...
    'Location','best', 'Box','off', 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE, ...
    'NumColumns', 2);
text(ax_b, mean(fitWin_s), yl_b(1) + 0.04*(yl_b(2)-yl_b(1)), 'analysis window', ...
    'HorizontalAlignment','center', 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE-2, ...
    'FontAngle','italic', 'Color', COL_GREY);
text(ax_b, 0.02, 0.94, '(b)', 'Units','normalized', ...
    'HorizontalAlignment','left', 'VerticalAlignment','top', ...
    'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE);

%% Apply publication font / size to every axes (defensive, R-017/R-019)
% LabelFontSizeMultiplier/TitleFontSizeMultiplier forced to 1 so axis labels are
% the SAME size as tick labels and the paper body (default 1.1 makes them bigger).
allAxes = findall(fig, 'Type','axes');
for k = 1:numel(allAxes)
    set(allAxes(k), 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE, ...
        'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1, ...
        'LineWidth', 0.8, ...   % R-017 item 4: axes frame (0.8 pt), not a data trace
        'TickLabelInterpreter','tex');
end

%% Save the two-panel figure (PNG + vector PDF in pngs/), R-018 / R-024
pngsDir = getFigureOutputDir('PlotLiStrippingMethods_Cell35');
drawnow;
pngFile = fullfile(pngsDir, 'LiStrippingMethods.png');
pdfFile = fullfile(pngsDir, 'LiStrippingMethods.pdf');
exportgraphics(fig, pngFile, 'Resolution', 300);
exportgraphics(fig, pdfFile, 'ContentType', 'vector');
fprintf('\nMethods figure saved:\n  %s\n  %s\n', pngFile, pdfFile);

%% Restore default groot settings
set(groot, 'defaultAxesFontName',     'remove');
set(groot, 'defaultTextFontName',     'remove');
set(groot, 'defaultLegendFontName',   'remove');
set(groot, 'defaultColorbarFontName', 'remove');
set(groot, 'defaultAxesFontSize',     'remove');


%% ====================== LOCAL HELPER FUNCTIONS =========================

function [t, V, dVdt, tFit, yFit] = local_prepSegment(seg, coef, alpha, smoothWin, fitWin_s)
% local_prepSegment - return interpolated V, smoothed dV/dt and the
% evaluated power-law fit for a single segment.
t = seg.timeS_interp;
V = seg.voltage_interp;
dVdt = movmean(gradient(V) ./ gradient(t), smoothWin);
tFit = linspace(fitWin_s(1), fitWin_s(2), 400)';
yFit = coef(1) + coef(2) * tFit.^(-alpha);
end
