classdef Module < Base.Singleton & matlab.mixin.Heterogeneous
    %MODULE Abstract Class for Modules.
    %   Simply enforces required properties.
    %
    %   All module managers will look for an optional invisible property (must be constant).
    %   If this exists, and is set to true, it will not render it in the
    %   menus.
    %
    %   If there is a Constant property "visible" and it is set to false,
    %   this will prevent CommandCenter from displaying it.
    
    properties(Access=private)
        namespace                   % Namespace for saving prefs
        prop_listeners              % Keep track of preferences in the GUI to keep updated
        GUI_handle                  % Handle to uicontrolgroup panel
    end
    properties(Access=protected)
        logger                      % Handle to log object
        module_delete_listener      % Used in garbage collecting
    end
    properties(Abstract,Constant,Hidden)
        modules_package;
    end
    events
        update_settings % Listened to by CC to allow modules to request settings to be reloaded
    end
    
    methods(Access=private)
        function savePrefs(obj)
            % This method is called in the Module destructor (this file),
            % so the user doesn't need to worry about calling it.
            %
            % Saves any property in the obj.pref cell array
            
            % if namespace isn't set, means error in constructor
            if isempty(obj.namespace)
                return
            end
            assert(ischar(obj.namespace),'Namespace must be a string!')
            if isprop(obj,'prefs')
                for i = 1:numel(obj.prefs)
                    if ~ischar(obj.prefs{i})
                        warning('MODULE:save_prefs','Error on savePrefs (position %i): %s',i,'Must be a string!')
                        continue
                    end
                    try
                        val = obj.(obj.prefs{i});
                        if contains('Base.Module',superclasses(val))
                            temp = {};
                            for j = 1:length(val)
                                temp{end+1} = class(val(j));
                            end
                            val = temp;
                        end
                        setpref(obj.namespace,obj.prefs{i},val);
                    catch err
                        warning('MODULE:save_prefs','Error on savePrefs. Skipped pref ''%s'': %s',obj.prefs{i},err.message)
                    end
                end
            end
        end
    end
    methods
        function obj = Module
            % First get namespace
            obj.namespace = strrep(class(obj),'.','_');
            % Second, add to global appdata if app is available
            hObject = findall(0,'name','CommandCenter');
            if isempty(hObject)
                obj.logger = Base.Logger_console();
                return
            end
            mods = getappdata(hObject,'ALLmodules');
            obj.logger = getappdata(hObject,'logger');
            mods{end+1} = obj;
            setappdata(hObject,'ALLmodules',mods)
            obj.logger.log(['Initializing ' class(obj)])
            % Garbage collect for Base.Modules properties
            mc = metaclass(obj);
            mp = mc.PropertyList;
            for i = 1:length(mp)
                if mp(i).HasDefault && contains('Base.Module',superclasses(mp(i).DefaultValue))
                    addlistener(obj,mp(i).Name,'PostSet',@obj.module_garbage_collect);
                end
            end
            % Go through and re-construct deleted modules (note they can't
            % be private or protected) This is necessary because MATLAB
            % only builds default properties once per MATLAB session,
            % meaning re-instantiation might result with deleted props
            % Note: This will fail when using heterogeneous arrays, as the
            % superclass will not be able to determine the original class
            % type. One can get around this by instantaiting in the
            % constructor instead of as a DefaultValue
            mc = metaclass(obj);
            props = mc.PropertyList;
            props = props([props.HasDefault]);
            for i = 1:length(props)
                prop = props(i);
                val = prop.DefaultValue;
                if contains('Base.Module',superclasses(val))
                    for j = 1:length(val) % Could be an array
                        try % If we fail on any in the array, might as well give up since it wont work as expected anyway!
                            if ~isvalid(obj.(prop.Name)(j))
                                obj.(prop.Name)(j) = eval(sprintf('%s.instance',class(obj.(prop.Name)(j))));
                            end
                        catch err
                            msg = sprintf('Was not able to reinstantiate %s! Might need to restart MATLAB and report this error: %s',err.message);
                            obj.logger.log(msg,obj.logger.ERROR);
                            rethrow(err)
                        end
                    end
                end
            end
        end
        function module_clean(obj,hObj,prop)
            to_remove = false(size(obj.(prop)));
            for i = 1:length(obj.(prop)) % Heterogeneous list; cant do in one line
                if obj.(prop)(i) == hObj
                    to_remove(i) = true;
                end
            end
            obj.(prop)(to_remove) = [];
        end
        function module_garbage_collect(obj,hObj,~)
            % Reset lifetime listeners
            mods = obj.(hObj.Name);
            to_remove = false(size(mods));
            % Reset listeners (easiest to go through cleanly each time
            delete(obj.module_delete_listener);
            obj.module_delete_listener = [];
            for i = 1:length(mods)
                if isvalid(mods(i))
                    l = addlistener(mods(i),'ObjectBeingDestroyed',@(modH,~)obj.module_clean(modH,hObj.Name));
                    if isempty(obj.module_delete_listener)
                        obj.module_delete_listener = l;
                    else
                        obj.module_delete_listener(end+1) = l;
                    end
                else
                    to_remove(i) = true;
                end
            end
            obj.(hObj.Name)(to_remove) = []; % Remove if not valid
        end
        function datastruct = prefs2struct(obj,datastruct)
            if nargin < 2
                datastruct = struct();
            else
                assert(isstruct(datastruct),'First argument must be a struct!')
            end
            if isprop(obj,'prefs')
                assert(iscell(obj.prefs),'Property "prefs" must be a cell array')
                for i = 1:numel(obj.prefs)
                    if ~ischar(obj.prefs{i})
                        warning('MODULE:prefs2struct','Error on loadPrefs (position %i): %s',i,'Must be a string!')
                        continue
                    end
                    val = obj.(obj.prefs{i});
                    if contains('Base.Module',superclasses(val))
                        temps = struct('name',{},'prefs',{});
                        for j = 1:length(val)
                            temp.name = class(val(j));
                            temp.prefs = val(j).prefs2struct; % Recurse as necessary
                            temps(j) = temp;
                        end
                        val = temps;
                    end
                    datastruct.(obj.prefs{i}) = val;
                end
            else
                warning('MODULE:prefs2struct','No prefs defined for %s!',class(obj))
            end
        end
        function loadPrefs(obj)
            % loadPrefs is a useful method to load any saved prefs. Not
            % called by default, because order might matter to user.
            %
            % Loads prefs listed in obj.prefs cell array
            
            % if namespace isn't set, means error in constructor
            if isempty(obj.namespace)
                return
            end
            assert(ischar(obj.namespace),'Namespace must be a string!')
            if isprop(obj,'prefs')
                assert(iscell(obj.prefs),'Property "prefs" must be a cell array')
                disp('number of prefs:')
                disp(numel(obj.prefs))
                for i = 1:numel(obj.prefs)
                    disp(i)
                    if ~ischar(obj.prefs{i})
                        warning('MODULE:load_prefs','Error on loadPrefs (position %i): %s',i,'Must be a string!')
                        continue
                    end
                    if ispref(obj.namespace,obj.prefs{i})
                        pref = getpref(obj.namespace,obj.prefs{i});
                        try
                            mp = findprop(obj,obj.prefs{i});
                            if mp.HasDefault && contains('Base.Module',superclasses(mp.DefaultValue))
                                if isempty(pref)% Means it is the default value, and not set
                                    continue
                                end
                                disp('length of prefs:')
                                disp(length(pref))
                                for j = 1:length(pref)
                                    disp(j)
                                    temp(j) = eval(sprintf('%s.instance',pref{j})); % Grab instance(s) from string
                                end
                                pref = temp;
                            end
                            obj.(obj.prefs{i}) = pref;
                        catch err
                            warning('MODULE:load_prefs','Error on loadPrefs (%s): %s',obj.prefs{i},err.message)
                        end
                    end
                end
                disp('for loop successful')
            end
            disp('function returning')
        end
        function delete(obj)
            obj.savePrefs;
            delete(obj.prop_listeners);
            delete(obj.module_delete_listener);
            hObject = findall(0,'name','CommandCenter');
            if isempty(hObject)
                return
            end
            mods = getappdata(hObject,'ALLmodules');
            obj.logger = getappdata(hObject,'logger');
            pos = 0;
            for i = 1:numel(mods)
                if mods{i}==obj
                    pos = i;
                end
            end
            mods(pos) = [];
            setappdata(hObject,'ALLmodules',mods)
            obj.logger.log(['Destroyed ' class(obj)])
        end
        
        % Default inactive is nothing
        function task = inactive(obj)
            task = '';
        end
        
        % Adds custom settings to main GUI.
        %   This can be a simple settings button that opens a new GUI!
        %   Callbacks must be taken care of in the module.
        %   Module length can be adjusted, but not width.
        %   There are a few things to keep in mind when making these
        %   settings. If another program/command line alters a property in
        %   your settings, if you aren't careful, you will have an
        %   inconsitency and confusion will follow.
        %   See documentation for how the default settings works below
        function varargout = settings(obj,panelH)
            % varargout is useful if this is called from a subclass
            %     out = handle to uicontrolgroup
            
            all_props = properties(obj);
            % First, get all the prefs in order
            if ismember('show_prefs',all_props)
                prop_names = obj.show_prefs;
            elseif ismember('prefs',all_props)
                prop_names = obj.prefs;
            else % Nothing to do here
                if nargout > 0
                    varargout{1} = [];
                end
                return
            end
            % Go through properties and format input for uicontrolgroup.m
            % Also setup listeners on them
            props = struct('name',[],'display_name',[],'default',[],'options',[],'enable',{},'readonly',{});
            logicalException=false;
            for i = 1:numel(prop_names)
                prop_md = obj.findprop(prop_names{i}); % property metadata
                if isempty(prop_md)
                    warning('MODULE:settings','Ignored "%s"; could not find as a property. Case sensitive.',prop_names{i})
                    continue
                elseif prop_md.HasDefault && ~strcmp(class(prop_md.DefaultValue),class(obj.(prop_md.Name)))
                    % There are some exceptions
                    multChoiceException = iscell(prop_md.DefaultValue)||isa(prop_md.DefaultValue,'function_handle');
                    logicalException = islogical(prop_md.DefaultValue)&&(obj.(prop_md.Name)==0||obj.(prop_md.Name)==1);
                    moduleException = contains('Base.Module',superclasses(prop_md.DefaultValue));
                    if ~(multChoiceException||logicalException||moduleException)
                        warning('MODULE:settings','Ignored "%s"; Current property value does not match default value type.',prop_names{i})
                        continue
                    elseif logicalException
                        obj.(prop_md.Name) = logical(obj.(prop_md.Name));
                    end
                end
                props(end+1).name = prop_md.Name;
                props(end).display_name = strrep(prop_md.Name,'_',' ');
                if logicalException  % Default value in GUI (if not multiple choice)
                    props(end).default = logical(obj.(prop_md.Name));
                else
                    props(end).default = obj.(prop_md.Name);
                end
                % Multiple choice defined by cell array or fn handle
                if prop_md.HasDefault && ...
                        (iscell(prop_md.DefaultValue) || isa(prop_md.DefaultValue,'function_handle'))
                    % Get options through function or DefaultValue
                    if isa(prop_md.DefaultValue,'function_handle')
                        try
                            options = prop_md.DefaultValue();
                            assert(iscell(options),'Must return a cell array.') % This will get concatenated with below message
                        catch err
                            error('Function to get options for pref "%s" failed:\n%s',prop_md.Name,err.message)
                        end
                    else
                        options = prop_md.DefaultValue;     % Default value defines options
                    end
                    assert(~isempty(options),sprintf('There must be atleast one option for pref "%s"',prop_md.Name))
                    props(end).options = options;
                    % If hasn't been changed from default value, choose first option arbitrarily
                    if isequal(obj.(prop_md.Name),prop_md.DefaultValue)
                        obj.(prop_md.Name) = options{1};
                    end
                    try
                        % Can't use ismember here incase there is a numerical value in options
                        ind = find(cellfun(@(a)isequal(num2str(a),num2str(obj.(prop_md.Name))),options),1);
                        props(end).default = ind;
                    catch err
                        error('Could not find current value of "%s" in choice set.',prop_md.Name)
                    end
                end
                % See if this prop is in readonly
                props(end).readonly = false;
                props(end).enable = 'on';
                if ismember('readonly_prefs',all_props) && ismember(prop_md.Name,obj.readonly_prefs)
                    props(end).enable = 'off';
                    props(end).readonly = true;
                end
            end
            handles = Base.uicontrolgroup(props,@obj.defaultCallback,'parent',panelH);
            obj.GUI_handle = handles;
            if nargout > 0
                varargout{1} = handles;
            end
            % Setup listeners based on what actually got made by uicontrolgroup
            for i = 1:numel(handles.UserData.input_handles)
                prop_name = handles.UserData.input_handles(i).Tag;
                lisH = addlistener(obj,prop_name,'PostSet',@obj.GUIupdate);
                if i == 1
                    obj.prop_listeners = lisH;
                else
                    obj.prop_listeners(end+1) = lisH;
                end
            end
            % Clean up listeners when settings closed
            addlistener(handles,'ObjectBeingDestroyed',@(~,~)delete(obj.prop_listeners));
        end
        
        % This updates the GUI anytime a pref is changed by anything.
        % Called by the prop_listeners
        function GUIupdate(obj,hProp,~)
            val = obj.(hProp.Name);
            obj.GUI_handle.UserData.setValue(obj.GUI_handle,hProp.Name,val);
        end
        
        % This method is called when a pref is changed in the GUI from the
        % uicontrolgroup.  It does nothing more than set the property.
        % GUIupdate should be called from the PostSet triggered by this
        % method.
        function defaultCallback(obj,hObj,~)
            % hObj.UserData has two important fields:
            %   setValue(hPanel,name,val) which will be used after PostSet
            %   getValue(hObj) which is used here so we don't worry what
            %       type of uicontrol was used
            prop_name = hObj.Tag; % Convention in uicontrolgroup
            mp = findprop(obj,prop_name);
            try
                [new_val,abort,reset] = hObj.UserData.getValue(hObj,obj.(prop_name));
                if abort
                    return
                end
                if reset
                    if mp.HasDefault % Querying DefaultValue will error if HasDefault is false
                        obj.(prop_name) = mp.DefaultValue;
                    else
                        obj.(prop_name) = []; % Matlab assigns [] to properties without explicit default
                    end
                    return
                end
                if contains('Base.Module',superclasses(new_val))
                    for i = 1:length(new_val)
                        assert(obj~=new_val(i),'Cannot set pref to self!')
                    end
                    % Length assertion
                    if mp.HasDefault
                        N = max(size(mp.DefaultValue));
                        if N && length(new_val) > N % N=0 don't check (e.g. Inf)
                            error('Prop "%s" defines a max length of %i; remove existing module before trying to add another',prop_name,N);
                            % NOTE: module created in getValue function. this does not delete the created module
                        end
                    end
                end
                obj.(prop_name) = new_val;
            catch err % Reset value in GUI
                % obj.(prop_name) = new_val could result in a module set
                % method to update_settings. If that happens, THEN that set
                % method subsequently errors, we end up here with a deleted
                % hObj. The update_settings should have taken care of
                % updating CC, so we can just ignore this and continue to
                % rethrow the err
                if isvalid(hObj)
                    hObj.UserData.setValue(obj.GUI_handle,prop_name,obj.(prop_name))
                end
                rethrow(err)
            end
            % the GUI will be udpated on the PostSet callback
        end
    end
end

