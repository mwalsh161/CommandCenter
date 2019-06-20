classdef pref_handler < handle
    %MODULE Summary of this class goes here
    %   Detailed explanation goes here
        
    properties(Access = private)
        temp_prop = struct();
        ls = struct(); % internal listeners
        external_ls;   % external listeners (addpreflistener)
    end
    events
        
    end
    methods
        % This requires SetObservable to be true, and careful use of
        % temp_prop in case a set method sets a different property. MATLAB
        % states the order listeners are executed is undefined, so there is
        % no guarantee this gets called before other listeners. CC GUI uses
        % listeners as well.
        % Cannot use set/get methods in MATLAB!
        function obj = pref_handler()
            mc = metaclass(obj);
            props = mc.PropertyList;
            props = props([props.HasDefault]);
            external_ls_struct.PreSet = {};
            external_ls_struct.PostSet = {};
            external_ls_struct.PreGet = {};
            external_ls_struct.PostGet = {};
            for i = 1:length(props)
                prop = props(i);
                if contains('Base.pref',superclasses(prop.DefaultValue))
                    % Add listeners to get and set so we can swap the value
                    % in/out behind the scenes. All listeners relate to
                    % this object, so no need to clean them up.
                    assert(isempty(prop.GetMethod)&&isempty(prop.SetMethod),...
                        ['Cannot use get/set methods with class-based prefs! ',...
                         'Instead use the callback methods available in the class-based pref.']);
                    assert(prop.GetObservable&&prop.SetObservable,...
                        sprintf('Class-based pref ''%s'' must be defined to be GetObservable and SetObservable.',prop.Name));
                    % Bind callback methods to this object if specified as strings
                    if ~isempty(obj.(prop.Name).set) && ischar(obj.(prop.Name).set)
                        fn = str2func(obj.(prop.Name).set);
                        obj.(prop.Name).set = @(val)fn(obj,val);
                    end
                    if ~isempty(obj.(prop.Name).custom_validate) && ischar(obj.(prop.Name).custom_validate)
                        fn = str2func(obj.(prop.Name).custom_validate);
                        obj.(prop.Name).custom_validate = @(val)fn(obj,val);
                    end
                    if ~isempty(obj.(prop.Name).custom_clean) && ischar(obj.(prop.Name).custom_clean)
                        fn = str2func(obj.(prop.Name).custom_clean);
                        obj.(prop.Name).custom_clean = @(val)fn(obj,val);
                    end
                    obj.ls.(prop.Name)    = addlistener(obj, prop.Name, 'PreSet',  @obj.pre);
                    obj.ls.(prop.Name)(2) = addlistener(obj, prop.Name, 'PostSet', @obj.post);
                    obj.ls.(prop.Name)(3) = addlistener(obj, prop.Name, 'PreGet',  @obj.pre);
                    obj.ls.(prop.Name)(4) = addlistener(obj, prop.Name, 'PostGet', @obj.post);
                    obj.external_ls.(prop.Name) = external_ls_struct;
                end
            end
        end
        
        function varargout = addlistener(obj,varargin)
            % el = addlistener(hSource,EventName,callback)
            % el = addlistener(hSource,PropertyName,EventName,callback)
            varargout = {};
            if nargin == 4 && isfield(obj.external_ls,varargin{1}) % externals_ls field names are all pref properties
                error('addlistener not supported for prefs. Use addpreflistener instead');
            else
                el = addlistener@handle(obj,varargin{:});
                if nargout
                    varargout = {el};
                end
            end
        end
        
        function varargout = addpreflistener(obj,PropertyName,EventName,callback)
            % ID = addpreflistener(hSource,PropertyName,EventName,callback)
            % Very similar to addlistener, but returns an ID instead of a
            % listener object. This ID can be used to remove the listener.
            % Will not be recursive; executed when obj.ls are all disabled
            assert(isa(callback,'function_handle'),'callback for pref listener must be a function_handle');
            assert(isprop(obj,PropertyName),sprintf('The name ''%s'' is not an accessible property for an instance of class ''%s''.',PropertyName,class(obj)));
            assert(isfield(obj.external_ls,PropertyName),'addpreflistener not supported for standard properties. Use addlistener instead');
            varargout = {};
            EventName = validatestring(EventName,fields(obj.external_ls.(PropertyName)));
            ind = length(obj.external_ls.(PropertyName).(EventName)) + 1;
            for i = 1:ind-1
                if isempty(obj.external_ls.(PropertyName).(EventName){i})
                    ind = i; % First empty slot (if one was deleted)
                    break
                end
            end
            obj.external_ls.(PropertyName).(EventName){ind} = callback;
            ID = {PropertyName,EventName,ind};
            if nargout
                varargout = {ID};
            end
        end
        
        function removepreflistener(obj,ID)
            try
                % addpreflistener recycles empty slots; not a memory leak
                obj.external_ls.(ID{1}).(ID{2}){ID{3}} = [];
            catch
                error('Invalid ID supplied; nothing removed');
            end
        end

        function val = get_meta_pref(obj,name)
            % Return the "meta pref" which contains the pref class
            % NOTE: this is a value class, so changing anything in the
            % returned instance does nothing.
            % NOTE: This by-passes pref get listeners
            if isfield(obj.ls,name) % Indicates class-based pref
                obj.prop_listener_ctrl(name,false);
                val = obj.(name);
                obj.prop_listener_ctrl(name,true);
                return
            end
            % old style prefs: auto generate default type here
            val = obj.(name);
            prop = findprop(obj,name);
            if isnumeric(val) % There are many numeric classes
                val = Prefs.Double(val);
            elseif prop.HasDefault && ...
                (iscell(prop.DefaultValue) || isa(prop.DefaultValue,'function_handle'))
                if iscell(prop.DefaultValue)
                    choices = prop.DefaultValue;
                else % function handle
                    choices = prop.DefaultValue();
                end
                val = Prefs.MultipleChoice(val,'choices',choices);
            else
                switch class(val)
                    case {'char'}
                        val = Prefs.String(val);
                    case {'logical'}
                        val = Prefs.Boolean(val);
                    otherwise
                        error('Not implemented for %s',class(val))
                end
            end
            val.auto_generated = true;
        end
        
    end
    methods(Access = private)
        function prop_listener_ctrl(obj,name,enabled)
            % name: string name of property
            % enabled: true/false
            assert(isprop(obj,name),sprintf('No appropriate method, property, or field ''%s'' for class ''%s''.',name,class(obj)))
            assert(isfield(obj.ls,name),sprintf('''%s'' is not a class-based pref.',name))
            for i = 1:4 % Disable this prop's listeners
                obj.ls.(name)(i).Enabled = enabled;
            end
        end
        
        function execute_external_ls(obj,prop,event)
            for i = 1:length(obj.external_ls.(prop.Name).(event.EventName))
                if ~isempty(obj.external_ls.(prop.Name).(event.EventName){i})
                    obj.external_ls.(prop.Name).(event.EventName){i}(prop,event);
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
            try
                obj.execute_external_ls(prop,event);
            catch err
                obj.prop_listener_ctrl(prop.Name,true);
                rethrow(err)
            end
            obj.prop_listener_ctrl(prop.Name,true);
        end
        
        function post(obj,prop,event)
            % Disable other listeners on this since we will be both getting
            % and setting this prop in this method
            obj.prop_listener_ctrl(prop.Name,false);
            % Execute any external listeners
            try
                obj.execute_external_ls(prop,event);
            catch ext_err % rethrow at the end
            end
            % Update stash, then copy back to prop (get listeners can alter
            % obj.(prop.Name) as well as the obvious SetEvent does)
            new_val = obj.temp_prop.(prop.Name); % Copy in case validation fails
            try
                new_val.value = obj.(prop.Name);
            catch err
                obj.(prop.Name) = obj.temp_prop.(prop.Name);
                obj.prop_listener_ctrl(prop.Name,true);
                rethrow(err) %%% CHANGE TO CC ERROR HANDLING %%%
            end
            obj.(prop.Name) = new_val;
            obj.prop_listener_ctrl(prop.Name,true);
            if exist('ext_err','var')
                rethrow(ext_err);
            end
        end
    end
    
end