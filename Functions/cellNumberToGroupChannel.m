function [tempGroup, channel] = cellNumberToGroupChannel(cellNumber)
% cellNumberToGroupChannel - Map a physical ageing-cell number to its test group/channel.
%
% Summary: Maps a physical cell number (R-025 plain Cell_<n> convention) to
% its ageing test (tempGroup, channel) pair, using the campaign crosswalk in
% ageing_test_plan.md. tempGroup 1-4 correspond to campaigns A1-A4
% (0 degC, 25 degC, 45 degC, 0-45 degC respectively).
%
% Extracted 2026-08-24 from getCellLabel.m's local function of the same name,
% so it can also be called from other Functions/ helpers (e.g.
% extractResistanceValues.m) that need to know which campaign a cell belongs
% to without re-parsing an old-form cell-ID string (which no longer exists
% under R-025).
%
% Author: GitHub Copilot (for Feye Hoekstra / Robinson Medina)
% Date: 2026-08-24
%
% Inputs:
%   cellNumber - physical cell number (double), e.g. 35 for 'Cell_35'
% Outputs:
%   tempGroup  - ageing campaign/temperature group (1-4), NaN if unknown
%   channel    - channel number within that campaign, NaN if unknown

% Cache the lookup map across calls (persistent) so it is only built once.
persistent M
if isempty(M)
    % Physical cell numbers, in the same order as ageing_test_plan.md.
    keys = [57 60 63 66 68 71 74 72 ...
            11 12 56 89 93 16 30 27 23 34 35 43 46 42 ...
            45 26 28 29 40 1 3 9 5 22 8 47 17 25 ...
            49 50 53 64 70];
    % Matching [tempGroup channel] pairs for each key above, same order.
    vals = { [1 1],[1 2],[1 3],[1 4],[1 5],[1 6],[1 7],[1 8], ...
             [2 1],[2 2],[2 2],[2 2],[2 2],[2 3],[2 4],[2 5],[2 6],[2 7],[2 8],[2 9],[2 10],[2 11], ...
             [3 1],[3 2],[3 3],[3 4],[3 5],[3 6],[3 7],[3 8],[3 9],[3 10],[3 11],[3 12],[3 13],[3 14], ...
             [4 1],[4 2],[4 3],[4 4],[4 5] };
    M = containers.Map(keys, vals);
end

% Look up the cell number; unknown cells return NaN/NaN rather than erroring,
% so callers can decide how to handle non-ageing (e.g. characterization) cells.
if isKey(M, cellNumber)
    gc = M(cellNumber);
    tempGroup = gc(1);
    channel = gc(2);
else
    tempGroup = NaN;
    channel = NaN;
end

end
