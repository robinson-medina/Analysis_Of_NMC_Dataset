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
%       minSegmentLength - min segment length [nominal 1 Hz samples]
%       maxSegmentLength - max segment length [nominal 1 Hz samples]
%       smoothWin        - movmean window for dV/dt smoothing
%
% Segment-length semantics (todo #061, 2026-08-12): the length filter is
% applied to the segment DURATION computed from the timestamps, not to the
% raw row count. An N-sample segment at a clean 1 Hz spans N-1 s, so the
% row filter [minSegmentLength, maxSegmentLength] maps onto the duration
% filter [minSegmentLength-1, maxSegmentLength-1] seconds. Rationale: AIT
% (A3/A4) files periodically split one 1 s tick into two rows (+0.1 s /
% +0.9 s) and TNO files carry occasional sub-second event rows, so a row
% count is not a duration; the duration filter is invariant to both.
% Spot-check note (verification_runs/2026-08-12_wave2_stripping): on the
% checked AIT cells the ~8% extra rows never breached the row cap, so
% counts are unchanged there; on TNO A2.08 one boundary segment with event
% rows (>=900 rows, <899 s true duration) is now rejected.
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
%         2026-08-12 duration-based length filter + duplicate-time guard (#061)

allSegs = {};
mask = abs(selectedCurrent - targetCurrent_A) <= params.tolerance_A;
mask(isnan(selectedCurrent)) = false;
% Find runs of true (= constant-current segments)
edges = diff([false; mask(:); false]);
runStarts = find(edges ==  1);
runEnds   = find(edges == -1) - 1;
% Duration filter in seconds from the timestamps (see semantics note above)
durS = selectedTimeS(runEnds) - selectedTimeS(runStarts);
keep = durS >= (params.minSegmentLength - 1) ...
     & durS <= (params.maxSegmentLength - 1);
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
    % Guard against duplicate time samples (AIT sub-second row splits can
    % produce coincident timestamps after float round-off) - interp1
    % requires strictly unique sample points.
    [segTs, iu] = unique(segTs);
    segV = segV(iu);
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
