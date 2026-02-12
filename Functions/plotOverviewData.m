function plotOverviewData(timeWithGaps, current, voltage, cellTemp, chamberTemp, cumulative_integral, cellNum)
% plotOverviewData - Create multi-panel overview plot
%
% This function creates a comprehensive 4-panel plot showing current,
% voltage, temperature, and cumulative capacity over time for battery
% test data visualization.
%
% Inputs:
%   timeWithGaps        - Datetime array with timestamps (may contain NaT)
%   current             - Current array in Amperes
%   voltage             - Voltage array in Volts
%   cellTemp            - Cell surface temperature in Celsius
%   chamberTemp         - Chamber ambient temperature in Celsius
%   cumulative_integral - Cumulative charge in Ampere-seconds (As)
%   cellNum             - Cell identifier string for plot title

fprintf('Creating overview plots...\n');
tic;  % Restart timer

figure('Units','normalized', 'OuterPosition',[0 0 0.5 1]); % Create a figure that takes up half the screen width

% Current plot
ax1 = subplot(4,1,1);
plot(timeWithGaps, current)
grid on
ylabel('Current [A]')

% Voltage plot
ax2 = subplot(4,1,2);
plot(timeWithGaps, voltage)
grid on
ylabel('Voltage [V]')

% Temperature plot (cell surface and chamber ambient)
ax3 = subplot(4,1,3);
plot(timeWithGaps, cellTemp)
hold on
plot(timeWithGaps, chamberTemp)
grid on
ylabel('Temperature [°C]')
legend('surface', 'ambient', 'location', 'best')

% Cumulative capacity plot (convert from As to Ah by dividing by 3600)
ax4 = subplot(4,1,4);
plot(timeWithGaps, cumulative_integral/3600)
grid on
xlabel('Date [h]')
ylabel('Capacity [Ah]')

% Link x-axes for synchronized zooming and panning
linkaxes([ax1, ax2, ax3, ax4], 'x')
xlim([timeWithGaps(1),timeWithGaps(end)])

sgtitle(sprintf('Data overview file %s',cellNum),'Interpreter','none')
fprintf('Overview plots created. (Elapsed: %.2f s)\n', toc);

end
