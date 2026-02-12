function [checkupCapacity_AhTimeStamp, checkupCapacity_Ah, legends,SegmentVoltage_V,dQdV_AperVs,SegmentCapacity_Ah] = analyzeCheckupDischarge(segments, selectedTime, selectedVoltage, selectedCurrent, selectedTimeS, windowSize, cellNum)
% analyzeCheckupDischarge - Analyze and plot discharge curves for checkup cycles
%
% This function processes constant-current discharge segments to calculate
% capacity and generate dQ/dV plots for battery checkup analysis.
%
% Inputs:
%   segments         - Cell array of segment index ranges
%   selectedTime     - Datetime array for selected time range
%   selectedVoltage  - Voltage array for selected range (Volts)
%   selectedCurrent  - Current array for selected range (Amperes)
%   selectedTimeS    - Time array in seconds for selected range
%   windowSize       - Window size for moving average in dQ/dV calculation
%   cellNum          - Cell identifier string for plot title
%
% Outputs:
%   checkupCapacity_AhTimeStamp - Datetime array of checkup timestamps
%   checkupCapacity_Ah          - Array of measured discharge capacities (Ah)
%   legends                  - Cell array of legend strings

% Loop through each segment and analyze discharge curves
fprintf('Analyzing discharge curves: ');
legends = {};
SegmentVoltage_V={};
dQdV_AperVs={};
SegmentCapacity_Ah={};
figure('Units','normalized', 'OuterPosition',[0 0 0.5 1]); % Create a figure that takes up half the screen width

hold on
% Define line styles for plot variation
lineStyles = {'-', '--', ':', '-.'};
if isempty(segments)
    warning('There are no checkup segments ')
    checkupCapacity_AhTimeStamp=[];
    checkupCapacity_Ah=[]; 
    legends='';
    return
end

ValidSegCount=1;
for i = 1:length(segments)
    if mod(i, 5) == 0 || i == 1
        fprintf('%d/%d ', i, length(segments));
    end
    % Select line style for this iteration
    lineIdx = mod(i-1, length(lineStyles)) + 1;
    currentLineStyle = lineStyles{lineIdx};
    
    segmentIndices = segments{i};
    segmentVoltage = selectedVoltage(segmentIndices);
    segmentCurrent = selectedCurrent(segmentIndices);
    segmentTime = selectedTime(segmentIndices);
    segmentTimeS = selectedTimeS(segmentIndices);
    segmentTimeS = segmentTimeS - segmentTimeS(1);  % Normalize to start at 0

    % Only process complete discharge cycles (ending below 2.76V)
    if segmentVoltage(end) < 2.76 && segmentVoltage(1) > 4.1
        % Plot discharge capacity vs voltage
        subplot(2,1,1)
        hold on;
        SegmentCapacity_Ah{ValidSegCount} = -cumtrapz(segmentTimeS, segmentCurrent)/3600;
        plot(SegmentCapacity_Ah{ValidSegCount}, segmentVoltage, ...
             'LineStyle', currentLineStyle, 'LineWidth', 1.5, ...
             'Color', [i/length(segments), 0, 1-i/length(segments)]);
        xlabel('Discharge Capacity [Ah]');
        ylabel('Voltage [V]');
        
        % Plot differential capacity (dQ/dV) vs voltage
        subplot(2,1,2)
        hold on;
        % Calculate smoothed dQ/dV
        smoothCurrent = movmean(segmentCurrent, windowSize);
        smoothVoltage = movmean(segmentVoltage, windowSize);
        dQdV_AperVs{ValidSegCount} = movmean(gradient(cumtrapz(segmentTimeS, smoothCurrent)) ./ ...
                       gradient(smoothVoltage), windowSize);
        plot(segmentVoltage, dQdV_AperVs{ValidSegCount}, ...
             'LineStyle', currentLineStyle, 'LineWidth', 1.5, ...
             'Color', [i/length(segments), 0, 1-i/length(segments)]);
        xlabel('Cell Voltage [V]');
        ylabel('dQ/dV');
        pause(0.01)
        SegmentVoltage_V{ValidSegCount} = segmentVoltage;
    
        % Store capacity and timestamp for trending
        checkupCapacity_AhTimeStamp(i) = segmentTime(1);
        checkupCapacity_Ah(i) = -min(cumtrapz(segmentTimeS, segmentCurrent)/3600);
        CheckedDate = segmentTime(1);
        CheckedDate.Format = 'yy-MM-dd''T''HH:mm';
        legends = {legends{:} [' ' char(CheckedDate)]};
        ValidSegCount = ValidSegCount+1;
    end
end

if isempty(checkupCapacity_AhTimeStamp)
    checkupCapacity_AhTimeStamp=0;
    checkupCapacity_Ah=0;
end
sgtitle(['Checkup Analysis' cellNum],'interpreter','none');
lgd = legend(legends);
% lgd.Orientation = 'horizontal';
lgd.Location = 'best';
hold off;
fprintf('\nCheckup capacity analysis complete. (Elapsed: %.2f s)\n', toc);

end
