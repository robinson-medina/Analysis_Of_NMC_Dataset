function cumulative_integral = computeCumulativeCharge(timeS, current)
% computeCumulativeCharge - Calculate cumulative charge integral
%
% This function calculates the cumulative charge (capacity) by integrating
% current over time. It processes each continuous segment separately,
% splitting by NaN gaps to maintain data integrity.
%
% Inputs:
%   timeS   - Time array in seconds (may contain NaN values to mark gaps)
%   current - Current array in Amperes (corresponding to timeS)
%
% Outputs:
%   cumulative_integral - Cumulative charge in Ampere-seconds (As)
%                         Contains NaN values at gap positions

fprintf('Computing cumulative charge integral...\n');
tic;  % Restart timer

cumulative_integral = [];
start_idx = 1;

% Loop through the time signal to find segments
for i = 2:length(timeS)
    if isnan(timeS(i))
        % Process the segment before this NaN

        current_segment = current(start_idx:i-1);      
        % Compute the integral using trapezoidal rule
        if start_idx < i-1
            segment_integral = cumtrapz(timeS(start_idx:i-1), current_segment);
        else
            segment_integral = 0;
        end
        
%         Append the segment integral with NaN separator
        cumulative_integral = [cumulative_integral; NaN; segment_integral];

        
        % Reset the start index for the next segment
        start_idx = i+1;
    end
end

% Handle the last segment (after final NaN or if no NaN exists)
if start_idx==length(current)
    cumulative_integral = [cumulative_integral; 0];
else
    current_segment = current(start_idx:end);
    segment_integral = cumtrapz(timeS(start_idx:end), current_segment);
    cumulative_integral = [cumulative_integral; segment_integral];
end
fprintf('Cumulative charge calculation complete. (Elapsed: %.2f s)\n', toc);

end
