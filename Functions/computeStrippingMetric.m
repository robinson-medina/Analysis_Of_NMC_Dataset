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
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-07-28 (extracted from PlotCellSummary.m into a shared helper)

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
