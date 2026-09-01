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
%       pulseAmp_A           - legacy / documentation only (nominal C/5 = 11.6 A)
%       pulseTol_A           - legacy / documentation only
%       maxPulseAmp_A        - UPPER |I| limit defining a pulse (A); the
%                              lower limit is restThr_A. Pulses with
%                              restThr_A < |I| < maxPulseAmp_A are kept
%                              (so C/5 and lower-rate GITT pulses are
%                              detected, but cycling at -87 / +29 A is
%                              excluded) (A-001)
%       minPulse_s           - reject pulses shorter than this (noise)
%       maxPulse_s           - reject pulses longer than this (cycling/checkup)
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
%       pulseFlatnessTol     - max std(I)/|mean(I)| within a pulse; rejects
%                              CV-decay phases that ramp through the
%                              [restThr_A, maxPulseAmp_A] amplitude window
%                              during the initial CLUSTERING step (A-001)
%       gradThr_Apers        - |dI/dt| threshold (A/s) used inside a
%                              validated cluster to re-detect pulse rising
%                              edges. Once an episode is gated by
%                              clustering, refinement only needs to spot
%                              the sharp ramp at the start of each pulse;
%                              this avoids depending on pulse shape
%                              (flatness) so a CC+CV last pulse is still
%                              picked up (A-001)
%       minPulsesPerEpisode  - keep only clusters with at least this many pulses
%       maxPulsesPerEpisode  - reject clusters with more than this many
%                              pulses (a real GITT half has 23-26 C/5 pulses;
%                              a merged discharge+charge episode is ~46-52;
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
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-07-28 (extracted from PlotCellSummary.m into a shared helper)
% Assumption: A-001 (see docs/assumptions.md)

% Defensive defaults (in case caller passes a partial struct)
def = struct('pulseAmp_A',11.6, 'pulseTol_A',0.5, ...
             'maxPulseAmp_A',20, ...
             'minPulse_s',60, 'maxPulse_s',3600, ...
             'maxIntraEpisodeGap_s',24*3600, 'restThr_A',0.5, ...
             'minRestDur_s',600, 'pulseFlatnessTol',0.05, ...
             'gradThr_Apers',3, ...
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
    % Constant-current flatness check: reject CV-decay phases of cycling
    % charge (current ramps through the [restThr_A, maxPulseAmp_A] window).
    iPulse = current(s:e);
    iPulse = iPulse(~isnan(iPulse));
    if isempty(iPulse); continue; end
    mu = abs(mean(iPulse));
    if mu < params.restThr_A; continue; end
    if (std(iPulse) / mu) > params.pulseFlatnessTol; continue; end
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
    restMask = abs(iSeg(1:end-1)) < params.restThr_A;
    isEdge   = (absDiDt > params.gradThr_Apers) & restMask;
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
    % exceeds maxIntraEpisodeGap_s (we walked into the next episode).
    nKeep = numel(pulseStartIdx_r);
    for k = 2:numel(pulseStartIdx_r)
        gap_s = timeS(pulseStartIdx_r(k)) - timeS(pulseEndIdx_r(k - 1));
        if ~isnan(gap_s) && gap_s > params.maxIntraEpisodeGap_s
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
