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
    %       ui - class specifying UI type (value class)
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
    properties(Abstract)
        ui; % The class governing the UI
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
    
    methods % May be overloaded by subclass pref
        % These methods are called prior to the data being set to "value"
        % start set -> validate -> clean -> complete set
        function validate(obj,val)
            % May throw an error if not valid
        end
        function val = clean(obj,val)
        end
        % This provides on opportunity to format or add to help_text
        % property upon creation. It is called via get.help_text, meaning
        % it will not be bypassed when retrieving obj.help_text.
        % NOTE: https://undocumentedmatlab.com/blog/multi-line-tooltips
        function text = get_help_text(obj,help_text_prop)
            summary_text = obj.validation_summary(2);
            if isempty(summary_text)
                summary_text = '  None'; % indent 2
            end
            summary_text = strrep(summary_text,'>','&gt;');
            summary_text = strrep(summary_text,'<','&lt;');
            if ~isempty(help_text_prop)
                text = sprintf('<html>%s<br/><pre><font face="courier new" color="blue">Properties:<br/>%s</font>',...
                                 help_text_prop, summary_text);
            else
                text = sprintf('<html><pre><font face="courier new" color="blue">Properties:<br/>%s</font>',...
                                 summary_text);
            end
            if obj.auto_generated
                text = [text '<br/><font color="red">This pref was auto generated and deprecated. Consider replacing with class-based pref.</font>'];
            end
            text = strip(strrep(text, newline, '<br/>'));
        end
        % These methods are used to get/set the value and cast it to the
        % correct type before returning. This does not need to validate or
        % clean further!
        % If this cannot be performed, throw an error with error ID set to
        % 'SETTINGS:bad_ui_val'
        function val = get_ui_value(obj)
            val = obj.ui.get_value();
        end
        function set_ui_value(obj,val)
            % Note: not required that val == obj.value
            obj.ui.set_value(val);
        end
    end

    methods(Sealed)
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
    end
    methods
        function summary = validation_summary(obj,indent)
            % Used to construct more helpful error messages when validation fails
            % Displays all properties that aren't hidden or defined in
            % Base.pref or a superclass thereof. It will also ignore the
            % "ui" abstract property.
            mc = metaclass(obj);
            ignore_classes = superclasses('Base.pref');
            ignore_classes = [ignore_classes ,{'Base.pref'}];
            public_props = properties(obj);
            mask = ~arrayfun(@(a)ismember(a.DefiningClass.Name,ignore_classes), mc.PropertyList) &...
                    ismember({mc.PropertyList.Name},public_props)';
            props = mc.PropertyList(mask);
            props(strcmp({props.Name},'ui')) = []; % Remove UI
            if isempty(props)
                summary = '';
                return
            end
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
        function val = get.help_text(obj)
            try
                val = obj.get_help_text(obj.help_text);
            catch err
                if isempty(obj.help_text)
                    val = sprintf('<html><font color="red">%s</font>',...
                        getReport(err, 'basic'));
                else
                    val = sprintf('<html>%s\n<font color="red">%s</font>',...
                        obj.help_text, getReport(err, 'basic'));
                end
                val = strrep(val, newline, '<br/>');
            end
        end
    end
    
end