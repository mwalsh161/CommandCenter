classdef File < Base.Pref
    %File allows selection of a file location on the system.
    % Note, if relative_to is specified (and not empty) all values will be
    % set relative to the path specified unless they are not relative.
    % If it is unset, the value must be a full path name.
    %
    % Filter_spec is passed directly to uigetfile
    %
    % This will remember last folder accessed while the UI exists (resets when refreshed)
    %
    % To remove a file, you must hit cancel and proceed with the questdlg as desired.

    properties (Hidden)
        default = '';
        ui = Prefs.Inputs.FileField;
        user_callback;
    end
    properties
        % Note, this will error immediately unless default value supplied
        allow_empty = {true, @(a)validateattributes(a,{'logical'},{'scalar'})};
        must_exist = {true, @(a)validateattributes(a,{'logical'},{'scalar'})};
        relative_to = {'', @(a)validateattributes(a,{'char'},{})};
        filter_spec = {'*.*', @(a)validateattributes(a,{'char'},{'vector'})};
    end

    methods (Static)
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
            obj = obj@Base.Pref(varargin{:});
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
                    assert(logical(exist(val,'file')),sprintf('File "%s" cannot be found.',val))
                end
            end
        end

        function obj = link_callback(obj,callback)
            obj.user_callback = callback;
            obj = link_callback@Base.Pref(obj,@obj.select_file);
        end
    end

    methods (Hidden) % Callback
        function select_file(obj,hObj,eventdata,~)
            if ~isfield(hObj.UserData,'last_choice')
                if ~isstruct(hObj.UserData)
                    hObj.UserData = struct();
                end
                hObj.UserData.last_choice = obj.value;
            end
            name = sprintf('Select File: %s',obj.name);
            [file,path] = uigetfile(obj.filter_spec,name,hObj.UserData.last_choice);
            if isequal(file,0) % No file selected; quitely abort
                if ~isempty(obj.value)
                    answer = questdlg('Remove current file?',name,'Yes','No','No');
                    if strcmp(answer,'Yes') % Proceed and remove value
                        file = '';
                        path = '';
                    else % Chose not to remove value, cancel silently
                        return
                    end
                else % Already empty, so cancel silently
                    return
                end
            end
            val = fullfile(path,file);
            hObj.UserData.last_choice = val;
            hObj.UserData.value = val;
            hObj.TooltipString = val;
            % Now, user's callback
            if ~isempty(obj.user_callback)
                switch class(obj.user_callback)
                    case 'cell'
                        obj.user_callback{1}(hObj,...
                        eventdata,obj.user_callback{2:end},obj);
                    case 'function_handle'
                        obj.user_callback(hObj,eventdata,obj);
                end
            end
        end
    end

end
