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