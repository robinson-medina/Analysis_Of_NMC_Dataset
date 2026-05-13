% Summary: Extract OCP-like lookup lines from GITT datasets for anode/cathode,
% then scale/interpolate and export each profile to CSV. Anode data is sourced
% from one combined anode CSV file containing both modes.
% Author: Copilot
% Date: 2026-03-19
% Inputs: CSV files containing time, current, and voltage columns; cathode from MAT files
% Outputs: Combined anode and cathode tables with mode, capacity, and voltage columns

% Reset workspace and figures for a clean run of the first section.
clear; close all; clc;
fprintf('--- extractOCPLines started ---\n');

%% Anode - Delithiation profile
% Load anode data from CSV file and filter for positive current (charging/delithiation).
fprintf('[1/8] Anode delithiation: loading data...\n');
AnodeCSV = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot\OCP_data\Anode_Graphite\NEXTMBS-full-charge-discharge-GITT-full0charge-discharge-NMC-anode.csv';
CathodeCSV = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot\OCP_data\Cathode_NMC532\NEXTMBS-full-charge-discharge-GITT-full0charge-discharge-NMC-cathode.csv';

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
% Quick diagnostic plots to verify detected step indices.
figure;
axCurrent = subplot(2,1,1);
hCurrent = plot(time, current);
hold on; hCurrentSteps = scatter(time(index), current(index));
title('Anode Delithiation: Current Trace with Detected Steps')
xlabel('Time (s)')
ylabel('Current (A)')
legend([hCurrent, hCurrentSteps], {'Current', 'Detected step indices'}, 'Location', 'best')
axVoltage = subplot(2,1,2);
hVoltage = plot(time, voltage);
hold on; hVoltageSteps = scatter(time(index), voltage(index));
title('Anode Delithiation: Voltage Trace with Detected Steps')
xlabel('Time (s)')
ylabel('Voltage (V)')
legend([hVoltage, hVoltageSteps], {'Voltage', 'Detected step indices'}, 'Location', 'best')
% Keep subplot panning/zoom synchronized along the time axis.
linkaxes([axCurrent, axVoltage], 'x')


% Integrate current from the selected pulse onward to obtain throughput.
throughput = cumtrapz(time(index(3):index(end)+50), current(index(3):index(end)+50));
% Preserve the delithiation capacity-axis reference for later comparison plots.
throughput_anode_del = throughput;
% Preserve the matching full delithiation voltage segment for overlay plots.
voltage_full_anode_del = voltage(index(3):index(end)+50);

% Keep only values at pulse boundaries plus final point.
Q = throughput([index(3:end) - index(3) + 1; numel(throughput)]);

% Final capacity/voltage vectors for this profile.
V = voltage([index(3:end); index(end)+50]);

% Compare unscaled boundary points against full integrated trajectory.
figure;
hQBefore = plot(Q, V, 'o-');
hold on
hThroughput = plot(throughput, voltage_full_anode_del);
% Compute interpolation to a uniform 0.2 Ah grid for downstream model use.
% Use explicit min/max and append qMax when needed, because colon stepping can
% miss the exact endpoint due to floating-point step accumulation.
dQ = 0.2;
qMin = min(Q);
qMax = max(Q);
Qsave = qMin:dQ:qMax;
if isempty(Qsave) || Qsave(end) < qMax
	Qsave = [Qsave, qMax];
end
Qsave = unique(Qsave, 'stable');
Vsave = interp1(Q, V, Qsave, 'pchip');
hInterp = plot(Qsave, Vsave);
title('Anode Delithiation: Boundary Points vs Full Throughput Curve')
xlabel('Capacity / Throughput (Ah)')
ylabel('Voltage (V)')
legend([hQBefore, hThroughput, hInterp], {'Boundary points', 'Full throughput trajectory', 'Profile interpolated with 0.2Ah grid'}, 'Location', 'best')

% Store the interpolated delithiation profile for the combined anode table.
Qsave_anode_delith = Qsave(:);
Vsave_anode_delith = Vsave(:);
fprintf('  Done. %d interpolated points, Q range [%.1f, %.1f] Ah\n', numel(Qsave_anode_delith), min(Qsave_anode_delith), max(Qsave_anode_delith));

%% Anode - Lithiation profile
fprintf('[2/8] Anode lithiation: filtering data...\n');
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

% Diagnostic plots of current/voltage with detected transition markers.
figure;
axCurrent = subplot(2,1,1);
hCurrent = plot(time, current);
hold on; hCurrentSteps = scatter(time(index), current(index));
title('Anode Lithiation: Current Trace with Detected Steps')
xlabel('Time (s)')
ylabel('Current (A)')
legend([hCurrent, hCurrentSteps], {'Current', 'Detected step indices'}, 'Location', 'best')
axVoltage = subplot(2,1,2);
hVoltage = plot(time, voltage);
hold on; hVoltageSteps = scatter(time(index), voltage(index));
title('Anode Lithiation: Voltage Trace with Detected Steps')
xlabel('Time (s)')
ylabel('Voltage (V)')
legend([hVoltage, hVoltageSteps], {'Voltage', 'Detected step indices'}, 'Location', 'best')
% Keep subplot panning/zoom synchronized along the time axis.
linkaxes([axCurrent, axVoltage], 'x')

% Integrate current to compute throughput over the selected interval.
throughput = cumtrapz(time(index(1):end), abs(current(index(1):end)));
% Preserve the lithiation capacity-axis reference for later comparison plots.
throughput_anode_lith = throughput;
% Preserve the matching full lithiation voltage segment for overlay plots.
voltage_full_anode_lith = voltage(index(1):end);

% Sample throughput at transition points and include final endpoint.
Q = throughput([index(1:end) - index(1) + 1; numel(throughput)]);

% Create capacity-voltage lookup vectors.
V = voltage([index(1:end); numel(voltage)]);

% Plot reduced points against full throughput curve for sanity checking.
figure;
hQBefore = plot(Q, V, 'o-');
hold on
hThroughput = plot(throughput, voltage_full_anode_lith);
% Compute interpolation to a uniform 0.2 Ah grid for downstream model use.
% Use explicit min/max and append qMax when needed, because colon stepping can
% miss the exact endpoint due to floating-point step accumulation.
dQ = 0.2;
qMin = min(Q);
qMax = max(Q);
Qsave = qMin:dQ:qMax;
if isempty(Qsave) || Qsave(end) < qMax
	Qsave = [Qsave, qMax];
end
Qsave = unique(Qsave, 'stable');
Vsave = interp1(Q, V, Qsave, 'pchip');
hInterp = plot(Qsave, Vsave);
title('Anode Lithiation: Boundary Points vs Full Throughput Curve')
xlabel('Capacity / Throughput (Ah)')
ylabel('Voltage (V)')
legend([hQBefore, hThroughput, hInterp], {'Boundary points', 'Full throughput trajectory', 'Profile interpolated with 0.2Ah grid'}, 'Location', 'best')

% Combine delithiation and lithiation into one anode table for export/use.
Qsave_anode_lith = Qsave(:);
Vsave_anode_lith = Vsave(:);
fprintf('  Done. %d interpolated points, Q range [%.1f, %.1f] Ah\n', numel(Qsave_anode_lith), min(Qsave_anode_lith), max(Qsave_anode_lith));

%% Compare the interpolated anode lithiation and delithiation profiles directly.
fprintf('[3/8] Anode: plotting comparison figure...\n');
figure;
hAnodeDelith = plot(Qsave_anode_delith, Vsave_anode_delith, 'LineWidth', 1.5);
hold on
hAnodeLith = plot(flip(Qsave_anode_lith), Vsave_anode_lith, 'LineWidth', 1.5);
title('Anode Interpolated Lithiation vs Delithiation Profiles')
xlabel('Capacity (Ah)')
ylabel('Voltage (V)')
legend([hAnodeDelith, hAnodeLith], {'Delithiation', 'Lithiation'}, 'Location', 'best')

%% Compare the interpolated anode lithiation and delithiation for publication
fprintf('[3/8] Anode: plotting comparison figure...\n');
% Compute the normalisation factor: maximum capacity across both profiles.
Qmax_anode = max([max(Qsave_anode_delith); max(Qsave_anode_lith)]);
figure;
% Divide all capacity axes by Qmax_anode so x-axis represents SoC (0–1).
hAnodeDelith = plot(Qsave_anode_delith / Qmax_anode, Vsave_anode_delith, 'r','LineWidth', 1.5);
hold on
hAnodeLith = plot(Qsave_anode_lith / Qmax_anode, Vsave_anode_lith, 'k', 'LineWidth', 1.5);
% Overlay the same full voltage segments with their throughput axes normalised
% by the same Qmax so all traces share the same SoC x-axis.
hVoltageFullDel = plot(throughput_anode_del / Qmax_anode, voltage_full_anode_del, 'b--', 'LineWidth', 1.1);
hVoltageFullLith = plot(throughput_anode_lith / Qmax_anode, voltage_full_anode_lith, 'b--', 'LineWidth', 1.1);
title('Anode Interpolated Lithiation vs Delithiation Profiles')
xlabel('SoC (-)')
ylabel('Voltage (V)')
legend([hAnodeDelith, hAnodeLith, hVoltageFullDel, hVoltageFullLith], {'Delithiation', 'Lithiation', 'GITT voltage'}, 'Location', 'best')

%%
% Store normalised SoC (capacity divided by Qmax_anode) in place of raw Ah values.
T_anode = table( ...
	[repmat("Delithiation", numel(Qsave_anode_delith), 1); repmat("Lithiation", numel(Qsave_anode_lith), 1)], ...
	[Qsave_anode_delith / Qmax_anode; Qsave_anode_lith / Qmax_anode], ...
	[Vsave_anode_delith; Vsave_anode_lith], ...
	'VariableNames', {'Mode', 'SoC(-)', 'Voltage(V)'});

% Write the combined anode table to CSV when export is needed.
% writetable(T_anode, 'GITT_anode_combined.csv');
fprintf('[4/8] Cathode delithiation: loading data...\n');

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

% Diagnostic plot: pulse boundaries over current and voltage traces.
figure;
axCurrent = subplot(2,1,1);
hCurrent = plot(time, current);
hold on; hCurrentSteps = scatter(time(index), current(index));
title('Cathode Delithiation: Current Trace with Detected Steps')
xlabel('Time (s)')
ylabel('Current (A)')
legend([hCurrent, hCurrentSteps], {'Current', 'Detected step indices'}, 'Location', 'best')
axVoltage = subplot(2,1,2);
hVoltage = plot(time, voltage);
hold on; hVoltageSteps = scatter(time(index), voltage(index));
title('Cathode Delithiation: Voltage Trace with Detected Steps')
xlabel('Time (s)')
ylabel('Voltage (V)')
legend([hVoltage, hVoltageSteps], {'Voltage', 'Detected step indices'}, 'Location', 'best')
% Keep subplot panning/zoom synchronized along the time axis.
linkaxes([axCurrent, axVoltage], 'x')

% Integrate current to form throughput and then reduce to boundary points.
throughput = cumtrapz(time(index(2):index(end)+50), current(index(2):index(end)+50));
% Preserve the delithiation capacity-axis reference for later comparison plots.
throughput_cathode_del = throughput;
% Preserve the matching full delithiation voltage segment for overlay plots.
voltage_full_cathode_del = voltage(index(2):index(end)+50);
Q = throughput([index(2:end) - index(2) + 1; numel(throughput)]);

% Capacity-voltage profile.
V = voltage([index(2:end); index(end)+50]);

% Visual check of reduced profile vs. full integrated trajectory.
figure;
hQBefore = plot(Q, V, 'o-');
hold on
hThroughput = plot(throughput, voltage_full_cathode_del);
% Compute interpolation and extrapolation to 108% of max capacity range.
% Use explicit min/max and append qMax when needed, because colon stepping can
% miss the exact endpoint due to floating-point step accumulation.
dQ = 0.2;
qMin = min(Q);
% qMax = max(Q) * 1.08;
qMax = max(Q);
Qsave = qMin:dQ:qMax;
if isempty(Qsave) || Qsave(end) < qMax
	Qsave = [Qsave, qMax];
end
Qsave = unique(Qsave, 'stable');
Vsave = interp1(Q, V, Qsave, 'pchip');
hInterp = plot(Qsave, Vsave);
title('Cathode Delithiation: Boundary Points vs Full Throughput Curve')
xlabel('Capacity / Throughput (Ah)')
ylabel('Voltage (V)')
legend([hQBefore, hThroughput, hInterp], {'Boundary points', 'Full throughput trajectory', 'Profile interpolated + extrapolated with 0.2Ah grid'}, 'Location', 'best')

% Store the interpolated delithiation profile for the combined cathode table.
Qsave_cathode_delith = Qsave(:);
Vsave_cathode_delith = Vsave(:);
fprintf('  Done. %d interpolated points, Q range [%.1f, %.1f] Ah\n', numel(Qsave_cathode_delith), min(Qsave_cathode_delith), max(Qsave_cathode_delith));

%% Cathode - Lithiation profile (with lower-range extrapolation)
fprintf('[5/8] Cathode lithiation: filtering data...\n');
% Keep workspace data for continuity; only load new source vectors.
% clear; close all
idx_cathode_lith = T_cathode_raw.Current <= 0;
time = T_cathode_raw.TestTime(idx_cathode_lith);
current = T_cathode_raw.Current(idx_cathode_lith);
voltage = T_cathode_raw.Voltage(idx_cathode_lith);

% Detect negative current transitions for pulse boundaries.
index = find(diff(current) < -1e-6);
index = index(2:end); % remove first and last indices

% Diagnostic plot of transitions in current and voltage.
figure;
axCurrent = subplot(2,1,1);
hCurrent = plot(time, current);
hold on; hCurrentSteps = scatter(time(index), current(index));
title('Cathode Lithiation: Current Trace with Detected Steps')
xlabel('Time (s)')
ylabel('Current (A)')
legend([hCurrent, hCurrentSteps], {'Current', 'Detected step indices'}, 'Location', 'best')
axVoltage = subplot(2,1,2);
hVoltage = plot(time, voltage);
hold on; hVoltageSteps = scatter(time(index), voltage(index));
title('Cathode Lithiation: Voltage Trace with Detected Steps')
xlabel('Time (s)')
ylabel('Voltage (V)')
legend([hVoltage, hVoltageSteps], {'Voltage', 'Detected step indices'}, 'Location', 'best')
% Keep subplot panning/zoom synchronized along the time axis.
linkaxes([axCurrent, axVoltage], 'x')

% Integrate current and sample at detected boundaries.
throughput = cumtrapz(time(index(1):end), abs(current(index(1):end)));
% Preserve the lithiation capacity-axis reference for later comparison plots.

% Preserve the matching full lithiation voltage segment for overlay plots.
voltage_full_cathode_lith = voltage(index(1):end);
Q = throughput([index(1:end) - index(1) + 1; numel(throughput)]);

% Construct profile capacity-voltage vectors.
V = voltage([index(1:end); numel(voltage)]);


% Compute interpolation across an extended lower capacity range (6% offset).
% Use explicit min/max and append qMax when needed, because colon stepping can
% miss the exact endpoint due to floating-point step accumulation.



%lets take the max voltage of the delithiation test (which has extrapolation) and get the missing capacity points for lithiation
% Q_extrapolated = interp1(V, Q, [Vsave_cathode_delith(end); V], 'pchip'); 
% ExtraCapaicty = -Q_extrapolated(1) ;
% Q_extrapolated = Q_extrapolated + ExtraCapaicty; % Shift the extrapolated points to start from zero capacity for lithiation
% qMin = min(Q_extrapolated);
% qMax = max(Q_extrapolated);

dQ = 0.2;
qMin = min(Q);
qMax = max(Q);
Qsave = qMin:dQ:qMax;
if isempty(Qsave) || Qsave(end) < qMax
	Qsave = [Qsave, qMax];
end
Qsave = unique(Qsave, 'stable');
Vsave = interp1(Q,  V, Qsave, 'pchip');



% Plot reduced and full trajectories for quality control.


%extrapolation
% Vsave = interp1(Q_extrapolated, [Vsave_cathode_delith(end); V], Qsave, 'pchip');
% Q = Q+ExtraCapaicty; %correct for the extrapolation
% throughput = throughput+ExtraCapaicty; %correct for the extrapolation

throughput_cathode_lith = throughput;
figure;
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

%% Compare the interpolated cathode lithiation and delithiation profiles directly.
fprintf('[6/8] Cathode: plotting comparison figure...\n');
figure;
hCathodeDelith = plot(Qsave_cathode_delith, Vsave_cathode_delith, 'LineWidth', 1.5);
hold on
hCathodeLith = plot(flip(Qsave_cathode_lith), Vsave_cathode_lith, 'LineWidth', 1.5);
title('Cathode Interpolated Lithiation vs Delithiation Profiles')
xlabel('Capacity (Ah)')
ylabel('Voltage (V)')
legend([hCathodeDelith, hCathodeLith], {'Delithiation', 'Lithiation'}, 'Location', 'best')

%% Compare the interpolated cathode lithiation and delithiation for publication
fprintf('[6b/8] Cathode: plotting publication figure...\n');
% Compute the normalisation factor: maximum capacity across both profiles.
Qmax_cathode = max([max(Qsave_cathode_delith); max(Qsave_cathode_lith)]);
figure;
% Divide all capacity axes by Qmax_cathode so x-axis represents SoC (0-1).
hCathodeDelith = plot(Qsave_cathode_delith / Qmax_cathode, Vsave_cathode_delith, 'k','LineWidth', 1.5);
hold on
hCathodeLith = plot(Qsave_cathode_lith / Qmax_cathode, Vsave_cathode_lith, 'LineWidth', 1.5);
% Overlay the full voltage segments with their throughput axes normalised
% by the same Qmax so all traces share the same SoC x-axis.
hVoltageFullDel = plot(throughput_cathode_del / Qmax_cathode, voltage_full_cathode_del, 'b--', 'LineWidth', 1.1);
hVoltageFullLith = plot(throughput_cathode_lith / Qmax_cathode, voltage_full_cathode_lith, 'b--', 'LineWidth', 1.1);
title('Cathode Interpolated Lithiation vs Delithiation Profiles')
xlabel('SoC (-)')
ylabel('Voltage (V)')
legend([hCathodeDelith, hCathodeLith, hVoltageFullDel, hVoltageFullLith], {'Lithiation', 'Delithiation', 'GITT voltage'}, 'Location', 'best')

%%
% Store normalised SoC (capacity divided by Qmax_cathode) in place of raw Ah values.
T_cathode = table( ...
	[repmat("Delithiation", numel(Qsave_cathode_delith), 1); repmat("Lithiation", numel(Qsave_cathode_lith), 1)], ...
	[Qsave_cathode_delith / Qmax_cathode; Qsave_cathode_lith / Qmax_cathode], ...
	[Vsave_cathode_delith; Vsave_cathode_lith], ...
	'VariableNames', {'Mode', 'SoC(-)', 'Voltage(V)'});

% Write the combined cathode table to CSV when export is needed.
% writetable(T_cathode, 'GITT_cathode_combined.csv');
fprintf('[7/8] Combined tables built: T_anode (%d rows), T_cathode (%d rows)\n', height(T_anode), height(T_cathode));

%% Save all open figures to PNG
fprintf('[8/8] Saving figures to pngs/ folder...\n');
pngDir = fullfile(pwd, 'pngs');
if ~exist(pngDir, 'dir')
	mkdir(pngDir);
end
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
fprintf('[9/9] --- extractOCPLines complete ---\n');