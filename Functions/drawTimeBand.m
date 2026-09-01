function drawTimeBand(axList, t0, t1, rgb, alpha)
% drawTimeBand - draw a semi-transparent vertical band on every axes in
% axList between t0 and t1 (datetime). Patches are sent to the bottom of
% the stack so the data line remains visible. R-003 compliant (no xregion).
%
% Inputs:
%   axList - array of axes handles to draw the band on
%   t0, t1 - datetime band start/end (x-axis coordinates)
%   rgb    - 1x3 fill colour
%   alpha  - face alpha (0..1)
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-07-28 (extracted from PlotCellSummary.m into a shared helper)

for ax = axList(:).'
    yl = ylim(ax);
    if isempty(yl) || any(~isfinite(yl))
        continue
    end
    p = patch(ax, ...
        'XData', [t0 t1 t1 t0], ...
        'YData', [yl(1) yl(1) yl(2) yl(2)], ...
        'FaceColor', rgb, 'FaceAlpha', alpha, ...
        'EdgeColor', 'none', 'HandleVisibility','off');
    uistack(p, 'bottom');
end
end
