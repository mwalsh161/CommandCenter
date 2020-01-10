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

    properties(Access = private)
        temp_prop = struct();
        ls = struct(); % internal listeners
        external_ls;   % external listeners (addpreflistener)
    end
%     properties(Access = ?Base.Pref)
%         ls_enabled = struct();
%     end
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

    methods
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
            external_ls_struct.PreSet = Base.PrefListener.empty(1,0);
            external_ls_struct.PostSet = Base.PrefListener.empty(1,0);
            external_ls_struct.PreGet = Base.PrefListener.empty(1,0);
            external_ls_struct.PostGet = Base.PrefListener.empty(1,0);

            pr = Base.PrefRegister.instance();

            for i = 1:length(props)
                prop = props(i);
                if contains('Base.Pref',superclasses(prop.DefaultValue))
                    assert(~strcmp(prop.GetAccess,'private')&&~strcmp(prop.SetAccess,'private'),...
                        sprintf('Class-based pref ''%s'' cannot have set/get access private.',prop.Name));
                    obj.(prop.Name).property_name = prop.Name; % Useful for callbacks
                    % Add listeners to get and set so we can swap the value
                    % in/out behind the scenes. All listeners relate to
                    % this object, so no need to clean them up.
                    assert(isempty(prop.GetMethod),...
                        ['Cannot use get methods with class-based prefs!\n',...
                         'Instead use the callback methods available in the class-based pref.']);
                    assert(isempty(prop.SetMethod),...
                        ['Cannot directly use set methods with class-based prefs! Please modify:', 10,...
                         '    `function set.<property_name>(obj, val)` ==>', 10,...
                         '    `function val = set_<property_name>(obj, val, ~)`', 10,...
                         'and set `val = obj.<property_name>` at the end of the function.']);
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
                    obj.set_meta_pref(prop.Name, pref);

                    pr.addPref(obj, pref);
                end
            end
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
            assert(ismember(name,allowed_names),sprintf(...
                'You may only set meta prefs for properties that were defined with them:\n%s',...
                strjoin(allowed_names,', ')));
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
            end
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
    methods(Access = private)
        function prop_listener_ctrl(obj,name,enabled)
            % name: string name of property
            % enabled: true/false

            % Asserts were taking a while...
%             assert(isprop(obj,name),sprintf('No appropriate method, property, or field ''%s'' for class ''%s''.',name,class(obj)))
%             assert(isfield(obj.ls,name),sprintf('''%s'' is not a class-based pref.',name))
%             for i = 1:4 % Disable this prop's listeners
%                 obj.ls.(name)(i).Enabled = enabled;
%             end

            listeners = obj.ls.(name);
            for i = 1:4 % Disable this prop's listeners
%                 listeners(i).Enabled = enabled;
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

%             [obj.ls.(name).Enabled]
%             [enabled enabled enabled enabled]
%             [obj.ls.(name).Enabled] = [enabled enabled enabled enabled];
%             obj.ls_enabled.(name) = enabled;
        end
    end

    methods(Access = private)
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

    methods (Hidden, Access=?Base.Pref)         
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
            obj.(prop.Name) = obj.temp_prop.(prop.Name).value;
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
                new_val.value = val; % validation occurs here
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
            
            event.EventName = 'PreSet'; % pre() =====

            event.EventName = 'PreGet';

            obj.prop_listener_ctrl(prop.Name,false);
            % Stash prop
            obj.temp_prop.(prop.Name) = obj.(prop.Name);
            obj.(prop.Name) = obj.temp_prop.(prop.Name).value;
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
                new_val.getEvent = true;
                new_val.value = obj.(prop.Name); % validation occurs here
                new_val.getEvent = false;

                obj.execute_external_ls(prop,event); % Execute any external listeners

                if ~nanisequal(new_val.value, obj.(prop.Name)) % Update if external_ls changed it
                    % This should now be interpreted as a set event
                    new_val.value = obj.(prop.Name); % validation occurs here
                end
            catch err
            end
            
            val = new_val.value;    % The line that returns the value;

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

end
