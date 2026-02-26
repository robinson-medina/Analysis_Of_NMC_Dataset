function plotOverviewData(timeWithGaps, current, voltage, cellTemp, chamberTemp, cumulative_integral, cellNum, cellLabel)
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
%   cellLabel           - (Optional) Descriptive label from test plan

if nargin < 8
    cellLabel = '';
end

fprintf('Creating overview plots...\n');
tic;  % Restart timer

figure('Units','normalized', 'OuterPosition',[0 0 0.5 1]); % Create a figure that takes up half the screen width

startTime = timeWithGaps(1);
endTime = timeWithGaps(end);


% Current plot
ax1 = subplot(4,1,1);
plot(timeWithGaps, current)
grid on
ylim([-100 100])
ylabel('Current [A]')
autoTicks = ax1.XTick;
allTicks = unique([startTime, autoTicks, endTime]); % Combine and sort unique tick values including start and end
ax1.XTick = allTicks;

% Voltage plot
ax2 = subplot(4,1,2);
plot(timeWithGaps, voltage)
grid on
ylabel('Voltage [V]')
ylim([2.5 4.5])
autoTicks = ax2.XTick;
allTicks = unique([startTime, autoTicks, endTime]); % Combine and sort unique tick values including start and end
ax2.XTick = allTicks;

% Temperature plot (cell surface and chamber ambient)
ax3 = subplot(4,1,3);
plot(timeWithGaps, cellTemp)
hold on
plot(timeWithGaps, chamberTemp)
grid on
ylabel('Temperature [°C]')
legend('surface', 'ambient', 'location', 'best')
ylim([0 60])
autoTicks = ax3.XTick;
allTicks = unique([startTime, autoTicks, endTime]); % Combine and sort unique tick values including start and end
ax3.XTick = allTicks;

% Cumulative capacity plot (convert from As to Ah by dividing by 3600)
ax4 = subplot(4,1,4);
plot(timeWithGaps, cumulative_integral/3600)
grid on
xlabel('Date [h]')
ylabel('Capacity [Ah]')
ylim([0 60])

% Link x-axes for synchronized zooming and panning
linkaxes([ax1, ax2, ax3, ax4], 'x')
xlim([timeWithGaps(1),timeWithGaps(end)])

% Ensure start and end dates are always visible on x-axis
% Get auto-generated ticks and add start/end if not present
autoTicks = ax4.XTick;
allTicks = unique([startTime, autoTicks, endTime]); % Combine and sort unique tick values including start and end
ax4.XTick = allTicks;

if isempty(cellLabel)
    sgtitle(sprintf('Data overview file %s',cellNum),'Interpreter','none')
else
    sgtitle(sprintf('Data overview file %s - %s',cellNum, cellLabel),'Interpreter','none')
end
fprintf('Overview plots created. (Elapsed: %.2f s)\n', toc);

end
