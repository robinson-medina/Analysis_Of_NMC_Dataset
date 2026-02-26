function plotCapacityAndResistanceTrending(checkupCapacityTimeStamp, checkupCapacity_Ah, checkupCapacityFEC, checkupResistanceTimeStamp, checkupResistance_Ohm, checkupResistanceFEC, cellNum, cellLabel)
% plotCapacityAndResistanceTrending - Plot capacity degradation and resistance growth
%
% This function creates a two-panel figure showing capacity fade and
% resistance growth over time from battery checkup measurements.
% Capacity plot shows FEC as text labels at each point.
% Resistance plot includes dual x-axes showing Date and FEC.
%
% Inputs:
%   checkupCapacityTimeStamp    - Datetime array of capacity measurement timestamps
%   checkupCapacity_Ah          - Array of measured discharge capacities (Ah)
%   checkupCapacityFEC          - Array of FEC values at capacity measurements
%   checkupResistanceTimeStamp  - Datetime array of resistance measurement timestamps
%   checkupResistance_Ohm       - Array of measured DC resistance values (Ω)
%   checkupResistanceFEC        - Array of FEC values at resistance measurements
%   cellNum                     - Cell identifier string for plot title
%   cellLabel                   - (Optional) Descriptive label from test plan

if nargin < 8
    cellLabel = '';
end

fprintf('\nGenerating capacity and resistance trending plots...\n');

%%
figure('Units','normalized', 'OuterPosition',[0 0 0.5 1]); % Create a figure that takes up half the screen width

checkupCapacityTimeStamp.Format = 'yyyy-MM-dd'; % don't show the hour

% Use subplot instead of tiledlayout to allow position manipulation for dual x-axis

% Capacity degradation over time (top panel)
x1 = subplot(2,1,1);
scatter(x1, checkupCapacityTimeStamp, checkupCapacity_Ah)
set(x1,'XLim',[min(checkupCapacityTimeStamp) max(checkupCapacityTimeStamp)]);
x1.XTick = checkupCapacityTimeStamp;
x1.XTickLabel = string(checkupCapacityTimeStamp);
ylim([20 62])
ylabel('Discharge Capacity [Ah]');
if isempty(cellLabel)
    title(['Capacity Degradation Trending ', cellNum], 'interpreter', 'none');
else
    title(['Capacity Degradation Trending ', cellNum, ' - ', cellLabel], 'interpreter', 'none');
end
grid on

% Add FEC values as text below each date tick label
yLimits1 = ylim(x1);
yOffset1 = yLimits1(1) - 0.05 * (yLimits1(2) - yLimits1(1));  % Position below axis
hold(x1, 'on');
for i = 1:length(checkupCapacityTimeStamp)
    text(x1, checkupCapacityTimeStamp(i), yOffset1, sprintf('(%d)', round(checkupCapacityFEC(i))), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 8, 'Clipping', 'off');
end
hold(x1, 'off');

% Create two-line xlabel and move it down to avoid overlap with FEC labels
xlh1 = xlabel(x1, sprintf('Date\n(FEC)'));
xlh1.Position(2) = xlh1.Position(2) - 0.05 * (yLimits1(2) - yLimits1(1));

% Resistance growth over time (bottom panel)

selectedResistanceTime = checkupResistanceTimeStamp;
selectedResistanceTime.Format = 'yyyy-MM-dd';
selectedResistance = checkupResistance_Ohm;

x3 = subplot(2,1,2);
scatter(x3, selectedResistanceTime, selectedResistance);
ylim([0.5e-3 10e-3])
x3.XTick = selectedResistanceTime;
x3.XTickLabel = string(selectedResistanceTime);
xlim([min(selectedResistanceTime) max(selectedResistanceTime)]);
ylabel('Resistance [Ω]');

% Add FEC values as text below each date tick label
yLimits = ylim(x3);
yOffset = yLimits(1) - 0.05 * (yLimits(2) - yLimits(1));  % Position below axis
hold(x3, 'on');
for i = 1:length(selectedResistanceTime)
    text(x3, selectedResistanceTime(i), yOffset, sprintf('(%d)', round(checkupResistanceFEC(i))), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontSize', 8, 'Clipping', 'off');
end
hold(x3, 'off');

% Create two-line xlabel and move it down to avoid overlap with FEC labels
xlh = xlabel(sprintf('Date\n(FEC)'));
xlh.Position(2) = xlh.Position(2) - 0.05 * (yLimits(2) - yLimits(1));
if isempty(cellLabel)
    title(['Resistance Growth (30s Pulse Method) ', cellNum], 'interpreter', 'none');
else
    title(['Resistance Growth (30s Pulse Method) ', cellNum, ' - ', cellLabel], 'interpreter', 'none');
end
grid on

fprintf('Trending plots created. (Elapsed: %.2f s)\n', toc);


if ~isempty(selectedResistanceTime)
    linkaxes([x1 x3],'x')
    MinTime = min(min(checkupCapacityTimeStamp),min(selectedResistanceTime))-minutes(1);
    MaxTime = max(max(checkupCapacityTimeStamp),max(selectedResistanceTime))+minutes(1);
    xlim(x1, [MinTime MaxTime]);  % Explicitly set on x1 (datetime axis)
end
%%
end