%% MakeManuscriptFigures.m
% Summary: Runs the MATLAB generators needed to reproduce the code-produced
%          manuscript figures. Each stage is isolated, reports PASS or FAIL,
%          and leaves generated outputs in the generator's R-022 directory.
%
% Usage: Run from MATLAB or with matlab -batch "run('MakeManuscriptFigures.m')".
%        The driver continues after a failed stage so the final summary shows
%        which figures were generated and which still need attention.
%
% Outputs: A terminal summary for all stages. Figure and CSV outputs are written
%          by the called generator scripts, not by this driver.
%
% Authors: Feye Hoekstra, GitHub Copilot.
% Dependency files: matlab_scripts/PlotCharacterizationData_Cell15.m,
%                   matlab_scripts/PlotReferencePerformanceCycleFigure_Cell68.m,
%                   matlab_scripts/PlotLiStrippingMethods_Cell35.m,
%                   matlab_scripts/extractOCPLines.m,
%                   matlab_scripts/PlotCharacterizationResults.m,
%                   matlab_scripts/ExtractAgeingData.m,
%                   matlab_scripts/PlotEISData.m,
%                   matlab_scripts/PlotAgeingCombinedOverview.m,
%                   matlab_scripts/PlotCellSummary.m,
%                   Functions/getFigureOutputDir.m.
% Last documented: 2026-09-03

thisDir = fileparts(mfilename('fullpath'));
functionsDir = fullfile(thisDir, '..', '..', 'Functions');
if ~exist(functionsDir, 'dir')
    functionsDir = fullfile(thisDir, '..', 'Functions');
end
if exist(functionsDir, 'dir')
    addpath(functionsDir);
else
    error('Shared Functions folder not found from %s.', thisDir);
end

% Own R-022 folder that collects every manuscript figure this driver produces.
manuscriptDir = getFigureOutputDir('MakeManuscriptFigures');
figuresMatlabRoot = fileparts(manuscriptDir);

% Heavy all-cell coverage stages (ExtractAgeingData, PlotEISData) run LAST so the
% single manuscript figures are produced and collected first during an overnight run.
stageNames = { ...
    'characterization_combined (PlotCharacterizationData_Cell15)'; ...
    'ReferencePerformanceCycle (PlotReferencePerformanceCycleFigure_Cell68)'; ...
    'LiStrippingMethods_a/_b (PlotLiStrippingMethods_Cell35)'; ...
    'OCP Anode/Cathode (extractOCPLines)'; ...
    'CharacterizationResults Cell_4'; ...
    'CharacterizationResults Cell_6'; ...
    'CharacterizationResults Cell_15'; ...
    'Calendar/CyclicAgeing (PlotAgeingCombinedOverview)'; ...
    'Cell summary Cell_35 (PlotCellSummary)'; ...
    'All cyclic/calendar cell overviews (ExtractAgeingData)'; ...
    'All ageing EIS diagrams (PlotEISData)'};

% Generator output stem for each stage; '' skips consolidation for the heavy
% all-cell coverage stages (they write hundreds of per-cell diagnostics, not
% single manuscript figures).
stageStems = { ...
    'PlotCharacterizationData_Cell15'; ...
    'PlotReferencePerformanceCycleFigure_Cell68'; ...
    'PlotLiStrippingMethods_Cell35'; ...
    'extractOCPLines'; ...
    'PlotCharacterizationResults'; ...
    'PlotCharacterizationResults'; ...
    'PlotCharacterizationResults'; ...
    'PlotAgeingCombinedOverview'; ...
    'PlotCellSummary'; ...
    ''; ...
    ''};

nStage = numel(stageNames);
stageOk = false(nStage, 1);
for stageIdx = 1:nStage
    fprintf('\n[MakeManuscriptFigures] === Stage %d/%d: %s ===\n', ...
        stageIdx, nStage, stageNames{stageIdx});
    tStageStart = now; %#ok<TNOW1> % serial date number, matches dir().datenum
    try
        switch stageIdx
            case 1, runStage(thisDir, 'PlotCharacterizationData_Cell15.m');
            case 2, runStage(thisDir, 'PlotReferencePerformanceCycleFigure_Cell68.m');
            case 3, runStage(thisDir, 'PlotLiStrippingMethods_Cell35.m');
            case 4, runStage(thisDir, 'extractOCPLines.m');
            case 5, runCharacterizationResults(thisDir, 'Cell_4');
            case 6, runCharacterizationResults(thisDir, 'Cell_6');
            case 7, runCharacterizationResults(thisDir, 'Cell_15');
            case 8, runStage(thisDir, 'PlotAgeingCombinedOverview.m');
            case 9, runCellSummary(thisDir, 'Cell_35');
            case 10, runAllCellOverviews(thisDir);
            case 11, runAllCellEis(thisDir);
        end
        stageOk(stageIdx) = true;
        if ~isempty(stageStems{stageIdx})
            consolidateStage(manuscriptDir, figuresMatlabRoot, stageStems{stageIdx}, tStageStart);
        end
        fprintf('[MakeManuscriptFigures] PASS: %s\n', stageNames{stageIdx});
    catch err
        fprintf(2, '[MakeManuscriptFigures] FAIL: %s\n    %s\n', ...
            stageNames{stageIdx}, err.message);
    end
    close all;
    % Recover driver state clobbered by the generator scripts' 'clear' calls:
    % runStage isolates them in a function workspace, so nothing to restore.
end

fprintf('\n[MakeManuscriptFigures] ======= Summary =======\n');
for stageIdx = 1:nStage
    if stageOk(stageIdx); status = 'PASS'; else; status = 'FAIL'; end
    fprintf('  %-4s %s\n', status, stageNames{stageIdx});
end
fprintf('[MakeManuscriptFigures] %d/%d stages passed. Manuscript figures collected in %s\n', ...
    sum(stageOk), nStage, manuscriptDir);

%% Local functions (each gives the generator script a disposable workspace)
function consolidateStage(manuscriptDir, figuresRoot, stem, tStart)
% Copy the PDF/PNG files the stage's generator wrote (mtime >= tStart) into the
% MakeManuscriptFigures folder so every manuscript figure lives in one place.
srcDir = fullfile(figuresRoot, stem);
if ~exist(srcDir, 'dir'); return; end
files = [dir(fullfile(srcDir, '*.pdf')); dir(fullfile(srcDir, '*.png'))];
for k = 1:numel(files)
    if files(k).datenum + 1e-6 >= tStart
        try
            copyfile(fullfile(srcDir, files(k).name), fullfile(manuscriptDir, files(k).name));
        catch copyErr
            fprintf(2, '[MakeManuscriptFigures] WARN copy %s: %s\n', ...
                files(k).name, copyErr.message);
        end
    end
end
end

function runStage(thisDir, scriptName)
run(fullfile(thisDir, scriptName));
end

function runCharacterizationResults(thisDir, cellId)
% Runs PlotCharacterizationResults.m for one characterization cell via its
% cellNumOverride hook (outputs are cell-tagged, so runs do not overwrite).
cellNumOverride = cellId;  %#ok<NASGU> % consumed by the script's guard block
run(fullfile(thisDir, 'PlotCharacterizationResults.m'));
end

function runCellSummary(thisDir, cellId)
% Run the manuscript's selected example-cell summary via the supported override.
cellNumOverride = cellId; %#ok<NASGU> % consumed by PlotCellSummary.m
run(fullfile(thisDir, 'PlotCellSummary.m'));
end

function runAllCellOverviews(thisDir)
% Regenerate each cyclic and calendar cell's overview diagnostics in the
% ExtractAgeingData R-022 folder without writing to the read-only data tree.
dataRoot = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
cyclicDir = fullfile(dataRoot, '4_Ageing', 'Cyclic_ageing_data');
calendarDir = fullfile(dataRoot, '4_Ageing', 'Calendar_ageing_data');
sourceFolders = {cyclicDir, calendarDir};
sourceLabels = {'cyclic', 'calendar'};
failures = {};

% Enumerate the actual dataset folders so Wave 8 covers every available cell.
for sourceIndex = 1:numel(sourceFolders)
    cellFolders = dir(fullfile(sourceFolders{sourceIndex}, 'Cell_*'));
    cellFolders = cellFolders([cellFolders.isdir]);
    for cellIndex = 1:numel(cellFolders)
        cellId = cellFolders(cellIndex).name;
        fprintf('[MakeManuscriptFigures] Overview %s %d/%d: %s\n', ...
            sourceLabels{sourceIndex}, cellIndex, numel(cellFolders), cellId);
        try
            runExtractAgeingData(thisDir, cellId, sourceFolders{sourceIndex});
            fprintf('[MakeManuscriptFigures] PASS overview: %s\n', cellId);
        catch err
            failures{end+1, 1} = sprintf('%s (%s): %s', ...
                cellId, sourceLabels{sourceIndex}, err.message); %#ok<AGROW>
            fprintf(2, '[MakeManuscriptFigures] FAIL overview: %s\n    %s\n', ...
                cellId, err.message);
        end
        close all;
    end
end

% Finish the full roster before surfacing failures to the enclosing stage.
if ~isempty(failures)
    error('MakeManuscriptFigures:AllCellOverviewsFailed', ...
        '%d all-cell overview run(s) failed:\n%s', numel(failures), strjoin(failures, '\n'));
end
end

function runExtractAgeingData(thisDir, cellId, sourceFolder)
% Supply the entry script's supported overrides from an isolated workspace.
cellNumOverride = cellId; %#ok<NASGU> % consumed by ExtractAgeingData.m
folderOverride = sourceFolder; %#ok<NASGU> % consumed by ExtractAgeingData.m
run(fullfile(thisDir, 'ExtractAgeingData.m'));
end

function runAllCellEis(thisDir)
% Regenerate every EIS input file from every available ageing life-stage folder.
dataRoot = '\\tsn.tno.nl\RA-Data\SV\sv-072952\BTS Data\NEXTBMS\ZenodoRoot';
eisRootDir = fullfile(dataRoot, '4_Ageing', 'EIS_data');
stageFolders = dir(fullfile(eisRootDir, '*_EIS'));
stageFolders = stageFolders([stageFolders.isdir]);
eisOutputDir = getFigureOutputDir('PlotEISData');
failures = {};

% One PlotEISData invocation per stage processes all of that stage's cell files.
for stageIndex = 1:numel(stageFolders)
    stageName = stageFolders(stageIndex).name;
    stageDir = fullfile(stageFolders(stageIndex).folder, stageName);
    inputFiles = dir(fullfile(stageDir, '*_impedanceData.csv'));
    fprintf('[MakeManuscriptFigures] EIS stage %d/%d: %s (%d files)\n', ...
        stageIndex, numel(stageFolders), stageName, numel(inputFiles));
    try
        runEisStage(thisDir, stageDir);

        % Confirm every source file produced a unique, stage-qualified R-022 PNG.
        for fileIndex = 1:numel(inputFiles)
            [~, fileBaseName] = fileparts(inputFiles(fileIndex).name);
            outputFile = fullfile(eisOutputDir, [stageName '_' fileBaseName '_NyquistPlot.png']);
            if ~exist(outputFile, 'file')
                error('MakeManuscriptFigures:MissingEisOutput', ...
                    'Expected EIS output was not created: %s', outputFile);
            end
        end
        fprintf('[MakeManuscriptFigures] PASS EIS stage: %s\n', stageName);
    catch err
        failures{end+1, 1} = sprintf('%s: %s', stageName, err.message); %#ok<AGROW>
        fprintf(2, '[MakeManuscriptFigures] FAIL EIS stage: %s\n    %s\n', ...
            stageName, err.message);
    end
    close all;
end

% Finish all stages before reporting any failed stage to the enclosing driver.
if ~isempty(failures)
    error('MakeManuscriptFigures:AllCellEisFailed', ...
        '%d EIS stage run(s) failed:\n%s', numel(failures), strjoin(failures, '\n'));
end
end

function runEisStage(thisDir, stageDir)
% Supply the supported stage override from an isolated workspace.
eisFolderOverride = stageDir; %#ok<NASGU> % consumed by PlotEISData.m
run(fullfile(thisDir, 'PlotEISData.m'));
end
