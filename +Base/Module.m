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
    
    properties(SetAccess=private,Hidden)
        namespace                   % Namespace for saving prefs
    end
    properties(Access=private)
        prop_listeners              % Keep track of preferences in the GUI to keep updated
        StructOnObject_state = 'on';% To restore after deleting
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

    methods(Sealed)
        function obj = Module
            warnStruct = warning('off','MATLAB:structOnObject');
            obj.StructOnObject_state = warnStruct.state;
            hObject = findall(0,'name','CommandCenter');
            if isempty(hObject)
                pre = '';
                obj.logger = Base.Logger_console();
            else
                pre = getappdata(hObject,'namespace_prefix');
            end
            obj.namespace = [pre strrep(class(obj),'.','_')];
            if isempty(hObject); return; end
            mods = getappdata(hObject,'ALLmodules');
            obj.logger = getappdata(hObject,'logger');
            mods{end+1} = obj;
            setappdata(hObject,'ALLmodules',mods)
            obj.logger.log(['Initializing ' class(obj)])
            % ******************************************************************
            % *************************[NOW LEGACY]*****************************
            % **********should be handled in class-based prefs******************
            % ******************************************************************
            % Garbage collect for Base.Modules properties
            mc = metaclass(obj);
            mp = mc.PropertyList;
            legacy_warning = false;
            for i = 1:length(mp)
                if mp(i).HasDefault && contains('Base.Module',superclasses(mp(i).DefaultValue))
                    legacy_warning = true;
                    addlistener(obj,mp(i).Name,'PostSet',@obj.module_garbage_collect);
                end
            end
            if legacy_warning
                warning('CC:legacy','Deleted-module garbage collection is legacy. Update to class-based pref!')
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
            % ******************************************************************
            % *********************(includes callbacks)*************************
            % *************************[END LEGACY]*****************************
            % ******************************************************************
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
                        if ismember('Base.Module',superclasses(val))
                            temp = {};
                            for j = 1:length(val)
                                temp{end+1} = class(val(j));
                            end
                            val = temp;
                        end
                        if ismember('Base.pref',superclasses(val))
                            % THIS SHOULD NOT HAPPEN, bug haven't figured
                            % out why it does sometimes yet
                            val = val.value;
                            warning('Listener for %s seems to have been deleted before savePrefs!',obj.prefs{i});
                        end
                        setpref(obj.namespace,obj.prefs{i},val);
                    catch err
                        warning('MODULE:save_prefs','Error on savePrefs. Skipped pref ''%s'': %s',obj.prefs{i},err.message)
                    end
                end
            end
        end
        function varargout = loadPrefs(obj,varargin)
            % loadPrefs is a useful method to load any saved prefs. Not
            % called by default, because order might matter to user.
            % Loads prefs listed in obj.prefs cell array
            % If output is requested, the warnings will not occur, rather the
            %   errors will be returned in a struct where the field name corresponds
            %   to the pref that errored and the value is the MException
            % Optional input allows only loading a subset of prefs or not loading them:
            %   prepending a '-' will indicate the instruction to not load that pref
            %   e.g. loadPrefs('pref1') will only load pref1 (if it is a pref)
            %        loadPrefs('-pref2') will load all but pref2
            varargout{1} = struct();
            if ~isprop(obj,'prefs')
                varargout = varargout(1:nargout);
                return
            end
            assert(all(ismember(strrep(varargin,'-',''), obj.prefs)),'Make sure all inputs in loadPrefs are also in obj.prefs')
            % if namespace isn't set, means error in constructor
            if isempty(obj.namespace)
                varargout = varargout(1:nargout);
                return
            end
            assert(ischar(obj.namespace),'Namespace must be a string!')
            if isprop(obj,'prefs')
                assert(iscell(obj.prefs),'Property "prefs" must be a cell array')
                prefs = obj.prefs;
                skip = {};
                if ~isempty(varargin)
                    % Separate into prefs and skip prefs. If prefs is empty, perhaps user only supplied skip prefs
                    mask = cellfun(@(a)a(1)=='-',varargin);
                    prefs = varargin(~mask);
                    skip = cellfun(@(a)a(2:end),varargin(mask),'uniformoutput',false);
                    if isempty(prefs)
                        prefs = obj.prefs;
                    end
                end
                obj.pref_set_try = true;  % try block for validation (caught after setting below)
                for i = 1:numel(prefs)
                    if ismember(prefs{i},skip)
                        continue
                    end
                    if ~ischar(prefs{i})
                        warning('MODULE:load_prefs','Error on loadPrefs (position %i): %s',i,'Must be a string!')
                        continue
                    end
                    if ispref(obj.namespace,prefs{i})
                        pref = getpref(obj.namespace,prefs{i});
                        try
                            mp = findprop(obj,prefs{i});
                            if mp.HasDefault && any(ismember([{class(mp.DefaultValue)}; superclasses(mp.DefaultValue)],...
                                            {'Base.Module','Prefs.ModuleInstance'}))
                                if isempty(pref)% Means it is the default value, and not set
                                    continue
                                end
                                for j = 1:length(pref)
                                    temp(j) = eval(sprintf('%s.instance',pref{j})); % Grab instance(s) from string
                                end
                                pref = temp;
                            end
                            obj.(prefs{i}) = pref;
                            if ~isempty(obj.last_pref_set_err)
                                % Effectively brings a listener "thread" to the main one
                                rethrow(obj.last_pref_set_err);
                            end
                        catch err
                            if nargout
                                varargout{1}.(prefs{i}) = err;
                            else
                                warning('MODULE:load_prefs','Error on loadPrefs (%s): %s',prefs{i},err.message)
                            end
                        end
                    end
                end
                obj.pref_set_try = false;
                varargout = varargout(1:nargout);
            end
        end
    end
    methods
        function delete(obj)
            warning(obj.StructOnObject_state,'MATLAB:structOnObject')
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
            if pos > 0
                mods(pos) = [];
                setappdata(hObject,'ALLmodules',mods)
            end
            obj.logger.log(['Destroyed ' class(obj)])
        end
        
        % Default inactive is nothing
        function task = inactive(obj)
            task = '';
        end
        
        function settings = get_settings(obj)
            % Override to change how settings are acquired
            % Must output cell array of strings
            % Order matters; first is on top, last is at the bottom.
            props = properties(obj);
            settings = {};
            if ismember('show_prefs',props)
                settings = obj.show_prefs;
            elseif ismember('prefs',props)
                settings = obj.prefs;
            end
            % Append any additional class-based prefs (no order)
            class_based = obj.get_class_based_prefs()';
            settings = [settings, class_based(~ismember(class_based,settings))];
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
        function settings(obj,panelH,pad,margin)
            % panelH: handle to the MATLAB panel
            % pad: double; vertical distance in pixels to leave between UI elements
            % margin: 1x2 double; additional space in pixels to leave on [left, right]
            
            panelH.Units = 'pixels';
            try % Make backwards compatible (around 2017a I think)
                widthPx = panelH.('InnerPosition')(3);
            catch err
                if ~strcmp(err.identifier,'MATLAB:noSuchMethodOrField')
                    rethrow(err)
                end
                widthPx = panelH.('Position')(3);
                warning('CC:legacy',['Using a version of MATLAB that does not use "InnerPosition" for uipanel.',...
                                    'Consider upgrading if you notice display issues.'])
            end

            % Establish legacy read_only settings
            readonly_settings = {};
            props = properties(obj);
            if ismember('readonly_prefs',props)
                warning('CC:legacy',['"readonly_prefs" will override any class-based setting.',...
                        'Note that it is legacy and should be updated to readonly property in class-based prefs.'])
                readonly_settings = obj.readonly_prefs;
            end
            
            try
                setting_names = obj.get_settings();
            catch err
                error('Error fetching settings names:\n%s',getReport(err,'basic','hyperlinks','off'));
            end
            nsettings = length(setting_names);

            panelH_loc = pad;
            mps = cell(1,nsettings); % meta pref
            label_size = NaN(1,nsettings);
            % Build up, starting from end to beginning
            for i = nsettings:-1:1
                try
                    mp = obj.get_meta_pref(setting_names{i});
                catch err
                    warning('Skipped pref "%s":\n%s',setting_names{i},err.message)
                    continue
                end
                if isempty(mp.name) % Default to setting (i.e. property) name
                    mp.name = strrep(setting_names{i},'_',' ');
                end
                if ismember(setting_names{i},readonly_settings)
                    mp.readonly = true; % Allowing readonly_prefs to override
                end
                % Make UI element and add to panelH (note mp is not a handle class)
                [mp,height_px,label_size(i)] = mp.make_UI(panelH,panelH_loc,widthPx, margin);
                mp = mp.link_callback(@obj.settings_callback);
                panelH_loc = panelH_loc + height_px + pad;
                mps{i} = mp;
                %obj.set_meta_pref(setting_names{i},mp);
                try
                    mp.set_ui_value(mp.value); % Update to current value
                catch err
                    warning(err.identifier,'Failed to set pref "%s" to value of type "%s":\n%s',...
                        setting_names{i},class(mp.value),err.message)
                end
            end
            max_label_width = widthPx/2;
            suggested_label_width = max(label_size(label_size < max_label_width)); % px
            if isempty(suggested_label_width)
                suggested_label_width = max_label_width;
            end
            lsh = Base.preflistener.empty;
            if ~isnan(suggested_label_width) % All must have been NaN for this to be false
                for i = 1:nsettings
                    if ~isnan(label_size(i)) % no error in fetching mp
                        mps{i} = mps{i}.adjust_UI(suggested_label_width, margin);
                        obj.set_meta_pref(setting_names{i},mps{i});
                        lsh(end+1) = addlistener(obj,setting_names{i},'PostSet',@(el,~)obj.settings_listener(el,mps{i}));
                    end
                end
            end
            addlistener(panelH,'ObjectBeingDestroyed',@(~,~)delete(lsh)); % Clean up listeners
        end
        function settings_callback(obj,~,~,mp)
            obj.pref_set_try = true;  % try block for validation
            try % try block for retrieving UI value
                obj.(mp.property_name) = mp.get_validated_ui_value();
                err = obj.last_pref_set_err; % Either [] or MException
            catch err % MException if we get here
            end
            % set method might notify "update_settings"
            mp = obj.get_meta_pref(mp.property_name);
            obj.pref_set_try = false; % "unset" try block for validation to route errors back to console
            try
                mp.set_ui_value(obj.(mp.property_name)); % clean methods may have changed it
            catch err
                error('MODULE:UI',['Failed to (re)set value in UI. ',... 
                       'Perhaps got deleted during callback? ',...
                       'You can click the settings refresh button to try and restore.',...
                       '\n\nError:\n%s'],err.message)
                % FUTURE UPDATE: make this an errordlg instead, and
                % provide a button to the user in the errordlg figure to
                % reload settings.
            end
            if ~isempty(err) % catch for both try blocks: Reset to old value and present errordlg
                try
                    val_help = mp.validation_summary(obj.pref_handler_indentation);
                catch val_help_err
                    val_help = sprintf('Failed to generate validation help:\n%s',...
                        getReport(val_help_err,'basic','hyperlinks','off'));
                end
                errmsg = err.message;
                % Escape tex modifiers
                val_help = strrep(val_help,'\','\\'); errmsg = strrep(errmsg,'\','\\');
                val_help = strrep(val_help,'_','\_'); errmsg = strrep(errmsg,'_','\_');
                val_help = strrep(val_help,'^','\^'); errmsg = strrep(errmsg,'^','\^');
                opts.WindowStyle = 'non-modal';
                opts.Interpreter = 'tex';
                errordlg(sprintf('%s\n\\fontname{Courier}%s',errmsg,val_help),...
                    sprintf('%s Error',class(mp)),opts);
            end
        end
        function settings_listener(obj,el,mp)
            mp.set_ui_value(obj.(el.Name));
        end
    end
end

