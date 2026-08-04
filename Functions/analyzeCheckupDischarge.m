function [checkupCapacity_AhTimeStamp, checkupCapacity_Ah, checkupCapacityFEC, legends,CheckUpOCV_V,dQdV_AperVs,SegmentCapacity_Ah,CheckUpSoC] = analyzeCheckupDischarge(segments, selectedTime, selectedVoltage, selectedCurrent, selectedTimeS, windowSize, cellNum, cellLabel)
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
%   cellLabel        - (Optional) Descriptive label from test plan
%
% Outputs:
%   checkupCapacity_AhTimeStamp - Datetime array of checkup timestamps
%   checkupCapacity_Ah          - Array of measured discharge capacities (Ah)
%   legends                  - Cell array of legend strings

if nargin < 8
    cellLabel = '';
end

% Loop through each segment and analyze discharge curves
fprintf('Analyzing discharge curves: ');
legends = {};
CheckUpOCV_V={};
dQdV_AperVs={};
SegmentCapacity_Ah={};
CheckUpSoC={};
% Pre-initialise trending outputs so the function is safe even when no valid
% checkup is found (previously these were only created inside the loop).
checkupCapacity_AhTimeStamp = NaT(0);
checkupCapacity_Ah = [];
checkupCapacityFEC = [];
figure('Units','normalized', 'OuterPosition',[0 0 0.5 1]); % Create a figure that takes up half the screen width

hold on
% Define line styles for plot variation
lineStyles = {'-', '--', ':', '-.'};
if isempty(segments)
    warning('There are no checkup segments ')
    checkupCapacity_AhTimeStamp=[];
    checkupCapacity_Ah=[]; 
    checkupCapacityFEC=[];
    legends='';
    return
end

BatteryCapacity_Ah = 58;
FullEquivalentCycles = cumtrapz(selectedTimeS,abs(selectedCurrent))/BatteryCapacity_Ah/3600/2;

% Compute the per-checkup capacity / voltage / dQ-dV curves via the shared
% helper (single source of the checkup formula, also used by PlotCellSummary.m).
% This helper applies the identical acceptance test (V(1)>4.1 && V(end)<2.76)
% and returns only the valid checkups, in age order.
checkups = computeCheckupCurves(segments, selectedTime, selectedVoltage, ...
    selectedCurrent, selectedTimeS, windowSize);

for validSegCount = 1:numel(checkups)
    thisCheckup    = checkups(validSegCount);
    i              = thisCheckup.segmentNumber;      % original segment index (for colour/style)
    segmentIndices = thisCheckup.segmentIndices;
    segmentVoltage = thisCheckup.voltage_vec;
    segmentTime    = selectedTime(segmentIndices);

    if mod(i, 5) == 0 || i == 1
        fprintf('%d/%d ', i, length(segments));
    end
    % Select line style for this iteration (unchanged age-based cycling).
    lineIdx = mod(i-1, length(lineStyles)) + 1;
    currentLineStyle = lineStyles{lineIdx};

    % Plot discharge capacity vs voltage (curve computed by the shared helper).
    subplot(3,1,1)
    hold on;
    SegmentCapacity_Ah{validSegCount} = thisCheckup.capacity_Ah_vec;
    plot(SegmentCapacity_Ah{validSegCount}, segmentVoltage, ...
         'LineStyle', currentLineStyle, 'LineWidth', 1.5, ...
         'Color', [i/length(segments), 0, 1-i/length(segments)]);
    xlabel('Discharge Capacity [Ah]');
    ylabel('Voltage [V]');

    % Plot differential capacity (dQ/dV) vs voltage (curve from shared helper).
    subplot(3,1,2)
    hold on;
    dQdV_AperVs{validSegCount} = thisCheckup.dQdV_vec;
    plot(segmentVoltage, dQdV_AperVs{validSegCount}, ...
         'LineStyle', currentLineStyle, 'LineWidth', 1.5, ...
         'Color', [i/length(segments), 0, 1-i/length(segments)]);
    xlabel('Cell Voltage [V]');
    ylabel('dQ/dV');
    pause(0.01)

    % Store capacity and timestamp for trending (dense, age-ordered).
    checkupCapacity_AhTimeStamp(validSegCount) = thisCheckup.timeStamp;
    checkupCapacity_Ah(validSegCount) = thisCheckup.capacity_Ah;
    checkupCapacityFEC(validSegCount) = FullEquivalentCycles(segmentIndices(1));

    % Compute SoC vector: starts at 100% and decreases during discharge.
    % Recompute the signed capacity integral locally (matches the previous
    % implementation exactly) to drive the SoC axis.
    segCurrent = selectedCurrent(segmentIndices);
    segTimeS   = selectedTimeS(segmentIndices); segTimeS = segTimeS - segTimeS(1);
    soc_raw = 100 + (cumtrapz(segTimeS, segCurrent)/3600) / thisCheckup.capacity_Ah * 100;

    % Interpolate SoC and OCV to 100 points
    soc_vec = linspace(100, min(soc_raw), 100);
    [sorted_soc, sort_idx] = sort(soc_raw, 'descend');
    sorted_voltage = segmentVoltage(sort_idx);
    [unique_soc, unique_idx] = unique(sorted_soc, 'stable');
    unique_voltage = sorted_voltage(unique_idx);
    CheckUpSoC{validSegCount} = soc_vec;
    CheckUpOCV_V{validSegCount} = interp1(unique_soc, unique_voltage, soc_vec, 'linear', 'extrap');

    % Plot SoC vs Voltage
    subplot(3,1,3)
    hold on;
    plot(CheckUpSoC{validSegCount}, CheckUpOCV_V{validSegCount}, ...
        'LineStyle', currentLineStyle, 'LineWidth', 1.5, ...
        'Color', [i/length(segments), 0, 1-i/length(segments)]);
    xlabel('State of Charge [%]');
    ylabel('OCV [V]');
    CheckedDate = segmentTime(1);
    CheckedDate.Format = 'yy-MM-dd''T''HH:mm';
    legends = {legends{:} [' ' char(CheckedDate)]};
end

if isempty(checkupCapacity_AhTimeStamp)
    checkupCapacity_AhTimeStamp=0;
    checkupCapacity_Ah=0;
    checkupCapacityFEC=0;
end
if isempty(cellLabel)
    sgtitle(['Checkup Analysis ' cellNum],'interpreter','none');
else
    sgtitle(['Checkup Analysis ' cellNum ' - ' cellLabel],'interpreter','none');
end
lgd = legend(legends);
% lgd.Orientation = 'horizontal';
lgd.Location = 'best';
hold off;
fprintf('\nCheckup capacity analysis complete. (Elapsed: %.2f s)\n', toc);


% Remove NaT entries from output arrays. Guard with isdatetime so the
% no-valid-checkup path (where the timestamp was replaced by the numeric
% sentinel 0 above) does not call isnat on a double.
if isdatetime(checkupCapacity_AhTimeStamp)
    validIdx = ~isnat(checkupCapacity_AhTimeStamp);
    checkupCapacity_AhTimeStamp = checkupCapacity_AhTimeStamp(validIdx);
    checkupCapacity_Ah = checkupCapacity_Ah(validIdx);
    checkupCapacityFEC = checkupCapacityFEC(validIdx);
end


end
