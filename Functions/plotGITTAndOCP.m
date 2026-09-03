function plotGITTAndOCP(ax, bolGITT, eolGITT, bolC50, eolC50, ...
        colBol, colEol, fontName, fontSize)
% plotGITTAndOCP - overlay BoL/EoL GITT OCV points with the first/last
% C/50 OCP curves on a shared signed-Q axis.
%   * GITT points: filled circles, no connecting line (BoL / EoL colours).
%   * C/50 OCP:    dashed lines for discharge and matching charge.
% The signed Q axis is integrated from the start of the discharge through
% the end of the matching charge, so discharge contributions push Q
% negative and the matching charge returns Q toward zero.
%
% Inputs:
%   ax               - target axes handle
%   bolGITT, eolGITT - GITT episode structs (from extractGITTfromTrace) or []
%   bolC50, eolC50   - C/50 phase structs (from buildC50Phase)
%   colBol, colEol   - 1x3 RGB colours for the BoL / EoL traces
%   fontName         - font name for labels/legend (R-019)
%   fontSize         - base font size (R-017)
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-07-28 (shared Functions/ helper; used by PlotCellSummary.m)

hold(ax, 'on');

handles = gobjects(0);
labels  = {};

% --- BoL C/50: dashed discharge then dashed charge (same colour, no legend dup)
[hBd, ~] = localPlotC50Phase(ax, bolC50, colBol);
if ~isempty(hBd); handles(end+1) = hBd; labels{end+1} = 'BoL OCV'; end

% --- EoL C/50
[hEd, ~] = localPlotC50Phase(ax, eolC50, colEol);
if ~isempty(hEd); handles(end+1) = hEd; labels{end+1} = 'EoL OCV'; end

% --- BoL GITT (scatter only, no connecting line)
hBg = localPlotGITTPoints(ax, bolGITT, colBol);
if ~isempty(hBg); handles(end+1) = hBg; labels{end+1} = 'BoL GITT'; end

% --- EoL GITT
hEg = localPlotGITTPoints(ax, eolGITT, colEol);
if ~isempty(hEg); handles(end+1) = hEg; labels{end+1} = 'EoL GITT'; end

xlabel(ax, 'Cumulative charge [Ah]');  % signed; - during discharge, returning toward 0 during charge (R-020)
ylabel(ax, 'Voltage / OCV [V]');       % R-020
title(ax, 'OCV: BoL vs EoL', 'FontWeight','normal');
grid(ax, 'on'); box(ax, 'on');

if ~isempty(handles)
    legend(ax, handles, labels, 'Location','best', 'Box','off', ...
        'FontName', fontName, 'FontSize', fontSize, 'NumColumns', 2);
else
    text(ax, 0.5, 0.5, 'No GITT detected and no C/50 OCP available', ...
        'Units','normalized', 'HorizontalAlignment','center', ...
        'FontName', fontName, 'FontSize', fontSize-1);
end
end


function h = localPlotGITTPoints(ax, gittEp, col)
% Scatter the GITT per-pulse OCV against the signed cumulative charge.
% No connecting line (per spec).
h = [];
if isempty(gittEp); return; end
% Real data: every detected pulse's OCV point, drawn with no legend entry
% of its own (HandleVisibility off) so it cannot contribute extra marker
% glyphs to whichever legend entry ends up representing this series.
plot(ax, gittEp.cumQ_signed_Ah, gittEp.OCV_V, 'o', ...
    'MarkerEdgeColor', col, 'MarkerFaceColor', col, ...
    'MarkerSize', 4, 'LineStyle', 'none', 'HandleVisibility', 'off');
% Legend proxy: a dedicated single-point Line object, plotted directly on
% top of the first real point (same style/colour, visually identical), so
% the legend icon always shows exactly one marker. Found 2026-08-25: the
% "BoL GITT" legend entry rendered with 2 stacked markers instead of 1 on
% Cell_60/Cell_34 while "EoL GITT" showed 1 - MATLAB's default legend icon
% for a many-point marker-only Line is data/context dependent, so a
% dedicated 1-point proxy handle guarantees a consistent single-marker icon.
h = plot(ax, gittEp.cumQ_signed_Ah(1), gittEp.OCV_V(1), 'o', ...
    'MarkerEdgeColor', col, 'MarkerFaceColor', col, ...
    'MarkerSize', 4, 'LineStyle', 'none');
end


function [hDisch, hCharge] = localPlotC50Phase(ax, c50, col)
% Plot the C/50 discharge phase and the matching charge phase as dashed
% lines in the same colour. Returns one handle per phase (the discharge
% handle is used for the legend; the charge handle is hidden from the
% legend to keep the entry list short).
hDisch  = [];
hCharge = [];
if isempty(c50) || isempty(c50.dischQ_Ah); return; end
hDisch = plot(ax, c50.dischQ_Ah, c50.dischV, '--', ...
    'Color', col, 'LineWidth', 1.0); % R-017 item 4
if ~isempty(c50.chargeQ_Ah)
    hCharge = plot(ax, c50.chargeQ_Ah, c50.chargeV, '--', ...
        'Color', col, 'LineWidth', 1.0, 'HandleVisibility','off'); % R-017 item 4
end
end
