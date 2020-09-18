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
    %       set* - syntax: val = set(val, pref)
    %       custom_validate* - syntax: custom_validate(val, pref)
    %       custom_clean* - syntax: val = custom_clean(val, pref)
    %       ui - class specifying UI type (value class)
    %   * These properties' values are function handles, or if you want a class
    %   method bound to your instance, specify the string names of the methods.
    %   (The binding happens in the pref's "bind" method)
    %
    % Subclass properties should follow the same syntax when defining
    % settable properties:
    %   {default_value, validation_function_handle}
    %
    % The syntax for the custom methods:
    %   value = set(value)
    %   custom_validate(value);
    %       should throw error if invalid
    %   value = custom_clean(value);
    %       send val to a device, and grab the device's actual val or escaping
    %       characters to avoid sql injection
    %   NOTE: if specified as a string, thus binding them to an instance,
    %   the first argument will be the module's object (as usual)
    %
    % When building/interacting with UI, it is recommended to use the wrapping methods
    %   defined here (some may take care of adding additional input):
    %       val = obj.get_ui_value()
    %       obj.set_ui_value(val)
    %       [obj,height_px,label_width_px] = obj.make_UI(parent, yloc_px, width_px)
    %       obj.link_callback(callback)
    %       obj.adjust_UI(suggested_label_width_px, margin)
    %
    %   When linking the callback, this wrapper will inject itself as the last
    %       argument: {callback, obj}
    %
    % Because MATLAB generates default properties only once, this must be a
    %   value class instead of a handle class to avoid persistent memory between
    %   instantiations, but not between sessions (e.g. we can't replace current pref
    %   architecture with this)
    
    properties % getEvent: Avoid calling custom_* methods when "getting" unless altered by a get listener
        value
    end
    properties(Abstract,Hidden)
        ui; % The class governing the UI
        default; % NOTE: goes through class validation function, so not treated
    end
    properties(Hidden)
    	getEvent = false;   % This is reserved for pref_handler.post to avoid calling set methods on a get event
    end
    properties(Access=private)
        initialized = false;
    end
    properties % Set by pref_handler constructor
        property_name = {'', @(a)validateattributes(a,{'char'},{'vector'})};
    end
    properties % {default, validation function}
        name = {'', @(a)validateattributes(a,{'char'},{'vector'})};
        units = {'', @(a)validateattributes(a,{'char'},{'vector'})};
        help_text = {'', @(a)validateattributes(a,{'char'},{'vector'})};
        % If true, sets GUI control to not be enabled
        readonly = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};
        % If true, this is only used for display, and not saved as a pref   
        display_only = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};
        % Used by Base.pref_handler to handle non class-based prefs
        auto_generated = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};
        % optional functions supplied by user (function or char vector; validated in set methods)
        %   Called directly after built-in validation
        custom_validate = {[], @(a)true};
        %   Called directly after built-in clean
        custom_clean = {[], @(a)true};
        % First things called before any validation
        set = {[], @(a)true};
    end
    
    methods % May be overloaded by subclass pref
        function obj = pref(varargin)
            obj = obj.init(varargin{:});
        end
        function obj = bind(obj,module_instance)
            % This method is called when the meta-pref is set in
            % pref_handler. It is intended to give the pref an opportunity
            % to bind a method of the module_instance.
            % Can also use to check/verify input/output
            mc = metaclass(module_instance);
            methods = mc.MethodList;
            avail_methods = {'set','custom_validate','custom_clean'};
            argouts = [1,0,1];
            for j = 1:length(avail_methods)
                if ~isempty(obj.(avail_methods{j}))
                    if ischar(obj.(avail_methods{j}))
                        fnstring = obj.(avail_methods{j});
                        mmethod = methods(strcmp(fnstring,{methods.Name}));
                        assert(~isempty(mmethod),sprintf('Could not find "%s" in "%s"',...
                            fnstring, class(module_instance)));
                        nout = mmethod.OutputNames;
                        if ismember('varargout',nout)
                            nout = -1;
                        else
                            nout = length(nout);
                        end
                        nin = mmethod.InputNames;
                        if ismember('varargin',nin)
                            nin = 2; % Doesn't matter, so make pass assertion below
                        else
                            nin = length(nin);
                        end
                        if mmethod.Static
                            fn = str2func(sprintf('%s.%s',class(module_instance),fnstring));
                            obj.(avail_methods{j}) = fn;
                        else
                            nin = nin - 1; % Exclude obj
                            fn = str2func(fnstring);
                            obj.(avail_methods{j}) = @(val,obj)fn(module_instance,val,obj);
                        end
                        fnstring = sprintf('%s.%s',class(module_instance),fnstring);
                    else
                        nout = nargout(obj.(avail_methods{j})); % neg values mean varargout
                        nin = nargin(obj.(avail_methods{j}));
                        fnstring = func2str(obj.(avail_methods{j}));
                    end
                    nout = abs(nout); % we can assume varargout has at least one output
                    assert(nout>=argouts(j),sprintf(...
                        'prefs require %s methods to output the set value\n\n  "%s" has %i outputs',...
                        (avail_methods{j}),fnstring,nout))
                    assert(nin==2,sprintf(...
                        'prefs require %s methods to take in val and pref\n\n  "%s" has %i inputs',...
                        (avail_methods{j}),fnstring,nin))
                end
            end
        end
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
        function [obj,height_px,label_width_px] = make_UI(obj,varargin)
            % This wraps ui.make_UI; careful overloading
            [obj.ui,height_px,label_width_px] = obj.ui.make_UI(obj,varargin{:});
        end
        function obj = link_callback(obj,callback)
            % This wraps ui.link_callback; careful overloading
            obj.ui.link_callback({callback,obj});
        end
        function obj = adjust_UI(obj,varargin)
            % This wraps ui.adjust_UI; careful overloading
            obj.ui.adjust_UI(varargin{:});
        end
    end

    methods(Sealed)
        function val = get_validated_ui_value(obj)
            % Note this is an extra layer primarily for backwards compatibility
            % such that non class-based prefs will still call validation methods
            % when they are used from the UI.
            val = obj.get_ui_value;
            obj.validate(val);
        end
        function obj = init(obj,varargin)
            try % Try is to throw all errors as caller
            % Process input (subclasses should use set methods to validate)
            p = inputParser;
            % Go through all public properties (removing value and Abstract ones)
            props = properties(obj);
            props = props(~ismember(props,{'value','default','ui'}));
            nprops = length(props);
            % If user supplied odd number of inputs, then we expect the
            % call syntax to be: subclass(default,property1,value1,...);
            if mod(length(varargin),2)
                default_in_parser = false;
                default = varargin{1}; %#ok<*PROPLC>
                varargin(1) = [];
            else % subclass(property1,value1,...); (where default could be a property)
                default_in_parser = true;
                % Default gets set to value at end of function, so will go through 
                % the validate method; no validation necessary here
                addParameter(p,'default',obj.default);
            end
            mc = metaclass(obj);
            mps = mc.PropertyList;
            for i = 1:nprops % Need to bypass get methods using the metaprop
                mp = mps(strcmp(props{i},{mps.Name}));
                assert(mp.HasDefault && iscell(mp.DefaultValue) && length(mp.DefaultValue)==2,...
                    'Default value of "%s" should be cell array: {default, validation_function}',props{i});
                addParameter(p,props{i},mp.DefaultValue{1},mp.DefaultValue{2});
            end
            parse(p,varargin{:});
            if default_in_parser
                default = p.Results.default;
            end
            % Assign props
            for i = 1:nprops
            	obj.(props{i}) = p.Results.(props{i});
            end
            % Finally assign default (dont ignore if empty, because
            % subclass might have validation preventing empty, in which
            % case we should error
            obj.value = default;
            catch err
                throwAsCaller(err);
            end
            obj.initialized = true;
        end
    end
    methods
        function summary = validation_summary(obj,indent,varargin)
            % Used to construct more helpful error messages when validation fails
            % Displays all properties that aren't hidden or defined in
            % Base.pref or a superclass thereof. It will also ignore the
            % "ui" abstract property.
            % The varargin inputs are useful if you want to use a different
            % property value for a particular property. For example, if
            % there is an input 'prop1:prop2', the help text that is
            % displayed will show the name of prop1 and the value of prop2.
            % If prop1 doesn't exist or wouldn't normally be shown, that
            % input does nothing.
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
            n = length(varargin);
            swap.names = arrayfun(@(~)'',1:n,'uniformoutput',false);
            swap.vals = arrayfun(@(~)'',1:n,'uniformoutput',false);
            for i = 1:n
                temp = strsplit(varargin{i},':');
                assert(length(temp)==2, 'Swapping properties should be formatted ''prop1:prop2''.');
                assert(~ismember(temp{1},swap.names),'Can only have a prop appear once on lh side of '':''.');
                swap.names{i} = temp{1};
                swap.vals{i} = temp{2};
            end
            for i = 1:length(summary)
                name = props(i).Name;
                val = obj.(props(i).Name);
                mask = ismember(name, swap.names);
                if any(mask)
                    val = obj.(swap.vals{mask});
                end
                if isnumeric(val) || islogical(val)
                    summary{i} = sprintf('%s: %g',summary{i},val);
                elseif iscell(val)
                    summary{i} = sprintf('%s: %s',summary{i},strjoin(val,'|'));
                else % characters/strings
                    summary{i} = sprintf('%s: %s',summary{i},val);
                end
            end
            summary = strjoin(summary,newline);
        end
        function obj = set.custom_validate(obj,val)
            if ~isempty(val)
                assert(isa(val,'function_handle')||ischar(val),...
                    'Custom validate function must be function_handle or char vector');
            end
            obj.custom_validate = val;
        end
        function obj = set.custom_clean(obj,val)
            if ~isempty(val)
                assert(isa(val,'function_handle')||ischar(val),...
                    'Custom clean function must be a function_handle or char vector');
            end
            obj.custom_clean = val;
        end
        function obj = set.set(obj,val)
            if ~isempty(val)
                assert(isa(val,'function_handle')||ischar(val),...
                    'Custom set function must be a function_handle or char vector');
            end
            obj.set = val;
        end
        function obj = set.value(obj,val)
            if ~obj.getEvent
                if ~isempty(obj.set) && obj.initialized %#ok<*MCSUP>
                    val = obj.set(val,obj);
                end
                obj.validate(val);
                if ~isempty(obj.custom_validate) && obj.initialized
                    obj.custom_validate(val,obj);
                end
                val = obj.clean(val);
                if ~isempty(obj.custom_clean) && obj.initialized
                    val = obj.custom_clean(val,obj);
                end
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