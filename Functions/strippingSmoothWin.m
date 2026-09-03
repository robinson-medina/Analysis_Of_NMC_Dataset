function w = strippingSmoothWin(cellNum)
% strippingSmoothWin - site-dependent movmean window for dV/dt smoothing in
% the Li-stripping analysis (A-002, todo #061).
%
% Single source of truth for the sensor-noise smoothing window; callers
% (analyzeDVdtAfterCharge, PlotCellSummary, extractDVdtSegmentsAll params)
% must NOT hard-code these values.
%
%   TNO rigs  (temp_group 1/2, campaigns A1/A2): low-noise sensors  -> window = 5 samples
%   AIT rigs  (temp_group 3/4, campaigns A3/A4): noisier sensors    -> window = 50 samples
%
% The window is in samples ON THE UNIFORM 1 s GRID that the segment
% extractors interpolate onto, so samples == seconds regardless of the raw
% file's row rate (AIT files periodically split one 1 s tick into two rows).
%
% Fixed 2026-08-25 (todo #105): the previous startsWith(cellNum,'A1'/'A2')
% site check always evaluated false once cell IDs moved to the plain R-025
% Cell_<n> form (no more 'A1.xx_Cell_n' prefix to match), so every cell
% silently fell through to the AIT branch (w=50). Now resolves the site via
% cellNumberToGroupChannel (the same campaign crosswalk used elsewhere),
% matching the already-fixed Python port (Functions/strippingSmoothWin.py).
%
% Input:  cellNum - cell identifier, e.g. 'Cell_35' (plain R-025 form); the
%                    legacy 'A2.08_Cell_35' prefixed form is still handled
%                    for back-compat.
% Output: w       - movmean window length [samples on the 1 s grid]
%
% Author: Feye Hoekstra (via Claude agent, todo #061); fix: GitHub Copilot (todo #105)
% Date:   2026-08-12 (created); 2026-08-25 (fixed)

tokens = regexp(cellNum, 'Cell_(\d+)', 'tokens', 'once');
if ~isempty(tokens)
    cellNumber = str2double(tokens{1});
    tempGroup = cellNumberToGroupChannel(cellNumber);
    if tempGroup == 1 || tempGroup == 2
        w = 5;   % TNO rigs (A1/A2): low-noise sensors
    else
        w = 50;  % AIT rigs (A3/A4) or unknown cell: noisier sensors
    end
elseif startsWith(cellNum, 'A1') || startsWith(cellNum, 'A2')
    % Legacy A1.xx/A2.xx-prefixed form, if ever encountered.
    w = 5;
else
    w = 50;
end
end

