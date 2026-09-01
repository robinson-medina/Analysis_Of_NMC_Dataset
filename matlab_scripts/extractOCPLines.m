%% extractOCPLines.m
% Summary: Extracts OCP-like lookup lines from half-cell GITT and slow-cycle
%          CSV data for the graphite anode and NMC532 cathode, then combines
%          them into a two-panel publication figure.
%
% Usage: Set DataRoot and the active-material masses in the configuration block,
%        then run this script with no arguments.
%
% Outputs: OCP_HalfCell.png and OCP_HalfCell.pdf in this script's R-022 output
%          directory. The script also builds intermediate anode and cathode
%          tables in memory; no MAT files are written.
%
% Authors: GitHub Copilot.
% Dependency files: Functions/getFigureOutputDir.m.
% Last documented: 2026-09-01

% Reset workspace and figures for a clean run of the first section.
clear; close all; clc;
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
fprintf('--- extractOCPLines started ---\n');

%% ===================================================================
% ACTIVE MATERIAL MASSES [g] - used to convert the slow charge/discharge
% CSVs' specific-capacity column (mAh/g) to an absolute mAh throughput axis.
% ====================================================================
massCathode_g = 0.03553;
massAnode_g   = 0.01668;

%% Anode - Delithiation profile
% Load anode data from CSV file and filter for positive current (charging/delithiation).
fprintf('[1/10] Anode delithiation: loading data...\n');
% DataRoot: single switch to the dataset root holding 1_Teardown/2_HalfCell/
% 3_Characterization/4_Ageing. Change this one line to retarget the script.
DataRoot = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
ocpRoot  = fullfile(DataRoot, '2_HalfCell', 'OCP_data');
AnodeCSV = fullfile(ocpRoot, 'Anode_Graphite', 'NEXTMBS-full-charge-discharge-GITT-full0charge-discharge-NMC-anode.csv');
CathodeCSV = fullfile(ocpRoot, 'Cathode_NMC532', 'NEXTMBS-full-charge-discharge-GITT-full0charge-discharge-NMC-cathode.csv');

% Read the anode CSV file; extract columns needed for processing.
T_anode_raw = readtable(AnodeCSV);
fprintf('  Loaded %d rows from %s\n', height(T_anode_raw), AnodeCSV);

% Filter for delithiation phase (positive current, charging).
idx_delith = T_anode_raw.Current >= 0;
time = T_anode_raw.TestTime(idx_delith);
timeDate = T_anode_raw.DateTime(idx_delith);
if ~isdatetime(timeDate)
	timeDate = datetime(timeDate, 'Format', 'yyyy-MM-dd HH:mm:ss');
end
current = T_anode_raw.Current(idx_delith);
voltage = T_anode_raw.Voltage(idx_delith);

% Detect current-step transitions (positive change marks pulse boundaries).
index = find(diff(current) > 1e-6);
index = index(1:end-1); %removing the last point
% Combined diagnostics figure: figs 1-4 merged into one 2x2 tiled layout.
figAnodeDiagnostics = figure('Name', 'Anode GITT Detection Diagnostics', 'Color', 'w', 'Position', [530 332 1324 839]);
tAnodeDiag = tiledlayout(figAnodeDiagnostics, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile(tAnodeDiag, 1);
yyaxis left
hCurrent = plot(time, current);
hold on; hCurrentSteps = scatter(time(index), current(index));
ylabel('Current (A)')
yyaxis right
hVoltage = plot(time, voltage);
scatter(time(index), voltage(index));
ylabel('Voltage (V)')
title('Anode Delithiation: Detected Steps')
xlabel('Time (s)')
legend([hCurrent, hVoltage, hCurrentSteps], {'Current', 'Voltage', 'Detected step indices'}, 'Location', 'best')


% Integrate current from the selected pulse onward to obtain throughput.
% Divide by 3600 to convert from A·s to Ah (TestTime is in seconds).
throughput = cumtrapz(time(index(3):index(end)+50), current(index(3):index(end)+50)) / 3600;
% Preserve the delithiation capacity-axis reference for later comparison plots.
throughput_anode_del = throughput;
% Preserve the matching full delithiation voltage segment for overlay plots.
voltage_full_anode_del = voltage(index(3):index(end)+50);

% Keep only values at pulse boundaries plus final point.
Q = throughput([index(3:end) - index(3) + 1; numel(throughput)]);

% Final capacity/voltage vectors for this profile.
V = voltage([index(3:end); index(end)+50]);

% Preserve the delithiation boundary points so the publication figure (fig 6)
% can overlay circular markers on the GITT voltage line (as in fig 4).
Q_anode_del = Q;   % capacity at each pulse boundary [Ah]
V_anode_del = V;   % voltage at each pulse boundary [V]

% Compare unscaled boundary points against full integrated trajectory (tile 2 of 4).
nexttile(tAnodeDiag, 2);
hQBefore = plot(Q, V, 'o-');
hold on
hThroughput = plot(throughput, voltage_full_anode_del);
% Compute interpolation to a 100-point uniform grid between min and max Q.
% Using linspace avoids the colon-step endpoint issue and works at any scale.
nInterpPoints = 100;
qMin = min(Q);
qMax = max(Q);
Qsave = linspace(qMin, qMax, nInterpPoints);
Vsave = interp1(Q, V, Qsave, 'pchip');
hInterp = plot(Qsave, Vsave);
title('Anode Delithiation: Boundary Points vs Full Throughput Curve')
xlabel('Capacity / Throughput [Ah]')
ylabel('Voltage [V]')
legend([hQBefore, hThroughput, hInterp], {'Boundary points', 'Full throughput trajectory', 'Interpolated profile (100 pts)'}, 'Location', 'best')

% Store the interpolated delithiation profile for the combined anode table.
Qsave_anode_delith = Qsave(:);
Vsave_anode_delith = Vsave(:);
fprintf('  Done. %d interpolated points, Q range [%.1f, %.1f] Ah\n', numel(Qsave_anode_delith), min(Qsave_anode_delith), max(Qsave_anode_delith));

%% Anode - Lithiation profile
fprintf('[2/10] Anode lithiation: filtering data...\n');
% Reuse the loaded combined anode table for lithiation (negative current, discharging).
% Close figures but retain variables for this phase.
% AnodeCSV = 'NEXTBMS-GITT-for-discharge_graphite-anode-Akzhan B..csv';
% CathodeCSV = 'NEXTMBS-full-charge-discharge-GITT-full0charge-discharge-NMC-cathode-Akzhan.B.csv';

% % Read the anode CSV file; extract columns needed for processing.
% T_anode_raw = readtable(AnodeCSV);

% Filter the raw anode table for lithiation phase (negative current, discharging).
idx_lith = T_anode_raw.Current <= -0;
time = T_anode_raw.TestTime(idx_lith);
current = T_anode_raw.Current(idx_lith);
voltage = T_anode_raw.Voltage(idx_lith);

% Detect negative current-step transitions for lithiation pulse boundaries.
index = find(diff(current) < -1e-6);
index = index(2:end); % remove the first index

% Combined diagnostic (tile 3 of 4 in figAnodeDiagnostics).
nexttile(tAnodeDiag, 3);
yyaxis left
hCurrent = plot(time, current);
hold on; hCurrentSteps = scatter(time(index), current(index));
ylabel('Current (A)')
yyaxis right
hVoltage = plot(time, voltage);
scatter(time(index), voltage(index));
ylabel('Voltage (V)')
title('Anode Lithiation: Detected Steps')
xlabel('Time (s)')
legend([hCurrent, hVoltage, hCurrentSteps], {'Current', 'Voltage', 'Detected step indices'}, 'Location', 'best')

% Integrate current to compute throughput over the selected interval.
% Divide by 3600 to convert from A·s to Ah (TestTime is in seconds).
throughput = cumtrapz(time(index(1):end), abs(current(index(1):end))) / 3600;
% Preserve the lithiation capacity-axis reference for later comparison plots.
throughput_anode_lith = throughput;
% Preserve the matching full lithiation voltage segment for overlay plots.
voltage_full_anode_lith = voltage(index(1):end);

% Sample throughput at transition points and include final endpoint.
Q = throughput([index(1:end) - index(1) + 1; numel(throughput)]);

% Create capacity-voltage lookup vectors.
V = voltage([index(1:end); numel(voltage)]);

% Preserve the lithiation boundary points so the publication figure (fig 6)
% can overlay circular markers on the GITT voltage line (as in fig 4).
Q_anode_lith = Q;   % capacity at each pulse boundary [Ah]
V_anode_lith = V;   % voltage at each pulse boundary [V]

% Plot reduced points against full throughput curve for sanity checking (tile 4 of 4).
nexttile(tAnodeDiag, 4);
hQBefore = plot(Q, V, 'o-');
hold on
hThroughput = plot(throughput, voltage_full_anode_lith);
% Compute interpolation to a 100-point uniform grid between min and max Q.
nInterpPoints = 100;
qMin = min(Q);
qMax = max(Q);
Qsave = linspace(qMin, qMax, nInterpPoints);
Vsave = interp1(Q, V, Qsave, 'pchip');
hInterp = plot(Qsave, Vsave);
title('Anode Lithiation: Boundary Points vs Full Throughput Curve')
xlabel('Capacity / Throughput [Ah]')
ylabel('Voltage [V]')
legend([hQBefore, hThroughput, hInterp], {'Boundary points', 'Full throughput trajectory', 'Interpolated profile (100 pts)'}, 'Location', 'best')

% Combine delithiation and lithiation into one anode table for export/use.
Qsave_anode_lith = Qsave(:);
Vsave_anode_lith = Vsave(:);
fprintf('  Done. %d interpolated points, Q range [%.1f, %.1f] Ah\n', numel(Qsave_anode_lith), min(Qsave_anode_lith), max(Qsave_anode_lith));

%% Compare the interpolated anode lithiation and delithiation for publication
fprintf('[3/10] Anode: plotting publication figure (panel a)...\n');
% Width tuned so the tight-cropped exported PDF hits the R-021 (2026-08-12)
% single-column target of 244.4 pt (= 8.59 cm, 97%% of the column span).
% Height covers two stacked panels (a: anode, b: cathode) sharing one x-label.
pubFigWidthCm = 9.24;
pubFigHeightCm = 6.60;
pubFontSizePt = 8;
colDarkBlue = [1 17 181] ./ 255;
colRed = [255 0 0] ./ 255;
colBlack = [0 0 0];
% Dimmed publication variants for fig. 2: use the same hue family as the
% corresponding slow curve, but blend towards white so the GITT traces read as
% a lighter-intensity overlay rather than a competing colour.
colRedLight = 0.65 * colRed + 0.35 * [1 1 1];
colDarkBlueLight = 0.65 * colDarkBlue + 0.35 * [1 1 1];
% R-017 preferred palette extension color, used to give the anode/cathode
% Slow delithiation line a distinct colour instead of sharing red with GITT.
colGreen = [12 195 82] ./ 255;
% One publication figure with two vertically stacked panels (R-024):
% panel (a) = graphite anode (top), panel (b) = NMC532 cathode (bottom).
figOCPPub = figure('Color', 'w', 'Units', 'centimeters', 'Position', [2 2 pubFigWidthCm pubFigHeightCm]);
figOCPPub.PaperPositionMode = 'auto';
tOCPPub = tiledlayout(figOCPPub, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
axAnodePub = nexttile(tOCPPub, 1);
% GITT voltage segments only (interpolated Delithiation/Lithiation lines removed);
% x-axis converted from Ah to mAh (x1000); dashed to distinguish from the
% solid slow charge/discharge lines overlaid later on this same figure.
% Thinner LineWidth tightens MATLAB's dash/gap pattern (which scales with
% LineWidth) so dashes sit closer together instead of leaving wide gaps.
% Mirror the GITT delithiation x-axis about its own max (mAh) so the trace
% reads right-to-left from max down to 0; lithiation keeps its original
% left-to-right direction. Line and its boundary markers share one max so
% both stay aligned after mirroring.
xGittDelAnode = throughput_anode_del * 1000;
qGittDelAnode = Q_anode_del * 1000;
mGittDelAnode = max([xGittDelAnode; qGittDelAnode]);
plot(mGittDelAnode - xGittDelAnode, voltage_full_anode_del,  '--', 'Color', colRedLight,      'LineWidth', 0.6);
hold on
plot(throughput_anode_lith * 1000, voltage_full_anode_lith, '--', 'Color', colDarkBlueLight, 'LineWidth', 0.6);
% Overlay open circular markers at each GITT pulse boundary on the voltage line
% (same boundary-point style as figs 4 and 10). Markers only (no connecting
% line) so the dashed GITT trace stays intact; coloured to match their own
% GITT line using the same hue family as the slow curve, but at lower intensity.
% Filled (MarkerFaceColor = edge colour) so the markers read as solid dots.
plot(mGittDelAnode - qGittDelAnode, V_anode_del,  'o', 'Color', colRedLight,      'MarkerFaceColor', colRedLight,      'MarkerSize', 1.5, 'LineStyle', 'none');
plot(Q_anode_lith * 1000, V_anode_lith, 'o', 'Color', colDarkBlueLight, 'MarkerFaceColor', colDarkBlueLight, 'MarkerSize', 1.5, 'LineStyle', 'none');
% Build legend-only proxy handles so the GITT entries show the combined style:
% dashed line plus relaxation marker. The real relaxation markers remain on
% the plotted data, but they are no longer separate legend entries.
hLegGittDelAnode = plot(nan, nan, '--o', 'Color', colRedLight, 'LineWidth', 0.6, ...
	'MarkerSize', 3, 'MarkerFaceColor', colRedLight);
hLegGittLithAnode = plot(nan, nan, '--o', 'Color', colDarkBlueLight, 'LineWidth', 0.6, ...
	'MarkerSize', 3, 'MarkerFaceColor', colDarkBlueLight);
% Single shared x-label lives on the bottom (cathode) panel only; this top
% panel keeps just its own y-label.
ylabel(axAnodePub, 'Voltage [V]', 'FontName', 'Times New Roman', 'FontSize', pubFontSizePt)
grid(axAnodePub, 'on')
box(axAnodePub, 'on')
axAnodePub.FontName = 'Times New Roman';
axAnodePub.FontSize = pubFontSizePt;
axAnodePub.LabelFontSizeMultiplier = 1.0;
axAnodePub.TitleFontSizeMultiplier = 1.0;
axAnodePub.LineWidth = 0.8;
xlim(axAnodePub, [0 5]);
ylim(axAnodePub, [0 0.6]);
legend(axAnodePub, [hLegGittDelAnode, hLegGittLithAnode], {'GITT delithiation', 'GITT lithiation'}, ...
	'Location', 'north', 'Box', 'off', 'FontName', 'Times New Roman', 'FontSize', pubFontSizePt)
% Baked-in panel letter (R-024), inside the axes at the top-left corner.
text(axAnodePub, 0.02, 0.96, '(a)', 'Units', 'normalized', ...
	'FontName', 'Times New Roman', 'FontSize', pubFontSizePt, ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');

% NOTE: export moved to the end of the slow charge/discharge section below,
% once the anode slow curves have been overlaid onto this same figure.
scriptDir = fileparts(mfilename('fullpath'));
saveDir   = getFigureOutputDir('extractOCPLines');

%%
% Store normalised SoC (capacity divided by Qmax_anode) in the exported table.
% Qmax_anode is computed here (not in the publication figure) because the
% publication figure uses raw Ah on the x-axis.
Qmax_anode = max([max(Qsave_anode_delith); max(Qsave_anode_lith)]);
T_anode = table( ...
	[repmat("Delithiation", numel(Qsave_anode_delith), 1); repmat("Lithiation", numel(Qsave_anode_lith), 1)], ...
	[Qsave_anode_delith / Qmax_anode; Qsave_anode_lith / Qmax_anode], ...
	[Vsave_anode_delith; Vsave_anode_lith], ...
	'VariableNames', {'Mode', 'SoC(-)', 'Voltage(V)'});

% Write the combined anode table to CSV when export is needed.
% writetable(T_anode, 'GITT_anode_combined.csv');
fprintf('[4/10] Cathode delithiation: loading data...\n');

%% Cathode - Delithiation profile (with upper-range extrapolation)
% Keep workspace data for continuity; only load new source vectors.
% clear; close all
T_cathode_raw = readtable(CathodeCSV);
fprintf('  Loaded %d rows from %s\n', height(T_cathode_raw), CathodeCSV);
idx_cathode_delith = T_cathode_raw.Current >= 0;
time = T_cathode_raw.TestTime(idx_cathode_delith);
current = T_cathode_raw.Current(idx_cathode_delith);
voltage = T_cathode_raw.Voltage(idx_cathode_delith);

% Detect positive current transitions to identify pulse boundaries.
index = find(diff(current) > 1e-6);
index = index(2:end); % remove the first index

% Combined diagnostics figure: figs 7-10 merged into one 2x2 tiled layout.
figCathodeDiagnostics = figure('Name', 'Cathode GITT Detection Diagnostics', 'Color', 'w', 'Position', [530 332 1324 839]);
tCathodeDiag = tiledlayout(figCathodeDiagnostics, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
nexttile(tCathodeDiag, 1);
yyaxis left
hCurrent = plot(time, current);
hold on; hCurrentSteps = scatter(time(index), current(index));
ylabel('Current (A)')
yyaxis right
hVoltage = plot(time, voltage);
scatter(time(index), voltage(index));
ylabel('Voltage (V)')
title('Cathode Delithiation: Detected Steps')
xlabel('Time (s)')
legend([hCurrent, hVoltage, hCurrentSteps], {'Current', 'Voltage', 'Detected step indices'}, 'Location', 'best')

% Integrate current to form throughput and then reduce to boundary points.
% Divide by 3600 to convert from A·s to Ah (TestTime is in seconds).
throughput = cumtrapz(time(index(2):index(end)+50), current(index(2):index(end)+50)) / 3600;
% Preserve the delithiation capacity-axis reference for later comparison plots.
throughput_cathode_del = throughput;
% Preserve the matching full delithiation voltage segment for overlay plots.
voltage_full_cathode_del = voltage(index(2):index(end)+50);
Q = throughput([index(2:end) - index(2) + 1; numel(throughput)]);

% Capacity-voltage profile.
V = voltage([index(2:end); index(end)+50]);

% Preserve the delithiation boundary points so the publication figure (fig 12)
% can overlay circular markers on the GITT voltage line (as in fig 10).
Q_cathode_del = Q;   % capacity at each pulse boundary [Ah]
V_cathode_del = V;   % voltage at each pulse boundary [V]

% Visual check of reduced profile vs. full integrated trajectory (tile 2 of 4).
nexttile(tCathodeDiag, 2);
hQBefore = plot(Q, V, 'o-');
hold on
hThroughput = plot(throughput, voltage_full_cathode_del);
% Compute interpolation to a 100-point uniform grid between min and max Q.
nInterpPoints = 100;
qMin = min(Q);
qMax = max(Q);
Qsave = linspace(qMin, qMax, nInterpPoints);
Vsave = interp1(Q, V, Qsave, 'pchip');
hInterp = plot(Qsave, Vsave);
title('Cathode Delithiation: Boundary Points vs Full Throughput Curve')
xlabel('Capacity / Throughput [Ah]')
ylabel('Voltage [V]')
legend([hQBefore, hThroughput, hInterp], {'Boundary points', 'Full throughput trajectory', 'Interpolated profile (100 pts)'}, 'Location', 'best')

% Store the interpolated delithiation profile for the combined cathode table.
Qsave_cathode_delith = Qsave(:);
Vsave_cathode_delith = Vsave(:);
fprintf('  Done. %d interpolated points, Q range [%.1f, %.1f] Ah\n', numel(Qsave_cathode_delith), min(Qsave_cathode_delith), max(Qsave_cathode_delith));

%% Cathode - Lithiation profile (with lower-range extrapolation)
fprintf('[5/10] Cathode lithiation: filtering data...\n');
% Keep workspace data for continuity; only load new source vectors.
% clear; close all
idx_cathode_lith = T_cathode_raw.Current <= 0;
time = T_cathode_raw.TestTime(idx_cathode_lith);
current = T_cathode_raw.Current(idx_cathode_lith);
voltage = T_cathode_raw.Voltage(idx_cathode_lith);

% Detect negative current transitions for pulse boundaries.
index = find(diff(current) < -1e-6);
index = index(2:end); % remove first and last indices

% Combined diagnostic (tile 3 of 4 in figCathodeDiagnostics).
nexttile(tCathodeDiag, 3);
yyaxis left
hCurrent = plot(time, current);
hold on; hCurrentSteps = scatter(time(index), current(index));
ylabel('Current (A)')
yyaxis right
hVoltage = plot(time, voltage);
scatter(time(index), voltage(index));
ylabel('Voltage (V)')
title('Cathode Lithiation: Detected Steps')
xlabel('Time (s)')
legend([hCurrent, hVoltage, hCurrentSteps], {'Current', 'Voltage', 'Detected step indices'}, 'Location', 'best')

% Integrate current and sample at detected boundaries.
% Divide by 3600 to convert from A·s to Ah (TestTime is in seconds).
throughput = cumtrapz(time(index(1):end), abs(current(index(1):end))) / 3600;
% Preserve the lithiation capacity-axis reference for later comparison plots.

% Preserve the matching full lithiation voltage segment for overlay plots.
voltage_full_cathode_lith = voltage(index(1):end);
Q = throughput([index(1:end) - index(1) + 1; numel(throughput)]);

% Construct profile capacity-voltage vectors.
V = voltage([index(1:end); numel(voltage)]);

% Preserve the lithiation boundary points so the publication figure (fig 12)
% can overlay circular markers on the GITT voltage line (as in fig 10).
Q_cathode_lith = Q;   % capacity at each pulse boundary [Ah]
V_cathode_lith = V;   % voltage at each pulse boundary [V]


% Compute interpolation across an extended lower capacity range (6% offset).
% Use explicit min/max and append qMax when needed, because colon stepping can
% miss the exact endpoint due to floating-point step accumulation.



%lets take the max voltage of the delithiation test (which has extrapolation) and get the missing capacity points for lithiation
% Q_extrapolated = interp1(V, Q, [Vsave_cathode_delith(end); V], 'pchip'); 
% ExtraCapaicty = -Q_extrapolated(1) ;
% Q_extrapolated = Q_extrapolated + ExtraCapaicty; % Shift the extrapolated points to start from zero capacity for lithiation
% qMin = min(Q_extrapolated);
% qMax = max(Q_extrapolated);

nInterpPoints = 100;
qMin = min(Q);
qMax = max(Q);
Qsave = linspace(qMin, qMax, nInterpPoints);
Vsave = interp1(Q, V, Qsave, 'pchip');



% Plot reduced and full trajectories for quality control.


%extrapolation
% Vsave = interp1(Q_extrapolated, [Vsave_cathode_delith(end); V], Qsave, 'pchip');
% Q = Q+ExtraCapaicty; %correct for the extrapolation
% throughput = throughput+ExtraCapaicty; %correct for the extrapolation

throughput_cathode_lith = throughput;
nexttile(tCathodeDiag, 4);
hQBefore = plot(Q, V, 'o-');
hold on
hThroughput = plot(throughput, voltage_full_cathode_lith);
hInterp = plot(Qsave, Vsave);
title('Cathode Lithiation: Boundary Points vs Full Throughput Curve')
xlabel('Capacity / Throughput (Ah)')
ylabel('Voltage (V)')
legend([hQBefore, hThroughput, hInterp], {'Boundary points', 'Full throughput trajectory', 'Profile interpolated + extrapolated with 0.2Ah grid'}, 'Location', 'best')

% Combine delithiation and lithiation into one cathode table for export/use.
Qsave_cathode_lith = Qsave(:);
Vsave_cathode_lith = Vsave(:);
fprintf('  Done. %d interpolated points, Q range [%.1f, %.1f] Ah\n', numel(Qsave_cathode_lith), min(Qsave_cathode_lith), max(Qsave_cathode_lith));

%% Compare the interpolated cathode lithiation and delithiation for publication
fprintf('[6/10] Cathode: plotting publication figure (panel b)...\n');
% Compute the normalisation factor: maximum capacity across both profiles.
Qmax_cathode = max([max(Qsave_cathode_delith); max(Qsave_cathode_lith)]);
% Panel (b): bottom tile of the shared two-panel publication figure.
figure(figOCPPub);
axCathodePub = nexttile(tOCPPub, 2);
% GITT voltage segments only (interpolated Delithiation/Lithiation lines removed);
% x-axis converted from Ah to mAh (x1000); dashed to distinguish from the
% solid slow charge/discharge lines overlaid later on this same figure.
% Thinner LineWidth tightens MATLAB's dash/gap pattern (which scales with
% LineWidth) so dashes sit closer together instead of leaving wide gaps.
% Mirror the GITT delithiation x-axis about its own max (mAh) so the trace
% reads right-to-left from max down to 0; lithiation keeps its original
% left-to-right direction. Line and its boundary markers share one max so
% both stay aligned after mirroring.
xGittDelCathode = throughput_cathode_del * 1000;
qGittDelCathode = Q_cathode_del * 1000;
mGittDelCathode = max([xGittDelCathode; qGittDelCathode]);
hVoltageFullDel = plot(mGittDelCathode - xGittDelCathode, voltage_full_cathode_del,  '--', 'Color', colRedLight,      'LineWidth', 0.6);
hold on
hVoltageFullLith = plot(throughput_cathode_lith * 1000, voltage_full_cathode_lith, '--', 'Color', colDarkBlueLight, 'LineWidth', 0.6);
% Overlay open circular markers at each GITT pulse boundary on the voltage line
% (same boundary-point style as figs 4 and 10). Markers only (no connecting
% line) so the dashed GITT trace stays intact; coloured to match their own
% GITT line using the same hue family as the slow curve, but at lower intensity.
% Filled (MarkerFaceColor = edge colour) so the markers read as solid dots.
hRelaxDel = plot(mGittDelCathode - qGittDelCathode, V_cathode_del,  'o', 'Color', colRedLight,      'MarkerFaceColor', colRedLight,      'MarkerSize', 1.5, 'LineStyle', 'none');
hRelaxLith = plot(Q_cathode_lith * 1000, V_cathode_lith, 'o', 'Color', colDarkBlueLight, 'MarkerFaceColor', colDarkBlueLight, 'MarkerSize', 1.5, 'LineStyle', 'none');
% Build legend-only proxy handles so the GITT entries show the combined style:
% dashed line plus relaxation marker. The real relaxation markers remain on
% the plotted data, but they are no longer separate legend entries.
hLegGittDelCathode = plot(nan, nan, '--o', 'Color', colRedLight, 'LineWidth', 0.6, ...
	'MarkerSize', 3, 'MarkerFaceColor', colRedLight);
hLegGittLithCathode = plot(nan, nan, '--o', 'Color', colDarkBlueLight, 'LineWidth', 0.6, ...
	'MarkerSize', 3, 'MarkerFaceColor', colDarkBlueLight);
grid(axCathodePub, 'on')
box(axCathodePub, 'on')
axCathodePub.FontName = 'Times New Roman';
axCathodePub.FontSize = pubFontSizePt;
axCathodePub.LabelFontSizeMultiplier = 1.0;
axCathodePub.TitleFontSizeMultiplier = 1.0;
axCathodePub.LineWidth = 0.8;
xlim(axCathodePub, [0 6.2]);
ylim(axCathodePub, [2.5 4.5]);
xlabel(axCathodePub, 'Throughput [mAh]', 'FontName', 'Times New Roman', 'FontSize', pubFontSizePt)
ylabel(axCathodePub, 'Voltage [V]', 'FontName', 'Times New Roman', 'FontSize', pubFontSizePt)
% No legend on panel (b) (user decision 2026-08-13): the single northeast
% legend on panel (a) covers both panels. NOTE: do not call legend() on
% axCathodePub at all - a lingering legend would auto-append data1/data2
% entries when the slow curves are plotted later.
% Baked-in panel letter (R-024), inside the axes at the top-left corner.
text(axCathodePub, 0.02, 0.96, '(b)', 'Units', 'normalized', ...
	'FontName', 'Times New Roman', 'FontSize', pubFontSizePt, ...
	'HorizontalAlignment', 'left', 'VerticalAlignment', 'top');

% NOTE: export moved to the end of the slow charge/discharge section below,
% once the cathode slow curves have been overlaid onto this same figure.

%%
% Store normalised SoC (capacity divided by Qmax_cathode) in place of raw Ah values.
T_cathode = table( ...
	[repmat("Delithiation", numel(Qsave_cathode_delith), 1); repmat("Lithiation", numel(Qsave_cathode_lith), 1)], ...
	[Qsave_cathode_delith / Qmax_cathode; Qsave_cathode_lith / Qmax_cathode], ...
	[Vsave_cathode_delith; Vsave_cathode_lith], ...
	'VariableNames', {'Mode', 'SoC(-)', 'Voltage(V)'});

% Write the combined cathode table to CSV when export is needed.
% writetable(T_cathode, 'GITT_cathode_combined.csv');
fprintf('[7/10] Combined tables built: T_anode (%d rows), T_cathode (%d rows)\n', height(T_anode), height(T_cathode));

%% Slow charge/discharge OCP curves (anode and cathode)
% Two additional publication figures from the slow (near-OCP) full charge and
% discharge sweeps supplied as simple Capacity(mAh/g),Voltage(V) CSVs. One line
% per direction (charge in red, discharge in black) on a Throughput [mAh] axis.
fprintf('[8/10] Slow charge/discharge: building anode and cathode figures...\n');

% Resolve the four CSV paths relative to the existing anode/cathode source files.
anodeChargeCSV      = fullfile(fileparts(AnodeCSV),   'anode_NExtBMS_fCharge.csv');
anodeDischargeCSV   = fullfile(fileparts(AnodeCSV),   'anode_NExtBMS_fDischarge.csv');
cathodeChargeCSV    = fullfile(fileparts(CathodeCSV), 'cathode_NExtBMS_fCharge.csv');
cathodeDischargeCSV = fullfile(fileparts(CathodeCSV), 'cathode_NExtBMS_fDischarge.csv');

% Read as tables; preserve headers so columns are accessed positionally (col 1 =
% Capacity(mAh/g), col 2 = Voltage(V)) without name mangling of the parenthesised headers.
T_anodeCharge      = readtable(anodeChargeCSV,      'VariableNamingRule', 'preserve');
T_anodeDischarge   = readtable(anodeDischargeCSV,   'VariableNamingRule', 'preserve');
T_cathodeCharge    = readtable(cathodeChargeCSV,    'VariableNamingRule', 'preserve');
T_cathodeDischarge = readtable(cathodeDischargeCSV, 'VariableNamingRule', 'preserve');

% --- Anode: overlay slow charge/discharge onto panel (a) of figOCPPub ---
% Combines the anode dashed GITT lines with these solid slow charge/discharge
% lines, sharing the same mAh axis.
hold(axAnodePub, 'on')
% Column 1 is specific capacity [mAh/g]; multiply by active mass [g] for mAh.
% Slow delithiation uses the base publication red; slow lithiation keeps the
% base publication dark blue so fig. 2 pairs each slow curve with its matching
% dimmed GITT overlay.
% Mirror the slow delithiation (charge) x-axis about its own max (mAh),
% independently from the GITT delithiation mirror above; discharge/lithiation
% keeps its original direction.
xSlowDelAnode = T_anodeCharge{:,1} * massAnode_g;
mSlowDelAnode = max(xSlowDelAnode);
hAnodeCharge    = plot(axAnodePub, mSlowDelAnode - xSlowDelAnode, T_anodeCharge{:,2},    '-', 'Color', colRed,      'LineWidth', 1.0);
hAnodeDischarge = plot(axAnodePub, T_anodeDischarge{:,1} * massAnode_g, T_anodeDischarge{:,2}, '-', 'Color', colDarkBlue, 'LineWidth', 1.0);
% Draw order requirement: continuous lines behind dashed lines, markers on top.
% These solid lines were added last, so push them to the bottom of the stack.
uistack(hAnodeDischarge, 'bottom');
uistack(hAnodeCharge, 'bottom');
% Keep relaxation markers on the data, but fold the marker cue into the GITT
% legend samples so the legend has no standalone "Relaxation" entries.
% User decision 2026-08-13: one legend for the whole figure, on the anode
% panel (a), northeast; the cathode panel (b) legend is removed (same four
% trace styles apply to both panels).
legend(axAnodePub, [hLegGittDelAnode, hLegGittLithAnode, hAnodeCharge, hAnodeDischarge], ...
	{'GITT delithiation', 'GITT lithiation', 'Slow delithiation', 'Slow lithiation'}, ...
	'Location', 'northeast', 'Box', 'off', 'FontName', 'Times New Roman', 'FontSize', pubFontSizePt)

% --- Cathode: overlay slow charge/discharge onto panel (b) of figOCPPub ---
% Combines the cathode dashed GITT lines with these solid slow charge/discharge
% lines, sharing the same mAh axis.
hold(axCathodePub, 'on')
% Column 1 is specific capacity [mAh/g]; multiply by active mass [g] for mAh.
% Slow delithiation uses the base publication red; slow lithiation keeps the
% base publication dark blue, matching fig. 2's colour pairing.
% Mirror the slow delithiation (charge) x-axis about its own max (mAh),
% independently from the GITT delithiation mirror above; discharge/lithiation
% keeps its original direction.
xSlowDelCathode = T_cathodeCharge{:,1} * massCathode_g;
mSlowDelCathode = max(xSlowDelCathode);
hCathodeCharge    = plot(axCathodePub, mSlowDelCathode - xSlowDelCathode, T_cathodeCharge{:,2},    '-', 'Color', colRed,      'LineWidth', 1.0);
hCathodeDischarge = plot(axCathodePub, T_cathodeDischarge{:,1} * massCathode_g, T_cathodeDischarge{:,2}, '-', 'Color', colDarkBlue, 'LineWidth', 1.0);
% Draw order requirement: continuous lines behind dashed lines, markers on top.
% These solid lines were added last, so push them to the bottom of the stack.
uistack(hCathodeDischarge, 'bottom');
uistack(hCathodeCharge, 'bottom');
% Cathode legend removed (user decision 2026-08-13): the single legend on
% panel (a) covers both panels.

% Export the combined two-panel figure as ONE vector PDF (R-024/R-018), plus a
% PNG snapshot at the same stem.
drawnow;
pdfFileOCP = fullfile(saveDir, 'OCP_HalfCell.pdf');
exportgraphics(figOCPPub, pdfFileOCP, 'ContentType', 'vector');
fprintf('OCP half-cell publication PDF saved: %s\n', pdfFileOCP);
pngFileOCP = fullfile(saveDir, 'OCP_HalfCell.png');
exportgraphics(figOCPPub, pngFileOCP, 'Resolution', 300);
fprintf('OCP half-cell publication PNG saved: %s\n', pngFileOCP);

%% Save all open figures to PNG
fprintf('[9/10] Saving figures to the R-022 output directory...\n');
% Use mfilename so the output folder is always relative to this script,
% not to the MATLAB current working directory.
pngDir = getFigureOutputDir('extractOCPLines');
figHandles = findall(0, 'Type', 'figure');
figNumbers = arrayfun(@(fig) fig.Number, figHandles);
[~, sortOrder] = sort(figNumbers);
figHandles = figHandles(sortOrder);
for k = 1:numel(figHandles)
	fig = figHandles(k);
	% Use figure title as filename; fall back to figure number if empty.
	ax = findobj(fig, 'Type', 'axes');
	titleStr = '';
	if ~isempty(ax)
		titleStr = get(get(ax(end), 'Title'), 'String');
	end
	if isempty(titleStr)
		titleStr = sprintf('figure_%d', fig.Number);
	end
	% Sanitise title for use as a filename.
	safeTitle = regexprep(titleStr, '[^\w\s-]', '');
	safeTitle = strtrim(regexprep(safeTitle, '\s+', '_'));
	outFile = fullfile(pngDir, sprintf('%02d_%s.png', k, safeTitle));
	exportgraphics(fig, outFile, 'Resolution', 150);
	fprintf('  Saved: %s\n', outFile);
end
fprintf('[10/10] --- extractOCPLines complete ---\n');