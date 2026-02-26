function label = getCellLabel(cellNum)
% getCellLabel - Generate a descriptive label for a battery cell based on the ageing test plan
%
% This function takes a cell identifier and returns a formatted label containing
% the temperature, charge C-rate, discharge C-rate, and test type.
%
% Input:
%   cellNum - Cell identifier string (e.g., 'A2.08_Cell_35' or 'A01_01')
%
% Output:
%   label - Formatted string with test conditions
%
% Author: GitHub Copilot
% Date: 2026-02-19

% Extract temperature group and channel from cellNum
% Supported formats:
%   - 'A01_01' -> tempGroup=1, channel=1
%   - 'A2.08_Cell_35' -> tempGroup=2, channel=8
%   - 'A02_02' -> tempGroup=2, channel=2

if contains(cellNum, '_Cell_')
    % Format: A2.08_Cell_35
    parts = split(cellNum, '_Cell_');
    conditionCode = parts{1};
    dotIdx = strfind(conditionCode, '.');
    tempGroup = str2double(conditionCode(2:dotIdx-1));
    channel = str2double(conditionCode(dotIdx+1:end));
else
    % Format: A01_01 or A02_02
    parts = split(cellNum, '_');
    conditionCode = parts{1};  % e.g., 'A01'
    % tempGroup is digits 2-3 (e.g., '01' -> 1)
    tempGroup = str2double(conditionCode(2:end));
    % Channel is the second part
    channel = str2double(parts{2});
end

% Define temperature based on group
switch tempGroup
    case 1
        temperature = '0°C';
    case 2
        temperature = '25°C';
    case 3
        temperature = '45°C';
    case 4
        temperature = '0-45°C';
    otherwise
        temperature = 'Unknown';
end

% Define test conditions based on temperature group and channel
% Data from ageing_test_plan.md
[testType, chargeRate, dischargeRate, effect] = getTestConditions(tempGroup, channel);

% Build label
if isempty(chargeRate) && isempty(dischargeRate)
    label = sprintf('%s, %s', temperature, testType);
elseif isempty(chargeRate)
    label = sprintf('%s, %s, Dch: %sC', temperature, testType, dischargeRate);
elseif isempty(dischargeRate)
    label = sprintf('%s, %s, Ch: %sC', temperature, testType, chargeRate);
else
    label = sprintf('%s, %s, Ch: %sC, Dch: %sC', temperature, testType, chargeRate, dischargeRate);
end

end

function [testType, chargeRate, dischargeRate, effect] = getTestConditions(tempGroup, channel)
% Returns test conditions based on temperature group and channel number

testType = '';
chargeRate = '';
dischargeRate = '';
effect = '';

switch tempGroup
    case 1 % 0°C
        switch channel
            case 1
                testType = 'Calendar'; chargeRate = ''; dischargeRate = '';
            case 2
                testType = 'CC cycle'; chargeRate = '0.5'; dischargeRate = '0.5';
            case 3
                testType = 'CC cycle'; chargeRate = '0.25'; dischargeRate = '0.5';
            case 4
                testType = 'CC cycle'; chargeRate = '0.75'; dischargeRate = '0.5';
            case 5
                testType = 'CC cycle'; chargeRate = '1'; dischargeRate = '0.5';
            case 6
                testType = 'CC cycle (var C-rate)'; chargeRate = '0.25-1'; dischargeRate = '0.5';
            case 7
                testType = 'EDF load cycle'; chargeRate = ''; dischargeRate = '';
            case 8
                testType = 'TOFAS drive cycle'; chargeRate = '0.5'; dischargeRate = '';
            otherwise
                testType = 'Unknown';
        end
        
    case 2 % 25°C
        switch channel
            case 1
                testType = 'Calendar'; chargeRate = ''; dischargeRate = '';
            case 2
                testType = 'CC cycle 100% DoD'; chargeRate = '0.5'; dischargeRate = '0.5';
            case 3
                testType = 'CC cycle 10% DoD'; chargeRate = '0.5'; dischargeRate = '0.5';
            case 4
                testType = 'CC cycle 40% DoD'; chargeRate = '0.5'; dischargeRate = '0.5';
            case 5
                testType = 'CC cycle 70% DoD'; chargeRate = '0.5'; dischargeRate = '0.5';
            case 6
                testType = 'CC cycle'; chargeRate = '1'; dischargeRate = '0.5';
            case 7
                testType = 'CC cycle'; chargeRate = '1.5'; dischargeRate = '0.5';
            case 8
                testType = 'CC cycle'; chargeRate = '2'; dischargeRate = '0.5';
            case 9
                testType = 'CC cycle'; chargeRate = '0.5'; dischargeRate = '1.5';
            case 10
                testType = 'EDF load cycle'; chargeRate = ''; dischargeRate = '';
            case 11
                testType = 'TOFAS drive cycle'; chargeRate = '0.5'; dischargeRate = '';
            otherwise
                testType = 'Unknown';
        end
        
    case 3 % 45°C
        switch channel
            case 1
                testType = 'Calendar 10% SoC'; chargeRate = ''; dischargeRate = '';
            case 2
                testType = 'Calendar 50% SoC'; chargeRate = ''; dischargeRate = '';
            case 3
                testType = 'Calendar 100% SoC'; chargeRate = ''; dischargeRate = '';
            case 4
                testType = 'CC cycle 100% DoD'; chargeRate = '0.5'; dischargeRate = '0.5';
            case 5
                testType = 'CC cycle 50% DoD @75% SoC'; chargeRate = '0.5'; dischargeRate = '0.5';
            case 6
                testType = 'CC cycle 50% DoD @25% SoC'; chargeRate = '0.5'; dischargeRate = '0.5';
            case 7
                testType = 'CC cycle 50% DoD @50% SoC'; chargeRate = '0.5'; dischargeRate = '0.5';
            case 8
                testType = 'CC cycle'; chargeRate = '1'; dischargeRate = '0.5';
            case 9
                testType = 'CC cycle 4.45V'; chargeRate = '1'; dischargeRate = '0.5';
            case 10
                testType = 'CCCV cycle 4.45V'; chargeRate = '1'; dischargeRate = '0.5';
            case 11
                testType = 'CC cycle'; chargeRate = '0.5'; dischargeRate = '1';
            case 12
                testType = 'CC cycle'; chargeRate = '1'; dischargeRate = '1';
            case 13
                testType = 'EDF load cycle'; chargeRate = ''; dischargeRate = '';
            case 14
                testType = 'TOFAS drive cycle'; chargeRate = '0.5'; dischargeRate = '';
            otherwise
                testType = 'Unknown';
        end
        
    case 4 % 0-45°C Dynamic
        switch channel
            case 1
                testType = 'CC cycle'; chargeRate = '0.5'; dischargeRate = '0.5';
            case 2
                testType = 'EDF load cycle'; chargeRate = ''; dischargeRate = '';
            case 3
                testType = 'TOFAS drive cycle'; chargeRate = '0.5'; dischargeRate = '';
            case 4
                testType = 'Mixed TOFAS/EDF'; chargeRate = '0.5'; dischargeRate = '';
            case 5
                testType = 'TOFAS+EDF'; chargeRate = '0.5'; dischargeRate = '';
            otherwise
                testType = 'Unknown';
        end
        
    otherwise
        testType = 'Unknown';
end

end
