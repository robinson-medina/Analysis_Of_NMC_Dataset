function outputDir = getFigureOutputDir(scriptStem)
% Summary: Resolve and create the R-022 MATLAB figure-output directory.
% Author: GitHub Copilot
% Date: 2026-08-25
% Inputs: scriptStem - Extensionless entry-script path relative to matlab_scripts.
% Outputs: outputDir - Existing MATLAB figure-output directory for the script.

% Validate that callers provide exactly one character-vector or string script identifier.
if ~(ischar(scriptStem) || (isstring(scriptStem) && isscalar(scriptStem)))
    error('getFigureOutputDir:InvalidScriptStem', ...
        'scriptStem must be a character vector or scalar string.');
end

% Convert to a character vector so the validation and path APIs behave consistently in R2022a.
scriptStem = char(scriptStem);

% Normalize Windows separators so one validation path handles both separator styles.
scriptStem = strrep(scriptStem, '\', '/');

% Reject blank, absolute, and drive-qualified paths before they can escape the output root.
if isempty(scriptStem) || startsWith(scriptStem, '/') || ~isempty(regexp(scriptStem, '^[A-Za-z]:/', 'once'))
    error('getFigureOutputDir:InvalidScriptStem', ...
        'scriptStem must be a non-empty path relative to matlab_scripts.');
end

% Split the relative identifier into path segments for independent validation.
pathParts = strsplit(scriptStem, '/');

% Permit only MATLAB-style entry-script identifiers and reject traversal or empty segments.
for partIndex = 1:numel(pathParts)
    pathPart = pathParts{partIndex};
    if isempty(pathPart) || strcmp(pathPart, '.') || strcmp(pathPart, '..') || ...
            isempty(regexp(pathPart, '^[A-Za-z][A-Za-z0-9_]*$', 'once'))
        error('getFigureOutputDir:InvalidScriptStem', ...
            'scriptStem contains an invalid path segment: %s.', pathPart);
    end
end

% Locate the shared Functions directory from this helper rather than relying on the caller cwd.
functionsDir = fileparts(mfilename('fullpath'));

% Resolve the project root explicitly so the returned path contains no literal parent segment.
projectDir = fileparts(functionsDir);

% In the staging repository, Functions/ is a sibling of JournalScripts/. In the
% public repository, Functions/ is copied next to matlab_scripts/ and there is
% no JournalScripts/ folder; default public-run output therefore goes to a temp
% folder unless NEXTBMS_FIGURE_ROOT explicitly points elsewhere.
journalScriptsDir = fullfile(projectDir, 'JournalScripts');
if exist(journalScriptsDir, 'dir')
    outputRoot = fullfile(journalScriptsDir, 'Figures', 'matlab');
else
    outputBase = getenv('NEXTBMS_FIGURE_ROOT');
    if isempty(outputBase)
        outputBase = fullfile(tempdir, 'NEXTBMS_PublicRepositoryFigures');
    end
    outputRoot = fullfile(outputBase, 'matlab');
end

% Append the MATLAB language partition and the validated entry-script path.
outputDir = fullfile(outputRoot, pathParts{:});

% Create the destination on first use so individual writers need no directory plumbing.
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end
end