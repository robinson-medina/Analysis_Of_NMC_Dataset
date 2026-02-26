function [checkupResistance_OhmTimeStamp, checkupResistance_Ohm,checkupResistenceFEC] = extractResistanceValues(timeWithGaps, voltage, current, timeS, startTime, endTime, cellNum, cellLabel)
% extractResistanceValues - Calculate internal resistance from current pulses
%
% This function identifies high-current pulse segments and calculates DC
% resistance from the voltage drop during pulses using Ohm's law.
%
% Inputs:
%   timeWithGaps - Datetime array with timestamps (may contain NaT)
%   voltage      - Voltage array in Volts
%   current      - Current array in Amperes
%   timeS        - Time array in seconds (may contain NaN values)
%   startTime    - Start datetime for analysis range
%   endTime      - End datetime for analysis range
%   cellNum      - Cell identifier string for plot title
%   cellLabel    - (Optional) Descriptive label from test plan
%
% Outputs:
%   checkupResistanceTimeStamp - Datetime array of resistance measurement timestamps
%   checkupResistance_Ohm          - Array of measured DC resistance values (Ω)

if nargin < 8
    cellLabel = '';
end

fprintf('\nExtracting resistance values from current pulses...\n');
tic;  % Restart timer

% Select data within the specified datetime range
selectedIndices = (timeWithGaps >= startTime) & (timeWithGaps <= endTime);
selectedTime = timeWithGaps(selectedIndices);
selectedVoltage = voltage(selectedIndices);
selectedCurrent = current(selectedIndices);
selectedTimeS = timeS(selectedIndices);

% Identify high-current pulse segments
constantCurrentValue = -58;  % Target current in Amperes
tolerance = 0.4;             % Tolerance in Amperes
constantCurrentIndices = abs(selectedCurrent - constantCurrentValue) <= tolerance;
AverageLength = 5; %number of samples to average V and I

% Filter for pulse segments (30-300 data points, typically ~30s duration)
minSegmentLength = 30; % to be deleted
maxSegmentLength = 300; % to be deleted
minSegmentTime_s = 29;
maxSegementTime_s = 31;

% Find segments meeting length criteria
segments = findSegmentsMinMax(constantCurrentIndices, AverageLength, selectedTime, minSegmentTime_s,maxSegementTime_s);
fprintf('Found %d current pulse segments. (Elapsed: %.2f s)\n', length(segments), toc);
if isempty(segments)
    warning('no segments found')
    checkupResistance_OhmTimeStamp=[];
    checkupResistance_Ohm=[];
    checkupResistenceFEC=[];
    return
end

BatteryCapacity_Ah = 58;
FullEquivalentCycles = cumtrapz(selectedTimeS,abs(selectedCurrent))/BatteryCapacity_Ah/3600/2;

% Initialize figure for resistance analysis
figure('Units','normalized', 'OuterPosition',[0 0 0.5 1]); % Create a figure that takes up half the screen width


% Define line styles for plot variation
lineStyles = {'-', '--', ':', '-.'};

% Loop through each pulse segment and calculate resistance
for i = 1:length(segments)
    if contains(cellNum,'A3') || contains(cellNum,'A4')
        if i==1 % skip the first test of cell A3 and A4. 
            continue
        end
    end

    % Select line style for this iteration
    lineIdx = mod(i-1, length(lineStyles)) + 1;
    currentLineStyle = lineStyles{lineIdx};
    
    segmentIndices = segments{i};
    % Include one point before pulse to capture voltage drop
    segmentIndices = [segmentIndices(1)-1 segmentIndices];
    segmentVoltage = selectedVoltage(segmentIndices);
    segmentCurrent = selectedCurrent(segmentIndices);
    segmentTime = selectedTime(segmentIndices);
    segmentTimeS = selectedTimeS(segmentIndices);
    segmentTimeS = segmentTimeS - segmentTimeS(1);  % Normalize to start at 0

    % this fixes an error on the original data. While concatenating
    % datasets, an artificial delayed was introduced in some of these
    % test
    if segmentTimeS(AverageLength*2+2)-segmentTimeS(AverageLength*2+1)>2 
        samplingTime_S = segmentTimeS(3)-segmentTimeS(2);
        DeltaTime_s = segmentTimeS(AverageLength*2+2)-segmentTimeS(AverageLength*2+1);
        segmentTimeS(AverageLength*2+2:end) = segmentTimeS(AverageLength*2+2:end) - DeltaTime_s + samplingTime_S;
        warning('At time %s, the algorithm corrected a delay created by concatenating multiple files of the original test data',string(segmentTime(1)));
    end
    
    % Plot voltage response to pulse
    subplot(2,1,1)
    hold on;
    plot(segmentTimeS, segmentVoltage, ...
         'LineStyle', currentLineStyle, 'LineWidth', 1.5, ...
         'Color', [i/length(segments), 0, 1-i/length(segments)]);
    xlabel('Time [s]');
    ylabel('Voltage [V]');
    
    % Plot current pulse
    subplot(2,1,2)
    hold on;
    plot(segmentTimeS, segmentCurrent, ...
         'LineStyle', currentLineStyle, 'LineWidth', 1.5, ...
         'Color', [i/length(segments), 0, 1-i/length(segments)]);
    xlabel('Time [s]');
    ylabel('Current [A]');
    
    % Calculate DC resistance from ohm's law: R = ΔV / ΔI
    checkupResistance_OhmTimeStamp(i) = segmentTime(1);
    DeltaVoltage_V = mean(segmentVoltage(end-AverageLength:end)) - mean(segmentVoltage(1:AverageLength));
    DeltaCurrent_A = mean(segmentCurrent(end-AverageLength:end)) - mean(segmentCurrent(1:AverageLength));
    checkupResistance_Ohm(i) = (DeltaVoltage_V) / (DeltaCurrent_A);
    checkupResistenceFEC(i) = FullEquivalentCycles(segmentIndices(1));
end
if isempty(cellLabel)
    sgtitle(['30s Resistance Analysis - V Response to I Pulses ' cellNum],'interpreter','none');
else
    sgtitle(['30s Resistance Analysis - V Response to I Pulses ' cellNum ' - ' cellLabel],'interpreter','none');
end
lgd = legend(string(checkupResistance_OhmTimeStamp));
lgd.Location = 'best';
fprintf('Resistance extraction complete. (Elapsed: %.2f s)\n', toc);

% Remove NaT entries from output arrays
validIdx = ~isnat(checkupResistance_OhmTimeStamp);
checkupResistance_OhmTimeStamp = checkupResistance_OhmTimeStamp(validIdx);
checkupResistance_Ohm = checkupResistance_Ohm(validIdx);
checkupResistenceFEC = checkupResistenceFEC(validIdx);

end

function segments = findSegmentsMinMax(indices, AverageLength, selectedTime, minDuration_s,maxDuration_S)
    % Find continuous segments where indices are true, with min and max length
    %
    % Inputs:
    %   indices   - Logical array indicating which points meet criteria
    %   minLength - Minimum number of consecutive true values
    %   maxLength - Maximum number of consecutive true values
    %
    % Outputs:
    %   segments  - Cell array where each cell contains index ranges
    
    segments = {};
    startIdx = find(indices, 1, 'first');
    
    while ~isempty(startIdx)
        % Find where the segment ends
        endIdx = find(~indices(startIdx:end), 1, 'first') + startIdx - 2;
        if isempty(endIdx)
            endIdx = length(indices);
        end
        
        % Only keep segments within length bounds
        segmentLength = endIdx - startIdx + 1;

        Duration_s = max(selectedTime(startIdx:endIdx))-min(selectedTime(startIdx:endIdx));

          if Duration_s>=seconds(minDuration_s)
              if Duration_s<=seconds(maxDuration_S)
                   segments{end+1} = startIdx-AverageLength*2:endIdx;   
              end
          end
%         if segmentLength >= minLength && Duration_s>seconds(minDuration_s)
%             if segmentLength <= maxLength
%                 segments{end+1} = startIdx:endIdx;         
%             else
%                 endIdxTmp = startIdx + maxLength;
%                 segments{end+1} = startIdx:endIdxTmp; 
%             end
%         end
        
        % Find next segment start
        startIdx = find(indices(endIdx+1:end), 1, 'first') + endIdx;
    end
end
