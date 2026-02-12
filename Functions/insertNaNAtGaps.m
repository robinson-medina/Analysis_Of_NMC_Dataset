function [timeWithGaps, timeS, voltage, current, cellTemp, chamberTemp] = ...
    insertNaNAtGaps(timeYYMMDD, dwellTimeS, voltageV, currentA, cellTempC, chamberTempC)
% insertNaNAtGaps - Insert NaN values at data gaps
%
% This function detects and inserts NaN values at data gaps to prevent
% continuous lines in plots across discontinuous data segments.
%
% Inputs:
%   timeYYMMDD   - Datetime array of timestamps
%   dwellTimeS   - Dwell time in seconds
%   voltageV     - Cell voltage in Volts
%   currentA     - Cell current in Amperes
%   cellTempC    - Cell surface temperature in Celsius
%   chamberTempC - Chamber ambient temperature in Celsius
%
% Outputs:
%   timeWithGaps - Datetime array with NaN inserted at gaps
%   timeS        - Time in seconds with NaN at gaps
%   voltage      - Voltage with NaN at gaps
%   current      - Current with NaN at gaps
%   cellTemp     - Cell temperature with NaN at gaps
%   chamberTemp  - Chamber temperature with NaN at gaps

fprintf('Detecting and processing data gaps...\n');
tic;  % Restart timer

% Calculate the time differences between consecutive data points
timeDiff = diff(timeYYMMDD);

% Find indices where the gap is longer than 1 minute
gapIndices = find(timeDiff > minutes(1));

% Find periods where current is zero for certain amount of samples and voltage lower than threshold
VoltageThreshold = 3.3; % minimum voltage with zero current
RestSamples = 60; % minimum number of samples to detect with 0 current
CountTimeSamples=0;CurrentState=1;
for i=1:length(dwellTimeS)
    if (currentA(i)==0) && voltageV(i)<VoltageThreshold
        CountTimeSamples=CountTimeSamples+1;
        if (CountTimeSamples>=RestSamples) && CurrentState
            gapIndices = [gapIndices;i];
            CurrentState = 0;
        end
    else
        CountTimeSamples=0;CurrentState=1;
    end
end
gapIndices = sort(gapIndices);
fprintf('Found %d data gaps. Inserting NaN values...\n', length(gapIndices));
tic;  % Restart timer

% Pre-allocate arrays with final size (much faster than repeated concatenation)
numGaps = length(gapIndices);
originalLength = length(timeYYMMDD);
finalLength = originalLength + numGaps;

% Pre-allocate with appropriate types
timeWithGaps = NaT(finalLength, 1);
dwellTimeWithGaps = NaN(finalLength, 1);
voltageWithGaps = NaN(finalLength, 1);
currentWithGaps = NaN(finalLength, 1);
cellTempWithGaps = NaN(finalLength, 1);
chamberTempWithGaps = NaN(finalLength, 1);

% Fill in the data with gaps
sourceIdx = 1;
destIdx = 1;
for i = 1:numGaps
    gapPos = gapIndices(i);
    % Copy data up to the gap
    chunkSize = gapPos - sourceIdx + 1;
    if chunkSize > 0
        timeWithGaps(destIdx:destIdx+chunkSize-1) = timeYYMMDD(sourceIdx:gapPos);
        dwellTimeWithGaps(destIdx:destIdx+chunkSize-1) = dwellTimeS(sourceIdx:gapPos);
        voltageWithGaps(destIdx:destIdx+chunkSize-1) = voltageV(sourceIdx:gapPos);
        currentWithGaps(destIdx:destIdx+chunkSize-1) = currentA(sourceIdx:gapPos);
        cellTempWithGaps(destIdx:destIdx+chunkSize-1) = cellTempC(sourceIdx:gapPos);
        chamberTempWithGaps(destIdx:destIdx+chunkSize-1) = chamberTempC(sourceIdx:gapPos);
        destIdx = destIdx + chunkSize;
    end
    % NaN is already in place from pre-allocation
    destIdx = destIdx + 1;  % Skip the NaN position
    sourceIdx = gapPos + 1;
    
    % Show progress every 5%
    if mod(i, max(1, round(numGaps * 0.05))) == 0
        percentComplete = round(i / numGaps * 100);
        fprintf('  Progress: %d%% (%d/%d gaps processed)\n', percentComplete, i, numGaps);
    end
end

% Copy remaining data after last gap
if sourceIdx <= originalLength
    remainingSize = originalLength - sourceIdx + 1;
    timeWithGaps(destIdx:destIdx+remainingSize-1) = timeYYMMDD(sourceIdx:end);
    dwellTimeWithGaps(destIdx:destIdx+remainingSize-1) = dwellTimeS(sourceIdx:end);
    voltageWithGaps(destIdx:destIdx+remainingSize-1) = voltageV(sourceIdx:end);
    currentWithGaps(destIdx:destIdx+remainingSize-1) = currentA(sourceIdx:end);
    cellTempWithGaps(destIdx:destIdx+remainingSize-1) = cellTempC(sourceIdx:end);
    chamberTempWithGaps(destIdx:destIdx+remainingSize-1) = chamberTempC(sourceIdx:end);
end

fprintf('NaN insertion complete. (Elapsed: %.2f s)\n', toc);

% Assign to output variable names
timeS = dwellTimeWithGaps;
voltage = voltageWithGaps;
current = currentWithGaps;
cellTemp = cellTempWithGaps;
chamberTemp = chamberTempWithGaps;

end
