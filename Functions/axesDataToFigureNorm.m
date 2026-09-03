function [xNorm, yNorm] = axesDataToFigureNorm(ax, xData, yData)
% axesDataToFigureNorm - map data coordinates of a plain (non-tiled) axes
% into figure-normalized coordinates, so annotation objects (which live in
% figure space) can be anchored to data points.
%
% Assumes ax.Units is 'normalized' and ax.Position is expressed directly in
% figure-normalized units (true for a standard axes created with
% axes('Position', ...)). For axes nested inside a tiledlayout with a custom
% OuterPosition, use the ancestor-walking version in
% Functions/plotReferencePerformanceCycle.m instead.
%
% Inputs:
%   ax    - target axes handle (Units = 'normalized')
%   xData - x value(s) in data units (numeric or datetime)
%   yData - y value(s) in data units (numeric)
%
% Outputs:
%   xNorm, yNorm - figure-normalized coordinates in [0, 1]
%
% Author: GitHub Copilot (for Feye Hoekstra)
% Date:   2026-08-11

p = ax.Position;   % figure-normalized [left bottom width height]

xLim = ax.XLim;
if isdatetime(xLim); xLim = datenum(xLim); end
if isdatetime(xData); xData = datenum(xData); end
xNorm = p(1) + ((xData - xLim(1)) ./ (xLim(2) - xLim(1))) * p(3);

yLim = ax.YLim;
yNorm = p(2) + ((yData - yLim(1)) ./ (yLim(2) - yLim(1))) * p(4);
end
