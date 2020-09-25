function [ prefix,classes,packages ] = GetClasses( varargin )
%GETCLASSES Returns all .m files and @folders in a directory.
target = fullfile(varargin{:});
files=what(target);
if ~(~isempty(target) && target(1) == '/' || ... % unix fullpath
        length(target)>1 && target(2) == ':')    % windows fullpath
    %check to see if the target is in our current directory
    if any(arrayfun(@(d)strcmpi(fullfile(d.folder,d.name),target),dir))
        files(1) = []; %assume first entry is the present working directory  and is thus redundant
    end
end

assert(length(files) <= 1, sprintf('Did not find a single or empty match for %s - found %i', target, length(files)))

% Determine if we are in a package
parts = strsplit(files.path,filesep);
prefix = '';
for i = 1:numel(parts)
    % Build up fully qualified prefix if in package
    if numel(parts{i}) && parts{i}(1)=='+'
        prefix = [prefix parts{i}(2:end) '.']; %#ok<AGROW>
    end
end
classes = {};
packages = {};
if isempty(files)
    return
end
packages = files.packages;
% '.m' files can be classes, and by CommandCenter rules, should be here!
% files.classes refer explicitly to @folder style classes, we want both
for i = 1:numel(files.m)
    % Gp through filenames and strip off '.m' extention
    addto(files.m{i}(1:end-2))
end
for i = 1:numel(files.classes)
    % Go through classes
    addto(files.classes{i})
end

    function addto(class_str)
        % Ignore classes that have filenames ending with "_invisible"
        visible = ~Base.EndsWith(class_str,'_invisible');
        
        if visible
            classes{end+1} = class_str;
        end
    end
end
