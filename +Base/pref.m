classdef pref < matlab.mixin.Heterogeneous % value class
    %PREF Superclass for pref properties.
    %    pref(default,property1,value1,property2,value2,...);
    %    pref(property1,value1,...,'default',DEFAULT_VALUE,...);
    %    pref(property1,value1,property2,value2,...); default will then
    %       be up to the subclass
    %    NOTE: empty values are ignored unless they are the default value;
    %       e.g. subclass('prop1',[]) is equivalent to subclass()
    %
    %   AVAILABLE PROPERTIES TO SET (Defined here):
    %       default (or as first argument)
    %       name - provide more context
    %       units - provide units if applicable
    %       help_text - provide longer text to describe what this pref does (think tooltip)
    %       readonly - boolean specifying if GUI control should be editable (e.g. "enabled")
    %       display_only - boolean specifying if saved as pref when module unloaded
    %       set*
    %       custom_validate*
    %       custom_clean*
    %   * These properties' values are function handles, or if you want a class
    %   method bound to your instance, specify the string names of the methods.
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
        readonly = false;       % If true, sets GUI control to not be enabled
        display_only = false;   % If true, this is only used for display, and not saved as a pref
        auto_generated = false; % Used by Base.pref_handler to handle non class-based prefs
        default = []; % Allows subclass to provide default value when user does not supply it
        % optional functions supplied by user (subclasses should allow
        % setting in constructor)
        custom_validate   % Called directly after built-in validation
        custom_clean      % Called directly after built-in clean
        set               % First thing called before any validation
        get
    end
    
    methods % To be overloaded by subclass pref (note this is a value class; need to explicitly pass obj)
        % These methods are called prior to the data being set to "value"
        % start set -> validate -> clean -> complete set
        function validate(obj,val)
            % May throw an error if not valid
        end
        function val = clean(obj,val)
        end
        % These methods are responsible for building the settings UI
        function [ui,height_px,label_width_px] = make_UI(obj,parent,yloc_px,width_px)
            % Prepare an appropriate UI container in parent no lower than yloc_px
            %   and no wider than width_px (parent width) and return:
            %   ui: matlab type containing UI data (passed to obj.adjust_UI)
            %   height_px: extent of UI constructed (not including any padding)
            %   label_width_px: the width of an optional label component. Used
            %       to justify all labels in adjust_UI. Return 0 if not needed.
            
        end
        function adjust_UI(obj,ui,suggested_label_width_px)
            % Once Module.settings calls all get_UI methods, it will go back
            % and call this method using a suggested label_width_px giving this
            % pref the opportunity to readjust positions if desired
        end
    end

    methods
        function obj = init(obj,varargin)
            % Process input (subclasses should use set methods to validate)
            p = inputParser;
            % Go through all public properties (removing value and default)
            props = properties(obj);
            props = props(~ismember(props,{'value','default'}));
            nprops = length(props);
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
            for i = 1:nprops
                addParameter(p,props{i},[]);
            end
            parse(p,varargin{:});
            if default_in_parser
                default = p.Results.default;
            end
            % Assign non-empty props
            for i = 1:nprops
                if ~isempty(p.Results.(props{i}))
                    obj.(props{i}) = p.Results.(props{i});
                end
            end
            % Finally assign default (dont ignore if empty, because
            % subclass might have validation preventing empty, in which
            % case we should error
            obj.value = default;
        end
        function summary = validation_summary(obj,indent)
            % Used to construct more helpful error messages when validation fails
            mc = metaclass(obj);
            props = mc.PropertyList([mc.PropertyList.DefiningClass]==mc);
            longest_name = max(cellfun(@length,{props.Name}))+indent;
            summary = pad({props.Name},longest_name,'left');
            for i  =1:length(summary) % integers of floats
                if isnumeric(obj.(props(i).Name)) || islogical(obj.(props(i).Name))
                    summary{i} = sprintf('%s: %g',summary{i},obj.(props(i).Name));
                else % characters/strings
                    summary{i} = sprintf('%s: %s',summary{i},obj.(props(i).Name));
                end
            end
            summary = strjoin(summary,newline);
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