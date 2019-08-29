classdef Module < Base.Singleton & Base.pref_handler & matlab.mixin.Heterogeneous
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
    properties
        logger                      % Handle to log object
    end
    properties(Access=protected)
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
                for i = 1:numel(obj.prefs)
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
                                for j = 1:length(pref)
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
            end
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
            for i = 1:length(all_props)
                mp = obj.get_meta_pref(all_props{i});

            end
            % For backwards compatibility:
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

            
        end
    end
end

