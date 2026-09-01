%% Summary: Methods figure for the Li-stripping detection / metric extraction.
% Two single-column publication figures (~8.4 cm each, exported as separate
% PDFs) comparing two real post-fast-charge C/5 discharge segments from cell
% A2.08:
%   - a low-alpha segment (Li-stripping shoulder visible in V(t), localised
%     flattening in dV/dt - the alpha < 1 ageing fingerprint).
%   - an alpha-near-1 segment (clean monotonic decay - the diffusion
%     baseline, no visible stripping shoulder).
%
% Figure (a):  V vs t for both segments, with the [30 400] s analysis
%              window shaded.
% Figure (b):  dV/dt vs t for both segments with the power-law fit
%              y = a + b * t^(-alpha) overlaid for each; alpha values
%              annotated.
%
% Inputs:  cached raw segments produced by EvaluateStrippingFit.m
%          (misc/.cache_stripping/A2.08_Cell_35_rawSegs.mat)
% Outputs: LiStrippingMethods_a.{png,pdf} and LiStrippingMethods_b.{png,pdf}
%          in ../pngs
%
% Usage:   Run the script (no arguments); it reads the cached raw segments and
%          writes both figures to ../pngs (R-022). Regenerate the cache with
%          EvaluateStrippingFit.m if it is missing.
% Produces: two single-column publication figures LiStrippingMethods_a/_b as
%          PNG + vector PDF in ../pngs.
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-06-30   (created)
% Last documented: 2026-08-04

clear; close all; clc;

%% Configuration
scriptDir = fileparts(mfilename('fullpath'));
addpath(fullfile(scriptDir, '..', '..', 'Functions'));

cacheFile  = fullfile(scriptDir, 'misc', '.cache_stripping', 'A2.08_Cell_35_rawSegs.mat');
smoothWin  = 11;              % movmean window (matches EvaluateStrippingFit.m)
fitWin_s   = [30 400];        % analysis window [s]
alphaGrid  = 0.10:0.02:2.00;  % grid for the alpha grid search

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
%   * FIG_W_CM is tuned so the tight-cropped exported PDF width equals 85 % of
%     the column width (0.85 x 252 pt = 214.2 pt = 7.53 cm).
PUB_FONTSIZE = 8;
FIG_W_CM     = 8.22;   % tuned so exported width ~= 214.2 pt (85 % column)
FIG_H_CM     = 7.0;
set(groot, 'defaultAxesFontName', PUB_FONT);
set(groot, 'defaultTextFontName', PUB_FONT);
set(groot, 'defaultLegendFontName', PUB_FONT);
set(groot, 'defaultColorbarFontName', PUB_FONT);
set(groot, 'defaultAxesFontSize', PUB_FONTSIZE);

%% Load cached segments and compute alpha for every segment
fprintf('Loading cache %s ... ', cacheFile);
S = load(cacheFile);
rawSegs = S.rawSegs;
nSeg    = numel(rawSegs);
fprintf('done (%d segments).\n', nSeg);

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

%% Figure (a): V vs t for both segments (single-column, own PDF)
figA = figure('Units','centimeters','Position',[2 2 FIG_W_CM FIG_H_CM], 'Color','w');
figA.PaperPositionMode = 'auto';
ax_a = axes('Parent', figA);
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
xlabel(ax_a, 'Time since current step [s]');
ylabel(ax_a, 'Voltage [V]');
grid(ax_a, 'on'); box(ax_a, 'on');
legend(ax_a, [hU, hL], ...
    {sprintf('mid-life, \\alpha = %.2f (no stripping)', alphas(idxUnity)), ...
     sprintf('early life, \\alpha = %.2f (stripping)',  alphas(idxLow))}, ...
    'Location','northeast', 'Box','off', 'FontSize', PUB_FONTSIZE-1);
text(ax_a, mean(fitWin_s), yl_a(1) + 0.04*(yl_a(2)-yl_a(1)), 'analysis window', ...
    'HorizontalAlignment','center', 'FontSize', PUB_FONTSIZE-2, ...
    'FontAngle','italic', 'Color', COL_GREY);

%% Figure (b): dV/dt with power-law fits (single-column, own PDF)
figB = figure('Units','centimeters','Position',[2 2 FIG_W_CM FIG_H_CM], 'Color','w');
figB.PaperPositionMode = 'auto';
ax_b = axes('Parent', figB);
hold(ax_b, 'on');
mL = (tL >= fitWin_s(1)) & (tL <= fitWin_s(2));
mU = (tU >= fitWin_s(1)) & (tU <= fitWin_s(2));
allD = [dL(mL); dU(mU)] * 1e3;
yl_b = [min(allD) max(allD)];
yl_b = yl_b + [-0.20 0.20] * (yl_b(2)-yl_b(1));
patch(ax_b, [fitWin_s(1) fitWin_s(2) fitWin_s(2) fitWin_s(1)], ...
            [yl_b(1) yl_b(1) yl_b(2) yl_b(2)], COL_BAND, ...
            'EdgeColor','none', 'HandleVisibility','off');
hUdat = plot(ax_b, tU, dU*1e3, '-',  'Color', COL_BLUE, 'LineWidth', 0.7);
hLdat = plot(ax_b, tL, dL*1e3, '-',  'Color', COL_RED,  'LineWidth', 0.7);
hUfit = plot(ax_b, tFitU, yFitU*1e3, '--', 'Color', COL_BLUE * 0.6, 'LineWidth', 1.3);
hLfit = plot(ax_b, tFitL, yFitL*1e3, '--', 'Color', COL_RED  * 0.6, 'LineWidth', 1.3);
xlim(ax_b, [0 max(max(tL), max(tU))]);
ylim(ax_b, yl_b);
xlabel(ax_b, 'Time since current step [s]');
ylabel(ax_b, 'dV/dt [mV/s]');
grid(ax_b, 'on'); box(ax_b, 'on');
legend(ax_b, [hUdat, hUfit, hLdat, hLfit], ...
    {'mid-life data', ...
     sprintf('fit, \\alpha = %.2f', alphas(idxUnity)), ...
     'early-life data', ...
     sprintf('fit, \\alpha = %.2f', alphas(idxLow))}, ...
    'Location','best', 'Box','off', 'FontSize', PUB_FONTSIZE-1, ...
    'NumColumns', 2);
text(ax_b, mean(fitWin_s), yl_b(1) + 0.04*(yl_b(2)-yl_b(1)), 'analysis window', ...
    'HorizontalAlignment','center', 'FontSize', PUB_FONTSIZE-2, ...
    'FontAngle','italic', 'Color', COL_GREY);

%% Apply publication font / size to every axes (defensive, R-017/R-019)
% LabelFontSizeMultiplier/TitleFontSizeMultiplier forced to 1 so axis labels are
% the SAME size as tick labels and the paper body (default 1.1 makes them bigger).
allAxes = findall([figA figB], 'Type','axes');
for k = 1:numel(allAxes)
    set(allAxes(k), 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE, ...
        'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1, ...
        'TickLabelInterpreter','tex');
end

%% Save each panel as its own figure (PNG + vector PDF in pngs/), R-018
pngsDir = fullfile(scriptDir, '..', 'pngs');
if ~exist(pngsDir, 'dir'); mkdir(pngsDir); end
drawnow;
% Panel (a): C/5 discharge segments
pngFileA = fullfile(pngsDir, 'LiStrippingMethods_a.png');
pdfFileA = fullfile(pngsDir, 'LiStrippingMethods_a.pdf');
exportgraphics(figA, pngFileA, 'Resolution', 300);
exportgraphics(figA, pdfFileA, 'ContentType', 'vector');
% Panel (b): power-law fits
pngFileB = fullfile(pngsDir, 'LiStrippingMethods_b.png');
pdfFileB = fullfile(pngsDir, 'LiStrippingMethods_b.pdf');
exportgraphics(figB, pngFileB, 'Resolution', 300);
exportgraphics(figB, pdfFileB, 'ContentType', 'vector');
fprintf('\nMethods figures saved:\n  %s\n  %s\n  %s\n  %s\n', pngFileA, pdfFileA, pngFileB, pdfFileB);

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
