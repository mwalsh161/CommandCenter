classdef PrefHandler < handle
    %PREFHANDLER A mixin that enables use of class-based prefs
    %   Intercepts pre/post set/get listeners and implements similar behavior.
    %   This should be a drop-in replacement for nearly all use cases.
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

    properties(SetAccess=private,Hidden)
        namespace                   % Namespace for saving prefs
        StructOnObject_state = 'on';% To restore after deleting
    end
    properties
        logger                      % Handle to log object
    end
    properties(Access = private)
        temp_prop = struct();
        ls = struct(); % internal listeners
        external_ls;   % external listeners (addpreflistener)
        implicit_mps = struct(); % When settings are made, all implicit ("old-style") meta props will go here
    end
    properties(Hidden, SetAccess = private)
        last_pref_set_err = [];
    end
    properties(Hidden, SetAccess = protected)
        % If true, when setting, post listener will not throw the error.
        % It will still populate last_pref_set_err. Think of this as a way
        % to implement a try/catch block
        pref_set_try = false;
    end
    properties(Hidden)
        PrefHandler_indentation = 2;
    end

    methods                             % Constructor and basic metapref stuff.
        % This requires SetObservable to be true, and careful use of
        % temp_prop in case a set method sets a different property. MATLAB
        % states the order listeners are executed is undefined, so there is
        % no guarantee this gets called before other listeners. CC GUI uses
        % listeners as well.
        % Cannot use set/get methods in MATLAB!
        function obj = PrefHandler()
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
                        obj.(prop.Name).name = prop.Name;
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
                    % Grap meta pref before listeners go active to pass to set_meta_pref
                    pref = obj.(prop.Name);

                    obj.ls.(prop.Name)    = addlistener(obj, prop.Name, 'PreSet',  @obj.pre);
                    obj.ls.(prop.Name)(2) = addlistener(obj, prop.Name, 'PostSet', @obj.post);
                    obj.ls.(prop.Name)(3) = addlistener(obj, prop.Name, 'PreGet',  @obj.pre);
                    obj.ls.(prop.Name)(4) = addlistener(obj, prop.Name, 'PostGet', @obj.post);

                    obj.external_ls.(prop.Name) = external_ls_struct;
                    % (Re)set meta pref which will validate and bind callbacks declared as strings
                    % Done after binding Set/Get listeners since the method call expects them to be set already

%                     pref
                    
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

        function varargout = addlistener(obj,varargin)
            % el = addlistener(hSource,EventName,callback)
            % el = addlistener(hSource,PropertyName,EventName,callback)
            varargout = {};
            if nargin == 4 && isfield(obj.external_ls,varargin{1}) % externals_ls field names are all pref properties
                el = Base.PrefListener(obj,varargin{:});
                obj.external_ls.(varargin{1}).(varargin{2})(end+1) = el;
                addlistener(el,'ObjectBeingDestroyed',@obj.preflistener_deleted);
            else
                el = addlistener@handle(obj,varargin{:});
                el = Base.PrefListener(el); % Wrap it to make array compatible
            end
            if nargout
                varargout = {el};
            end
        end

        function prefs = get_class_based_prefs(obj)
            % Get string name of all prefs (MATLAB properties) that were defined as a class-based pref
            % Note: necessary to use this method to keep obj.ls private
            prefs = fields(obj.ls);
        end

        function set_meta_pref(obj,name,pref)
            % Set the "meta pref" for property "name".
            % If the property's default value is not a class-based pref
            % this will not allow you to set it because the constructor
            % handles preparing all class-based pref stuff
            % NOTE: this does not do anything with the current value and
            %   MAY result in it changing if you aren't careful!!
            allowed_names = obj.get_class_based_prefs();
            if ~ismember(name,allowed_names)
                obj.implicit_mps.(name) = pref;
                return
            end
            pref = pref.bind(obj);
            obj.prop_listener_ctrl(name,false);
            obj.(name) = pref; % Assign back to property
            obj.prop_listener_ctrl(name,true);
        end
        function val = get_meta_pref(obj,name)
            % Return the "meta pref" which contains the pref class
            % NOTE: this is a value class, so changing anything in the
            % returned instance does nothing.
            % NOTE: This by-passes pref get listeners
            if isfield(obj.ls,name) % Indicates class-based pref
                assert(all([obj.ls.(name).Enabled]),...
                    sprintf(['"%s" pref, child of "%s", is in use elsewhere. You may be getting this because you are trying ',...
                    'to reload settings in a set/custom_validate/custom_clean method of a meta pref.'],name,class(obj)));
%                 assert(obj.ls_enabled)
                obj.prop_listener_ctrl(name,false);
                val = obj.(name);
                obj.prop_listener_ctrl(name,true);
                return
            elseif isfield(obj.implicit_mps,name)
                val = obj.implicit_mps.(name);
                return
            end
            % Anything beyond this point must be an old-stlye pref that was
            %   not loaded (or for the first time) in the settings call
            % old style prefs: auto generate default type here
            val = obj.(name);
            prop = findprop(obj,name);
            if prop.HasDefault && ...
                (iscell(prop.DefaultValue) || isa(prop.DefaultValue,'function_handle'))
                if iscell(prop.DefaultValue)
                    choices = prop.DefaultValue;
                else % function handle
                    choices = prop.DefaultValue();
                end
                if iscell(val) || isa(val,'function_handle')
                    warning('PREF:oldstyle_pref','Default choice not specified for %s; using empty option',prop.Name);
                    val = '';
                    obj.(name) = '';
                end
                val = Prefs.MultipleChoice(val,'choices',choices);
            elseif isnumeric(val) && numel(val)==1 % There are many numeric classes
                val = Prefs.Double(val);
            elseif ismember('Base.Module',superclasses(val))
                warningtext = 'Update to class-based pref! While Prefs.ModuleInstance will protect from bad values set in the UI, it won''t extend to console or elsewhere.';
                warning('PREF:oldstyle_pref',[prop.Name ': ' warningtext]);
                % Deserves an extra annoying warning that cant be turned off
                warndlg([warningtext newline newline 'See console warnings for offending prefs.'],'Update to class-based pref!','modal');
                n = Inf;
                inherits = {};
                if prop.HasDefault
                    n = max(size(prop.DefaultValue));
                    if n == 0; n = Inf; end
                    if isempty(prop.DefaultValue) % if it isn't empty, it must be an actual module defined, not a category
                        inherits = {class(prop.DefaultValue)};
                    end
                end
                val = Prefs.ModuleInstance(val,'n',n,'inherits',inherits);
            elseif isnumeric(val)
                val = Prefs.DoubleArray(val);
            else
                switch class(val)
                    case {'char'}
                        val = Prefs.String(val);
                    case {'logical'}
                        val = Prefs.Boolean(val);
                    otherwise
                        sz = num2str(size(val),'%ix'); sz(end) = []; % remove last "x"
                        error('PREF:notimplemented','Class-based pref not implemented for %s %s',sz,class(val))
                end
            end
            val.auto_generated = true;
            val.property_name = name;
        end

    end
    methods(Static,Sealed)              % Namespace is used to determine where prefs are saved.
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
    methods(Sealed)                     % Functions dealing with prefs.
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
                for i = 1:numel(obj.prefs) %#ok<*MCNPN>
                    if ~ischar(obj.prefs{i})
                        warning('MODULE:save_prefs','Error on savePrefs (position %i): %s',i,'Must be a string!')
                        continue
                    end
                    try
                        mp = findprop(obj,obj.prefs{i});
                        
                        try %#ok<TRYNC>
                            setpref(obj.namespace, obj.prefs{i}, mp.encode(obj.(obj.prefs{i})));
                        end
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
            
            obj.pref_set_try = true;  % try block for validation (caught after setting below)
            for i = 1:numel(prefs)
                if ismember(prefs{i},skip)          % Pass on prefs that should be skipped.
                    continue
                end
                if ~ischar(prefs{i})                % Pass on pref labels that are (for whatever strange reason) not strings.
                    warning('MODULE:load_prefs','Error on loadPrefs (position %i): %s',i,'Must be a string!')
                    continue
                end
                
                if ispref(obj.namespace,prefs{i})   % If we have data saved to set the pref to...
                    data = getpref(obj.namespace,prefs{i});     % ...Grab that data...
                    try
                        mp = findprop(obj,prefs{i});
                        
                        % For most prefs, mp.decode is the identity. However, some prefs carry runtime information which must be encoded to something
                        % savable on save and decoded to something runable on load. For this reason, the metapref deals with interpretation. In order
                        % to prevent unwanted overwriting of the default value, the decode function has the option to error.
                        try  %#ok<TRYNC>
                            temp = mp.decode(data);
                            obj.(prefs{i}) = temp;
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
    end
    methods(Access = private)           % Listener functions.
        function prop_listener_ctrl(obj,name,enabled)
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
        function preflistener_deleted(obj,el,~)
            % Clean-up method for preflisteners (unless obj already deleted)
            if isvalid(obj)
                obj.external_ls.(el.PropertyName) ...
                    .(el.EventName)(...
                    obj.external_ls.(el.PropertyName)...
                    .(el.EventName)==el...
                    ) = [];
            end
        end
        function execute_external_ls(obj,prop,event)
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
        function pre(obj,prop,event)
            % Disable other listeners on this since we will be both getting
            % and setting this prop in this method
            obj.prop_listener_ctrl(prop.Name,false);
            % Stash prop
            obj.temp_prop.(prop.Name) = obj.(prop.Name);
            obj.(prop.Name) = obj.temp_prop.(prop.Name).value;
            % Execute any external listeners
            obj.execute_external_ls(prop,event);
            obj.prop_listener_ctrl(prop.Name,true);
        end
        function post(obj,prop,event)
            % Disable other listeners on this since we will be both getting
            % and setting this prop in this method
            obj.prop_listener_ctrl(prop.Name,false);
            % Update stash, then copy back to prop (get listeners can alter
            % obj.(prop.Name) as well as the obvious SetEvent does)
            new_val = obj.temp_prop.(prop.Name); % Copy in case validation fails
            try
                new_val.getEvent = strcmp(event.EventName,'PostGet');
                new_val.value = obj.(prop.Name); % validation occurs here
                new_val.getEvent = false;
                obj.execute_external_ls(prop,event); % Execute any external listeners
                if ~nanisequal(new_val.value, obj.(prop.Name)) % Update if external_ls changed it
                    % This should now be interpreted as a set event
                    new_val.value = obj.(prop.Name); % validation occurs here
                end
            catch err
            end
            % Update the class-pref and re-engage listeners
            % Note if the above try block failed; this is still the old value
            obj.(prop.Name) = new_val;
            obj.prop_listener_ctrl(prop.Name,true);
            if exist('err','var')
                % This will be thrown as warning in console because it is
                % from a listener, so we will use a flag for detection with
                % a readable property
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

    methods (Hidden, Access=?Base.Pref) % read and writ calls.
        % These functions have the same functionality as pre() post() called successivly, except with two
        % out of four fewer calls to obj.prop_listener_ctrl(prop,tf), which is the limiting time factor.
        function tf = writProp(obj,prop,val)
            tf = true;

            event.EventName = 'PreSet'; % pre() =====

            % Disable other listeners on this since we will be both getting
            % and setting this prop in this method
            obj.prop_listener_ctrl(prop.Name,false);
            % Stash prop
            obj.temp_prop.(prop.Name) = obj.(prop.Name);
            obj.(prop.Name) = val;
            % Execute any external listeners
            obj.execute_external_ls(prop,event);
%             obj.prop_listener_ctrl(prop.Name,true); **********

            event.EventName = 'PostSet'; % post() =====

            % Disable other listeners on this since we will be both getting
            % and setting this prop in this method
%             obj.prop_listener_ctrl(prop.Name,false); **********
            % Update stash, then copy back to prop (get listeners can alter
            % obj.(prop.Name) as well as the obvious SetEvent does)
            new_val = obj.temp_prop.(prop.Name); % Copy in case validation fails
            try
                new_val.getEvent = false;
                new_val.value = obj.(prop.Name); % validation occurs here
                new_val.getEvent = false;

                obj.execute_external_ls(prop,event); % Execute any external listeners
                
                if ~nanisequal(new_val.value, obj.(prop.Name)) % Update if external_ls changed it
                    % This should now be interpreted as a set event
                    new_val.value = obj.(prop.Name); % validation occurs here
                end
            catch err
            end
            % Update the class-pref and re-engage listeners
            % Note if the above try block failed; this is still the old value
            obj.(prop.Name) = new_val;
            obj.prop_listener_ctrl(prop.Name,true);
            if exist('err','var')
                % This will be thrown as warning in console because it is
                % from a listener, so we will use a flag for detection with
                % a readable property
                obj.last_pref_set_err = err;
                if obj.pref_set_try
                    tf = false;
                    return
                else
                    rethrow(err);
                end
            end
            obj.last_pref_set_err = [];
        end
        function val = readProp(obj,prop)
            event.EventName = 'PreGet'; % pre() ====='
            
            % Disable other listeners on this since we will be both getting
            % and setting this prop in this method
            obj.prop_listener_ctrl(prop.Name,false);
            if ~isa(obj.(prop.Name), 'Base.Pref')   % If we are calling readProp from a state where we have already stashed, then just return;
                val = obj.(prop.Name);
                return;
            end
            
            % Stash prop
            obj.temp_prop.(prop.Name) = obj.(prop.Name);
            obj.(prop.Name) = obj.temp_prop.(prop.Name).value;
            % Execute any external listeners
            obj.execute_external_ls(prop,event);
%             obj.prop_listener_ctrl(prop.Name,true);

%             event.EventName = 'PostGet'; % post() =====
            
            % Disable other listeners on this since we will be both getting
            % and setting this prop in this method
%             obj.prop_listener_ctrl(prop.Name,false);
            % Update stash, then copy back to prop (get listeners can alter
            % obj.(prop.Name) as well as the obvious SetEvent does)
            
%             new_val = obj.temp_prop.(prop.Name); % Copy in case validation fails
%             try
%                 new_val.getEvent = strcmp(event.EventName,'PostGet');
%                 new_val.value = obj.(prop.Name); % validation occurs here
%                 new_val.getEvent = false;
%                 obj.execute_external_ls(prop,event); % Execute any external listeners
%                 if ~nanisequal(new_val.value, obj.(prop.Name)) % Update if external_ls changed it
%                     % This should now be interpreted as a set event
%                     new_val.value = obj.(prop.Name); % validation occurs here
%                 end
%             catch err
%             end

            % Update the class-pref and re-engage listeners
            % Note if the above try block failed; this is still the old value
            obj.(prop.Name) =  obj.temp_prop.(prop.Name);
            val =  obj.temp_prop.(prop.Name).value;
            obj.prop_listener_ctrl(prop.Name,true);
            if exist('err','var')
                % This will be thrown as warning in console because it is
                % from a listener, so we will use a flag for detection with
                % a readable property
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

end
