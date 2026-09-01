function checkups = computeCheckupCurves(segments, selectedTime, selectedVoltage, selectedCurrent, selectedTimeS, windowSize)
% computeCheckupCurves - Compute per-checkup OCP / capacity / dQ-dV curves.
%
% This is the single, authoritative implementation of the checkup-discharge
% math that was previously duplicated between:
%   (a) Functions/analyzeCheckupDischarge.m  (used by ExtractAgeingData.m), and
%   (b) the inline "Recompute per-checkup curves" block in PlotCellSummary.m.
%
% It performs NO plotting and NO file I/O; it only returns the numeric curves
% so that each caller can render / export them however it needs. Callers that
% also need State-of-Charge / OCV interpolation, Full-Equivalent-Cycles, or
% figures build those on top of the returned data.
%
% Acceptance test (identical to the previous implementations): a segment is a
% valid checkup discharge only if it both STARTS above 4.1 V and ENDS below
% 2.76 V (i.e. a complete top-to-bottom constant-current discharge).
%
% Inputs:
%   segments        - Cell array of segment index ranges (into the selected*
%                     arrays), e.g. from findCheckupSegments
%   selectedTime    - datetime array for the selected range
%   selectedVoltage - voltage array for the selected range [V]
%   selectedCurrent - current array for the selected range [A]
%   selectedTimeS   - seconds-since-start array for the selected range [s]
%   windowSize      - movmean window for the dQ/dV smoothing pipeline
%
% Output:
%   checkups - struct array (1 x nValid), one element per valid checkup, with:
%       .segmentNumber   - index of this segment within the input `segments`
%                          cell array (preserved so callers can reproduce the
%                          original age-ordered colour: [i/N, 0, 1-i/N])
%       .segmentIndices  - the segment's index vector into the selected* arrays
%       .capacity_Ah_vec - per-sample discharge capacity vector [Ah]
%                          (= -cumtrapz(t, I)/3600)
%       .voltage_vec     - per-sample voltage vector [V]
%       .dQdV_vec        - smoothed dQ/dV vector [As/V]
%       .startTime       - datetime of the first sample of the segment
%       .endTime         - datetime of the last sample of the segment
%       .capacity_Ah     - scalar discharge capacity [Ah] (= -min(cumtrapz/3600))
%       .timeStamp       - datetime used for trending (segment start time)
%   If no valid checkup is found, `checkups` is a 0x0 struct array carrying the
%   same field names (so numel(checkups)==0 and field access is safe).
%
% Author: GitHub Copilot (for Róbinson Medina / Feye Hoekstra)
% Date:   2026-07-28
%
% Compliance: R-003 (R2022a-safe), R-006 (Ah/V/s units), R-012 (commented).

% Preallocate an empty struct array carrying every field, so callers can
% always rely on the field set and on numel() even when nothing is found.
checkups = struct('segmentNumber', {}, 'segmentIndices', {}, ...
    'capacity_Ah_vec', {}, 'voltage_vec', {}, 'dQdV_vec', {}, ...
    'startTime', {}, 'endTime', {}, 'capacity_Ah', {}, 'timeStamp', {});

if isempty(segments)
    return
end

for i = 1:numel(segments)
    segmentIndices = segments{i};
    sV  = selectedVoltage(segmentIndices);          % segment voltage [V]
    sI  = selectedCurrent(segmentIndices);          % segment current [A]
    sT  = selectedTime(segmentIndices);             % segment datetime
    sTs = selectedTimeS(segmentIndices);            % segment time [s]
    sTs = sTs - sTs(1);                             % normalise to start at 0 s

    % Acceptance test: only complete discharge cycles (start > 4.1 V, end < 2.76 V).
    if ~(sV(end) < 2.76 && sV(1) > 4.1)
        continue
    end

    % Per-sample discharge capacity [Ah]. Discharge current is negative, so the
    % negated integral is a positive, increasing capacity trace.
    capVec = -cumtrapz(sTs, sI) / 3600;

    % Smoothed dQ/dV via the movmean/gradient pipeline (identical smoothing to
    % the previous implementations): smooth I and V, integrate charge, then take
    % gradient(charge)/gradient(V) and smooth again.
    smI  = movmean(sI, windowSize);
    smV  = movmean(sV, windowSize);
    dQdV = movmean(gradient(cumtrapz(sTs, smI)) ./ gradient(smV), windowSize);

    % Assemble this checkup's record.
    entry = struct();
    entry.segmentNumber   = i;                       % original position in `segments`
    entry.segmentIndices  = segmentIndices;
    entry.capacity_Ah_vec = capVec;
    entry.voltage_vec     = sV;
    entry.dQdV_vec        = dQdV;
    entry.startTime       = sT(1);
    entry.endTime         = sT(end);
    entry.capacity_Ah     = -min(cumtrapz(sTs, sI) / 3600);  % scalar checkup capacity
    entry.timeStamp       = sT(1);

    checkups(end+1) = entry; %#ok<AGROW> % number of checkups is small (tens)
end

end
