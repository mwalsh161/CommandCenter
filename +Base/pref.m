classdef pref % value class
    %PREF Superclass for pref properties.
    %   AVAILABLE PROPERTIES TO SET (Defined here):
    %       default (or as first argument)
    %       name - provide more context
    %       units - provide units if applicable
    %       help_text - provide longer text to describe what this pref does (think tooltip)
    %       set*
    %       custom_validate*
    %       custom_clean*
    %   * These properties' values are function handles, or if you want a class
    %   method bound to your instance, specify the string names of the methods.
    %
    % Default call syntax:
    %    subclass(default,property1,value1,property2,value2,...);
    %    subclass(property1,value1,...,'default',DEFAULT_VALUE,...);
    %    subclass(property1,value1,property2,value2,...); default will then
    %       be up to the subclass
    %    NOTE: empty values are ignored unless they are the default value;
    %       e.g. subclass('prop1',[]) is equivalent to subclass()
    %
    % The syntax for the custom methods:
    %   value = set(value)
    %   custom_validate(value);
    %       should throw error if invalid
    %   value = custom_clean(value);
    %       send val to a device, and grab the device's actual val or escaping
    %       characters to avoid sql injection
    %   NOTE: if specified as a string, thust binding them to an instance,
    %   the first argument will be the module's object (as usual)
    %
    % Because MATLAB generates default properties only once, this must be a
    %   value class instead of a handle class to avoid persistent memory between
    %   instantiations, but not between sessions (e.g. we can't replace current pref
    %   architecture with this)
    
    properties(AbortSet) % Avoids calling custom_* methods when "getting" unless altered by a get listener
        value
    end
    properties
        name
        units
        help_text
        auto_generated = false; % Used by Base.pref_handler to handle non class-based prefs
        default = []; % Allows subclass to provide default value when user does not supply it
        % optional functions supplied by user (subclasses should allow
        % setting in constructor)
        custom_validate   % Called directly after built-in validation
        custom_clean      % Called directly after built-in clean
        set               % First thing called before any validation
        get
    end
    
    methods % To be overloaded by subclass pref
        % These methods are called prior to the data being set to "value"
        % start set -> validate -> clean -> complete set
        function validate(obj,val)
            % May throw an error if not valid
        end
        function val = clean(obj,val)
        end
        function ui = get_UI(obj)
            % Prepare an appropriate UI container
        end
    end

    methods
        function obj = init(obj,varargin)
            % Process input (subclasses should use set methods to validate)
            p = inputParser;
            % Go through all public properties
            mc = metaclass(obj);
            props = mc.PropertyList;
            props = props(and(ismember({props.SetAccess},{'immutable','public'}),...
                              ismember({props.GetAccess},{'immutable','public'})));
            props = props(~ismember({props.Name},{'value','default'}));
            % If user supplied odd number of inputs, then we expect the
            % call syntax to be: subclass(default,property1,value1,...);
            if mod(length(varargin),2)
                default_in_parser = false;
                default = varargin{1}; %#ok<*PROPLC>
                varargin(1) = [];
            else % subclass(property1,value1,...); (where default could be a property)
                default_in_parser = true;
                addParameter(p,'default',obj.default);
            end
            for i = 1:length(props)
                addParameter(p,props(i).Name,[]);
            end
            parse(p,varargin{:});
            % NOTE: item was removed from varargin earlier switching the parity
            if default_in_parser
                default = p.Results.default;
            end
            % Assign non-empty props
            for i = 1:length(props)
                if ~isempty(p.Results.(props(i).Name))
                    obj.(props(i).Name) = p.Results.(props(i).Name);
                end
            end
            % Finally assign default (dont ignore if empty, because
            % subclass might have validation preventing empty, in which
            % case we should error
            obj.value = default;
        end

        function obj = set.custom_validate(obj,val)
            assert(isa(val,'function_handle')||ischar(val),...
                'Custom validate function must be function_handles or strings');
            obj.custom_validate = val;
        end
        function obj = set.custom_clean(obj,val)
            assert(isa(val,'function_handle')||ischar(val),...
                'Custom clean function must be a function_handles or strings');
            obj.custom_clean = val;
        end
        function obj = set.value(obj,val)
            if ~isempty(obj.set) &&...
                    isa(obj.set,'function_handle') %#ok<*MCSUP>
                val = obj.set(val);
            end
            obj.validate(val);
            if ~isempty(obj.custom_validate) &&...
                    isa(obj.custom_validate,'function_handle')
                obj.custom_validate(val);
            end
            val = obj.clean(val);
            if ~isempty(obj.custom_clean) &&...
                    isa(obj.custom_clean,'function_handle')
                val = obj.custom_clean(val);
            end
            obj.value = val;
        end
    end
    
end