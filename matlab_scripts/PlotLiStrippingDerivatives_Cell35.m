%% PlotLiStrippingDerivatives_Cell35.m
% Summary: Compares dV/dt, dV/dQ, and dQ/dV signatures for two selected Cell_35
%          post-fast-charge C/5 discharge segments. The panels show how the same
%          stripping shoulder appears in time, capacity-normalised voltage
%          slope, and differential-capacity representations.
%
% Usage: Set DataRoot if needed, then run this script with no arguments. The
%        segment selection is fixed to Cell_35.
%
% Outputs: LiStrippingDerivatives.png and LiStrippingDerivatives.pdf in this
%          script's R-022 output directory.
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
% convention as PlotLiStrippingMethods_Cell35.m.
DataRoot      = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
DesiredFolder = fullfile(DataRoot, '4_Ageing', 'Cyclic_ageing_data');
cellNum       = 'Cell_35';
fastChargeI_A = -11.6;        % target post-charge C/5 discharge current (matches PlotCellSummary.m)
smoothWin  = 11;              % movmean window (matches PlotLiStrippingMethods_Cell35.m)
fitWin_s   = [30 400];        % analysis window [s]
alphaGrid  = 0.10:0.02:2.00;  % grid for the alpha grid search
I_target_A = -11.6;           % nominal C/5 current used to convert t -> Q

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
PUB_FONTSIZE = 10;
set(groot, 'defaultAxesFontName', PUB_FONT);
set(groot, 'defaultTextFontName', PUB_FONT);
set(groot, 'defaultLegendFontName', PUB_FONT);
set(groot, 'defaultColorbarFontName', PUB_FONT);
set(groot, 'defaultAxesFontSize', PUB_FONTSIZE);

%% Load Cell_35's CSV and extract raw segments (no cache; matches PlotLiStrippingMethods_Cell35.m)
% (identical logic to PlotLiStrippingMethods_Cell35.m so the chosen example
% segments line up with that figure).
loadName = fullfile(DesiredFolder, cellNum, [cellNum '.csv']);
fprintf('Loading %s ... ', cellNum); tic;
[timeWithGaps, timeS, voltage, current] = loadAndPreprocessAgeingCsv(loadName);
fprintf('done (%.1f s)\n', toc);

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
            bestRss   = rss;
            alphas(k) = a;
        end
    end
end

earlyMask = false(nSeg,1); earlyMask(1:round(nSeg/4))    = true;
midMask   = false(nSeg,1); midMask(round(nSeg/4)+1:round(3*nSeg/4)) = true;
aEarly = alphas; aEarly(~earlyMask) = NaN;
[~, idxLow] = min(aEarly);
aMid = abs(alphas - 1); aMid(~midMask) = NaN;
[~, idxUnity] = min(aMid);

fprintf('Low-alpha example:   segment %d, alpha = %.2f\n', idxLow,   alphas(idxLow));
fprintf('Alpha-~1 example:    segment %d, alpha = %.2f\n', idxUnity, alphas(idxUnity));

%% Compute derivatives in all three representations
[tL, VL, QL, dVdtL, dVdQL, dQdVL] = local_derivatives(rawSegs{idxLow},   smoothWin, I_target_A);
[tU, VU, QU, dVdtU, dVdQU, dQdVU] = local_derivatives(rawSegs{idxUnity}, smoothWin, I_target_A);

% Window masks (restrict to the [30 400] s analysis window for clarity).
% In Q-space this corresponds to a fixed |Q| window (constant current).
mL = (tL >= fitWin_s(1)) & (tL <= fitWin_s(2));
mU = (tU >= fitWin_s(1)) & (tU <= fitWin_s(2));

%% Figure: full text width, 1 x 3 panels
fig = figure('Units','centimeters','Position',[2 2 19.0 7.2], 'Color','w');
fig.PaperPositionMode = 'auto';
tl = tiledlayout(fig, 1, 3, 'TileSpacing','compact', 'Padding','compact');

labelMid   = sprintf('mid-life, \\alpha = %.2f (no stripping)', alphas(idxUnity));
labelEarly = sprintf('early life, \\alpha = %.2f (stripping)',  alphas(idxLow));

% ---- Panel (a): dV/dt vs t ----
ax_a = nexttile(tl);
hold(ax_a, 'on');
yA = [dVdtL(mL); dVdtU(mU)] * 1e3;
yl = [min(yA) max(yA)] + [-0.2 0.2]*(max(yA)-min(yA));
patch(ax_a, [fitWin_s(1) fitWin_s(2) fitWin_s(2) fitWin_s(1)], ...
            [yl(1) yl(1) yl(2) yl(2)], COL_BAND, ...
            'EdgeColor','none', 'HandleVisibility','off');
hU = plot(ax_a, tU, dVdtU*1e3, 'Color', COL_BLUE, 'LineWidth', 0.9);
hL = plot(ax_a, tL, dVdtL*1e3, 'Color', COL_RED,  'LineWidth', 0.9);
xlim(ax_a, [0 max(max(tL), max(tU))]);
ylim(ax_a, yl);
xlabel(ax_a, 'Time since current step [s]');
ylabel(ax_a, 'dV/dt [mV/s]');
title(ax_a, '(a) dV/dt vs time', 'FontWeight','normal');
grid(ax_a, 'on'); box(ax_a, 'on');
legend(ax_a, [hU, hL], {labelMid, labelEarly}, ...
    'Location','southeast', 'Box','off', 'FontSize', PUB_FONTSIZE-1);

% ---- Panel (b): dV/dQ vs Q ----
ax_b = nexttile(tl);
hold(ax_b, 'on');
yB = [dVdQL(mL); dVdQU(mU)] * 1e3;
yl = [min(yB) max(yB)] + [-0.2 0.2]*(max(yB)-min(yB));
patch(ax_b, [min(QL(mL)) max(QL(mL)) max(QL(mL)) min(QL(mL))], ...
            [yl(1) yl(1) yl(2) yl(2)], COL_BAND, ...
            'EdgeColor','none', 'HandleVisibility','off');
plot(ax_b, QU, dVdQU*1e3, 'Color', COL_BLUE, 'LineWidth', 0.9);
plot(ax_b, QL, dVdQL*1e3, 'Color', COL_RED,  'LineWidth', 0.9);
xlim(ax_b, [0 max(max(QL), max(QU))]);
ylim(ax_b, yl);
xlabel(ax_b, 'Discharge capacity Q [Ah]');
ylabel(ax_b, 'dV/dQ [mV/Ah]');
title(ax_b, '(b) dV/dQ vs capacity', 'FontWeight','normal');
grid(ax_b, 'on'); box(ax_b, 'on');

% ---- Panel (c): dQ/dV vs Q ----
ax_c = nexttile(tl);
hold(ax_c, 'on');
yC = [dQdVL(mL); dQdVU(mU)];
yl = [min(yC) max(yC)] + [-0.2 0.2]*(max(yC)-min(yC));
patch(ax_c, [min(QL(mL)) max(QL(mL)) max(QL(mL)) min(QL(mL))], ...
            [yl(1) yl(1) yl(2) yl(2)], COL_BAND, ...
            'EdgeColor','none', 'HandleVisibility','off');
plot(ax_c, QU, dQdVU, 'Color', COL_BLUE, 'LineWidth', 0.9);
plot(ax_c, QL, dQdVL, 'Color', COL_RED,  'LineWidth', 0.9);
xlim(ax_c, [0 max(max(QL), max(QU))]);
ylim(ax_c, yl);
xlabel(ax_c, 'Discharge capacity Q [Ah]');
ylabel(ax_c, 'dQ/dV [Ah/V]');
title(ax_c, '(c) dQ/dV vs capacity', 'FontWeight','normal');
grid(ax_c, 'on'); box(ax_c, 'on');

%% Apply publication font / size to every axes (defensive, R-017/R-019)
allAxes = findall(fig, 'Type','axes');
for k = 1:numel(allAxes)
    set(allAxes(k), 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE, ...
        'TickLabelInterpreter','tex');
end

%% Save figure (PNG + vector PDF in pngs/), R-018
pngsDir = getFigureOutputDir('PlotLiStrippingDerivatives_Cell35');
pngFile = fullfile(pngsDir, 'LiStrippingDerivatives.png');
pdfFile = fullfile(pngsDir, 'LiStrippingDerivatives.pdf');
drawnow;
exportgraphics(fig, pngFile, 'Resolution', 300);
exportgraphics(fig, pdfFile, 'ContentType', 'vector');
fprintf('\nDerivative-comparison figure saved:\n  %s\n  %s\n', pngFile, pdfFile);

%% Restore default groot settings
set(groot, 'defaultAxesFontName',     'remove');
set(groot, 'defaultTextFontName',     'remove');
set(groot, 'defaultLegendFontName',   'remove');
set(groot, 'defaultColorbarFontName', 'remove');
set(groot, 'defaultAxesFontSize',     'remove');


%% ====================== LOCAL HELPER FUNCTIONS =========================

function [t, V, Q, dVdt, dVdQ, dQdV] = local_derivatives(seg, smoothWin, I_target_A)
% local_derivatives - return interpolated t, V, Q (discharge capacity in
% Ah, positive going) and smoothed dV/dt, dV/dQ, dQ/dV for one segment.
% Q is computed from the nominal constant current I_target_A (the segment
% extraction enforced |I - I_target_A| <= 0.1 A so this introduces at most
% ~1% scale error on the Q-axis but leaves the shape unchanged).
t = seg.timeS_interp;
V = seg.voltage_interp;
Q = abs(I_target_A) * t / 3600;     % [Ah], positive going during discharge
dVdt = movmean(gradient(V) ./ gradient(t), smoothWin);
dVdQ = movmean(gradient(V) ./ gradient(Q), smoothWin);
dQdV = movmean(gradient(Q) ./ gradient(V), smoothWin);
end
