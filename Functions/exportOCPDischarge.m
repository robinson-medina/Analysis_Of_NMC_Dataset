function ocpCsvPath = exportOCPDischarge(savePath, cellNum, CheckUpSoC, CheckUpOCV_V, checkupCapacity_Ah, checkupCapacityTimeStamp)
% exportOCPDischarge - Export flattened OCP discharge data to CSV
%
% Creates one CSV with columns:
%   1) CheckUpSoC
%   2) CheckUpOCV_V
%   3) CheckupCapacity_Ah (repeated to match SoC/OCV points per checkup)
%   4) CheckupCapacityTimeStamp (repeated to match SoC/OCV points per checkup)
%
% Filename format:
%   OCPDis_<cellNum>.csv

ocpSocAll = [];
ocpVAll = [];
ocpCapAll = [];
ocpTsAll = NaT(0,1);

numCheckups = min([numel(CheckUpSoC), numel(CheckUpOCV_V), numel(checkupCapacity_Ah), numel(checkupCapacityTimeStamp)]);
for checkupIdx = 1:numCheckups
    socVec = CheckUpSoC{checkupIdx};
    ocvVec = CheckUpOCV_V{checkupIdx};
    if isempty(socVec) || isempty(ocvVec)
        continue;
    end

    nPoints = min(numel(socVec), numel(ocvVec));
    ocpSocAll = [ocpSocAll; socVec(1:nPoints).'];
    ocpVAll = [ocpVAll; ocvVec(1:nPoints).'];
    ocpCapAll = [ocpCapAll; repmat(checkupCapacity_Ah(checkupIdx), nPoints, 1)];
    ocpTsAll = [ocpTsAll; repmat(checkupCapacityTimeStamp(checkupIdx), nPoints, 1)];
end

safeCellNum = regexprep(cellNum, '[^A-Za-z0-9_-]', '_');
ocpCsvName = ['OCPDis_' safeCellNum '.csv'];
ocpCsvPath = fullfile(savePath, ocpCsvName);

if ~isempty(ocpSocAll)
    ocpTable = table(ocpSocAll, ocpVAll, ocpCapAll, ocpTsAll, ...
        'VariableNames', {'CheckUpSoC', 'CheckUpOCV_V', 'CheckupCapacity_Ah', 'CheckupCapacityTimeStamp'});
    writetable(ocpTable, ocpCsvPath);
    fprintf('OCP discharge data saved to: %s\n', ocpCsvPath);
else
    fprintf('No OCP discharge data available to export for %s\n', cellNum);
end

end
