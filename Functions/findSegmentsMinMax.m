function segments = findSegmentsMinMax(indices, minLength, maxLength)
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
        if segmentLength >= minLength && segmentLength <= maxLength
            segments{end+1} = startIdx-1:endIdx+1;
        end
        
        % Find next segment start
        startIdx = find(indices(endIdx+1:end), 1, 'first') + endIdx;
    end
end