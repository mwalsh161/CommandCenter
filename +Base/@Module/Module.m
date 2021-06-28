classdef Module < Base.Singleton & matlab.mixin.Heterogeneous
    % MODULE Abstract Class for Modules.
    %   Simply enforces required properties.
    %
    %   All module managers will look for an optional invisible property (must be constant).
    %   If this exists, and is set to true, it will not render it in the
    %   menus.
    %
    %   If there is a Constant property "visible" and it is set to false,
    %   this will prevent CommandCenter from displaying it.
    %
    % This class also manages Prefs (previously, this was done by pref_handler).
    %
    %   The bulk of this mixin is responsible for maintaining a more complex "meta"
    %   property that is stored in memory (see +Prefs and Base.Pref). When the user
    %   attempts to get or set this, the machinery here will make it appear to behave
    %   as the standard MATLAB type that resides in the meta property (named "value").
    %
    %   Any class-based pref cannot define a MATLAB set or get method. Rather, one
    %   should be supplied to the constructor of the class-based pref (see Base.Pref).
    %
    %   NOTE: This constructor MUST be called before anything modifies a
    %   property that uses a class-based pref!! In the case of multiple
    %   inheritance, one should explicity call the class hierarchy that
    %   uses this prior to any others.
    
    properties(Abstract, Constant, Hidden)
        modules_package;
    end
    properties(SetAccess=private,Hidden)
        namespace                   % Namespace for saving prefs
    end
    properties
        logger = [];                % Handle to logger object
    end
    
    properties(SetAccess=private, Hidden)   % Internal flags/variables for dealing with certain cases.
        last_pref_set_err = [];
        pref_set_try = false;       % If true, when setting, post listener will not throw the error. It will still populate last_pref_set_err. Think of this as a way to implement a try/catch block
        module_delete_listener      % Used in garbage collecting
        StructOnObject_state = 'on';% To restore after deleting
        hardware_get = false;
    end
    
    properties(SetAccess=private, Hidden)   % Pref storage variables.
        prop_listeners          % Keep track of preferences in the GUI to keep updated
        ls = struct();          % internal listeners
        external_ls;            % external listeners (addpreflistener)
        
%         props = struct();
        
        temp_prop = struct();
        implicit_mps = struct(); % When settings are made, all implicit ("old-style") meta props will go here
    end
    
    events
        update_settings % Listened to by CC to allow modules to request settings to be reloaded
    end

    methods(Static)                     % Michael's uibuild stuff.
        [code,f] = uibuild(block,varargin)
    end
    methods                             % Inactive function.
        
        % Default inactive is nothing
        function task = inactive(obj)
            task = '';
        end
    end
    
    methods                             % Constructor and delete.
        % This requires SetObservable to be true, and careful use of
        % temp_prop in case a set method sets a different property. MATLAB
        % states the order listeners are executed is undefined, so there is
        % no guarantee this gets called before other listeners. CC GUI uses
        % listeners as well.
        % Cannot use set/get methods in MATLAB!
        function obj = Module()
            mc = metaclass(obj);
            props = mc.PropertyList;
            props = props([props.HasDefault]);
            external_ls_struct.PreSet =  Base.PrefListener.empty(1,0);
            external_ls_struct.PostSet = Base.PrefListener.empty(1,0);
            external_ls_struct.PreGet =  Base.PrefListener.empty(1,0);
            external_ls_struct.PostGet = Base.PrefListener.empty(1,0);

            for i = 1:length(props)
                prop = props(i);
                if contains('Base.Pref',superclasses(prop.DefaultValue))
                    assert(~strcmp(prop.GetAccess,'private')&&~strcmp(prop.SetAccess,'private'),...
                        sprintf('Class-based pref ''%s'' cannot have set/get access private.',prop.Name));
                    obj.(prop.Name).property_name = prop.Name; % Useful for callbacks
                    
                    if isempty(obj.(prop.Name).name)
                        obj.(prop.Name).name = strrep(prop.Name, '_', ' ');
                    end
                    
                    % Add listeners to get and set so we can swap the value
                    % in/out behind the scenes. All listeners relate to
                    % this object, so no need to clean them up.
                    assert(isempty(prop.GetMethod),...
                        ['Cannot use get methods with class-based prefs!\n',...
                         'Instead use the callback methods available in the class-based pref.']);
                    assert(isempty(prop.SetMethod),...
                        ['Cannot directly use set methods with class-based prefs! Please (a) modify:', 10,...
                         '    `function set.<property_name>(obj, val)` ==>', 10,...
                         '    `function val = set_<property_name>(obj, val, ~)`', 10,...
                         'and (b) assign `val = obj.<property_name>` at the end of the function.']);
                    assert(prop.GetObservable&&prop.SetObservable,...
                        sprintf('Class-based pref ''%s'' in class ''%s'' must be defined to be GetObservable and SetObservable.', prop.Name, class(obj)));
                    
                    % Grab meta pref before listeners go active to pass to set_meta_pref
                    pref = obj.(prop.Name);
                    obj.(prop.Name) = pref.value;

                    obj.ls.(prop.Name)    = obj.addlistener(prop.Name, 'PreSet',  @obj.pre);
                    obj.ls.(prop.Name)(2) = obj.addlistener(prop.Name, 'PostSet', @obj.post);
                    obj.ls.(prop.Name)(3) = obj.addlistener(prop.Name, 'PreGet',  @obj.pre);
                    obj.ls.(prop.Name)(4) = obj.addlistener(prop.Name, 'PostGet', @obj.post);

                    obj.external_ls.(prop.Name) = external_ls_struct;
                    % (Re)set meta pref which will validate and bind callbacks declared as strings
                    % Done after binding Set/Get listeners since the method call expects them to be set already
                    
                    obj.set_meta_pref(prop.Name, pref);
                end
            end
            
            warnStruct = warning('off','MATLAB:structOnObject');
            obj.StructOnObject_state = warnStruct.state;
            [obj.namespace,hObject] = obj.get_namespace(class(obj));
            
            if isempty(hObject) 
                obj.logger = Base.Logger_console();
                return
            end
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
    end
    methods(Sealed)                     % Cleanup and garbage collection. REVISIT THIS
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
    end
    
    methods                             % Methods for getting and setting prefs
        function set_meta_pref(obj, name, pref)
            % Set the "meta pref" for property "name".
            % If the property's default value is not a class-based pref
            % this will not allow you to set it because the constructor
            % handles preparing all class-based pref stuff
            % NOTE: this does not do anything with the current value and
            %   MAY result in it changing if you aren't careful!!
%             allowed_names = obj.get_class_based_prefs();
%             if ~ismember(name,allowed_names)
%                 obj.implicit_mps.(name) = pref;
%                 return
%             end

            % Updating the value is expensive due to having to supress and
            % enable the listeners. So we first determine whether the value
            % changed from the current -- if so, we don't need to update.
            shouldUpdate = isfield(obj.temp_prop, name) && ~nanisequal(obj.temp_prop.(name).value, pref.value);

            % Update the Pref class to the supplied class
            obj.temp_prop.(name) = pref.bind(obj);
            
            % Update the Pref value to the supplied value
            if shouldUpdate
                obj.prop_listener_ctrl(name,false);
                obj.(name) = pref.value; % Assign back to property
                obj.prop_listener_ctrl(name,true);
            end
        end
        function pref = get_meta_pref(obj,name)
            pref = obj.temp_prop.(name);
            
            % Return the "meta pref" which contains the pref class
            % NOTE: this is a value class, so changing anything in the
            % returned instance does nothing.
            % NOTE: This by-passes pref get listeners
%             if isfield(obj.ls,name) % Indicates class-based pref
%                 assert(all([obj.ls.(name).Enabled]),...
%                     sprintf(['"%s" pref, child of "%s", is in use elsewhere. You may be getting this because you are trying ',...
%                     'to reload settings in a set/custom_validate/custom_clean method of a meta pref.'],name,class(obj)));
% %                 assert(obj.ls_enabled)
%                 obj.prop_listener_ctrl(name,false);
%                 val = obj.(name);
%                 obj.prop_listener_ctrl(name,true);
%                 return
%             elseif isfield(obj.implicit_mps,name)
%                 val = obj.implicit_mps.(name);
%                 return
%             end
%             % Anything beyond this point must be an old-stlye pref that was
%             %   not loaded (or for the first time) in the settings call
%             % old style prefs: auto generate default type here
%             val = obj.(name);
%             prop = findprop(obj,name);
%             if prop.HasDefault && ...
%                 (iscell(prop.DefaultValue) || isa(prop.DefaultValue,'function_handle'))
%                 if iscell(prop.DefaultValue)
%                     choices = prop.DefaultValue;
%                 else % function handle
%                     choices = prop.DefaultValue();
%                 end
%                 if iscell(val) || isa(val,'function_handle')
%                     warning('PREF:oldstyle_pref','Default choice not specified for %s; using empty option',prop.Name);
%                     val = '';
%                     obj.(name) = '';
%                 end
%                 val = Prefs.MultipleChoice(val,'choices',choices);
%             elseif isnumeric(val) && numel(val)==1 % There are many numeric classes
%                 val = Prefs.Double(val);
%             elseif ismember('Base.Module',superclasses(val))
%                 warningtext = 'Update to class-based pref! While Prefs.ModuleInstance will protect from bad values set in the UI, it won''t extend to console or elsewhere.';
%                 warning('PREF:oldstyle_pref',[prop.Name ': ' warningtext]);
%                 % Deserves an extra annoying warning that cant be turned off
%                 warndlg([warningtext newline newline 'See console warnings for offending prefs.'],'Update to class-based pref!','modal');
%                 n = Inf;
%                 inherits = {};
%                 if prop.HasDefault
%                     n = max(size(prop.DefaultValue));
%                     if n == 0; n = Inf; end
%                     if isempty(prop.DefaultValue) % if it isn't empty, it must be an actual module defined, not a category
%                         inherits = {class(prop.DefaultValue)};
%                     end
%                 end
%                 val = Prefs.ModuleInstance(val,'n',n,'inherits',inherits);
%             elseif isnumeric(val)
%                 val = Prefs.DoubleArray(val);
%             else
%                 switch class(val)
%                     case {'char'}
%                         val = Prefs.String(val);
%                     case {'logical'}
%                         val = Prefs.Boolean(val);
%                     otherwise
%                         sz = num2str(size(val),'%ix'); sz(end) = []; % remove last "x"
%                         error('PREF:notimplemented','Class-based pref not implemented for %s %s',sz,class(val))
%                 end
%             end
%             val.auto_generated = true;
%             val.property_name = name;
        end
        function prefs = get_class_based_prefs(obj)
            % Get string name of all prefs (MATLAB properties) that were defined as a class-based pref
            % Note: necessary to use this method to keep obj.ls private
%             prefs = fields(obj.ls);
            prefs = fields(obj.temp_prop);
        end
    end
    
    methods(Hidden)                     % UI settings construction
        function settings = get_settings(obj)       % Get the names of the prefs that should be displayed in settings. Used by obj.settings().
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
        function settings(obj,panelH,pad,margin)    % Arranges appropriate uicontrols for prefs inside a desired panel (usually the one owned by the relevant Manager).
            % Adds custom settings to main GUI.
            %   This can be a simple settings button that opens a new GUI!
            %   Callbacks must be taken care of in the module.
            %   Module length can be adjusted, but not width.
            %   There are a few things to keep in mind when making these
            %   settings. If another program/command line alters a property in
            %   your settings, if you aren't careful, you will have an
            %   inconsitency and confusion will follow.
            %   See documentation for how the default settings works below.
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
            
            % Grab the list of settings from get_settings()
            try
                setting_names = obj.get_settings();
            catch err
                error('Error fetching settings names:\n%s', getReport(err,'basic','hyperlinks','off'));
            end
            nsettings = length(setting_names);

            % Make the uicontrol elements with each metapref's make_UI().
            panelH_loc = pad;
            mps = cell(1,nsettings); % meta pref
            label_size = NaN(1,nsettings);
            % Build up, starting from end to beginning
            for i = nsettings:-1:1
                try
                    mp = obj.get_meta_pref(setting_names{i});
                catch err
                    warning('Skipped pref "%s":\n%s', setting_names{i}, err.message)
                    continue
                end
                
                if isempty(mp.name) % Default to setting (i.e. property) name
                    mp.name = strrep(setting_names{i}, '_', ' ');
                end
                if ismember(setting_names{i}, readonly_settings)
                    mp.readonly = true; % Allowing readonly_prefs to override
                end
                
                % Make UI element and add to panelH (note mp is not a handle class)
                [mp,height_px,label_size(i)] = mp.make_UI(panelH, panelH_loc, widthPx, margin);
                if isprop(mp, 'reference') && ~isempty(mp.reference)
                    obj2 = mp.reference.parent;
                    mp = mp.link_callback(@obj2.settings_callback);
%                     mp.value = mp.reference.value;
                    mp.value = mp.read();
                else
                    mp = mp.link_callback(@obj.settings_callback);
                end
                
                panelH_loc = panelH_loc + height_px + pad;
                mps{i} = mp;
                obj.set_meta_pref(setting_names{i}, mp);
%                 try
                    mp = mp.set_ui_value(mp.value); % Update to current value
%                 catch err
%                     warning(err.identifier,'Failed to set pref "%s" to value of type "%s":\n%s',...
%                         setting_names{i},class(mp.value),err.message)
%                 end
                obj.set_meta_pref(setting_names{i}, mp);
            end
            
            % Adjust the UI such that label widths are nice.
            max_label_width = widthPx/2;
            suggested_label_width = max(label_size(label_size < max_label_width)); % px
            if isempty(suggested_label_width) || any(label_size > max_label_width) || isnan(suggested_label_width)
                suggested_label_width = max_label_width;
            end
            
            % For each setting, update UI and set listeners.
            lsh = Base.PrefListener.empty;
            for i = 1:nsettings
                if ~isnan(label_size(i)) % no error in fetching mp
                    mps{i} = mps{i}.adjust_UI(suggested_label_width, margin);
                    obj.set_meta_pref(setting_names{i}, mps{i});
                    
                    if isprop(mps{i}, 'reference')
                        if ~isempty(mps{i}.reference)
%                                 lsh(end+1) = mps{i}.reference.parent.addlistener(mps{i}.reference.property_name, 'PostSet', @(~,~)(obj.settings_listener(struct('Name', mps{i}.property_name), mps{i})));
                            % References should update based on the parent of the referenced pref.
                            if strcmp(class(mps{i}.reference.parent), 'Drivers.NIDAQ.dev')
                                out = mps{i}.reference.parent.getLines(mps{i}.reference.name, 'out');
                                
                                lsh(end+1) = out.addlistener(...
                                    'state',...
                                    'PostSet',...
                                    @(~,~)(mps{i}.set_ui_value( out.state ))...
                                );
                            else
                                lsh(end+1) = mps{i}.reference.parent.addlistener(...
                                    mps{i}.reference.property_name,...
                                    'PostSet',...
                                    @(~,~)(mps{i}.set_ui_value( mps{i}.reference.parent.(mps{i}.reference.property_name) ))...
                                );
                            end
                        end
                    else
                        lsh(end+1) = obj.addlistener(setting_names{i}, 'PostSet', @(el,~)(obj.settings_listener(el, mps{i})));
                    end
                end
            end
            addlistener(panelH, 'ObjectBeingDestroyed', @(~,~)delete(lsh)); % Listeners for cleanup
        end
        function settings_callback(obj,~,~,mp)      % Callback used to set prefs to the values requested by the settings panel uicontrols.
            err = [];
            
            obj.pref_set_try = true;  % try block for validation
            try % try block for retrieving UI value
                if isa(mp.parent, 'Drivers.NIDAQ.dev')
                    mp.writ(mp.get_validated_ui_value());
%                     out = mp.parent.getLines(mp.name, 'out');
%                     out.state = mp.get_validated_ui_value();
                else
                    obj.(mp.property_name) = mp.get_validated_ui_value();
                end
%                 obj.(mp.property_name) = obj.(mp.property_name);
                err = obj.last_pref_set_err; % Either [] or MException
            catch err % MException if we get here
            end
            obj.pref_set_try = false; % "unset" try block for validation to route errors back to console
            
            % set method might notify "update_settings"
            try
                if isa(mp.parent, 'Drivers.NIDAQ.dev')
                    out = mp.parent.getLines(mp.name, 'out');
                    mp.writ(out.state);
%                     mp.set_ui_value(out.state);
                else
                    mp.set_ui_value(obj.(mp.property_name)); % clean methods may have changed it
                end
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
                    val_help = mp.validationSummary(2); % Indent 2.
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
    
    methods(Static, Sealed)             % Namespace is used to determine where prefs are saved.
        function [namespace,CC_handle] = get_namespace(classname)
            % This function returns the formatted namespace string to be used with MATLAB prefs
            % It is recommended to be called using either mfilename or class to help construct input:
            %   ... obj.get_namespace(class(obj));
            %   ... Base.Module.get_namespace(mfilename('class'))

            % isvector takes care of non-empty too
            assert(ischar(classname) && isvector(classname),'classname must be a non-empty character vector.')
            % Convert periods in classname to underscores
            name = strrep(classname,'.','_');
            assert(isvarname(name),'converting "." to "_" was not sufficient to turn classname into a valid variable name in MATLAB.')
            
            CC_handle = findall(0,'name','CommandCenter');
            if length(CC_handle) > 1
                warning('Found more than one CommandCenter handle. Have you opened more than one instance of CC? Choosing the first one.')
                CC_handle = CC_handle(1);
            end
            
            if isempty(CC_handle)
                pre = '';
            else
                pre = getappdata(CC_handle,'namespace_prefix');
            end
            namespace = [pre name];
        end
    end
    methods                             % In the case where a module instance needs to be saved, identity = obj.encode() records the information required to recreate a runtime instance as a struct.
        function identity = encode(obj, includestate)
            if nargin < 2
                includestate = false;
            end
            
            if isempty(obj.singleton_id)
                identity = struct('name', class(obj));
            else
                assert(ischar(obj.singleton_id) || isnumeric(obj.singleton_id), 'Encoding is limited to modules which have displayable (string or numeric) or empty singleton IDs, for now.')
                identity = struct('name', class(obj), 'singleton_id', obj.singleton_id);
            end
            
            if includestate
                identity.state = obj.prefs2struct();
            end
        end
        function str = encodeReadable(obj, isHTML, isSimple)
            if nargin < 2
                isHTML = false;
            end
            if nargin < 3
                isSimple = false;
            end
            
            str = class(obj);
            
            if isSimple
                fullname = strsplit(str,'.');
                str = fullname{end};
            end
            
            if ~isempty(obj.singleton_id)
                if ischar(obj.singleton_id)
                    str2 = ['''' obj.singleton_id ''''];
                elseif isnumeric(obj.singleton_id)
                    try 
                        str2 = mat2str(obj.singleton_id);
                    catch
                        str2 = '';
                    end
                end

                if ~isempty(str2)
                    if isHTML
                        str = [str '(<font face="Courier New" color="purple">' str2 '</font>)'];
                    else
                        str = [str '(' str2 ')'];
                    end
                end
            end
        end
    end
    methods(Static)                     % The static function obj = decode(identity) acts as the inverse of encode(), and recovers the runtime instanced described by identity.
        function obj = decode(identity)
            if ischar(identity)
                identity = struct('name', identity);
            end
            
            assert(isstruct(identity))
            assert(isfield(identity, 'name'))

            if isfield(identity, 'singleton_id')
                obj = eval(sprintf('%s.instance(''%s'')', identity.name, identity.singleton_id));
            else
                obj = eval(sprintf('%s.instance()', identity.name));
            end
        end
    end
    methods(Sealed)                     % Functions for saving, loading, and databasing prefs.
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
                for i = 1:numel(obj.prefs) %#ok<*MCNPN>
                    if ~ischar(obj.prefs{i})
                        warning('MODULE:save_prefs','Error on savePrefs (position %i): %s',i,'Must be a string!')
                        continue
                    end
                    try
                        mp = obj.get_meta_pref(obj.prefs{i});
                        
                        setpref(obj.namespace, obj.prefs{i}, mp.encodeValue( obj.(obj.prefs{i}) ));
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
            
            % First check prefs.
            varargout{1} = struct();
            if ~isprop(obj,'prefs')
                varargout = varargout(1:nargout);
                return
            end
            assert(iscell(obj.prefs),'Property "prefs" must be a cell array')
            assert(all(ismember(strrep(varargin,'-',''), obj.prefs)),'Make sure all inputs in loadPrefs are also in obj.prefs')
            
            % Then check namespace.
            if isempty(obj.namespace) % if namespace isn't set, means error in constructor
                varargout = varargout(1:nargout);
                return
            end
            assert(ischar(obj.namespace),'Namespace must be a string!')
            
            % Separate into prefs and skip prefs. If prefs is empty, perhaps user only supplied skip prefs.
            prefs = obj.prefs;
            skip = {};
            if ~isempty(varargin)
                mask = cellfun(@(a)a(1)=='-',varargin);
                prefs = varargin(~mask);
                skip = cellfun(@(a)a(2:end),varargin(mask),'uniformoutput',false);
                if isempty(prefs)
                    prefs = obj.prefs;
                end
            end
            
            % Lastly, actually load the prefs.
            obj.pref_set_try = true;  % try block for validation (caught after setting below)
            for i = 1:numel(prefs)
                if ismember(prefs{i},skip)          % Pass on prefs that should be skipped.
                    continue
                end
                if ~ischar(prefs{i})                % Pass on pref labels that are (for whatever strange reason) not strings.
                    warning('MODULE:load_prefs','Error on loadPrefs (position %i): %s',i,'Must be a string!')
                    continue
                end
                
                if ispref(obj.namespace, prefs{i})   % If we have data saved to set the pref to...
                    data = getpref(obj.namespace, prefs{i});     % ...Grab that data...
                    try
                        mp = obj.get_meta_pref(prefs{i});
                        
                        % For most prefs, mp.decodeValue is the identity. However, some prefs carry runtime information which must be encoded to something
                        % savable on save and decoded to something runable on load. For this reason, the metapref deals with interpretation. In order
                        % to prevent unwanted overwriting of the default value, the decode function has the option to error.
                        try  %#ok<TRYNC>
                            [temp, mp] = mp.decodeValue(data);
                            mp.value = temp;
                            obj.(prefs{i}) = temp;
                            obj.set_meta_pref(mp.property_name, mp);
                        end
                        
                        if ~isempty(obj.last_pref_set_err)  % This could use better commenting. Not sure what it does.
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
        function datastruct = prefs2struct(obj,datastruct)  % In the case of ModuleInstance, recurses to build a full struct.
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
                    
                    mp = obj.get_meta_pref(obj.prefs{i});
                    val = obj.(obj.prefs{i});
                    
                    if contains('Base.Module', superclasses(val))    
                        temps = struct('name', {}, 'prefs', {});
                        for j = 1:length(val)
                            temp.name = class(val(j));
                            temp.prefs = val(j).prefs2struct; % Recurse as necessary
                            temps(j) = temp;
                        end
                        val = temps;
                    else
                        val = mp.encodeValue(obj.(obj.prefs{i}));
                    end
                    datastruct.(obj.prefs{i}) = val;
                end
            else
                warning('MODULE:prefs2struct','No prefs defined for %s!',class(obj))
            end
        end
    end
    
    methods                             % Pref listener functions.
        function varargout = addlistener(obj,varargin)
            % el = addlistener(hSource,EventName,callback)
            % el = addlistener(hSource,PropertyName,EventName,callback)
            varargout = {};
            if nargin == 4 && isfield(obj.external_ls, varargin{1}) % externals_ls field names are all pref properties
                el = Base.PrefListener(obj,varargin{:});
                obj.external_ls.(varargin{1}).(varargin{2})(end+1) = el;
                addlistener(el, 'ObjectBeingDestroyed', @obj.preflistener_deleted);
            else
                el = addlistener@handle(obj, varargin{:});
                el = Base.PrefListener(el); % Wrap it to make array compatible
            end
            if nargout
                varargout = {el};
            end
        end
    end
    methods(Access=private)             % Private listener functions.
        function prop_listener_ctrl(obj, name, enabled)
            % name: string name of property
            % enabled: true/false

            listeners = obj.ls.(name);
            for i = 1:4 % Disable this prop's listeners
                if numel(listeners(i)) == 1
                    if listeners(i).wrapper
                        listeners(i).proplistener.Enabled = enabled;    % This isn't super kosher, but will work except for super fringe cases. Helps with speed a lot.
                    else
                        listeners(i).Enabled = enabled;
                    end
                else
                    listeners(i).Enabled = enabled;
                end
            end
        end
        function preflistener_deleted(obj, el, ~)
            % Clean-up method for preflisteners (unless obj already deleted)
            if isvalid(obj)
                obj.external_ls.(el.PropertyName) ...
                    .(el.EventName)(...
                    obj.external_ls.(el.PropertyName)...
                    .(el.EventName)==el...
                    ) = [];
            end
        end
        function execute_external_ls(obj, prop, event)
            for i = 1:length(obj.external_ls.(prop.Name).(event.EventName))
                % Do not allow recursive calls and only call Enabled ones
                if  obj.external_ls.(prop.Name).(event.EventName)(i).Enabled && ...
                        (obj.external_ls.(prop.Name).(event.EventName)(i).Recursive || ...
                         ~obj.external_ls.(prop.Name).(event.EventName)(i).executing) % "Recursive or not executing"
                    obj.external_ls.(prop.Name).(event.EventName)(i).executing = true;
                    try
                        obj.external_ls.(prop.Name).(event.EventName)(i).Callback(prop,event);
                    catch err
                        warning('MATLAB:callback:PropertyEventError',...
                            'Error occurred while executing the listener callback for the %s class %s property %s event:\n%s',...
                            class(obj),prop.Name,event.EventName,getReport(err));
                    end
                    obj.external_ls.(prop.Name).(event.EventName)(i).executing = false;
                end
            end
        end

        % MATLAB turns errors in listeners to warnings, so make sure we
        % handle validation errors here!
        function pre(obj, prop, event)
            obj.execute_external_ls(prop, event);
        end
        function post(obj, prop, event)
            obj.prop_listener_ctrl(prop.Name, false);   % Listeners DISABLED.
            
            % Copy in case validation fails
            pref = obj.temp_prop.(prop.Name);
            
            err = [];
            
            try
                switch event.EventName
                    case 'PostSet'
                        obj.(prop.Name) = pref.set_value(obj.(prop.Name));   % validation occurs here
                    case 'PostGet'
                        if obj.hardware_get
                            obj.(prop.Name) = pref.get_value(obj.(prop.Name));
                        end
                end
                
                obj.execute_external_ls(prop,event);                % Execute any external listeners
                
                if ~nanisequal(pref.value, obj.(prop.Name))         % Update if external_ls changed it
                    pref.value = pref.set_value(obj.(prop.Name));   % This should now be interpreted as a set event; validation occurs here
                end
            catch err
            end
            
            % Update the pref and re-engage listeners. Note if the above try block failed on any set_value; this is still the old value
            obj.temp_prop.(prop.Name) = pref;
            obj.(prop.Name) = pref.value;
            
            obj.prop_listener_ctrl(prop.Name,true);     % Listeners ENABLED.
            
            % Error handling
            if ~isempty(err)
                % This will be thrown as warning in console because it is from a listener, so we will use a flag for detection with a readable property
                obj.last_pref_set_err = err;
                if obj.pref_set_try
                    return
                else
                    rethrow(err);
                end
            end
            obj.last_pref_set_err = [];
        end
    end
    methods (Hidden, Access=?Base.Pref) % Pref access x = read() and writ(x) calls.
        function tf = writProp(obj, prop, val)
            tf = true;
            
            try
                obj.(prop.Name) = val;
            catch err
                tf = false;
                warning(err.message)
            end
        end
        function val = readProp(obj,prop)
            obj.hardware_get = true;
            try
                val = obj.(prop.Name);
            catch err
                warning(err.message)
            end
            obj.hardware_get = false;
        end
    end
end
