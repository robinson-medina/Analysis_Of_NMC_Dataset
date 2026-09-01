%% PlotCharacterizationResults.m
% Summary: Builds the OCV and EIS manuscript figures for one characterisation
%          cell. The OCV figure shows the GITT charge/discharge curve and the
%          temperature dependency of discharge OCV; the EIS figure shows Nyquist
%          panels across the measured SoC and temperature conditions.
%
% Usage: Set DataRoot and cellNum in the Parameters block, then run this script.
%        External drivers may set cellNumOverride before calling run(...) to
%        process Cell_4, Cell_6, or Cell_15.
%
% Outputs: <cell>_CharacterizationOCV.png/.pdf and
%          <cell>_CharacterizationEIS.png/.pdf in this script's R-022 output
%          directory.
%
% Authors: Feye Hoekstra, GitHub Copilot.
% Dependency files: Functions/getFigureOutputDir.m.
% Last documented: 2026-09-01

% Allow an external driver (MakeManuscriptFigures.m) to preselect the cell by
% setting cellNumOverride before run(...); the guard survives the clear below.
if exist('cellNumOverride', 'var'); keepCellOverride = cellNumOverride; end
clearvars -except keepCellOverride; close all; clc;

%% Parameters
% Every tunable lives here so the whole figure is steered from one block.

% --- Data source (single switch, Zenodo 1_Teardown/.../4_Ageing layout) ---
DataRoot   = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
cellNum    = 'Cell_4';                             % characterization cell to plot
if exist('keepCellOverride', 'var'); cellNum = keepCellOverride; end
charFolder = fullfile(DataRoot, '3_Characterization', cellNum);
gittFile   = fullfile(charFolder, [cellNum '_2-GITT.csv']);
eisFolder  = fullfile(charFolder, 'EIS');

% --- EIS conditions to show -----------------------------------------------
% EIS is shown as one panel per SoC, with temperature as line color.
tempsToShow_C = [0 5 25 45];                        % temperature traces within each panel
eisSoCList    = [10 50 90];                         % one Nyquist panel per SoC (%)
eisMinFreq_Hz = 0.05;                               % cut off very low frequencies
eisMaxFreq_Hz = 10000;                              % cut off very high frequencies

% --- OCV extraction settings (reference OCVextraction.m method) -----------
% A rest sample is any |I| below the pulse threshold; the OCV points are the
% last rest sample before every current pulse. The final tail discharge is a
% pulse too, so its preceding rest gives the equilibrated top-of-charge point.
pulseThr_A = 0.3;                                   % |I| above this = under load

% Temperature dependency: during selected DISCHARGE rests the chamber is
% stepped 25 -> 0 -> -15 -> 45 -> 25 degC. The 25 degC rest just BEFORE each
% excursion is the reference OCV; dV(T) = V(T) - V(25,pre) at that SoC.
sweepTemps_C  = [45 25 0 -15];                      % chamber set-points [degC]
refTemp_C     = 25;                                 % reference set-point for dV
tempTol_C     = 1;                                  % match window to a set-point [degC]
sweepAway_C   = 2;                                  % |T-25|>this marks a sweep excursion
sweepMergeGap = 3000;                               % merge sweep sub-blocks < this apart [samples]
sweepMinDwell = 1500;                               % min samples to accept a plateau dwell

% --- Publication styling (R-017/R-019/R-020/R-021) ------------------------
PUB_FONT      = 'Times New Roman';
PUB_FONTSIZE  = 8;                                   % caption size (R-021 default)
green    = [ 12 195  82] ./ 255;
darkblue = [  1  17 181] ./ 255;
red      = [255   0   0] ./ 255;
magenta  = [255   0 255] ./ 255;
black    = [  0   0   0];
LW_DATA  = 1.0;                                      % data traces (R-017 item 4)
LW_AXES  = 0.8;                                      % axes frame
LW_AUX   = 0.75;                                     % connectors / box edges

tempColors = {darkblue; green; black; red};         % maps to tempsToShow_C order (0/5/25/45)

% Figure sizes (cm). Single-column figures; tune with pdfinfo -box per R-021.
OCV_W_CM = 9.37;  OCV_H_CM = 9.6;                    % two stacked panels with fixed plot boxes; width tuned for 97% columnwidth
EIS_W_CM = 9.25;  EIS_H_CM = 5.2;                    % compact 1x3 Nyquist layout; width tuned for 97% columnwidth

% --- Output location (R-022) ----------------------------------------------
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
pngsDir = getFigureOutputDir('PlotCharacterizationResults');

fprintf('=== PlotCharacterizationResults: %s ===\n', cellNum);

%% Step 1: Load the GITT trace and reconstruct the time vector
% Column order (see PlotCharacterizationData_Cell15.m header):
%   Time , Voltage [V], Current [A], Cell temp [degC], Chamber temp [degC]
opts = detectImportOptions(gittFile);
opts.VariableTypes{1}  = 'string';
opts.DataLines         = [2 Inf];
opts.VariableNamesLine = 1;
fprintf('Loading %s ... ', [cellNum '_2-GITT.csv']); tic;
T = readtable(gittFile, opts);
fprintf('done (%.1f s, %d rows)\n', toc, height(T));

timeStr    = T{:, 1};
timeYYMMDD = NaT(size(timeStr));
timeYYMMDD(1)     = datetime(timeStr(1), 'Format', 'dd-MMM-yyyy HH:mm:ss.SSS');
timeYYMMDD(2:end) = cumsum(seconds(double(timeStr(2:end)))) + timeYYMMDD(1);
voltageV     = T{:, 2};
currentA     = T{:, 3};
cellTempC    = T{:, 4};
chamberTempC = T{:, 5};
dwellS       = seconds(timeYYMMDD - timeYYMMDD(1));
clear T timeStr

%% Step 2: Detect the OCV rest points (reference OCVextraction.m method)
% Binarise the current into rest/pulse and take the sample just before each
% pulse onset. Skipping the initial formation charge makes the first point the
% equilibrated full charge before the first discharge pulse; the final tail
% discharge is a pulse too, so its preceding rest is the top-of-charge point.
t_s   = dwellS;
V     = voltageV;
I     = currentA;
Tcham = chamberTempC;

pulseMask = abs(I) > pulseThr_A;
onsetIdx  = find(diff(pulseMask) > 0);               % last rest sample before each pulse

firstDis = find(I < -pulseThr_A, 1, 'first');        % first discharge sample
kStart   = find(onsetIdx < firstDis, 1, 'last');     % rest just before it
restIdx  = onsetIdx(kStart:end);                     % OCV anchor sample indices
fprintf('Detected %d OCV rest points (after skipping formation).\n', numel(restIdx));

%% Step 3: Coulomb-counted SoC / capacity axis and discharge/charge split
% Anchor the coulomb count at the first full-charge rest and measure the
% discharge depth over the GITT span only (the final tail discharge is
% excluded). Full charge maps to 100 %, the deepest discharge rest to 0 %.
cumQ_As = cumtrapz(t_s, I);                          % running charge [A*s]
cumQ_As = cumQ_As - cumQ_As(restIdx(1));             % zero at full charge (GITT start)
gittWin = restIdx(1):restIdx(end);                   % GITT span (excludes tail discharge)
C0_As   = abs(min(cumQ_As(gittWin)));                % discharge depth [A*s]
C0_Ah   = C0_As / 3600;                              % = full capacity
socPct  = 100 * (cumQ_As / C0_As + 1);               % full charge = 100 %, deepest = 0 %

socRest = socPct(restIdx);
vRest   = V(restIdx);
[~, kBnd] = min(socRest);                            % deepest discharge (SoC ~0)

disSel = 1:kBnd;                                     % discharge branch
chgSel = kBnd:numel(restIdx);                        % charge branch (shares boundary)
socDis = socRest(disSel);  ocvDis = vRest(disSel);
socChg = socRest(chgSel);  ocvChg = vRest(chgSel);
fprintf('Discharge OCV: %.3f -> %.3f V (SoC %.0f -> %.0f %%)\n', ...
    ocvDis(1), ocvDis(end), socDis(1), socDis(end));
fprintf('Charge    OCV: %.3f -> %.3f V (SoC %.0f -> %.0f %%)\n', ...
    ocvChg(1), ocvChg(end), socChg(1), socChg(end));

%% Step 4: Temperature dependency - dV(T) vs SoC from the discharge sweeps
% Detect each chamber-temperature excursion, keep only those on the discharge
% branch, and for every sweep use the 25 degC rest just before it as reference.
% Each other set-point's LONGEST dwell (ignoring transient ramp crossings) gives
% the equilibrated plateau; dV(T) = V(T) - V(25,pre) at that sweep's SoC.
targetTemps = sweepTemps_C(sweepTemps_C ~= refTemp_C);   % 45 / 0 / -15
tColorMap   = containers.Map([45 25 0 -15], {red, black, darkblue, magenta});

iDisEnd  = restIdx(kBnd);                            % deepest GITT discharge (charge after)
awayMask = abs(Tcham - refTemp_C) > sweepAway_C;
dd   = diff([0; awayMask; 0]);
segS = find(dd == 1);  segE = find(dd == -1) - 1;
sS = []; sE = []; k = 1;                             % merge sub-blocks split by 25 degC crossings
while k <= numel(segS)
    s = segS(k); e = segE(k);
    while k < numel(segS) && segS(k + 1) - e < sweepMergeGap
        k = k + 1; e = max(e, segE(k));
    end
    sS(end + 1, 1) = s; sE(end + 1, 1) = e; k = k + 1; %#ok<AGROW>
end

sweeps = struct('soc', {}, 'T', {}, 'dV', {}, 'V', {}, 'refIdx', {}, 'ptIdx', {});
for m = 1:numel(sS)
    s = sS(m); e = sE(m);
    if s >= iDisEnd; continue; end                   % discharge branch only
    rIdx = find(abs(Tcham(1:s-1) - refTemp_C) <= tempTol_C & abs(I(1:s-1)) < pulseThr_A, 1, 'last');
    if isempty(rIdx); continue; end
    en = struct('soc', socPct(rIdx), 'T', [], 'dV', [], 'V', [], 'refIdx', rIdx, 'ptIdx', []);
    for T0 = targetTemps
        mask = abs(Tcham(s:e) - T0) <= tempTol_C & abs(I(s:e)) < pulseThr_A;
        rr = diff([0; mask; 0]); rS = find(rr == 1); rE = find(rr == -1) - 1;
        [maxLen, im] = max(rE - rS + 1);             % longest dwell = true plateau
        if isempty(maxLen) || maxLen < sweepMinDwell; continue; end
        pIdx = s - 1 + rE(im);                       % plateau end (best equilibrated)
        en.T(end+1) = T0; en.ptIdx(end+1) = pIdx;
        en.V(end+1) = V(pIdx); en.dV(end+1) = 1000 * (V(pIdx) - V(rIdx));
    end
    if ~isempty(en.T); sweeps(end+1) = en; end %#ok<AGROW>
end
fprintf('Discharge temperature sweeps: %d (set-points %s degC)\n', ...
    numel(sweeps), strjoin(string(targetTemps), '/'));

%% Step 5: Figure 1 - OCV curve (a) and temperature dependency (b), 2 panels
figOCV = figure('Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 OCV_W_CM OCV_H_CM]);
styleAx = {'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE, 'LineWidth', LW_AXES, ...
    'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1};

% R-023: fix each panel's plot box to 3.5190 cm high (cm InnerPosition, so the
% box height is exact and independent of the figure canvas / tight crop).
OCV_PANEL_H_CM = 3.5190;
ocvLeftM = 1.35; ocvRightM = 0.30; ocvBotM = 1.20; ocvGap = 1.05;
ocvPlotW = OCV_W_CM - ocvLeftM - ocvRightM;

% --- (a) OCV vs SoC: discharge + charge -----------------------------------
axA = axes(figOCV, 'Units', 'centimeters', 'PositionConstraint', 'innerposition', ...
    'InnerPosition', [ocvLeftM, ocvBotM + OCV_PANEL_H_CM + ocvGap, ocvPlotW, OCV_PANEL_H_CM]);
hold(axA, 'on');
hDis = plot(axA, socDis, ocvDis, '-o', 'Color', darkblue, ...
    'MarkerFaceColor', darkblue, 'MarkerSize', 3, 'LineWidth', LW_DATA);
hChg = plot(axA, socChg, ocvChg, '-o', 'Color', red, ...
    'MarkerFaceColor', red, 'MarkerSize', 3, 'LineWidth', LW_DATA);
ylabel(axA, 'OCV [V]');                              % R-020 bracketed unit
xlim(axA, [0 100]);
grid(axA, 'on'); box(axA, 'on'); set(axA, styleAx{:});
legend(axA, [hDis hChg], {'Discharge', 'Charge'}, 'Location', 'northwest', ...
    'Box', 'off', 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE);
text(axA, 0.02, 0.93, '(a)', 'Units', 'normalized', 'FontName', PUB_FONT, ...
    'FontSize', PUB_FONTSIZE, 'FontWeight', 'bold');

% --- (b) dV vs SoC per temperature (discharge sweeps, vs pre-sweep 25 degC) -
axB = axes(figOCV, 'Units', 'centimeters', 'PositionConstraint', 'innerposition', ...
    'InnerPosition', [ocvLeftM, ocvBotM, ocvPlotW, OCV_PANEL_H_CM]);
hold(axB, 'on');
yline(axB, 0, ':', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
hT = gobjects(numel(targetTemps), 1); lblT = cell(numel(targetTemps), 1);
for ti = 1:numel(targetTemps)
    T0 = targetTemps(ti);
    soc = []; dv = [];
    for m = 1:numel(sweeps)
        j = find(sweeps(m).T == T0, 1);
        if isempty(j); continue; end
        soc(end+1) = sweeps(m).soc; dv(end+1) = sweeps(m).dV(j); %#ok<AGROW>
    end
    [soc, o] = sort(soc); dv = dv(o);
    hT(ti) = plot(axB, soc, dv, '-o', 'Color', tColorMap(T0), ...
        'MarkerFaceColor', tColorMap(T0), 'MarkerSize', 3, 'LineWidth', LW_DATA);
    lblT{ti} = sprintf('%d \\circC', T0);
end
xlabel(axB, 'State of charge [%]');
ylabel(axB, '\DeltaV vs 25 \circC [mV]');            % R-020
xlim(axB, [0 100]); grid(axB, 'on'); box(axB, 'on'); set(axB, styleAx{:});
legend(axB, hT, lblT, 'Location', 'northeast', 'Box', 'off', ...
    'Orientation', 'horizontal', 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE);
text(axB, 0.02, 0.93, '(b)', 'Units', 'normalized', 'FontName', PUB_FONT, ...
    'FontSize', PUB_FONTSIZE, 'FontWeight', 'bold');

linkaxes([axA axB], 'x');

% Export vector PDF + PNG (R-018/R-022), fonts preserved.
figOCV.PaperPositionMode = 'auto';
for ax = findall(figOCV, 'Type', 'axes')'
    if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = 'off';
    end
end
ocvPdf = fullfile(pngsDir, sprintf('%s_CharacterizationOCV.pdf', cellNum));
ocvPng = fullfile(pngsDir, sprintf('%s_CharacterizationOCV.png', cellNum));
exportgraphics(figOCV, ocvPng, 'Resolution', 300);
exportgraphics(figOCV, ocvPdf, 'ContentType', 'vector');
fprintf('Wrote %s\n', ocvPdf);

%% Step 6: Figure 2 - EIS Nyquist panels (one SoC per panel)
% Preload every panel first so all three share ONE set of x/y limits. This
% keeps SoC-to-SoC differences directly comparable while color encodes temp.
figEIS = figure('Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 EIS_W_CM EIS_H_CM]);
tl = tiledlayout(figEIS, 1, numel(eisSoCList), ...
    'TileSpacing', 'compact', 'Padding', 'compact');
tl.Units = 'normalized';
tl.OuterPosition = [0 0.25 1 0.75];              % pin panels; reserve bottom band for x-label + legend

nS = numel(eisSoCList); nT = numel(tempsToShow_C);
reC = cell(nS, nT); imC = cell(nS, nT); fC = cell(nS, nT);  % cached traces [m\Omega], [Hz]
allRe = []; allIm = [];
for ti = 1:nT
    eisFile = fullfile(eisFolder, sprintf('Test_%dC_impedanceData.csv', tempsToShow_C(ti)));
    optsE = detectImportOptions(eisFile);
    optsE.DataLines = [2 Inf]; optsE.VariableNamesLine = 1;
    E = readtable(eisFile, optsE);
    for pi = 1:nS
        soc = eisSoCList(pi);
        rRe =  E.(sprintf('R_real_ohm_SoC%d', soc)) * 1000;
        rIm = -E.(sprintf('R_img_ohm_SoC%d',  soc)) * 1000;
        frq =  E.(sprintf('Freq_Hz_SoC%d',    soc));
        keep = ~isnan(rRe) & ~isnan(rIm) & ~isnan(frq) & ...
            frq >= eisMinFreq_Hz & frq <= eisMaxFreq_Hz;
        reC{pi, ti} = rRe(keep); imC{pi, ti} = rIm(keep); fC{pi, ti} = frq(keep);
        allRe = [allRe; rRe(keep)]; allIm = [allIm; rIm(keep)]; %#ok<AGROW>
    end
end

% One common x-limit and y-limit shared by all three panels.
xLo = min(allRe); xHi = max(allRe);
yLo = min(allIm); yHi = max(allIm);
xPad = 0.04 * (xHi - xLo);
yPad = 0.06 * (yHi - yLo);
commonX = [xLo - xPad, xHi + xPad];
commonY = [yLo - yPad, yHi + yPad];

tempHandles = gobjects(1, nT);                       % for one shared legend
tiRef = find(tempsToShow_C == 25, 1, 'first');      % place freq labels on the 25 degC trace
midPanel = ceil(nS / 2);                             % annotate only the middle SoC panel
for pi = 1:nS
    ax = nexttile(tl); hold(ax, 'on');
    for ti = 1:nT
        h = plot(ax, reC{pi, ti}, imC{pi, ti}, '-', 'Color', tempColors{ti}, ...
            'LineWidth', LW_DATA);
        if pi == 1; tempHandles(ti) = h; end
    end
    title(ax, sprintf('SoC %d%%', eisSoCList(pi)), 'FontWeight', 'normal');
    xlim(ax, commonX); ylim(ax, commonY);
    grid(ax, 'on'); box(ax, 'on');
    set(ax, 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE, ...
        'LineWidth', LW_AXES, 'LabelFontSizeMultiplier', 1, 'TitleFontSizeMultiplier', 1);

    if pi == midPanel
        xR = commonX(2) - commonX(1);
        yR = commonY(2) - commonY(1);
        xLblLow = commonX(1) + 0.62 * xR;  yLblLow = commonY(1) + 0.69 * yR;  % slight extra left shift
        xLblHigh = commonX(1) + 0.33 * xR; yLblHigh = commonY(1) + 0.12 * yR; % shift 10 kHz left
        text(ax, xLblLow, yLblLow, '0.05 Hz', 'FontName', PUB_FONT, ...
            'FontSize', PUB_FONTSIZE - 1, 'Color', black, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Clipping', 'on');
        text(ax, xLblHigh, yLblHigh, '10 kHz', 'FontName', PUB_FONT, ...
            'FontSize', PUB_FONTSIZE - 1, 'Color', black, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', 'Clipping', 'on');
    end

    if pi == 1
        ylabel(ax, '-Z_{im} [m\Omega]');             % R-020
    else
        set(ax, 'YTickLabel', []);                   % shared axis -> label once
    end
end

% Layout-managed x-label sits just under the ticks inside the pinned region.
xlabel(tl, 'Z_{re} [m\Omega]', 'FontName', PUB_FONT, 'FontSize', PUB_FONTSIZE, 'Color', black);

lgdE = legend(tempHandles, arrayfun(@(t) sprintf('%d \\circC', t), tempsToShow_C, ...
    'UniformOutput', false), 'Box', 'off', 'FontName', PUB_FONT, ...
    'FontSize', PUB_FONTSIZE, 'Orientation', 'horizontal');
drawnow;
lgdE.Units = 'normalized';
lgdE.Position = [0.08 0.015 0.84 0.05];            % bottom of reserved band, below the x-label

figEIS.PaperPositionMode = 'auto';
for ax = findall(figEIS, 'Type', 'axes')'
    if isprop(ax, 'Toolbar') && ~isempty(ax.Toolbar)
        ax.Toolbar.Visible = 'off';
    end
end
eisPdf = fullfile(pngsDir, sprintf('%s_CharacterizationEIS.pdf', cellNum));
eisPng = fullfile(pngsDir, sprintf('%s_CharacterizationEIS.png', cellNum));
exportgraphics(figEIS, eisPng, 'Resolution', 300);
exportgraphics(figEIS, eisPdf, 'ContentType', 'vector');
fprintf('Wrote %s\n', eisPdf);

%% Step 7: Summary
fprintf('\n--- Summary ---\n');
fprintf('Cell            : %s\n', cellNum);
fprintf('GITT OCV points : %d discharge, %d charge\n', numel(disSel), numel(chgSel));
fprintf('Full capacity   : %.2f Ah (from discharge depth)\n', C0_Ah);
fprintf('Temp sweeps     : %d discharge sweeps, set-points %s degC\n', ...
    numel(sweeps), strjoin(string(targetTemps), '/'));
fprintf('EIS panels      : SoC %s %%, temperatures %s degC\n', ...
    strjoin(string(eisSoCList), '/'), strjoin(string(tempsToShow_C), '/'));
fprintf('EIS freq window : %.2f Hz to %.0f Hz\n', eisMinFreq_Hz, eisMaxFreq_Hz);
fprintf('Figures written to %s\n', pngsDir);
