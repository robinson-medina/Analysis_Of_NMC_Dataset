function plotCapacityAndResistanceTrending(checkupCapacityTimeStamp, checkupCapacity, checkupResistanceTimeStamp, checkupResistance, cellNum)
% plotCapacityAndResistanceTrending - Plot capacity degradation and resistance growth
%
% This function creates a two-panel figure showing capacity fade and
% resistance growth over time from battery checkup measurements.
%
% Inputs:
%   checkupCapacityTimeStamp    - Datetime array of capacity measurement timestamps
%   checkupCapacity             - Array of measured discharge capacities (Ah)
%   checkupResistanceTimeStamp  - Datetime array of resistance measurement timestamps
%   checkupResistance           - Array of measured DC resistance values (Ω)
%   cellNum                     - Cell identifier string for plot title

fprintf('\nGenerating capacity and resistance trending plots...\n');
tic;  % Start timer

figure('Units','normalized', 'OuterPosition',[0 0 0.5 1]); % Create a figure that takes up half the screen width


% Capacity degradation over time
ax1 = subplot(2,1,1);
scatter(checkupCapacityTimeStamp, checkupCapacity)
ylim([20 62])
xlabel('Time');
ylabel('Discharge Capacity [Ah]');
title(['Capacity Degradation Trending ', cellNum], 'interpreter', 'none');
grid on

% Resistance growth over time
ax2 = subplot(2,1,2);
% Select at most 5 equally distributed resistance measurements
% numResistancePoints = length(checkupResistance);
% if numResistancePoints > 5
%     resistanceIndices = round(linspace(1, numResistancePoints, 5));
%     selectedResistanceTime = checkupResistanceTimeStamp(resistanceIndices);
%     selectedResistance = checkupResistance(resistanceIndices);
% else
    selectedResistanceTime = checkupResistanceTimeStamp;
    selectedResistance = checkupResistance;
% end
scatter(selectedResistanceTime, selectedResistance)
% ylim([0.5e-3 10e-3])
xlabel('Time');
ylabel('Resistance [Ω]');
title(['Resistance Growth (30s Pulse Method) ', cellNum], 'interpreter', 'none');
grid on

fprintf('Trending plots created. (Elapsed: %.2f s)\n', toc);

if ~isempty(selectedResistanceTime)
    linkaxes([ax1 ax2],'x')
    MinTime = min(min(checkupCapacityTimeStamp),min(selectedResistanceTime));
    MaxTime = max(max(checkupCapacityTimeStamp),max(selectedResistanceTime));
    xlim([MinTime MaxTime]);
end
end