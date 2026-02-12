function [plottedSegments, dVdtData] = analyzeDVdtAfterCharge(selectedTime, selectedVoltage, selectedCurrent, selectedTimeS, constantCurrentValue, cellNum)
% analyzeDVdtAfterCharge - Analyze voltage relaxation rate after fast charge
%
% Inputs:
%   selectedTime - Time array in datetime format
%   selectedVoltage - Voltage array [V]
%   selectedCurrent - Current array [A]
%   selectedTimeS - Time array in seconds
%   constantCurrentValue - Target current value to find [A]
%   cellNum - Cell identifier string
%
% Outputs:
%   plottedSegments - Cell array containing segment information
%   dVdtData - Cell array containing dV/dt data for each segment

% Parameters
tolerance = 0.1;
constantCurrentIndices = abs(selectedCurrent - constantCurrentValue) <= tolerance;

% Filter for segments of appropriate length (900-1500 points)
minSegmentLength = 900;
maxSegmentLength = 1500;

% Find segments meeting criteria
segments = findSegmentsMinMax(constantCurrentIndices, minSegmentLength, maxSegmentLength);

% Initialize figure with voltage overview and dV/dt analysis
figure('Units','normalized', 'OuterPosition',[0 0 0.5 1]); % Create a figure that takes up half the screen width

% Check if segments were found
if isempty(segments)
    fprintf('\n*** No detectable discharge cycles found. ***\n');
    fprintf('*** This is probably calendar ageing data. ***\n\n');
    plottedSegments = {};
    dVdtData = {};
    return;
end



hold on;

% Upper subplot: voltage overview with arrow indicator
subplot(2,1,1)
hold on
plot(selectedTime, selectedVoltage)
xlabel('Time');
ylabel('Voltage [V]');
ylim([2.75 4.35])
xlim([selectedTime(1) selectedTime(end)])
xLimits = xlim;

% Lower subplot: dV/dt analysis
subplot(2,3,4)
hold on

% Select 5 segments distributed equally over time
numSegmentsToPlot = min(5, length(segments));
segmentIndices = round(linspace(1, length(segments), numSegmentsToPlot));

% Initialize output arrays
plottedSegments = cell(numSegmentsToPlot, 1);
dVdtData = cell(numSegmentsToPlot, 1);
legendEntries = cell(numSegmentsToPlot, 1);

for idx = 1:numSegmentsToPlot
    i = segmentIndices(idx);
    segmentIdx = segments{i};
    segmentVoltage = selectedVoltage(segmentIdx);
    segmentCurrent = selectedCurrent(segmentIdx);
    segmentTime = selectedTime(segmentIdx);
    segmentTimeS = selectedTimeS(segmentIdx);
    segmentTimeS = segmentTimeS - segmentTimeS(1);  % Normalize to start at 0

    % interpolate the voltage so the average is the same accross all
    % experiments

    InterpolationTime_s=0:1:max(segmentTimeS); 
    InterpolationVoltage_V = interp1(segmentTimeS,segmentVoltage,InterpolationTime_s);


    % Calculate smoothed dV/dt
    windowSize = 50;
    movMeanGradientRatio = movmean(gradient(InterpolationVoltage_V) ./ gradient(InterpolationTime_s), windowSize);

    % Calculate color for this segment
    segmentColor = [i/length(segments), 0, 1-i/length(segments)];

    % Create arrow annotation for current segment (new arrow each iteration)
    xNorm = (segmentTime(1) - xLimits(1)) / (xLimits(2) - xLimits(1));
    xNorm = max(0, min(1, xNorm)) * 0.75 + 0.140;
    annotation('arrow', [xNorm xNorm], [0.6 0.9], 'Color', segmentColor, 'LineWidth', 2);
    drawnow;

    % plot voltage
    subplot(2,3,4)
    hold on
    plot(InterpolationTime_s,InterpolationVoltage_V,'Color', segmentColor);
    xlabel('Time [s]');
    ylabel('V [V]');

% plot current
    subplot(2,3,5)
    hold on
    plot(segmentTimeS,segmentCurrent,'Color', segmentColor);  
    xlabel('Time [s]');
    ylabel('I [A]');
    % Plot dV/dt with color gradient

    subplot(2,3,6)
    hold on
    dVdt = movMeanGradientRatio(1:end);
    plot(InterpolationTime_s, dVdt, 'Color', segmentColor);
    ylim([-0.002 0])
    xlim([0 500])
    xlabel('Time [s]');
    ylabel('dV/dt [V/s]');

    % Store segment data and dV/dt
    plottedSegments{idx} = struct('indices', segmentIdx, ...
        'time', segmentTime, ...
        'timeS', InterpolationTime_s, ...
        'voltage', segmentVoltage);
    dVdtData{idx} = struct('timeS', InterpolationTime_s, 'dVdt_Vpers', dVdt);

    % Store legend entry with date
    legendEntries{idx} = datestr(selectedTime(segmentIdx(1)), 'dd-mmm-yyyy HH:MM');

    % Pause for dramatic effect
    pause(0.1)

end

% Add legend to lower subplot
legend(legendEntries, 'Location', 'best');

sgtitle(['dV/dt in discharge After Fast Charge ', cellNum], 'Interpreter', 'none');
hold off;
end
