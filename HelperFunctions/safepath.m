function [fullpath] = safepath(varargin)
%SAFEPATH Never overwrite a filename
%   Appends the lowest unused integer to the end if necessary
fullpath = fullfile(varargin{:});
if ~exist(fullpath,'file')
    return
end
[path,name,ext] = fileparts(fullpath);
i = 0;
while true
    test = fullfile(path,[name num2str(i) ext]);
    if ~isfile(test)
        fullpath = test;
        return
    end
    i = i + 1;
end
end

