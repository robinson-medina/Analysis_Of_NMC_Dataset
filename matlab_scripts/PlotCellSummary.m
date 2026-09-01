%% PlotCellSummary.m
% Summary: Builds a one-page A4 summary for a selected ageing cell. The figure
%          combines the full current, voltage, and temperature trace; checkup
%          capacity and resistance trends; C/50 OCV and dQ/dV curves; dV/dt
%          lithium-stripping analysis; BoL/EoL zoom windows; and optional EIS
%          comparison panels.
%
% Usage: Set DataRoot, DesiredFolder, and cellNum in the Configuration block,
%        then run this script. External drivers may set cellNumOverride and
%        folderOverride before calling run(...) to process a selected cell.
%
% Outputs: <cellNum>_Summary.png, <cellNum>_Summary.pdf, and standalone EIS
%          comparison figures in this script's R-022 output directory.
%
% Authors: Feye Hoekstra, GitHub Copilot.
% Dependency files: Functions/loadAndPreprocessAgeingCsv.m,
%                   Functions/getCellLabel.m, Functions/getFigureOutputDir.m,
%                   Functions/findCheckupSegments.m,
%                   Functions/extractResistanceValues.m,
%                   Functions/analyzeDVdtAfterCharge.m,
%                   Functions/extractDVdtSegmentsAll.m,
%                   Functions/extractGITTfromTrace.m,
%                   Functions/computeCheckupCurves.m,
%                   Functions/computeStrippingAlpha.m,
%                   Functions/computeStrippingMetric.m,
%                   Functions/buildC50Phase.m, Functions/drawTimeBand.m,
%                   Functions/generateEISComparisonFromPlotEISData.m,
%                   Functions/liStrippingFigure.m,
%                   Functions/plotEISComparisonOnAxes.m,
%                   Functions/plotGITTAndOCP.m,
%                   Functions/strippingSmoothWin.m.
% Last documented: 2026-09-01

% Allow an external driver to preselect the cell (cellNumOverride) and the
% source data folder (folderOverride, e.g. Calendar_ageing_data) before
% run(...); the guards survive the clear below.
if exist('cellNumOverride', 'var'); keepCellOverride = cellNumOverride; end
if exist('folderOverride', 'var'); keepFolderOverride = folderOverride; end
clearvars -except keepCellOverride keepFolderOverride; close all; clc;

%% Resolve Functions path so the script works from any cwd
scriptDir = fileparts(mfilename('fullpath'));
functionsDir = fullfile(scriptDir, '..', '..', 'Functions');
if ~exist(functionsDir, 'dir')
    functionsDir = fullfile(scriptDir, '..', 'Functions');
end
if exist(functionsDir, 'dir')
    addpath(functionsDir)
else
    error('Shared Functions folder not found from %s.', scriptDir);
end

% Resolve one shared destination for every artifact owned by this entry script.
figureOutputDir = getFigureOutputDir('PlotCellSummary');

%% Configuration
% Single configurable dataset root. Read-only (R-001).
DataRoot      = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
DesiredFolder = fullfile(DataRoot, '4_Ageing', 'Cyclic_ageing_data');
cellNum       = 'Cell_22';       % cell to summarise (BoL + EoL GITT present in this trace)
if exist('keepCellOverride', 'var'); cellNum = keepCellOverride; end
if exist('keepFolderOverride', 'var'); DesiredFolder = keepFolderOverride; end
windowSize    = 5000;                  % movmean window for dQ/dV smoothing (matches analyzeCheckupDischarge.m)
fastChargeI_A = -11.6;                 % discharge current after fast charge, for dV/dt (matches ExtractAgeingData.m)
bolDurationDays = 7;                   % fallback BoL panel window (only used if GITT detection fails)
eolDurationDays = 7;                   % fallback EoL panel window (only used if GITT detection fails)

% EIS publication export path copied from PlotEISData.m workflow.
% This script now always builds the Nyquist publication figure
% (EISComparison.pdf) after saving the summary figure.
%
% IMPORTANT: the campaign stores life stages in separate folders:
%   1_BOL_EIS, 2_MOL_EIS, 3_EOL_EIS
% For publication Figure 4 we overlay ANY available life-stage trace(s)
% for the selected cell at a SINGLE SoC (50%), instead of plotting all
% SoC columns from a single file.
eisRootForComparison = fullfile(DataRoot, '4_Ageing', 'EIS_data');
eisTargetSoC_pct = 50;
eisMaxFreq_Hz = 12000;

% GITT detector parameters. The ageing trace contains a back-to-back
% discharge + charge GITT (C/5 pulses with ~2 h rests) at BoL and EoL.
gittParams = struct( ...
    'pulseAmp_A',          11.6,    ... % nominal C/5 pulse amplitude (58 Ah / 5); ACTIVE as of 2026-08-20 (#082 fix) - tests the pulse's PEAK |I| against this +/- pulseTol_A, replacing the old whole-pulse flatness test
    'pulseTol_A',          0.5,     ... % +/- tolerance around nominal C/5, used by the peak-amplitude test above
    'maxPulseAmp_A',       20,      ... % UPPER |I| limit for any pulse: above C/5=11.6 A with margin, below cycling charge=+29 A. Lets low-rate (C/10, C/20) pulses near the discharge cutoff be detected too (A-001)
    'minPulse_s',          60,      ... % reject < 1 min (noise / transients)
    'maxPulse_s',          3600,    ... % reject > 1 h (a full C/5 cycling discharge is ~5 h)
    'minPulseCharge_Ah',   0.15,    ... % #082 fix (2026-08-26, lowered 1.21 -> 0.15): minimum |integral(I dt)/3600| over the pulse window for it to count as a real SoC-changing GITT pulse. A full untruncated C/5 pulse (~12.5 min at 11.6 A) transfers ~2.42 Ah, but genuine pulses near the SoC extremes end in a CC->CV taper and carry far less - the most extreme observed (A3.10_Cell_22 EoL: 22 s CC + 46 s CV, -11.49 A -> -2.898 A) transfers only ~0.16 Ah. The old 1.21 Ah floor re-dropped exactly those tapered pulses (the peak-amplitude test accepted them, this floor rejected them), so enough EoL pulses were lost to fail the per-half count and the whole EoL episode disappeared. 0.15 Ah sits just below that ~0.16 Ah pulse while still clearing brief noise (a 60 s / minPulse_s full-amplitude blip is ~0.19 Ah). This floor is a per-pulse MINIMUM and is deliberately DECOUPLED from the refinement's single-pulse MAXIMUM (maxSinglePulseCharge_Ah, no longer derived from it).
    'maxIntraEpisodeGap_s', 24*3600, ... % consecutive pulses within 1 day belong to the same GITT episode. Longer than the within-checkup gap between the discharge and charge halves (~10 h on this cell) but shorter than any inter-checkup gap (~3 weeks) AND shorter than the gap between spurious 'preparation' partial pulses and the real GITT start (observed 2-day gap on EoL Mar 4) (A-001).
    'restThr_A',           0.5,     ... % |I| below this is considered rest when locating the OCV sample after the last pulse (A-001)
    'minRestDur_s',        7000,     ... % minimum duration (10 min) of a contiguous rest run used as the post-last-pulse OCV anchor; shorter than a real GITT rest (~2 h) but long enough to reject post-pulse settling transients (A-001)
    'pulseFlatnessTol',    0.05,    ... % RETIRED as of 2026-08-20 (#082 fix) - no longer used in extractGITTfromTrace; kept only for backward-compatible struct shape. See pulseAmp_A/minPulseCharge_Ah above for the current acceptance test.
    'gradThr_Apers',       3,       ... % |dI/dt| threshold (A/s) used inside a validated cluster to find pulse rising edges: a C/5 (~11.6 A) step ramps in <1 s so |dI/dt| ~ 11.6 A/s, while CV taper and noise stay well below; replaced the brittle 'first rest > minRestDur_s' walk-forward (A-001)
    'edgeJump_A',          2,       ... % #013: dt-independent companion edge test - ALSO accept a rising edge when |dI| out of rest exceeds 2 A within one sample. The logger occasionally has ~5 s rest ticks; when a pulse onset lands inside one, |dI/dt| = 11.6/5.3 = 2.2 A/s < gradThr_Apers and the pulse was silently skipped (verified on A2.02_Cell_93 BoL: 6/52 onsets failed exactly this way). 2 A sits above rest noise (< restThr_A) and below the lowest GITT pulse (C/20 = 2.9 A) (A-001)
    'minPulsesPerEpisode', 20,      ... % a real GITT half has 23–26 C/5 pulses; allow a few missing/rejected (e.g., one truncated by a gap) but reject small spurious clusters (A-001)
    'maxPulsesPerEpisode', 55,      ... % a full discharge+charge merged episode is ~46–52 pulses; 55 leaves margin without admitting cycling clusters (A-001)
    'minBoLEoLSeparation_days', 14);    % minimum gap between end of first detected episode and start of last detected episode for the last one to count as a genuine EoL; otherwise EoL is left empty (some cells do not have an EoL GITT)

% Publication palette (R-017)
COL_DARKBLUE = [1  17 181]./255;
COL_RED      = [255  0  0]./255;
COL_BLACK    = [0   0   0];

% Publication font (R-017, R-019)
PUB_FONT     = 'Times New Roman';
PUB_FONTSIZE = 8;   % caption size (R-021 default); matches paper \footnotesize
set(groot, 'defaultAxesFontName', PUB_FONT);
set(groot, 'defaultTextFontName', PUB_FONT);
set(groot, 'defaultLegendFontName', PUB_FONT);
set(groot, 'defaultColorbarFontName', PUB_FONT);
set(groot, 'defaultAxesFontSize', PUB_FONTSIZE);

cellLabel = getCellLabel(cellNum);
fprintf('\n========================================\n');
fprintf('Plotting summary for cell %s (%s)\n', cellNum, cellLabel);
fprintf('========================================\n');

%% Load CSV + preprocess (shared helper; same pipeline as ExtractAgeingData.m)
% loadAndPreprocessAgeingCsv centralises the readtable + time-reconstruction +
% NaN-gap insertion + cumulative-charge pipeline that both drivers share, so
% the ingestion code lives in exactly one place (Functions/).
loadName = fullfile(DesiredFolder, cellNum, [cellNum '.csv']);
fprintf('Loading %s ... ', cellNum); tic;
[timeWithGaps, timeS, voltage, current, cellTemp, chamberTemp, cumulative_integral] = ...
    loadAndPreprocessAgeingCsv(loadName);
fprintf('done (%.1f s)\n', toc);

%% Define analysis window (same as ExtractAgeingData.m)
startTime = datetime(timeWithGaps(1));
endTime   = datetime(timeWithGaps(end-20));
selectedIndices = (timeWithGaps >= startTime) & (timeWithGaps <= endTime);
selectedTime    = timeWithGaps(selectedIndices);
selectedVoltage = voltage(selectedIndices);
selectedCurrent = current(selectedIndices);
selectedTimeS   = timeS(selectedIndices);

%% Run reused analyses
% NOTE: these helpers each open a diagnostic figure of their own. We snapshot
% the figure list before/after each call and delete the helper's figure so
% only the unified summary remains.
preFigs = findall(groot, 'Type','figure');

% Checkup segments (constant-current C/50 discharge segments)
checkupSegs = findCheckupSegments(timeWithGaps, voltage, current, timeS, startTime, endTime);

% Resistance pulses (30s, -58A)
[resTime, res_Ohm, resFEC] = extractResistanceValues( ...
    timeWithGaps, voltage, current, timeS, startTime, endTime, cellNum, cellLabel);

% dV/dt after fast charge (lithium-stripping diagnostic)
[plottedDVdtSegs, dVdtData] = analyzeDVdtAfterCharge( ...
    selectedTime, selectedVoltage, selectedCurrent, selectedTimeS, ...
    fastChargeI_A, cellNum, cellLabel);

% Extract ALL 15-min C/5 post-charge discharge segments (not just the 5
% sampled by analyzeDVdtAfterCharge) and compute a per-segment Li-stripping
% metric (A-002). Uses the same constant-current detection criteria as
% analyzeDVdtAfterCharge (same tolerance, same min/max segment length).
strippingParams = struct( ...
    'tolerance_A',      0.1,    ... % match analyzeDVdtAfterCharge
    'minSegmentLength', 900,    ... % ~15 min at 1 Hz (A-002)
    'maxSegmentLength', 1500,   ... % ~25 min at 1 Hz (A-002)
    'metricWin_s',      [30 400], ... % early-discharge window where the Li-stripping plateau appears (A-002)
    'smoothWin',        strippingSmoothWin(cellNum), ... % site-dependent dV/dt smoothing, single-sourced (TNO A1/A2 -> 5, AIT A3/A4 -> 50)
    'alphaGrid',        0.10:0.02:2.00); % grid of power-law exponents tested by computeStrippingAlpha (A-002)

% Fixed y-axis upper limit for the Li-stripping RMSE panel [mV/s]. Pinned
% to the worst-case observed across the dataset (A2.08, plating cell) so
% the panel is directly comparable across cells (A-002).
strippingRMSE_yMax_mVpers = 0.10;
allDVdtSegs    = extractDVdtSegmentsAll( ...
    selectedTime, selectedVoltage, selectedCurrent, selectedTimeS, ...
    fastChargeI_A, strippingParams);
nAllDVdt = numel(allDVdtSegs);
strippingMetric  = zeros(nAllDVdt, 1);
strippingAlpha   = NaN(nAllDVdt, 1);
strippingRMSE    = NaN(nAllDVdt, 1);
strippingTime    = NaT(nAllDVdt, 1);
for i = 1:nAllDVdt
    strippingMetric(i) = computeStrippingMetric(allDVdtSegs{i}, strippingParams.metricWin_s);
    [strippingAlpha(i), strippingRMSE(i)] = ...
        computeStrippingAlpha(allDVdtSegs{i}, strippingParams.metricWin_s, strippingParams.alphaGrid);
    strippingTime(i)   = allDVdtSegs{i}.startTime;
end
fprintf('Extracted %d post-charge C/5 discharge segments for Li-stripping analysis.\n', nAllDVdt);

% Close the helpers' auxiliary figures (we only want the unified A4 figure)
postFigs = findall(groot, 'Type','figure');
delete(setdiff(postFigs, preFigs));

%% Per-checkup curves via shared helper (single source of the checkup formula)
% computeCheckupCurves applies the identical acceptance test
% (V(1) > 4.1 V and V(end) < 2.76 V) and returns the per-checkup capacity,
% voltage and dQ/dV vectors. Functions/analyzeCheckupDischarge.m uses the same
% helper, so the checkup formula now lives in exactly one place.
fprintf('Computing per-checkup OCP / dQdV curves ... ');
checkups = computeCheckupCurves(checkupSegs, selectedTime, selectedVoltage, ...
    selectedCurrent, selectedTimeS, windowSize);
nValid = numel(checkups);

% Unpack into the parallel arrays used by the rest of this script.
validSegs    = {checkups.segmentIndices};   % per-checkup index vectors
validCapAh   = {checkups.capacity_Ah_vec};  % per-checkup capacity vector [Ah]
validVoltage = {checkups.voltage_vec};      % per-checkup voltage vector [V]
validdQdV    = {checkups.dQdV_vec};         % per-checkup dQ/dV vector [As/V]
if nValid > 0
    validStartTime           = [checkups.startTime];    % checkup start datetimes
    validEndTime             = [checkups.endTime];      % checkup end datetimes
    checkupCapacity_Ah       = [checkups.capacity_Ah];  % per-checkup capacity [Ah]
    checkupCapacityTimeStamp = [checkups.timeStamp];    % per-checkup trend timestamp
else
    validStartTime           = NaT(0);
    validEndTime             = NaT(0);
    checkupCapacity_Ah       = [];
    checkupCapacityTimeStamp = NaT(0);
end
fprintf('done. %d valid checkup discharges found.\n', nValid);

%% Build colour map: one colour per valid checkup, used everywhere
% Re-using the same colormap across panels is the visual "link" between
% the bands on the time-series and the curves in the analysis panels.
% The colour thread runs oldest (BoL, dark blue) -> newest (EoL). The raw
% parula colormap ends in a very pale/bright yellow that looked "too
% transparent" (washed out) for the EoL colour, so the sampling range is
% trimmed to the first 88% of parula, which keeps the same smooth
% gradient but stops short of the palest tail, giving the EoL colour more
% contrast against the white figure background.
if nValid > 0
    fullParulaMap = parula(256);
    maxParulaIdx  = round(0.88 * size(fullParulaMap, 1));
    sampleIdx     = round(linspace(1, maxParulaIdx, max(nValid, 2)));
    checkupColors = fullParulaMap(sampleIdx, :);
else
    checkupColors = [];
end

% For each resistance pulse / dV/dt segment, pick the colour of the nearest
% checkup so all downstream points colour-match the band on the top panel.
resColors  = zeros(numel(resTime), 3);
for i = 1:numel(resTime)
    if nValid > 0
        [~, k] = min(abs(validStartTime - resTime(i)));
        resColors(i,:) = checkupColors(k,:);
    end
end
dVdtColors = zeros(numel(plottedDVdtSegs), 3);
dVdtStartTimes = NaT(numel(plottedDVdtSegs),1);
for i = 1:numel(plottedDVdtSegs)
    dVdtStartTimes(i) = plottedDVdtSegs{i}.time(1);
    if nValid > 0
        [~, k] = min(abs(validStartTime - dVdtStartTimes(i)));
        dVdtColors(i,:) = checkupColors(k,:);
    end
end

%% Detect BoL and EoL GITT episodes inside the trace
% A GITT episode = cluster of C/5 (+/-11.6 A) pulses with multi-hour rests
% in between. The cycling discharge on A2.09 is at -1.5C (=-87 A) and the
% checkup C/50 is at -1.16 A, so a +/-11.6 A pulse only appears during
% GITT or characterization. Per-pulse OCV is extracted as the voltage at
% the end of the rest following that pulse (just before the next pulse).
fprintf('Detecting GITT episodes (C/5 pulse train) ... ');
gittEpisodes = extractGITTfromTrace(timeWithGaps, voltage, current, timeS, gittParams);
fprintf('found %d episode(s).\n', numel(gittEpisodes));
% BoL/EoL assignment is POSITION-AWARE (#013, 2026-08-14): an episode only
% counts as BoL/EoL if it actually sits near the corresponding end of the
% trace. Blindly taking gittEpisodes(1) as BoL mislabels cells whose BoL
% GITT is missing from the csv (observed on A2.02_Cell_93: the only
% detected episode is the EoL train at the very end of the trace; the BoL
% train was never recorded in this file - a data-side gap). An episode is
% BoL-positioned when its start is closer to the trace start than its end
% is to the trace end, and vice versa.
traceT0 = timeWithGaps(find(~isnat(timeWithGaps), 1, 'first'));
traceT1 = timeWithGaps(find(~isnat(timeWithGaps), 1, 'last'));
bolGITT = [];
eolGITT = [];
if numel(gittEpisodes) == 1
    ep = gittEpisodes(1);
    if days(ep.timeStart - traceT0) <= days(traceT1 - ep.timeEnd)
        bolGITT = ep;
        fprintf('Single episode is BoL-positioned (%.1f d from trace start); EoL empty.\n', ...
            days(ep.timeStart - traceT0));
    else
        eolGITT = ep;
        fprintf(['Single episode is EoL-positioned (%.1f d from trace END, %.1f d from start): ' ...
            'classified as EoL; BoL empty (BoL GITT missing from this csv).\n'], ...
            days(traceT1 - ep.timeEnd), days(ep.timeStart - traceT0));
    end
elseif numel(gittEpisodes) >= 2
    % First episode = BoL, last = EoL, with the established guards: EoL is
    % only accepted when genuinely separated from BoL (>= 14 d; rejects
    % spurious clusters a few days after BoL on stopped tests).
    bolGITT = gittEpisodes(1);
    sepDays = days(gittEpisodes(end).timeStart - gittEpisodes(1).timeEnd);
    if sepDays >= gittParams.minBoLEoLSeparation_days
        eolGITT = gittEpisodes(end);
        fprintf('EoL GITT accepted (BoL-EoL gap = %.1f d >= %g d).\n', ...
            sepDays, gittParams.minBoLEoLSeparation_days);
    else
        fprintf('EoL GITT REJECTED (BoL-EoL gap = %.1f d < %g d); leaving EoL empty.\n', ...
            sepDays, gittParams.minBoLEoLSeparation_days);
    end
else
    fprintf('No GITT episodes detected; BoL and EoL empty.\n');
end

%% Detect C/50 charge segments (mirror of findCheckupSegments at +1.16 A)
% findCheckupSegments only returns C/50 discharge segments. We mirror its
% logic inline here to also find the matching C/50 charge segments so the
% BoL/EoL OCV-vs-Q overlay can show the full discharge + charge OCP curve.
chargeCurrentValue_A   = +58/50;   % +C/50 (1.16 A) for a 58 Ah cell
chargeCurrentTol_A     = 0.1;      % matches the discharge tolerance
minChargeSegmentLength = 2000;     % matches findCheckupSegments
chgMask = abs(selectedCurrent - chargeCurrentValue_A) <= chargeCurrentTol_A;
chgMask(isnan(selectedCurrent)) = false;
dCM       = diff([false; chgMask(:); false]);
chgStarts = find(dCM ==  1);
chgEnds   = find(dCM == -1) - 1;
keepChg   = (chgEnds - chgStarts + 1) >= minChargeSegmentLength;
chargeSegs = arrayfun(@(s,e) (s:e)', chgStarts(keepChg), chgEnds(keepChg), ...
    'UniformOutput', false);
fprintf('Found %d C/50 charge segments.\n', numel(chargeSegs));

%% Build BoL and EoL C/50 phase data (discharge + matching charge on shared Q)
% Q is the signed cumulative charge integrated from the start of the C/50
% discharge through the end of the matching C/50 charge, exactly as
% requested for alignment with the GITT signed-Q axis.
% Pick the checkup temporally closest to the corresponding GITT episode.
% Blindly using the first/last valid checkup can anchor the two curves' Q=0
% references to different real-world SoC points and make them appear offset.
% Fall back to the first/last checkup when no GITT episode was detected.
if nValid >= 1
    bolIdx = 1;
    if ~isempty(bolGITT)
        [~, bolIdx] = min(abs(validStartTime - bolGITT.timeStart));
    end
    bolC50 = buildC50Phase(validSegs{bolIdx}, chargeSegs, ...
        selectedVoltage, selectedCurrent, selectedTimeS);
else
    bolC50 = struct('dischQ_Ah',[], 'dischV',[], 'chargeQ_Ah',[], 'chargeV',[]);
end
if nValid >= 2
    eolIdx = nValid;
    if ~isempty(eolGITT)
        [~, eolIdx] = min(abs(validStartTime - eolGITT.timeStart));
    end
    eolC50 = buildC50Phase(validSegs{eolIdx}, chargeSegs, ...
        selectedVoltage, selectedCurrent, selectedTimeS);
else
    eolC50 = struct('dischQ_Ah',[], 'dischV',[], 'chargeQ_Ah',[], 'chargeV',[]);
end

%% Define BoL and EoL time windows for the linking bands
% If a GITT episode was detected, the band on the top I/V/T spans that
% episode. For BoL we fall back to the first N days of the trace when no
% BoL GITT was found. For EoL we DO NOT fall back; if no EoL GITT was
% confidently detected, no EoL band is drawn (the previous 'last N days'
% fallback was misleading because some cells genuinely have no EoL data).
if ~isempty(bolGITT)
    bolStart = bolGITT.timeStart;
    bolEnd   = bolGITT.timeEnd;
else
    bolStart = timeWithGaps(1);
    bolEnd   = bolStart + days(bolDurationDays);
end
if ~isempty(eolGITT)
    eolStart = eolGITT.timeStart;
    eolEnd   = eolGITT.timeEnd;
else
    eolStart = NaT;
    eolEnd   = NaT;
end

% Colours for the BoL / EoL bands (reuse publication palette so they are
% distinguishable from the per-checkup parula colours)
COL_BOL = COL_DARKBLUE;
COL_EOL = COL_RED;

%% ====================== GITT DIAGNOSTIC FIGURE =========================
% Standalone debug plot for each detected GITT episode. Shows the raw
% current and voltage traces over the episode window with the detected
% pulses highlighted (discharge in blue, charge in orange) and the OCV
% measurement points overlaid as red markers. The third row shows the
% extracted OCV vs cumulative signed charge curve. A textual summary is
% printed for each episode and the figure is saved to pngs/.
debugGITTPlot(timeWithGaps, voltage, current, bolGITT, 'BoL', cellNum, figureOutputDir);
debugGITTPlot(timeWithGaps, voltage, current, eolGITT, 'EoL', cellNum, figureOutputDir);

%% ================ LI-STRIPPING STANDALONE FIGURE =======================
% Self-contained publication figure that documents the Li-stripping
% detection concept (A-002):
%   Row 1: full V-vs-time trace with a coloured tick at the start of every
%          detected 15-min C/5 post-charge discharge segment (link to the
%          time-series data so the reader can see where the segments come
%          from).
%   Row 2 left:  V vs time (per segment, time-zeroed), colour by age.
%   Row 2 right: dV/dt vs time (per segment), colour by age, with the
%                metric window shaded. A smooth (no-stripping) curve sits
%                roughly flat; a Li-stripping segment shows a clear bump
%                whose peak-to-trough magnitude is the per-segment metric.
liStrippingFigure(timeWithGaps, voltage, allDVdtSegs, strippingMetric, ...
    strippingParams, cellNum, cellLabel, scriptDir, PUB_FONT, PUB_FONTSIZE);

%% ============================ FIGURE ===================================
% Double-column figure* sized to 85% of \textwidth (443.7 pt ~= 15.66 cm)
% per R-021, keeping the original ~0.74 A4-portrait aspect. Position width
% is tuned so the tight-cropped export lands on the 443.7 bp target.
% PaperPositionMode='auto' + vector exportgraphics preserves the 8 pt fonts.
% Height reduced (2026-08-19) from 25.43 to 22.00 cm: at 25.43 cm the figure
% left no room on the page for its caption, which overflowed onto the page
% number; width (already tuned to the 97% textwidth target) is unchanged.
fig = figure('Units','centimeters','Position',[1 1 18.05 22.00], 'Color','w'); % width tuned for 97% of textwidth after tight cropping; height avoids page-number overlap
fig.PaperPositionMode = 'auto';
tl = tiledlayout(fig, 7, 6, 'TileSpacing','compact','Padding','compact');
% title(tl, sprintf('Cell summary: %s  -  %s', cellNum, cellLabel), ...
%     'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE+1, 'Interpreter','none');

%% Top three rows: I, V, T full-width
ax_I = nexttile(tl,  1, [1 6]);
plot(ax_I, timeWithGaps, current, 'Color', COL_DARKBLUE, 'LineWidth', 1.0); % R-017 item 4
ylabel(ax_I, 'Current [A]');     % R-020
grid(ax_I, 'on'); box(ax_I, 'on');

ax_V = nexttile(tl,  7, [1 6]);
plot(ax_V, timeWithGaps, voltage, 'Color', COL_DARKBLUE, 'LineWidth', 1.0); % R-017 item 4
ylabel(ax_V, 'Voltage [V]');     % R-020
ylim(ax_V, [2.5 4.5]);
grid(ax_V, 'on'); box(ax_V, 'on');

ax_T = nexttile(tl, 13, [1 6]);
plot(ax_T, timeWithGaps, cellTemp,    'Color', COL_DARKBLUE, 'LineWidth', 1.0); hold(ax_T,'on'); % R-017 item 4
plot(ax_T, timeWithGaps, chamberTemp, 'Color', COL_RED,      'LineWidth', 1.0); % R-017 item 4
ylabel(ax_T, 'Temperature [°C]');  % R-020
legend(ax_T, {'Cell','Chamber'}, 'Location','northeast', 'Box','off', ...
    'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE);
grid(ax_T, 'on'); box(ax_T, 'on');

%% Overlay coloured vertical bands on the I/V/T panels
% One band per valid checkup discharge (parula colour scheme).
for i = 1:nValid
    drawTimeBand([ax_I ax_V ax_T], validStartTime(i), validEndTime(i), ...
        checkupColors(i,:), 0.25);
end
% Also mark the BoL and EoL visual zoom windows in their own colours
drawTimeBand([ax_I ax_V ax_T], bolStart, bolEnd, COL_BOL, 0.12);
if ~isnat(eolStart) && ~isnat(eolEnd)
    drawTimeBand([ax_I ax_V ax_T], eolStart, eolEnd, COL_EOL, 0.12);
end

%% Row 4: combined Capacity (left axis) + Resistance (right axis) trend
% Full-width twin-axis panel: capacity in blue on the left, resistance in
% red on the right, on a shared date axis. Replaces the previous two-panel
% capacity/resistance row so the next row can give dQ/dV and the
% Li-stripping metric more space.
ax_CapRes = nexttile(tl, 19, [1 6]);
yyaxis(ax_CapRes, 'left');
hold(ax_CapRes, 'on');
if nValid > 0
    plot(ax_CapRes, checkupCapacityTimeStamp, checkupCapacity_Ah, '-', ...
        'Color', [0.5 0.5 0.5], 'LineWidth', 1.0, 'HandleVisibility','off'); % R-017 item 4
    for i = 1:nValid
        plot(ax_CapRes, checkupCapacityTimeStamp(i), checkupCapacity_Ah(i), 'o', ...
            'MarkerEdgeColor', COL_DARKBLUE, 'MarkerFaceColor', checkupColors(i,:), ...
            'MarkerSize', 5, 'HandleVisibility','off');
    end
end
ylabel(ax_CapRes, 'C_{RPT} [Ah]', 'Color', COL_DARKBLUE);
ax_CapRes.YAxis(1).Color = COL_DARKBLUE;
yyaxis(ax_CapRes, 'right');
hold(ax_CapRes, 'on');
if numel(resTime) > 0
    plot(ax_CapRes, resTime, res_Ohm*1000, '-', ...
        'Color', [0.5 0.5 0.5], 'LineWidth', 1.0, 'HandleVisibility','off'); % R-017 item 4
    for i = 1:numel(resTime)
        plot(ax_CapRes, resTime(i), res_Ohm(i)*1000, 's', ...
            'MarkerEdgeColor', COL_RED, 'MarkerFaceColor', resColors(i,:), ...
            'MarkerSize', 5, 'HandleVisibility','off');
    end
end
hResLabel = ylabel(ax_CapRes, 'R_{RPT} [m\Omega]', 'Color', COL_RED); % R-020
ax_CapRes.YAxis(2).Color = COL_RED;
% Lift the right-hand y-axis label slightly so its lower end no longer
% overlaps the last (rightmost) date x-tick label in the corner. (A previous
% horizontal nudge pushed the label off the right figure edge, so it was
% clipped/invisible on export; a small vertical shift keeps it on-canvas.)
hResLabel.Units = 'normalized';
hResLabel.Position(2) = hResLabel.Position(2) + 0.05;
xlabel(ax_CapRes, 'Date');
title(ax_CapRes, 'Capacity and resistance vs age', 'FontWeight','normal');
grid(ax_CapRes, 'on'); box(ax_CapRes, 'on');

% Keep subplots 1-4 on the exact same x-limits and ensure the boundary
% months are always present in the datetime tick labels.
commonXLim = [timeWithGaps(1) timeWithGaps(end)];
monthTickStart = dateshift(commonXLim(1), 'start', 'month');
monthTickEnd   = dateshift(commonXLim(2), 'start', 'month');
monthTicks = (monthTickStart:calmonths(1):monthTickEnd).';
commonXTicks = unique([commonXLim(1); monthTicks; commonXLim(2)]);
for ax = [ax_I, ax_V, ax_T, ax_CapRes]
    ax.XTick = commonXTicks;
    xtickformat(ax, 'MMM yyyy');
end
linkaxes([ax_I, ax_V, ax_T, ax_CapRes], 'x');
xlim(ax_I, commonXLim);

% EIS stage colors: BoL/EoL follow the same age-gradient endpoints used in
% the rest of Figure 3; MoL stays green for stage distinction.
if nValid > 0
    eisColBoL = checkupColors(1,:);
    eisColEoL = checkupColors(nValid,:);
else
    % Fallback when no valid checkup colours exist.
    eisColBoL = COL_BOL;
    eisColEoL = COL_EOL;
end
eisStageColors  = [eisColBoL; [0 140 70] ./ 255; eisColEoL];
eisStageMarkers = {'o', 's', 'd'};

%% Row 5: Li-stripping vs age (full width, directly below Capacity/Resistance)
% Placed immediately under the capacity / resistance trend and sharing the
% same datetime window/ticks so the two age panels line up.
ax_dVdt = nexttile(tl, 25, [1 6]);
hold(ax_dVdt, 'on');
% Per-segment power-law fit RMSE vs date (A-002).
% RMSE = sqrt(mean(residual^2)) of the fit  dV/dt = a + b*t^(-alpha)
% over the [30 400] s metric window, expressed in mV/s. A clean,
% monotonic dV/dt relaxation fits the power-law form well (small RMSE);
% a Li-stripping shoulder is a non-monotonic deviation that the smooth
% power-law form cannot reproduce, so the RMSE rises.
% Each marker uses the colour of the nearest checkup so it visually links
% to the I/V/T bands above.
if nAllDVdt == 0
    text(ax_dVdt, 0.5, 0.5, ...
        sprintf('No segments at %.1f A\nfound for Li-stripping', fastChargeI_A), ...
        'Units','normalized','HorizontalAlignment','center', ...
        'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE-1);
else
    % Map every dV/dt segment to the colour of the nearest valid checkup.
    stripColors = zeros(nAllDVdt, 3);
    for i = 1:nAllDVdt
        if nValid > 0
            [~, k] = min(abs(validStartTime - strippingTime(i)));
            stripColors(i,:) = checkupColors(k,:);
        else
            stripColors(i,:) = [0.5 0.5 0.5];
        end
    end
    % Scatter (markers) + faint connecting line for readability. Marker
    % edge matches the marker face so the BoL->EoL colour thread reads.
    plot(ax_dVdt, strippingTime, strippingRMSE * 1000, '-', ...
        'Color', [0.5 0.5 0.5], 'LineWidth', 1.0); % R-017 item 4
    for i = 1:nAllDVdt
        plot(ax_dVdt, strippingTime(i), strippingRMSE(i) * 1000, 'o', ...
            'MarkerEdgeColor', stripColors(i,:), 'MarkerFaceColor', stripColors(i,:), ...
            'MarkerSize', 4);
    end
end
xlabel(ax_dVdt, 'Date');
ylabel(ax_dVdt, 'Power-law fit RMSE [mV/s]'); % R-020
title(ax_dVdt, 'Li-stripping vs age', 'FontWeight','normal');
ylim(ax_dVdt, [0 strippingRMSE_yMax_mVpers]);  % fixed across cells (A-002)
grid(ax_dVdt, 'on'); box(ax_dVdt, 'on');
% Align this datetime x-axis with the top time-series/cap-res axis set.
% Cells with NO stripping segments (calendar / stationary-storage profiles)
% never plot datetime data into this panel; its ruler is numeric and cannot
% take datetime ticks (nor accept datetime data once established, #079).
% Graceful fallback: keep the "no segments" note and suppress the ticks.
if nAllDVdt > 0
    ax_dVdt.XTick = commonXTicks;
    xtickformat(ax_dVdt, 'MMM yyyy');
    xlim(ax_dVdt, commonXLim);
else
    ax_dVdt.XTick = [];
end

%% Rows 6-7: 2x2 diagnostic tiles (dQ/dV, EIS on row 6; OCV, OCP on row 7)
% The BoL/EoL OCV/OCP overlay colours match the EIS gradient endpoints so
% the whole 2x2 block reads as one BoL->EoL colour thread.
colGITT_BoL = eisColBoL;
colGITT_EoL = eisColEoL;

% Row 6 left: dQ/dV (differential capacity)
ax_dQdV = nexttile(tl, 31, [1 3]);
hold(ax_dQdV, 'on');
for i = 1:nValid
    plot(ax_dQdV, validVoltage{i}, validdQdV{i}, ...
        'Color', checkupColors(i,:), 'LineWidth', 1.0); % R-017 item 4
end
xlabel(ax_dQdV, 'Voltage [V]');
ylabel(ax_dQdV, 'dQ/dV [As/V]'); % R-020
title(ax_dQdV, 'Differential capacity', 'FontWeight','normal');
grid(ax_dQdV, 'on'); box(ax_dQdV, 'on');

% Row 6 right: EIS Nyquist comparison (BoL/MoL/EoL at one SoC)
ax_EIS = nexttile(tl, 34, [1 3]);
plotEISComparisonOnAxes(ax_EIS, eisRootForComparison, eisTargetSoC_pct, eisMaxFreq_Hz, ...
    cellNum, eisStageColors, eisStageMarkers, true);

% Row 7 left: OCV (BoL/EoL GITT per-pulse OCV + first/last C/50 OCP overlay)
ax_OCV = nexttile(tl, 37, [1 3]);
plotGITTAndOCP(ax_OCV, bolGITT, eolGITT, bolC50, eolC50, ...
    colGITT_BoL, colGITT_EoL, PUB_FONT, PUB_FONTSIZE);

% Row 7 right: C/50 OCV curves (per-checkup discharge capacity vs voltage)
ax_OCP = nexttile(tl, 40, [1 3]);
hold(ax_OCP, 'on');
for i = 1:nValid
    plot(ax_OCP, validCapAh{i}, validVoltage{i}, ...
        'Color', checkupColors(i,:), 'LineWidth', 1.0); % R-017 item 4
end
xlabel(ax_OCP, 'Discharge capacity [Ah]');
ylabel(ax_OCP, 'Voltage [V]');
title(ax_OCP, 'C/50 OCV curves', 'FontWeight','normal');
grid(ax_OCP, 'on'); box(ax_OCP, 'on');

%% Apply publication font / size to every axes (defensive, R-017/R-019)
% LabelFontSizeMultiplier/TitleFontSizeMultiplier = 1 keeps axis labels and
% titles at exactly PUB_FONTSIZE (defaults of 1.1 would enlarge them; R-021).
% Axes frame (box) width set to 0.8 pt per R-017 item 4 (was left at the
% MATLAB default of 0.5 pt).
allAxes = findall(fig, 'Type','axes');
for k = 1:numel(allAxes)
    set(allAxes(k), 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE, ...
        'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1, ...
        'LineWidth', 0.8, ... % R-017 item 4: axes frame, not a data trace
        'TickLabelInterpreter','tex');
end

%% Save figure (PNG + vector PDF in pngs/), R-018
pngsDir = figureOutputDir;
pngFile = fullfile(pngsDir, [cellNum '_Summary.png']);
pdfFile = fullfile(pngsDir, [cellNum '_Summary.pdf']);
drawnow;
exportgraphics(fig, pngFile, 'Resolution', 300);
exportgraphics(fig, pdfFile, 'ContentType', 'vector');
fprintf('\nSummary figure saved:\n  %s\n  %s\n', pngFile, pdfFile);

%% Restore default groot settings so we don't pollute later sessions
set(groot, 'defaultAxesFontName',     'remove');
set(groot, 'defaultTextFontName',     'remove');
set(groot, 'defaultLegendFontName',   'remove');
set(groot, 'defaultColorbarFontName', 'remove');
set(groot, 'defaultAxesFontSize',     'remove');


function plottedCount = plotEISComparisonOnAxes(ax, eisRootFolder, targetSoC_pct, maxFreq, cellNum, stageColors, stageMarkers, showTitle)
% plotEISComparisonOnAxes - plot BoL/MoL/EoL Nyquist traces at one SoC on
% a provided axes using publication styling and fixed axis limits.
stageFolders = {'1_BOL_EIS', '2_MOL_EIS', '3_EOL_EIS'};
stageLabels  = {'BoL', 'MoL', 'EoL'};

hold(ax, 'on');
grid(ax, 'on');
box(ax, 'on');

legendHandles = gobjects(0);
legendLabels  = {};
plottedCount  = 0;

if ~exist(eisRootFolder, 'dir')
    text(ax, 0.5, 0.5, 'EIS root folder not found', ...
        'Units','normalized', 'HorizontalAlignment','center');
    return
end

for stageIdx = 1:numel(stageFolders)
    stageFolder = fullfile(eisRootFolder, stageFolders{stageIdx});
    if ~exist(stageFolder, 'dir')
        continue
    end

    stageCsv = fullfile(stageFolder, [cellNum '_impedanceData.csv']);
    if ~exist(stageCsv, 'file')
        continue
    end

    opts = detectImportOptions(stageCsv);
    opts.DataLines = [2 Inf];
    opts.VariableNamesLine = 1;
    data = readtable(stageCsv, opts);
    colNames = data.Properties.VariableNames;

    rRealCol = '';
    for c = 1:numel(colNames)
        thisCol = colNames{c};
        tok = regexp(thisCol, '^R_real_ohm_SoC(\d+)$', 'tokens', 'once');
        if isempty(tok)
            continue
        end
        thisSoC = str2double(tok{1});
        if isfinite(thisSoC) && abs(thisSoC - targetSoC_pct) < 1e-9
            rRealCol = thisCol;
            break
        end
    end
    if isempty(rRealCol)
        continue
    end

    socSuffix = extractAfter(rRealCol, 'R_real_ohm_SoC');
    rImgCol   = ['R_img_ohm_SoC' socSuffix];
    freqCol   = ['Freq_Hz_SoC'   socSuffix];
    if ~ismember(rImgCol, colNames)
        continue
    end

    rReal = data.(rRealCol);
    rImg  = data.(rImgCol);
    if ismember(freqCol, colNames)
        freq = data.(freqCol);
        validIdx = ~isnan(rReal) & ~isnan(rImg) & ~isnan(freq) & (freq <= maxFreq);
    else
        validIdx = ~isnan(rReal) & ~isnan(rImg);
    end
    rReal = rReal(validIdx);
    rImg  = rImg(validIdx);
    if isempty(rReal)
        continue
    end

    h = plot(ax, rReal*1000, -rImg*1000, '-', ...  % Ohm -> milliohm for display
        'Color', stageColors(stageIdx,:), ...
        'LineWidth', 1.0, ...  % R-017 item 4
        'Marker', stageMarkers{stageIdx}, ...
        'MarkerSize', 5, ...
        'MarkerFaceColor', stageColors(stageIdx,:), ...
        'MarkerEdgeColor', stageColors(stageIdx,:));

    plottedCount = plottedCount + 1;
    legendHandles(end+1,1) = h; %#ok<AGROW>
    legendLabels{end+1,1} = sprintf('%s (SoC %.0f%%)', stageLabels{stageIdx}, targetSoC_pct); %#ok<AGROW>
end

xlabel(ax, 'R_{real} [m\Omega]');
ylabel(ax, '-R_{img} [m\Omega]');
% xlim upper bound widened from 3 to 4 mOhm (2026-08-07): with 'axis equal'
% below, this data aspect ratio makes the rendered plot box exactly as wide
% as the "C/50 OCV curves" tile directly below it (measured via ax.Position
% in the summary figure), instead of being letterboxed narrower.
xlim(ax, [0.7 4]);
ylim(ax, [-0.4 0.3]);
axis(ax, 'equal');
xlim(ax, [0.7 4]);
ylim(ax, [-0.4 0.3]);
if showTitle
    title(ax, sprintf('EIS comparison (SoC %.0f%%)', targetSoC_pct), 'FontWeight','normal');
end

if ~isempty(legendHandles)
    lgd = legend(ax, legendHandles, legendLabels, 'Box', 'off');
    % Pin the legend box flush into the extreme lower-right corner of the
    % axes; 'southeast' leaves inward padding that still overlaps the arcs.
    drawnow;                                   % force layout so Position is valid
    lgd.Units = 'normalized';                  % match the axes Position units
    axPos = ax.Position;                       % [x y w h] of the axes in the figure
    lgd.Position(1) = axPos(1) + axPos(3) - lgd.Position(3);  % right edge flush
    lgd.Position(2) = axPos(2);                              % bottom edge flush
else
    text(ax, 0.5, 0.5, sprintf('No EIS traces at SoC %.0f%%', targetSoC_pct), ...
        'Units','normalized', 'HorizontalAlignment','center');
end
end


function generateEISComparisonFromPlotEISData(eisRootFolder, targetSoC_pct, maxFreq, scriptDir, pubFont, pubFontSize, cellNum, colBolRef, colEolRef) %#ok<DEFNU>
% generateEISComparisonFromPlotEISData - build one Nyquist comparison plot
% for a selected cell at ONE SoC (default: 50%) across life stages.
%
% NOTE: the standalone Figure 4 (independent EIS export) is no longer
% produced by this script; the EIS comparison now lives only as a tile in
% the summary figure (via plotEISComparisonOnAxes). This helper is retained
% (uncalled) in case the standalone export is needed again.
%
% Data layout assumption (campaign convention):
%   EIS root contains stage folders
%     1_BOL_EIS, 2_MOL_EIS, 3_EOL_EIS
%   each stage folder may contain
%     <cellID>_impedanceData.csv
%
% Goal:
%   Overlay ANY available stage traces (BoL/MoL/EoL) for the selected cell
%   at targetSoC_pct. Missing stage files are skipped gracefully.

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

eisPdf = fullfile(figureOutputDir, 'EISComparison.pdf');
eisPng = fullfile(figureOutputDir, 'EISComparison.png');
exportgraphics(fig, eisPdf, 'ContentType', 'vector');
exportgraphics(fig, eisPng, 'Resolution', 300);
fprintf('EIS publication figure exported:\n  %s\n  %s\n', eisPdf, eisPng);

fprintf('\n########################################\n');
fprintf('Nyquist analysis complete!\n');
fprintf('Processed available BoL/MoL/EoL traces for %s at SoC %.0f%%\n', cellNum, targetSoC_pct);
fprintf('########################################\n');
end


function plotZoomVI(ax, t, V, I, t0, t1, colV, colI, ttl, fontName, fontSize)
% plotZoomVI - twin-y zoom of V (left axis) and I (right axis) over [t0,t1]
% Currently unused (the combined GITT panel renders an in-axes message when
% no GITT episode is detected). Kept here for diagnostic re-use.
mask = (t >= t0) & (t <= t1);
if ~any(mask)
    text(ax, 0.5, 0.5, 'No data in window', ...
        'Units','normalized','HorizontalAlignment','center', ...
        'FontName', fontName, 'FontSize', fontSize-1);
    title(ax, ttl, 'FontWeight','normal');
    return
end
yyaxis(ax, 'left');
plot(ax, t(mask), V(mask), 'Color', colV, 'LineWidth', 1.0); % R-017 item 4
ylabel(ax, 'Voltage [V]'); % R-020
ax.YColor = colV;
yyaxis(ax, 'right');
plot(ax, t(mask), I(mask), 'Color', colI, 'LineWidth', 1.0); % R-017 item 4
ylabel(ax, 'Current [A]'); % R-020
ax.YColor = colI;
xlim(ax, [t0 t1]);
xlabel(ax, 'Date');
title(ax, ttl, 'FontWeight','normal');
grid(ax, 'on'); box(ax, 'on');
end


% extractDVdtSegmentsAll lives in Functions/ so the duration-based segment
% filter and duplicate-time guard have one maintained implementation. The
% local metric helpers below mirror their Functions/ counterparts.
function metric = computeStrippingMetric(seg, windowS)
% computeStrippingMetric - quantitative Li-stripping indicator for one
% post-charge C/5 discharge segment (A-002).
%
% Definition: max(dV/dt) - min(dV/dt) over the early-discharge time window
% windowS = [t1 t2] (seconds, relative to segment start). A smooth (no-
% stripping) curve has near-constant dV/dt over this window -> small
% metric. A Li-stripping segment shows a plateau (voltage roughly flat for
% a while) which produces a localised bump in dV/dt -> large metric.
%
% Inputs:
%   seg     - struct produced by extractDVdtSegmentsAll (uses .timeS_interp
%             and .dVdt_Vpers)
%   windowS - 2-element vector [t_start t_end] in seconds
%
% Output:
%   metric  - scalar [V/s], NaN if the window has too few samples
metric = NaN;
if isempty(seg) || ~isfield(seg, 'dVdt_Vpers') || ~isfield(seg, 'timeS_interp')
    return
end
t = seg.timeS_interp;
y = seg.dVdt_Vpers;
m = (t >= windowS(1)) & (t <= windowS(2)) & ~isnan(y);
if nnz(m) < 5
    return
end
metric = max(y(m)) - min(y(m));
end


function [alpha, rmse] = computeStrippingAlpha(seg, windowS, alphaGrid)
% computeStrippingAlpha - power-law exponent of the dV/dt relaxation shape
% for one post-charge C/5 discharge segment (A-002).
%
% Definition: fit  dV/dt(t) = a + b * t^(-alpha)  over the early-discharge
% time window windowS = [t1 t2] (seconds, relative to segment start). For
% each candidate alpha in alphaGrid the linear-in-(a,b) least-squares
% problem is solved; the alpha that minimises the residual sum of squares
% is returned together with the corresponding RMSE.
%
% This replaces a log-basis fit; a basis-function comparison across cells
% A1.05, A2.05, A2.08 and A2.11 showed the power-law form has the lowest
% residual on every cell (see EvaluateStrippingFit.m).
%
% Inputs:
%   seg       - struct produced by extractDVdtSegmentsAll (uses
%               .timeS_interp and .dVdt_Vpers)
%   windowS   - 2-element vector [t_start t_end] in seconds
%   alphaGrid - vector of candidate exponents (e.g. 0.10:0.02:2.00)
%
% Outputs:
%   alpha     - scalar best-fit exponent, NaN if the window has too few
%               samples or the fit fails.
%   rmse      - sqrt(mean(residual.^2)) of the best-fit power-law model
%               over the metric window, in V/s. Small RMSE means the
%               dV/dt(t) shape is smooth and monotonic (well described by
%               the power-law form); large RMSE means there is a non-
%               monotonic deviation in the window (e.g. a Li-stripping
%               shoulder).
alpha = NaN;
rmse  = NaN;
if isempty(seg) || ~isfield(seg, 'dVdt_Vpers') || ~isfield(seg, 'timeS_interp')
    return
end
t = seg.timeS_interp;
y = seg.dVdt_Vpers;
m = (t >= windowS(1)) & (t <= windowS(2)) & ~isnan(y);
if nnz(m) < 10
    return
end
tw = t(m); yw = y(m);
bestRss = Inf;
bestN   = numel(yw);
for a = alphaGrid
    A = [ones(numel(tw),1), tw.^(-a)];
    c = A \ yw;
    r = yw - A*c;
    rss = sum(r.^2);
    if rss < bestRss
        bestRss = rss;
        alpha   = a;
    end
end
rmse = sqrt(bestRss / bestN);
end


function liStrippingFigure(timeWithGaps, voltage, allSegs, stripMetric, params, cellNum, cellLabel, scriptDir, fontName, fontSize) %#ok<DEFNU>
% liStrippingFigure - self-contained publication figure documenting the
% Li-stripping detection concept (A-002).
% Layout (3 tiles):
%   Top  full width: full ageing V-trace, with a coloured vertical tick at
%                    the start time of every detected 15-min C/5 post-
%                    charge discharge segment (link to the time series).
%   Bottom-left:     V vs time per segment (time-zeroed), colour by age.
%   Bottom-right:    dV/dt vs time per segment, colour by age, with the
%                    metric window shaded. A smooth curve is roughly flat;
%                    a Li-stripping segment shows a clear bump whose
%                    peak-to-trough magnitude is the per-segment metric.
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
    'Color', [0.4 0.4 0.4], 'LineWidth', 1.0); % R-017 item 4
hold(ax_top, 'on');
yl = [2.5 4.5];
ylim(ax_top, yl);
for i = 1:nSeg
    t0 = allSegs{i}.startTime;
    plot(ax_top, [t0 t0], yl, '-', ...
        'Color', cols(i,:), 'LineWidth', 1.0, 'HandleVisibility','off'); % R-017 item 4
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
        'Color', cols(i,:), 'LineWidth', 1.0); % R-017 item 4
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
        'Color', cols(i,:), 'LineWidth', 1.0); % R-017 item 4
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
        'LineWidth', 0.8, ... % R-017 item 4: axes frame, not a data trace
        'TickLabelInterpreter','tex');
end

% Save as PNG (300 dpi) and vector PDF in the script-owned output directory.
pngsDir = getFigureOutputDir('PlotCellSummary');
pngFile = fullfile(pngsDir, [cellNum '_LiStripping.png']);
pdfFile = fullfile(pngsDir, [cellNum '_LiStripping.pdf']);
drawnow;
exportgraphics(fig, pngFile, 'Resolution', 300);
exportgraphics(fig, pdfFile, 'ContentType', 'vector');
fprintf('Li-stripping figure saved:\n  %s\n  %s\n', pngFile, pdfFile);
end


function gittEpisodes = extractGITTfromTrace(timeWithGaps, voltage, current, timeS, params)
% extractGITTfromTrace - find back-to-back discharge+charge GITT episodes
% in an ageing trace and extract the per-pulse OCV (voltage at the end of
% the rest that follows each pulse).
%
% Inputs
%   timeWithGaps - datetime array (may contain NaT at gap markers)
%   voltage      - V array (NaN at gaps)
%   current      - A array (NaN at gaps); sign convention: + charge / - discharge
%   timeS        - seconds-since-start array (NaN at gaps)
%   params       - struct with fields:
%       pulseAmp_A           - nominal C/5 pulse amplitude (11.6 A). ACTIVE
%                              as of 2026-08-20 (#082 fix): a pulse's PEAK
%                              |I| must fall within pulseAmp_A +/- pulseTol_A
%                              to be accepted (a CC->CV taper can only decay
%                              FROM the peak, so testing the peak is robust
%                              to a later voltage-cutoff taper near the SoC
%                              extremes, unlike the old whole-pulse flatness
%                              test it replaces)
%       pulseTol_A           - +/- tolerance around pulseAmp_A for the peak
%                              amplitude test above
%       maxPulseAmp_A        - UPPER |I| limit defining a pulse (A); the
%                              lower limit is restThr_A. Pulses with
%                              restThr_A < |I| < maxPulseAmp_A are kept
%                              (so C/5 and lower-rate GITT pulses are
%                              detected, but cycling at -87 / +29 A is
%                              excluded) (A-001)
%       minPulse_s           - reject pulses shorter than this (noise)
%       maxPulse_s           - reject pulses longer than this (cycling/checkup)
%       minPulseCharge_Ah    - #082 fix (lowered 1.21 -> 0.15 on 2026-08-26):
%                              minimum |integral(I dt)/3600| over the pulse
%                              for it to count as a real SoC-changing GITT
%                              pulse, rather than a brief noise blip. Set to
%                              0.15 Ah, just below the most extreme observed
%                              CC->CV tapered pulse (~0.16 Ah, Cell_22 EoL),
%                              so those genuine near-cutoff pulses survive.
%                              Per-pulse MINIMUM only; decoupled from the
%                              refinement's single-pulse MAXIMUM.
%       maxIntraEpisodeGap_s - max time gap between consecutive pulses inside
%                              one GITT episode (rests are <= this gap).
%                              Set to ~5 days so the discharge-GITT and
%                              charge-GITT halves of one checkup merge into
%                              a single episode while consecutive checkups
%                              (~3 weeks apart) stay separate (A-001).
%       restThr_A            - |I| below this is considered rest when
%                              locating the OCV sample after the last pulse (A-001)
%       minRestDur_s         - minimum contiguous rest duration accepted as
%                              the post-last-pulse OCV anchor (A-001)
%       pulseFlatnessTol     - RETIRED as of 2026-08-20 (#082 fix); no longer
%                              read. Superseded by pulseAmp_A/pulseTol_A
%                              (peak-amplitude test) + minPulseCharge_Ah
%                              (charge-integral test) above. Kept in the
%                              struct only for backward-compatible shape.
%       gradThr_Apers        - |dI/dt| threshold (A/s) used inside a
%                              validated cluster to re-detect pulse rising
%                              edges. Once an episode is gated by
%                              clustering, refinement only needs to spot
%                              the sharp ramp at the start of each pulse;
%                              this avoids depending on pulse shape
%                              (flatness) so a CC+CV last pulse is still
%                              picked up (A-001)
%       edgeJump_A           - dt-independent companion to gradThr_Apers
%                              (#013): a rising edge is ALSO accepted when
%                              |dI| between a resting sample and the next
%                              exceeds this (A). Catches onsets that land
%                              inside a single long logger tick, where the
%                              per-sample gradient falls below
%                              gradThr_Apers. Must sit above rest noise
%                              (< restThr_A) and below the lowest GITT
%                              pulse amplitude (C/20 = 2.9 A) (A-001)
%       minPulsesPerEpisode  - keep only clusters with at least this many pulses
%       maxPulsesPerEpisode  - reject clusters with more than this many
%                              pulses (a real GITT half has 23–26 C/5 pulses;
%                              a merged discharge+charge episode is ~46–52;
%                              this upper bound rejects cycling clusters
%                              that happen to slip past the flatness check) (A-001)
%
% Output
%   gittEpisodes - struct array; one element per detected episode:
%       .timeStart, .timeEnd      - episode time bounds (datetime)
%       .pulseStartTimes (Nx1)    - datetime
%       .pulseEndTimes   (Nx1)    - datetime
%       .pulseStartIdx,  (Nx1)    - sample index of each pulse start
%       .pulseEndIdx     (Nx1)    - sample index of each pulse end
%       .pulseModes      (Nx1 cell of 'discharge'/'charge')
%       .OCV_V          ((N+1)x1) - OCV at end of each rest (including pre-first)
%       .ocvIdx         ((N+1)x1) - sample index of each OCV measurement
%       .ocvModes       ((N+1)x1) - 'discharge' / 'charge' half-cycle of each OCV
%       .cumQ_signed_Ah ((N+1)x1) - cumulative signed charge since episode start
%                                   (starts at 0 BEFORE the first pulse) (A-001)
%       .q_per_pulse_Ah  (Nx1)    - signed Ah delivered by each pulse

% Defensive defaults (in case caller passes a partial struct)
def = struct('pulseAmp_A',11.6, 'pulseTol_A',0.5, ...
             'maxPulseAmp_A',20, ...
             'minPulse_s',60, 'maxPulse_s',3600, 'minPulseCharge_Ah',0.15, ...
             'maxIntraEpisodeGap_s',24*3600, 'restThr_A',0.5, ...
             'minRestDur_s',600, 'pulseFlatnessTol',0.05, ...
             'gradThr_Apers',3, 'edgeJump_A',2, ...
             'minPulsesPerEpisode',20, 'maxPulsesPerEpisode',55);
fn = fieldnames(def);
for k = 1:numel(fn)
    if ~isfield(params, fn{k}) || isempty(params.(fn{k}))
        params.(fn{k}) = def.(fn{k});
    end
end

% Empty default output (compatible with [] short-circuit downstream)
gittEpisodes = struct([]);

% 1) Pulse mask: any current excursion above rest and below the cycling
%    amplitude. This captures BOTH the C/5 GITT pulses and any lower-rate
%    (C/10, C/20) pulses used at the discharge cutoff (A-001). The duration
%    filter below removes continuous C/5 references and CV-charge phases.
pulseMask = (abs(current) > params.restThr_A) ...
          & (abs(current) < params.maxPulseAmp_A) ...
          & ~isnan(current);

% 2) Find continuous pulse segments (runs of true)
%    Use a 0/1 diff trick; works for both row and column vectors.
pm = pulseMask(:);
edges = diff([false; pm; false]);
pulseStarts = find(edges ==  1);
pulseEnds   = find(edges == -1) - 1;

if isempty(pulseStarts); return; end

% 3) Filter pulses by duration and build a pulse table
pulseStartIdx = [];
pulseEndIdx   = [];
pulseStartTime= NaT(0);
pulseEndTime  = NaT(0);
pulseModeCell = {};
for i = 1:numel(pulseStarts)
    s = pulseStarts(i); e = pulseEnds(i);
    if isnan(timeS(s)) || isnan(timeS(e)); continue; end
    dur = timeS(e) - timeS(s);
    if dur < params.minPulse_s || dur > params.maxPulse_s; continue; end
    % Pulse-acceptance test (#082 fix, 2026-08-20): a genuine C/5 GITT pulse
    % can end in a CC->CV taper near the SoC extremes (voltage cutoff hit
    % mid-pulse), which the old whole-pulse flatness test incorrectly
    % rejected (confirmed on A3.10_Cell_22). Replaced with two checks that
    % are invariant to a later taper: (1) peak |I| must sit at the nominal
    % C/5 amplitude - a CV tail can only decay FROM that peak, never exceed
    % it, so checking the peak is equivalent to checking the pulse onset;
    % (2) the pulse must transfer a minimum amount of charge, i.e. represent
    % a real SoC change, not just brief noise.
    iPulse = current(s:e);
    tPulse = timeS(s:e);
    keepM  = ~isnan(iPulse) & ~isnan(tPulse);
    iPulse = iPulse(keepM);
    tPulse = tPulse(keepM);
    if isempty(iPulse); continue; end
    iPeak = max(abs(iPulse));
    if abs(iPeak - params.pulseAmp_A) > params.pulseTol_A; continue; end
    if numel(iPulse) < 2; continue; end
    qPulse_Ah = trapz(tPulse, iPulse) / 3600;
    if abs(qPulse_Ah) < params.minPulseCharge_Ah; continue; end
    if mean(current(s:e), 'omitnan') < 0
        m = 'discharge';
    else
        m = 'charge';
    end
    pulseStartIdx(end+1,1)  = s; %#ok<AGROW>
    pulseEndIdx(end+1,1)    = e; %#ok<AGROW>
    pulseStartTime(end+1,1) = timeWithGaps(s); %#ok<AGROW>
    pulseEndTime(end+1,1)   = timeWithGaps(e); %#ok<AGROW>
    pulseModeCell{end+1,1}  = m; %#ok<AGROW>
end
nPulses = numel(pulseStartIdx);
if nPulses == 0; return; end

% 4) Cluster pulses into episodes by inter-pulse time gap
clusterId = ones(nPulses, 1);
for i = 2:nPulses
    gap_s = seconds(pulseStartTime(i) - pulseEndTime(i-1));
    if gap_s > params.maxIntraEpisodeGap_s
        clusterId(i:end) = clusterId(i:end) + 1;
    end
end

% 5) Build episode list for clusters with pulse counts in the expected range
nClusters = max(clusterId);
for c = 1:nClusters
    idx = find(clusterId == c);
    if numel(idx) < params.minPulsesPerEpisode; continue; end
    if numel(idx) > params.maxPulsesPerEpisode; continue; end

    % Per-half pulse-count sanity check. A real GITT half (discharge OR
    % charge) has 23-26 C/5 pulses. A merged episode contains two such
    % halves separated by a multi-hour rest (~10 h on this cell). Detect
    % half boundaries inside the cluster as the largest inter-pulse rest(s)
    % and require every half to fall in [minHalf, maxHalf]. This rejects
    % clusters whose total count happens to land in [min, max] but whose
    % per-half breakdown is wrong (e.g., a few spurious pulses + a real
    % half, or a half-checkup spliced to an unrelated cycling pulse). (A-001)
    minHalf = 23 - 3;   % allow 3 missing/rejected pulses per half
    maxHalf = 26 + 3;   % allow 3 spurious accepted pulses per half
    intraGaps_s = seconds(pulseStartTime(idx(2:end)) - pulseEndTime(idx(1:end-1)));
    % A rest is a "half boundary" if it is much longer than a normal
    % within-half rest (~2 h). Use 4 h as a robust threshold: comfortably
    % above the typical 2 h GITT rest and below the ~10 h between-half gap.
    halfBoundaryThr_s = 4 * 3600;
    halfBoundaries = find(intraGaps_s > halfBoundaryThr_s);
    halfStartsLocal = [1; halfBoundaries + 1];
    halfEndsLocal   = [halfBoundaries; numel(idx)];
    halfSizes = halfEndsLocal - halfStartsLocal + 1;
    if any(halfSizes < minHalf) || any(halfSizes > maxHalf)
        fprintf('  [GITT] Rejected cluster (%s -> %s, %d pulses, halves = [%s]).\n', ...
            datestr(pulseStartTime(idx(1)),   'yyyy-mm-dd'), ...
            datestr(pulseEndTime(idx(end)),   'yyyy-mm-dd'), ...
            numel(idx), strjoin(string(halfSizes), ','));
        continue
    end

    % --- Refinement inside the validated cluster --------------------
    % The cluster step uses a CC flatness check, which (correctly) rejects
    % cycling CV-decay phases but ALSO rejects the last GITT pulse of a
    % discharge/charge half (CC + CV taper). And the post-last-pulse OCV
    % anchor used a "first rest >= minRestDur_s" walk-forward, which can
    % latch onto an intermediate rest rather than the rest after the true
    % final pulse. Both problems disappear with a simpler approach now
    % that we KNOW the cluster is a real GITT episode (A-001):
    %   - Within the cluster's time window (extended forward to capture
    %     a CV-tapered last pulse + its long rest), find every pulse
    %     RISING edge by |dI/dt| > gradThr_Apers. A C/5 step ramps at
    %     ~11.6 A/s; CV taper and noise stay well below the threshold.
    %   - Each rest OCV is the sample just before a rising edge. The
    %     post-last-pulse OCV is the sample just before the FIRST rising
    %     edge that occurs AFTER the refined last pulse ends (i.e., the
    %     start of the next test step / next checkup activity).
    %   - Each pulse end is found by walking forward from the rising
    %     edge until |I| drops below restThr_A (handles CC + optional CV).
    sFirst = pulseStartIdx(idx(1));
    sLastClusterPulse = pulseEndIdx(idx(end));
    % Walk the window start backwards into the pre-pulse rest so that
    % iSeg(1) is a RESTING sample. Without this, pulse 1 starts at index
    % 1 of seg, restMask(1) is false (the cell is already pulsing), and
    % the rising-edge detector misses the first pulse entirely. Walk back
    % through any contiguous rest until we hit a non-rest sample or a
    % NaN gap; cap at index 1.
    while sFirst > 1
        if isnan(current(sFirst - 1)) || abs(current(sFirst - 1)) >= params.restThr_A
            break
        end
        sFirst = sFirst - 1;
    end
    % Extend lookahead by one inter-episode gap so a CV-tapered last
    % pulse and the long rest that follows are inside the window.
    tEndSearch  = timeS(sLastClusterPulse) + params.maxIntraEpisodeGap_s;
    candidate = find(~isnan(timeS(:)) & timeS(:) <= tEndSearch);
    if isempty(candidate)
        sLast = numel(timeS);
    else
        sLast = max(candidate);
    end
    if sLast < sFirst; sLast = numel(timeS); end

    seg  = (sFirst:sLast).';
    iSeg = current(seg);
    tSeg = timeS(seg);
    dI = diff(iSeg);
    dT = diff(tSeg);
    diDt = dI ./ dT;            % signed A/s (NaN where iSeg/tSeg has NaN)
    absDiDt = abs(diDt);

    % A rising edge is a sample where current changes sharply AND the
    % cell was at rest just before (so we don't pick up the down-ramp at
    % the end of a pulse, or mid-pulse noise).
    % #013: the rate test alone misses onsets that land inside a single
    % long logger tick (rest ticks of ~5 s occur; 11.6 A / 5.3 s =
    % 2.2 A/s < gradThr_Apers, so the pulse was silently skipped). Accept
    % EITHER a sharp ramp OR a dt-independent amplitude jump out of rest
    % larger than edgeJump_A within one sample. CV taper never jumps
    % upward out of rest, so the jump branch adds no false edges (A-001).
    restMask = abs(iSeg(1:end-1)) < params.restThr_A;
    isEdge   = restMask & ((absDiDt > params.gradThr_Apers) ...
                           | (abs(dI) > params.edgeJump_A));
    isEdge(isnan(isEdge)) = false;

    % Each ramp produces one run of true in isEdge (because once the
    % current is high, restMask flips false). Take the START of each run.
    edgeStarts = find(diff([false; isEdge(:)]) == 1);
    if isempty(edgeStarts); continue; end

    prePulseGlobal  = seg(edgeStarts);       % last resting sample (= OCV anchor)
    pulseStartIdx_r = seg(edgeStarts + 1);   % first ramp sample (= pulse start)

    % Per-pulse mode from the sign of dI/dt at the edge.
    pulseModes_r = cell(numel(edgeStarts), 1);
    for k = 1:numel(edgeStarts)
        if diDt(edgeStarts(k)) < 0
            pulseModes_r{k} = 'discharge';
        else
            pulseModes_r{k} = 'charge';
        end
    end

    % Pulse end: walk forward from pulseStartIdx_r(k) until |I| returns
    % below restThr_A or until the next pulse starts. Handles CC + CV.
    pulseEndIdx_r = zeros(numel(edgeStarts), 1);
    for k = 1:numel(edgeStarts)
        if k < numel(edgeStarts)
            walkEnd = prePulseGlobal(k + 1);
        else
            walkEnd = sLast;
        end
        pe = pulseStartIdx_r(k);
        for j = pulseStartIdx_r(k):walkEnd
            if isnan(current(j)) || abs(current(j)) < params.restThr_A
                pe = j - 1;
                break
            end
            pe = j;
        end
        pulseEndIdx_r(k) = pe;
    end

    % Truncate to the episode boundary: stop once the inter-pulse gap
    % exceeds maxIntraEpisodeGap_s (we walked into the next episode), OR
    % once a pulse's own duration/charge is far outside what a genuine C/5
    % GITT pulse can be (found 2026-08-25, Cell_34): the refined rising-edge
    % scan above has NO amplitude/charge gate (unlike the coarse pass), so
    % within the 5-day lookahead window it can pick up one extra unrelated
    % pulse - e.g. the start of the next test phase (a 43.89 min, -10.6 Ah
    % discharge, vs. the ~12.5-21 min / <=2.5 Ah GITT pulses seen on this
    % cell) - as a spurious "one more GITT pulse". A nominal full C/5 pulse
    % carries ~2.42 Ah over ~12.5 min; allow a generous margin so
    % legitimately longer / CV-tapered pulses near the SoC extremes still
    % pass, while the much larger/longer next-phase pulse does not. This
    % MAXIMUM is a fixed value, decoupled from params.minPulseCharge_Ah
    % (now a small per-pulse MINIMUM, 0.15 Ah, #082 2026-08-26).
    maxSinglePulseCharge_Ah = 3.63;  % ~1.5x the nominal full C/5 pulse charge (2.42 Ah)
    maxSinglePulseDur_s     = 30 * 60;                       % 30 min
    nKeep = numel(pulseStartIdx_r);
    for k = 1:numel(pulseStartIdx_r)
        if k > 1
            gap_s = timeS(pulseStartIdx_r(k)) - timeS(pulseEndIdx_r(k - 1));
            if ~isnan(gap_s) && gap_s > params.maxIntraEpisodeGap_s
                nKeep = k - 1;
                break
            end
        end
        s = pulseStartIdx_r(k); e = pulseEndIdx_r(k);
        dur_s = timeS(e) - timeS(s);
        tk = timeS(s:e); ik = current(s:e);
        m = ~isnan(tk) & ~isnan(ik);
        qk = 0;
        if nnz(m) >= 2; qk = trapz(tk(m), ik(m)) / 3600; end
        if (~isnan(dur_s) && dur_s > maxSinglePulseDur_s) || abs(qk) > maxSinglePulseCharge_Ah
            nKeep = k - 1;
            break
        end
    end
    pulseStartIdx_r = pulseStartIdx_r(1:nKeep);
    pulseEndIdx_r   = pulseEndIdx_r(1:nKeep);
    pulseModes_r    = pulseModes_r(1:nKeep);
    prePulseGlobal  = prePulseGlobal(1:nKeep);

    nP = numel(pulseStartIdx_r);
    if nP < params.minPulsesPerEpisode || nP > params.maxPulsesPerEpisode
        fprintf('  [GITT] Refinement rejected cluster (%s, %d pulses out of [%d,%d]).\n', ...
            datestr(timeWithGaps(sFirst), 'yyyy-mm-dd'), nP, ...
            params.minPulsesPerEpisode, params.maxPulsesPerEpisode);
        continue
    end

    % Per-pulse signed Ah (trapezoidal over [pulseStart, pulseEnd]).
    q_per_pulse_Ah = zeros(nP, 1);
    for k = 1:nP
        s = pulseStartIdx_r(k);
        e = pulseEndIdx_r(k);
        tk = timeS(s:e); ik = current(s:e);
        m = ~isnan(tk) & ~isnan(ik);
        if nnz(m) >= 2
            q_per_pulse_Ah(k) = trapz(tk(m), ik(m)) / 3600;
        end
    end

    % OCV anchors: prePulseGlobal(k) for k=1..nP, plus the rest after the
    % last pulse, anchored at the FIRST rising edge AFTER pulseEndIdx_r(nP).
    ocvIdx    = zeros(nP + 1, 1);
    ocvModesC = cell(nP + 1, 1);
    ocvIdx(1)    = prePulseGlobal(1);
    ocvModesC{1} = pulseModes_r{1};
    for k = 1:nP - 1
        ocvIdx(k + 1)    = prePulseGlobal(k + 1);
        ocvModesC{k + 1} = pulseModes_r{k};
    end
    % Post-last-pulse anchor: scan from pulseEndIdx_r(nP)+1 to end of trace.
    lastE = pulseEndIdx_r(nP);
    ocvIdx(nP + 1)    = lastE;            % fallback (trace cut short)
    ocvModesC{nP + 1} = pulseModes_r{nP};
    rem = (lastE + 1 : numel(timeS)).';
    if numel(rem) >= 2
        iR = current(rem);
        tR = timeS(rem);
        diDtR = diff(iR) ./ diff(tR);
        restMaskR = abs(iR(1:end-1)) < params.restThr_A;
        isEdgeR = (abs(diDtR) > params.gradThr_Apers) & restMaskR;
        isEdgeR(isnan(isEdgeR)) = false;
        firstEdgeR = find(isEdgeR, 1, 'first');
        if ~isempty(firstEdgeR)
            ocvIdx(nP + 1) = rem(firstEdgeR);
        end
    end

    OCV_V = voltage(ocvIdx);

    ep = struct();
    ep.timeStart       = timeWithGaps(pulseStartIdx_r(1));
    ep.timeEnd         = timeWithGaps(pulseEndIdx_r(end));
    ep.pulseStartTimes = timeWithGaps(pulseStartIdx_r);
    ep.pulseEndTimes   = timeWithGaps(pulseEndIdx_r);
    ep.pulseStartIdx   = pulseStartIdx_r;
    ep.pulseEndIdx     = pulseEndIdx_r;
    ep.pulseModes      = pulseModes_r;
    ep.cumQ_signed_Ah  = [0; cumsum(q_per_pulse_Ah)];
    ep.OCV_V           = OCV_V;
    ep.ocvIdx          = ocvIdx;
    ep.ocvModes        = ocvModesC;
    ep.q_per_pulse_Ah  = q_per_pulse_Ah;

    if isempty(fieldnames(gittEpisodes))
        gittEpisodes = ep;
    else
        gittEpisodes(end+1) = ep; %#ok<AGROW>
    end
end
end


