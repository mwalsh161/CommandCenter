function watcher = FileSystemWatcher(name,varargin)
%FileSystemWatcher Wrapper to System.IO.FileSystemWatcher
%   Helps prevent memory leak where MATLAB does not actually delete
%   System.IO.FileSystemWatcher
%   FileSystemWatcher(name,varargin)
%    -> System.IO.FileSystemWatcher(varargin{:})

assert(~isempty(name),'Must provide nonempty name.')
try % Test struct here before making a new watcher later
    test.(name) = NaN; %#ok<STRNU>
catch err
    if strcmp(err.identifier,'MATLAB:AddField:InvalidFieldName')
        error('name must satisfy rules for a valid MATLAB struct field')
    else
        rethrow(err)
    end
end

root_userdata = get(0,'userdata');
try
    watcher = root_userdata.filesystemwatcher.(name);
    if ~isvalid(watcher)
        watcher = makeNew(name,root_userdata,varargin{:});
    elseif ~isempty(varargin)
        warning('varargin ignored, because existing FileSystemWatcher found with name "%s"',name)
    end
catch err
    if ~strcmp(err.identifier,'MATLAB:nonExistentField') && ~strcmp(err.identifier,'MATLAB:structRefFromNonStruct')
        rethrow(err)
    end
    watcher = makeNew(name,root_userdata,varargin{:});
end
end

function watcher = makeNew(name,root_userdata,varargin)
    % Note, root_userdata necessary to not overwrite existing ones
    watcher = System.IO.FileSystemWatcher(varargin{:});
    root_userdata.filesystemwatcher.(name) = watcher;
    set(0,'userdata',root_userdata);
end