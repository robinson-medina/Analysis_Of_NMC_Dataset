function c50 = buildC50Phase(dischSeg, chargeSegs, selectedVoltage, selectedCurrent, selectedTimeS)
% buildC50Phase - assemble a C/50 phase (discharge + matching charge) with
% a shared signed-Q axis integrated from the start of the discharge.
%
% The matching charge segment is the first C/50 charge segment whose start
% index is greater than the discharge end index. If no such charge segment
% exists, the discharge half is returned alone.
%
% Inputs:
%   dischSeg        - index vector of a C/50 discharge segment
%   chargeSegs      - cell array of C/50 charge segment index vectors
%   selectedVoltage - voltage array [V] for the selected range
%   selectedCurrent - current array [A] for the selected range
%   selectedTimeS   - seconds-since-start array [s] for the selected range
%
% Output:
%   c50 - struct with fields dischQ_Ah, dischV, chargeQ_Ah, chargeV
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-07-28 (extracted from PlotCellSummary.m into a shared helper)

c50 = struct('dischQ_Ah',[], 'dischV',[], 'chargeQ_Ah',[], 'chargeV',[]);
if isempty(dischSeg); return; end
dischSeg = dischSeg(:);  % column

% Find the first charge segment that starts after the discharge end
dischEnd  = dischSeg(end);
matchedChg = [];
for ii = 1:numel(chargeSegs)
    if chargeSegs{ii}(1) > dischEnd
        matchedChg = chargeSegs{ii}(:);
        break
    end
end

if isempty(matchedChg)
    % Discharge-only fallback (no matching C/50 charge after this discharge)
    sTs = selectedTimeS(dischSeg); sTs = sTs - sTs(1);
    sI  = selectedCurrent(dischSeg);
    m   = ~isnan(sTs) & ~isnan(sI);
    Q   = NaN(size(sTs));
    if nnz(m) >= 2
        Q(m) = cumtrapz(sTs(m), sI(m)) / 3600;
    end
    c50.dischQ_Ah = Q;
    c50.dischV    = selectedVoltage(dischSeg);
    return
end

% Integrate over the FULL window from discharge start to charge end so the
% Q values at the start of the charge segment correctly include any
% (near-zero) current accumulated during the intervening rest.
fullRange = dischSeg(1) : matchedChg(end);
tFull = selectedTimeS(fullRange);
iFull = selectedCurrent(fullRange);

% NaN-safe trapz: linearly interpolate time across NaT gap markers, treat
% NaN-current as zero contribution. This is a no-op for clean segments.
iClean = iFull; iClean(isnan(iClean)) = 0;
tClean = tFull;
if any(isnan(tClean))
    idxAll = (1:numel(tClean))';
    good   = ~isnan(tClean);
    if nnz(good) >= 2
        tClean(~good) = interp1(idxAll(good), tClean(good), idxAll(~good), ...
            'linear', 'extrap');
    else
        tClean = idxAll;  % degenerate fallback
    end
end
cumQ_full_Ah = cumtrapz(tClean - tClean(1), iClean) / 3600;

% Index of each segment within fullRange (1-based, relative to dischSeg(1))
relDisch  = 1 : numel(dischSeg);
relCharge = (matchedChg(1) - dischSeg(1) + 1) : numel(fullRange);

c50.dischQ_Ah  = cumQ_full_Ah(relDisch);
c50.dischV     = selectedVoltage(dischSeg);
c50.chargeQ_Ah = cumQ_full_Ah(relCharge);
c50.chargeV    = selectedVoltage(matchedChg);
end
