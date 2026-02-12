function segments = findCheckupSegments(timeWithGaps, voltage, current, timeS, startTime, endTime)
% findCheckupSegments - Find constant-current discharge segments for checkup analysis
%
% This function identifies constant-current discharge segments within a
% specified time range for battery checkup capacity analysis.
%
% Inputs:
%   timeWithGaps - Datetime array with timestamps (may contain NaT)
%   voltage      - Voltage array in Volts
%   current      - Current array in Amperes
%   timeS        - Time array in seconds (may contain NaN values)
%   startTime    - Start datetime for analysis range
%   endTime      - End datetime for analysis range
%
% Outputs:
%   segments     - Cell array where each cell contains index ranges of
%                  constant-current discharge segments

fprintf('\nStarting checkup capacity analysis...\n');
tic;  % Restart timer

% Select data within the specified datetime range
selectedIndices = (timeWithGaps >= startTime) & (timeWithGaps <= endTime);
selectedTime = timeWithGaps(selectedIndices);
selectedVoltage = voltage(selectedIndices);
selectedCurrent = current(selectedIndices);
selectedTimeS = timeS(selectedIndices);

% Identify segments where current is constant (checkup discharge)
% Target current: -1.16 A (58/50), tolerance: ±0.1 A
constantCurrentValue = -58/50;
tolerance = 0.1;
constantCurrentIndices = abs(selectedCurrent - constantCurrentValue) <= tolerance;

% Segment filtering parameters
minSegmentLength = 2000;  % Minimum data points for valid checkup

% Find constant-current segments that meet minimum length requirement
segments = findSegments(constantCurrentIndices, minSegmentLength);
fprintf('Found %d checkup discharge segments. (Elapsed: %.2f s)\n', length(segments), toc);

end

function segments = findSegments(indices, minLength)
    % Find continuous segments where indices are true, with minimum length
    %
    % Inputs:
    %   indices   - Logical array indicating which points meet criteria
    %   minLength - Minimum number of consecutive true values to form a segment
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
        
        % Only keep segments that meet minimum length requirement
        if (endIdx - startIdx + 1) >= minLength
            segments{end+1} = startIdx:endIdx;
        end
        
        % Find next segment start
        startIdx = find(indices(endIdx+1:end), 1, 'first') + endIdx;
    end
end
