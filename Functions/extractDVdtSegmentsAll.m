function allSegs = extractDVdtSegmentsAll(selectedTime, selectedVoltage, selectedCurrent, selectedTimeS, targetCurrent_A, params)
% extractDVdtSegmentsAll - return EVERY 15-min post-charge C/5 discharge
% segment in the trace (analyzeDVdtAfterCharge only returns 5). Each
% segment is interpolated onto a 1 s grid and the smoothed dV/dt is
% computed (matches the math in Functions/analyzeDVdtAfterCharge.m) so the
% downstream Li-stripping metric and the standalone Li-stripping figure
% see a consistent dV/dt definition.
%
% Inputs:
%   selectedTime    - datetime array
%   selectedVoltage - V array
%   selectedCurrent - A array
%   selectedTimeS   - seconds-since-start array
%   targetCurrent_A - target |I| value (e.g. -11.6 A for C/5 discharge)
%   params          - struct with fields:
%       tolerance_A      - +/- tolerance around targetCurrent_A
%       minSegmentLength - min segment length in samples
%       maxSegmentLength - max segment length in samples
%       smoothWin        - movmean window for dV/dt smoothing
%
% Output:
%   allSegs - cell array of structs, one per detected segment, with fields:
%       .startTime         - datetime of segment start
%       .timeS_interp      - interpolated time-since-start vector [s]
%       .voltage_interp    - interpolated voltage vector [V]
%       .dVdt_Vpers        - smoothed dV/dt vector [V/s] (same length as timeS_interp)
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-07-28 (extracted from PlotCellSummary.m into a shared helper)

allSegs = {};
mask = abs(selectedCurrent - targetCurrent_A) <= params.tolerance_A;
mask(isnan(selectedCurrent)) = false;
% Find runs of true (= constant-current segments)
edges = diff([false; mask(:); false]);
runStarts = find(edges ==  1);
runEnds   = find(edges == -1) - 1;
% Length filter (matches analyzeDVdtAfterCharge.m)
keep = (runEnds - runStarts + 1) >= params.minSegmentLength ...
     & (runEnds - runStarts + 1) <= params.maxSegmentLength;
runStarts = runStarts(keep);
runEnds   = runEnds(keep);
for i = 1:numel(runStarts)
    idx = runStarts(i):runEnds(i);
    segV  = selectedVoltage(idx);
    segTs = selectedTimeS(idx);
    segT  = selectedTime(idx);
    % Skip if any NaT/NaN at the segment boundaries
    if isempty(segTs) || isnan(segTs(1)) || isnan(segTs(end)); continue; end
    segTs = segTs - segTs(1);
    % Interpolate onto a uniform 1 s grid (same as analyzeDVdtAfterCharge)
    tInterp = (0:1:floor(max(segTs)))';
    if numel(tInterp) < 3; continue; end
    vInterp = interp1(segTs, segV, tInterp);
    % Smoothed dV/dt via gradient ratio (matches analyzeDVdtAfterCharge)
    dVdt = movmean(gradient(vInterp) ./ gradient(tInterp), params.smoothWin);
    s = struct();
    s.startTime      = segT(1);
    s.timeS_interp   = tInterp;
    s.voltage_interp = vInterp;
    s.dVdt_Vpers     = dVdt;
    allSegs{end+1} = s; %#ok<AGROW>
end
end
