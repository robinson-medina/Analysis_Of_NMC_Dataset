function generateEISComparisonFromPlotEISData(eisRootFolder, targetSoC_pct, maxFreq, scriptDir, pubFont, pubFontSize, cellNum, colBolRef, colEolRef)
% generateEISComparisonFromPlotEISData - build one standalone Nyquist
% comparison figure for a selected cell at ONE SoC (default: 50%) across
% life stages and export it as EISComparison.{pdf,png} to ../pngs.
%
% Data layout assumption (campaign convention):
%   EIS root contains stage folders
%     1_BOL_EIS, 2_MOL_EIS, 3_EOL_EIS
%   each stage folder may contain
%     <cellID>_impedanceData.csv
%
% The actual drawing is delegated to plotEISComparisonOnAxes so the
% standalone export and the in-figure EIS tile share one implementation.
%
% Inputs:
%   eisRootFolder - EIS root folder holding the stage subfolders
%   targetSoC_pct - SoC (%) to plot (e.g. 50)
%   maxFreq       - upper frequency limit [Hz] for plotted points
%   scriptDir     - directory of the calling script (PDF/PNG saved to ../pngs)
%   pubFont       - publication font (R-019)
%   pubFontSize   - base font size (R-017)
%   cellNum       - cell identifier (selects <cellNum>_impedanceData.csv)
%   colBolRef     - 1x3 RGB for the BoL trace (age-gradient endpoint)
%   colEolRef     - 1x3 RGB for the EoL trace (age-gradient endpoint)
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-07-28 (extracted from PlotCellSummary.m into a shared helper)

fprintf('\n########################################\n');
fprintf('Checking EIS root folder  %s\n', eisRootFolder);

% Guard against a missing input folder to avoid failing the summary script.
if ~exist(eisRootFolder, 'dir')
    fprintf('No EIS root folder found in %s, skipping EISComparison export...\n', eisRootFolder);
    return
end

fprintf('EIS root folder found! Processing: %s\n', eisRootFolder);
fprintf('########################################\n');

% Reuse the same age-gradient endpoints as the summary figure so
% EIS BoL/EoL colours match the blue->yellowish thread used elsewhere.
% MoL keeps a distinct green publication color.
stageColors = zeros(3, 3);
stageColors(1,:) = colBolRef;           % BoL: same as Figure 3 BoL color
stageColors(2,:) = [0 140 70] ./ 255;   % MoL: green publication color
stageColors(3,:) = colEolRef;           % EoL: same as Figure 3 EoL color
stageMarkers = {'o', 's', 'd'};

fig = figure('Position', [100, 100, 800, 600], 'Color', 'w');
ax  = axes(fig); %#ok<LAXES>
plottedCount = plotEISComparisonOnAxes(ax, eisRootFolder, targetSoC_pct, maxFreq, cellNum, ...
    stageColors, stageMarkers, false);

if plottedCount == 0
    close(fig);
    fprintf('No valid BOL/MOL/EOL SoC %.0f%% traces found for %s; EISComparison export skipped.\n', ...
        targetSoC_pct, cellNum);
    return
end

set(findall(fig, 'Type', 'axes'), ...
    'FontName', pubFont, 'FontSize', pubFontSize, 'TickLabelInterpreter', 'tex');

eisPdf = fullfile(scriptDir, '..', 'pngs', 'EISComparison.pdf');
eisPng = fullfile(scriptDir, '..', 'pngs', 'EISComparison.png');
exportgraphics(fig, eisPdf, 'ContentType', 'vector');
exportgraphics(fig, eisPng, 'Resolution', 300);
fprintf('EIS publication figure exported:\n  %s\n  %s\n', eisPdf, eisPng);

fprintf('\n########################################\n');
fprintf('Nyquist analysis complete!\n');
fprintf('Processed available BoL/MoL/EoL traces for %s at SoC %.0f%%\n', cellNum, targetSoC_pct);
fprintf('########################################\n');
end
