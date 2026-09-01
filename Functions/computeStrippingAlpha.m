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
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-07-28 (extracted from PlotCellSummary.m into a shared helper)

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
