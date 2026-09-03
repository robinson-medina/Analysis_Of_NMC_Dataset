function debugGITTPlot(timeWithGaps, voltage, current, gittEp, episodeName, cellNum, outputDir)
% debugGITTPlot - standalone diagnostic figure for one detected GITT
% episode. Shows:
%   Row 1: current vs time (full episode window with padding) with each
%          detected pulse highlighted (blue = discharge, orange = charge).
%   Row 2: voltage vs time over the same window with the OCV measurement
%          points overlaid as red markers.
%   Row 3: extracted OCV vs cumulative signed charge.
% Also prints a per-pulse table to the console.
%
% Inputs:
%   timeWithGaps - datetime array (NaT at gaps)
%   voltage      - voltage array [V]
%   current      - current array [A]
%   gittEp       - GITT episode struct (from extractGITTfromTrace) or []
%   episodeName  - label for the episode (e.g. 'BoL' / 'EoL')
%   cellNum      - cell identifier string
%   outputDir     - R-022 directory supplied by the owning entry script.
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-07-28 (extracted from PlotCellSummary.m into a shared helper)

if nargin < 7 || isempty(outputDir)
    error('debugGITTPlot:MissingOutputDir', ...
        'An R-022 output directory must be supplied by the owning entry script.');
end

if isempty(gittEp)
    fprintf('\n[debugGITTPlot] No %s GITT episode to plot.\n', episodeName);
    return
end

COL_DISCH = [0.00 0.45 0.74];   % blue
COL_CHG   = [0.85 0.33 0.10];   % orange
COL_TRACE = [0.30 0.30 0.30];   % grey
COL_OCV   = [1.00 0.00 0.00];   % red

% Window padding around the episode for visual context.
pad = minutes(30);
t0 = gittEp.timeStart - pad;
t1 = gittEp.timeEnd   + pad;
maskW = (timeWithGaps >= t0) & (timeWithGaps <= t1);

figName = sprintf('GITT debug [%s] - %s', cellNum, episodeName);
fig = figure('Name', figName, 'NumberTitle','off', 'Color','w', ...
    'Units','centimeters', 'Position',[2 2 32 22]);
tl = tiledlayout(3, 1, 'TileSpacing','compact','Padding','compact');
title(tl, figName, 'Interpreter','none');

% Row 1: current trace
ax1 = nexttile(tl);
plot(ax1, timeWithGaps(maskW), current(maskW), '-', ...
    'Color', COL_TRACE, 'LineWidth', 0.6);
hold(ax1, 'on');
nP = numel(gittEp.pulseStartIdx);
for k = 1:nP
    s = gittEp.pulseStartIdx(k); e = gittEp.pulseEndIdx(k);
    if strcmp(gittEp.pulseModes{k}, 'discharge')
        col = COL_DISCH;
    else
        col = COL_CHG;
    end
    plot(ax1, timeWithGaps(s:e), current(s:e), '-', ...
        'Color', col, 'LineWidth', 2.0);
end
ylabel(ax1, 'Current [A]'); % R-020
title(ax1, sprintf('Detected pulses  (blue = discharge, orange = charge)  -  %d pulses', nP));
grid(ax1, 'on'); box(ax1, 'on');

% Row 2: voltage trace with OCV measurement markers
ax2 = nexttile(tl);
plot(ax2, timeWithGaps(maskW), voltage(maskW), '-', ...
    'Color', COL_TRACE, 'LineWidth', 0.6);
hold(ax2, 'on');
plot(ax2, timeWithGaps(gittEp.ocvIdx), gittEp.OCV_V, 'o', ...
    'MarkerFaceColor', COL_OCV, 'MarkerEdgeColor', 'k', 'MarkerSize', 6);
ylabel(ax2, 'Voltage [V]'); % R-020
title(ax2, 'Voltage trace with extracted OCV measurement points (red markers)');
grid(ax2, 'on'); box(ax2, 'on');

linkaxes([ax1 ax2], 'x');
xlim(ax1, [t0 t1]);

% Row 3: extracted OCV vs cumulative signed charge (OCVs split by half-cycle)
ax3 = nexttile(tl);
isDis = strcmp(gittEp.ocvModes, 'discharge');
isChg = strcmp(gittEp.ocvModes, 'charge');
hold(ax3, 'on');
if any(isDis)
    plot(ax3, gittEp.cumQ_signed_Ah(isDis), gittEp.OCV_V(isDis), 'o-', ...
        'Color', COL_DISCH, 'MarkerFaceColor', COL_DISCH, 'MarkerSize', 5);
end
if any(isChg)
    plot(ax3, gittEp.cumQ_signed_Ah(isChg), gittEp.OCV_V(isChg), 's-', ...
        'Color', COL_CHG, 'MarkerFaceColor', 'w', 'MarkerSize', 5);
end
xlabel(ax3, 'Cumulative signed charge [Ah]'); % R-020
ylabel(ax3, 'OCV [V]');                       % R-020
title(ax3, sprintf('Extracted OCV vs cumulative Q  -  %d discharge + %d charge OCV points', nnz(isDis), nnz(isChg)));
legHandles = gobjects(0); legLabels = {};
if any(isDis); legHandles(end+1) = plot(ax3, NaN, NaN, 'o-', 'Color', COL_DISCH, 'MarkerFaceColor', COL_DISCH); legLabels{end+1} = 'Discharge GITT'; end
if any(isChg); legHandles(end+1) = plot(ax3, NaN, NaN, 's-', 'Color', COL_CHG,   'MarkerFaceColor', 'w');        legLabels{end+1} = 'Charge GITT';    end
if ~isempty(legHandles); legend(ax3, legHandles, legLabels, 'Location','best', 'Box','off'); end
grid(ax3, 'on'); box(ax3, 'on');

% Console summary
nDisPulse = nnz(strcmp(gittEp.pulseModes, 'discharge'));
nChgPulse = nnz(strcmp(gittEp.pulseModes, 'charge'));
fprintf('\n=== %s GITT episode summary [%s] ===\n', episodeName, cellNum);
fprintf('  Time window:    %s   to   %s\n', datestr(gittEp.timeStart), datestr(gittEp.timeEnd));
fprintf('  Pulses:         %d total  (%d discharge, %d charge)\n', nP, nDisPulse, nChgPulse);
fprintf('  OCV samples:    %d total  (%d discharge, %d charge)\n', numel(gittEp.OCV_V), nnz(isDis), nnz(isChg));
fprintf('  cumQ range:     [%+.3f, %+.3f] Ah\n', min(gittEp.cumQ_signed_Ah), max(gittEp.cumQ_signed_Ah));
fprintf('  OCV range:      [%.3f, %.3f] V\n', min(gittEp.OCV_V), max(gittEp.OCV_V));
fprintf('  Per-OCV table (OCV index 0 = pre-first-pulse rest):\n');
fprintf('    k  | mode       | cumQ [Ah] | OCV [V] | OCV time\n');
fprintf('    ---+------------+-----------+---------+------------------\n');
for k = 1:numel(gittEp.OCV_V)
    fprintf('    %2d | %-10s | %+9.3f | %7.3f | %s\n', ...
        k - 1, gittEp.ocvModes{k}, gittEp.cumQ_signed_Ah(k), gittEp.OCV_V(k), ...
        datestr(timeWithGaps(gittEp.ocvIdx(k)), 'yyyy-mm-dd HH:MM:SS'));
end
fprintf('  Per-pulse table:\n');
fprintf('    k  | mode       | dur [min] | q_pulse [Ah]\n');
fprintf('    ---+------------+-----------+--------------\n');
for k = 1:nP
    dur_min = minutes(gittEp.pulseEndTimes(k) - gittEp.pulseStartTimes(k));
    fprintf('    %2d | %-10s | %9.2f | %+12.4f\n', ...
        k, gittEp.pulseModes{k}, dur_min, gittEp.q_per_pulse_Ah(k));
end

% Save the diagnostic figure to disk so it can be inspected when MATLAB
% runs in -batch mode (no GUI). Uses the caller-provided R-022 folder so
% the diagnostic stays with the owning entry script's other outputs.
try
    if ~exist(outputDir, 'dir'); mkdir(outputDir); end
    safeName = sprintf('debugGITT_%s_%s.png', cellNum, episodeName);
    exportgraphics(fig, fullfile(outputDir, safeName), 'Resolution', 150);
    fprintf('  Diagnostic figure saved to: %s\n', fullfile(outputDir, safeName));
catch ME
    fprintf('  [debugGITTPlot] Could not save figure: %s\n', ME.message);
end
end
