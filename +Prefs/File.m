classdef File < Base.pref
    %File allows selection of a file location on the system.
    % Note, if relative_to is specified (and not empty) all values will be
    % set relative to the path specified unless they are not relative.
    % If it is unset, the value must be a full path name.
    
    properties(Hidden)
        default = '';
        ui = Prefs.Inputs.ButtonField;
        last_choice = ''; % Used in uigetfile
    end
    properties
        % Note, this will error immediately unless default value supplied
        allow_empty = {true, @(a)validateattributes(a,{'logical'},{'scalar'})};
        must_exist = {true, @(a)validateattributes(a,{'logical'},{'scalar'})};
        relative_to = {'', @(a)validateattributes(a,{'char'},{})};
    end
    
    methods(Static)
        function tf = relative(path)
            if ispc % All full paths are specified with a single drive letter followed by ':'
                tf = ~(length(path)>1 && path(2) == ':');
            else % All full paths are 
                tf = ~(~isempty(path) && path(1) == '/');
            end
        end
    end
    methods
        function obj = File(varargin)
            obj = obj@Base.pref(varargin{:});
            obj.ui.empty_string = 'Select File';
        end
        function val = clean(obj,val)
            if ~isempty(obj.relative_to) && obj.relative(val)
                val = fullfile(obj.relative_to,val);
            end
        end
        function validate(obj,val)
            validateattributes(val,{'char','string'},{'scalartext'})
            if ~obj.allow_empty
                assert(~isempty(val),'Cannot set an empty string.')
            end
            if ~isempty(val)
                assert(~obj.relative(val),sprintf(['Cannot specify relative paths: %s\n ',...
                    'Did you forget to set the Prefs.File.relative_to?'],val));
                if obj.must_exist
                    assert(exist(val,'file'),sprintf('File "%s" cannot be found.',val))
                end
            end
        end

        function obj = link_callback(obj,callback)
            link_callback@Base.pref(obj,obj.select_file);
        end
    end

    methods(Hidden) % Callback
        function select_file(obj,hObj,eventdata)
            [file,path] = uigetfile(obj.filter,obj.empty_string);
            assert(~isequal(file,0),'No file selected.')
            val = fullfile(path,file);
            obj.last_choice = val; % Might not work
            hObj.UserData = val;
        end
    end
    
end