% Get list of deepest level folders in InputFolder
function deepestFolders = getDeepestFolders(rootPath)
    deepestFolders = {};
    
    function findLeafFolders(currentPath)
        folderList = dir(currentPath);
        folderList = folderList([folderList.isdir]); % Keep only directories
        folderList = folderList(~ismember({folderList.name}, {'.', '..'})); % Remove '.' and '..' entries
        
        if isempty(folderList)
            % No subfolders found, this is a leaf folder
            deepestFolders{end+1} = currentPath;
        else
            % Has subfolders, recurse into each one
            for i = 1:length(folderList)
                subfolderPath = fullfile(currentPath, folderList(i).name);
                findLeafFolders(subfolderPath);
            end
        end
    end
    
    findLeafFolders(rootPath);
    deepestFolders = deepestFolders';
end