function ep = extractCharacterizationGITT(timeWithGaps, voltage, current, chamberTemp, timeS, params)
% extractCharacterizationGITT - detect all GITT pulses in a trace that
% contains a single back-to-back discharge+charge GITT test with clean
% long rests (i.e. a characterization-cell `..._2-GITT.csv` file).
%
% Summary: Shared detector for the beginning-of-life GITT test recorded for
% a CHARACTERIZATION cell. Originally reused by matlab_scripts/misc/
% ExtractGITTToCSV.m (CSV export); that script was retired 2026-08-25
% (todo #109 / R-027, was unused from matlab_scripts/ root or Functions/).
% Kept here as the reusable, tested live-computation path for GITT
% rest-point extraction if any future script needs this data (per the
% "regenerate live, don't cache" decision in todo #109) - PlotCharacterizationResults.m
% does NOT currently call this (it uses its own inline detection).
%
% Returns a struct with the field layout used by both callers:
%   ep.timeStart, ep.timeEnd
%   ep.pulseStartIdx, ep.pulseEndIdx
%   ep.pulseModes         (cell of 'discharge' / 'charge')
%   ep.ocvIdx             (nP + 1 sample indices, one OCV anchor per pulse
%                          boundary plus one after the last pulse)
%   ep.OCV_V              (voltages at ocvIdx)
%   ep.q_per_pulse_Ah     (signed Ah per pulse)
%   ep.cumQ_signed_Ah     (nP + 1 signed cumulative Ah, starting at 0)
%
% Inputs:
%   timeWithGaps - datetime vector (NaT at inserted gaps)
%   voltage      - cell voltage [V]
%   current      - cell current [A] (sign convention: negative = discharge)
%   chamberTemp  - chamber temperature [degC] (used for sweep-aware anchors)
%   timeS        - seconds vector aligned with the samples
%   params       - struct with fields restThr_A, minPulseAmp_A, maxPulseAmp_A,
%                  minPulse_s, maxPulse_s, pulseFlatnessTol, minTrailRest_s,
%                  T_baseline_C (NaN => auto-detect), tempBaselineTol_C
%
% Detection rules:
%   * Pulse mask: params.minPulseAmp_A < |I| < params.maxPulseAmp_A
%   * Duration filter: [params.minPulse_s, params.maxPulse_s]
%   * Flatness filter: std(I)/mean(|I|) <= params.pulseFlatnessTol
%   * Rest boundary: |I| < params.restThr_A
%   * OCV anchor placement inside each rest window: LAST sample where the
%     chamber is at baseline (|Tchamber - T_baseline| <= tempBaselineTol_C)
%     before ANY chamber-temperature sweep begins. Falls back to the last
%     rest sample before the next pulse if no sweep is present in that
%     rest window. Baseline is auto-detected from the rest-sample median
%     when params.T_baseline_C is NaN.
%
% Handling of a truncated trace: if the quiescent samples following the
% last accepted pulse span less than params.minTrailRest_s, the last pulse
% is dropped so no bogus under-load "OCV" is emitted.
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-08-11 (extracted from ExtractGITTToCSV.m into a shared helper)

ep = struct([]);

% 1) Pulse mask
absI = abs(current);
pulseMask = (absI > params.minPulseAmp_A) & (absI < params.maxPulseAmp_A) & ~isnan(current);

% 2) Contiguous pulse runs
pm = pulseMask(:);
edges = diff([false; pm; false]);
runStarts = find(edges ==  1);
runEnds   = find(edges == -1) - 1;
if isempty(runStarts); return; end

% 3) Filter runs by duration + flatness -> pulses
pulseStartIdx = zeros(0, 1);
pulseEndIdx   = zeros(0, 1);
pulseModes    = {};
for i = 1:numel(runStarts)
    s = runStarts(i); e = runEnds(i);
    if isnan(timeS(s)) || isnan(timeS(e)); continue; end
    dur = timeS(e) - timeS(s);
    if dur < params.minPulse_s || dur > params.maxPulse_s; continue; end
    iP = current(s:e);
    iP = iP(~isnan(iP));
    if isempty(iP); continue; end
    mu = abs(mean(iP));
    if mu < params.minPulseAmp_A; continue; end
    if (std(iP) / mu) > params.pulseFlatnessTol; continue; end
    if mean(iP) < 0
        m = 'discharge';
    else
        m = 'charge';
    end
    pulseStartIdx(end+1, 1) = s; %#ok<AGROW>
    pulseEndIdx(end+1, 1)   = e; %#ok<AGROW>
    pulseModes{end+1, 1}    = m; %#ok<AGROW>
end
nP = numel(pulseStartIdx);
if nP == 0; return; end

% 4) Verify the sign pattern: some discharge pulses followed by some charge
%    pulses, in that order, with exactly one flip. A trace with all one
%    sign or with multiple flips is still exported but flagged in the log.
isDis = strcmp(pulseModes, 'discharge');
isChg = strcmp(pulseModes, 'charge');
if any(isDis) && any(isChg)
    firstChg = find(isChg, 1, 'first');
    lastDis  = find(isDis, 1, 'last');
    if lastDis > firstChg
        fprintf(['  [WARN] discharge and charge pulses are interleaved; ' ...
                 'CSV split will still occur at the last discharge pulse.\n']);
    end
end

% 5) Determine the chamber baseline temperature (auto-detect if NaN).
restMaskGlobal = ~isnan(current) & (abs(current) < params.restThr_A);
if isnan(params.T_baseline_C)
    T_baseline = median(chamberTemp(restMaskGlobal & ~isnan(chamberTemp)));
else
    T_baseline = params.T_baseline_C;
end
fprintf('  Using chamber baseline = %.2f degC (tol +/- %.1f degC).\n', ...
    T_baseline, params.tempBaselineTol_C);

% 6) OCV anchor indices: last baseline-temp rest sample BEFORE any
%    temperature sweep begins in each rest window (or the last rest sample
%    before the next pulse if no sweep is present). One anchor per pulse
%    boundary, plus one after the last pulse -> nP + 1 anchors.
ocvIdx = zeros(nP + 1, 1);

% Anchor before pulse 1: rest window = [1, pulseStartIdx(1) - 1].
ocvIdx(1) = findAnchorBeforeSweep( ...
    1, pulseStartIdx(1) - 1, ...
    current, chamberTemp, params.restThr_A, ...
    T_baseline, params.tempBaselineTol_C);

% Anchor between pulse k and k+1: rest window = [pulseEndIdx(k)+1, pulseStartIdx(k+1)-1].
for k = 1:nP - 1
    ocvIdx(k + 1) = findAnchorBeforeSweep( ...
        pulseEndIdx(k) + 1, pulseStartIdx(k + 1) - 1, ...
        current, chamberTemp, params.restThr_A, ...
        T_baseline, params.tempBaselineTol_C);
end

% Anchor after last pulse: walk forward to the end of the trailing rest,
% then apply the same sweep-aware placement inside that window.
[lastRestEnd, trailDur_s] = findLastRestAfter( ...
    pulseEndIdx(nP), current, timeS, params.restThr_A);
if isempty(lastRestEnd) || trailDur_s < params.minTrailRest_s
    fprintf('  [WARN] trailing rest after last pulse is %.1f s < %.0f s => dropping the final pulse from the export.\n', ...
        max(trailDur_s, 0), params.minTrailRest_s);
    nP            = nP - 1;
    if nP == 0; return; end
    pulseStartIdx = pulseStartIdx(1:nP);
    pulseEndIdx   = pulseEndIdx(1:nP);
    pulseModes    = pulseModes(1:nP);
    ocvIdx        = ocvIdx(1:nP + 1);
    [lastRestEnd, ~] = findLastRestAfter( ...
        pulseEndIdx(nP), current, timeS, params.restThr_A);
    if isempty(lastRestEnd)
        fprintf('  [ERROR] no rest sample after new last pulse; aborting.\n');
        return
    end
end
ocvIdx(nP + 1) = findAnchorBeforeSweep( ...
    pulseEndIdx(nP) + 1, lastRestEnd, ...
    current, chamberTemp, params.restThr_A, ...
    T_baseline, params.tempBaselineTol_C);

% 7) Per-pulse signed Ah via trapezoidal integration.
q_per_pulse_Ah = zeros(nP, 1);
for k = 1:nP
    s = pulseStartIdx(k);
    e = pulseEndIdx(k);
    tk = timeS(s:e); ik = current(s:e);
    m  = ~isnan(tk) & ~isnan(ik);
    if nnz(m) >= 2
        q_per_pulse_Ah(k) = trapz(tk(m), ik(m)) / 3600;
    end
end

% 8) Package.
ep = struct();
ep.timeStart       = timeWithGaps(pulseStartIdx(1));
ep.timeEnd         = timeWithGaps(pulseEndIdx(end));
ep.pulseStartIdx   = pulseStartIdx;
ep.pulseEndIdx     = pulseEndIdx;
ep.pulseModes      = pulseModes;
ep.ocvIdx          = ocvIdx;
ep.OCV_V           = voltage(ocvIdx);
ep.q_per_pulse_Ah  = q_per_pulse_Ah;
ep.cumQ_signed_Ah  = [0; cumsum(q_per_pulse_Ah)];
end


function idx = findAnchorBeforeSweep(restStart, restEnd, current, chamberTemp, restThr_A, T_baseline, tempTol)
% Scan the rest window [restStart, restEnd] forward. Return the sample
% index of the LAST rest sample where the chamber is still at baseline
% BEFORE any temperature sweep begins (i.e. the sample just before the
% first departure from baseline). If no sweep is present in the window,
% return restEnd (fall back to the last rest sample before the next pulse).
%
% A sample is considered rest+baseline when:
%   * ~isnan(current) & |current| < restThr_A
%   * ~isnan(chamberTemp) & |chamberTemp - T_baseline| <= tempTol
%
% Fix (2026-08-25, todo #106): a genuine current excursion inside the
% window (e.g. an earlier long charge/discharge event that was rejected as
% a detected "pulse" only because it exceeded the duration filter) is NOT
% a temperature sweep - it just means the rest period was interrupted by
% an unrelated event. Previously any non-rest-or-non-baseline sample was
% treated as "the sweep starts here", so an early, stale rest streak
% (e.g. a brief low-voltage rest before that earlier event) got locked in
% as the anchor instead of the true rest that follows. Now a genuine
% current excursion (~atRest) resets the baseline-seen streak instead of
% ending the scan, so the algorithm keeps looking for the rest period that
% actually precedes the next pulse/window end.
    if restStart < 1;         restStart = 1;         end
    if restEnd > numel(current); restEnd = numel(current); end
    if restEnd < restStart
        idx = max(restStart, 1);
        return
    end
    idx = restEnd;                       % fallback: last rest sample
    seenBaseline = false;
    for j = restStart:restEnd
        atRest = ~isnan(current(j)) && abs(current(j)) < restThr_A;
        atBase = ~isnan(chamberTemp(j)) && abs(chamberTemp(j) - T_baseline) <= tempTol;
        if atRest && atBase
            seenBaseline = true;
            continue
        end
        if ~atRest
            % A real current excursion, not a temperature sweep: discard
            % any stale baseline-rest streak and keep scanning.
            seenBaseline = false;
            continue
        end
        if seenBaseline
            % Still at current-rest, but chamber has drifted off baseline
            % -> a genuine temperature sweep starts here.
            idx = j - 1;
            return
        end
    end
end


function [idx, dur_s] = findLastRestAfter(pulseEnd, current, timeS, restThr_A)
% Walk forward from (pulseEnd + 1) through the trailing rest and return
% the LAST contiguous rest sample plus the duration of that rest (in
% seconds). Returns [] / 0 if no rest sample exists after pulseEnd.
    N = numel(current);
    if pulseEnd >= N
        idx = []; dur_s = 0; return
    end
    startRest = pulseEnd + 1;
    if isnan(current(startRest)) || abs(current(startRest)) >= restThr_A
        idx = []; dur_s = 0; return
    end
    idx = startRest;
    for j = startRest:N
        if isnan(current(j)) || abs(current(j)) >= restThr_A
            idx = j - 1;
            break
        end
        idx = j;
    end
    dur_s = timeS(idx) - timeS(startRest);
end
