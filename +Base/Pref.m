classdef Pref < matlab.mixin.Heterogeneous % value class
    %PREF Superclass for Pref properties.
    %    Pref(DEFAULT_VALUE,property1,value1,property2,value2,...);
    %    Pref(property1,value1,...,'default',DEFAULT_VALUE,...);
    %    Pref(property1,value1,property2,value2,...); default will then
    %       be up to the subclass
    %    NOTE: empty values are ignored unless they are the default value;
    %       e.g. subclass('prop1',[]) is equivalent to subclass()
    %
    %   AVAILABLE PROPERTIES TO SET (Defined here):
    %       default (or as first argument)
    %       name - provide more context
    %       unit - provide units if applicable
    %       help_text - provide longer text to describe what this Pref does (think tooltip)
    %       readonly - boolean specifying if GUI control should be editable (e.g. "enabled")
    %       display_only - boolean specifying if saved as Pref when module unloaded
    %       set* - syntax: val = set(val, pref)
    %       get* - syntax: val = get(val, pref)
    %       custom_validate* - syntax: custom_validate(val, pref)
    %       custom_clean* - syntax: val = custom_clean(val, pref)
    %       ui - class specifying UI type (value class)
    %   * These properties' values are function handles, or if you want a class
    %   method bound to your instance, specify the string names of the methods.
    %   (The binding happens in the Pref's "bind" method)
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
    %   instantiations, but not between sessions (e.g. we can't replace current Pref
    %   architecture with this)

    properties (Hidden, SetAccess={?Base.Module, ?Base.Input, ?Base.Pref, ?Base.Reference})
        value = NaN;                        % The property at the heart of it all: value that we are controlling.
    end
    
    
    properties (Abstract, Hidden)
        ui;                                 % The class governing the UI
        default;                            % NOTE: goes through class validation function, so not treated
    end
    properties (Hidden, Access=private)
        initialized = false;                % Flag to prevent the Pref from being used until it has been fully constructed.
    end

    properties (Hidden)     % Used by Pref and Module so Pref can retain access to Module. Set in Base.Pref.bind(Module)
        read_fn     = [];                   % Calls val = Module.readProp(prop), with the appropriate arguments already filled in.
        writ_fn     = [];                   % Calls tf = Module.writProp(prop, val), with the appropriate arguments already filled in.

        listen_fn   = [];                   % Calls Module.addlistener(prop, event, callback), with the appropriate arguments already filled in.
    end
    properties (Hidden, SetAccess={?Base.Pref, ?Base.PrefRegister, ?Drivers.NIDAQ.out, ?Base.Sweep})
        parent = [];
    end
    properties (Hidden, SetAccess={?Base.Pref, ?Base.Module, ?Drivers.NIDAQ.out, ?Base.Sweep})
        property_name = '';                 % Name of the property (variable) in Module that this Pref fondles.
    end

    properties % {default, validation function}
        name = {'', @(a)validateattributes(a,{'char'},{'vector'})};
        unit = {'', @(a)validateattributes(a,{'char'},{'vector'})};
    end

    properties %(Hidden) %, SetAccess = ?Base.Module)
        help_text = {'', @(a)validateattributes(a,{'char'},{'vector'})};
    end
    
    properties
        % If true, sets GUI control to not be enabled
        readonly = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};
        % If true, this is only used for display, and not saved as a pref
        display_only = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};
        % Used by Base.Module to handle non class-based prefs
        auto_generated = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};
        % optional functions supplied by user (function or char vector; validated in set methods)
        %   Called directly after built-in validation
        custom_validate = {[], @(a)true};
        %   Called directly after built-in clean
        custom_clean = {[], @(a)true};
        % First things called before any validation
        get = {[], @(a)true};
        set = {[], @(a)true};
    end

    methods % May be overloaded by subclass pref
        function obj = Pref(varargin)
            obj = obj.init(varargin{:});
        end
        function obj = bind(obj,module_instance)
            % This method is called when the meta-pref is set in
            % Module. It is intended to give the Pref an opportunity
            % to bind a method of the module_instance.
            % Can also use to check/verify input/output
%             obj.parent_class = class(module_instance);
            obj.parent = module_instance;
            
%             if isa(obj, 'Base.Measurement') % This needs to be after pref is initialized and filled with property_name, but before it is fully bound.
%                 obj.sizes = struct(obj.property_name, [1 1]);
%                 obj.names = struct(obj.property_name, obj.name);
%                 obj.units = struct(obj.property_name, obj.unit);
%                 obj.scans = struct();   % 1 x 1 data doesn't need scans or dims.
%                 obj.dims =  struct();
%             end

%             class(obj)
%             mc = metaclass(obj)
%             mc
%             props = mc.PropertyList
%             props.Name
            
            if isa(obj, 'Base.Measurement') % This needs to be after pref is initialized and filled with property_name, but before it is fully bound.
%                 obj.measurements = 
                    m = Base.Meas([1 1], ...
                        'field', obj.property_name, ...
                        'name', obj.name, ...
                        'unit', obj.unit);
                    obj.measurements = m;
%                     obj.set_measurements(m);
                
%                 struct(obj.property_name, [1 1]);
%                 obj.names = struct(obj.property_name, obj.name);
%                 obj.units = struct(obj.property_name, obj.unit);
%                 obj.scans = struct();   % 1 x 1 data doesn't need scans or dims.
%                 obj.dims =  struct();
            end
            
            if isa(obj, 'Prefs.Time')
                return
            end
            
            mc = metaclass(module_instance);

            props = mc.PropertyList;

            for i = 1:length(props)
                if strcmp(props(i).Name, obj.property_name)
                    obj.read_fn =       @()(module_instance.readProp(props(i)));
                    obj.writ_fn =       @(val)(module_instance.writProp(props(i), val));
                    obj.listen_fn =     @(event, callback)(module_instance.addlistener(obj.property_name, event, callback));
                end
            end

            methods = mc.MethodList;

            avail_methods = {'get', 'set','custom_validate','custom_clean'};
            argouts = [1,1,0,1];

            for j = 1:length(avail_methods)
                if j == 1 && isempty(obj.(avail_methods{j}))                % If no function is given for 'set'...
                    fnstring = [avail_methods{j} '_' obj.property_name];    % Look for `set_prop` functions which were converted from `set.prop`.
                    mmethod = methods(strcmp(fnstring,{methods.Name}));

                    if ~isempty(mmethod)
                        obj.(avail_methods{j}) = fnstring;
                    end
                end

                if ~isempty(obj.(avail_methods{j}))
                    if ischar(obj.(avail_methods{j}))
                        fnstring = obj.(avail_methods{j});
                        mmethod = methods(strcmp(fnstring,{methods.Name}));
                        assert(~isempty(mmethod), sprintf('Could not find "%s" in "%s", which is assigned as the %s method for %s.',...
                            fnstring, class(module_instance), avail_methods{j}, obj.property_name));
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
                            
                            if strcmp(avail_methods{j}, 'get')  % get takes only pref.
                                obj.(avail_methods{j}) = @(obj)fn(module_instance,obj);
                            else                                % set and related takes val and pref.
                                obj.(avail_methods{j}) = @(val,obj)fn(module_instance,val,obj);
                            end
                        end
                        fnstring = sprintf('%s.%s',class(module_instance),fnstring);
                    else
                        nout = nargout(obj.(avail_methods{j})); % neg values mean varargout
                        nin = nargin(obj.(avail_methods{j}));
                        fnstring = func2str(obj.(avail_methods{j}));
                    end

                    nout = abs(nout); % we can assume varargout has at least one output
                    assert(nout>=argouts(j),sprintf(...
                        'Prefs require %s methods to output the set value\n\n  "%s" has %i outputs',...
                        (avail_methods{j}),fnstring,nout))
                    if strcmp(avail_methods{j}, 'get')  % get takes only pref.
                        assert(nin==1,sprintf(...
                            'Prefs require %s methods to take in Pref\n\n  "%s" has %i inputs',...
                            (avail_methods{j}),fnstring,nin))
                    else                                % set and related takes val and pref.
                        assert(nin==2,sprintf(...
                            'Prefs require %s methods to take in val and Pref\n\n  "%s" has %i inputs',...
                            (avail_methods{j}),fnstring,nin))
                    end
                end
            end
            
            pr = Base.PrefRegister.instance();
                    
            pr.addPref(module_instance, obj);
        end
        
        function tf = isnumeric(~)
            tf = false;
        end
        function tf = isequal(obj, obj2)
            superclasses(obj2)
            tf = ismember('Base.Pref', superclasses(obj2)) && strcmp(obj.property_name, obj2.property_name) && isequal(obj.parent, obj2.parent);
        end
        
        % These methods are called prior to the data being set to "value"
        % start set -> validate -> clean -> complete set
        function validate(obj,val) %#ok<INUSD>
            % May throw an error if not valid
        end
        function val = clean(obj,val) %#ok<INUSL>
            % May throw an error if not valid
        end
    end
    methods(Hidden)
        % Function (and inverse) to transform the value of the pref into something that can be saved, then recovered.
        function saved = encodeValue(~, data)
            if ismember('Base.Pref',superclasses(data))
                % THIS SHOULD NOT HAPPEN, but haven't figured
                % out why it does sometimes yet
                data = data.value;
%                 warning('Listener for %s seems to have been deleted before savePrefs!',obj.prefs{i});
            end
            saved = data;
        end
        function [data, obj] = decodeValue(obj, saved)
            data = saved;
        end
        
        % Function (and inverse) to transform the pref itself into something that can be saved, then recovered.
        function identity = encode(obj)
            identity = struct('parent', obj.parent.encode(), 'pref', obj.property_name);
        end
    end
    methods(Static, Hidden)
        function obj = decode(identity)
            assert(isfield(identity, 'parent'))
            assert(isfield(identity, 'pref'))
            
            try
                parent = Base.Module.decode(identity.parent);
                obj = parent.get_meta_pref(identity.pref);
            catch err
                warning(err.message)
                obj = [];
            end
        end
    end
    methods(Sealed)
        function val = get_validated_ui_value(obj)
            % Note this is an extra layer primarily for backwards compatibility
            % such that non class-based Prefs will still call validation methods
            % when they are used from the UI.
            val = obj.get_ui_value;
            obj.validate(val);
        end
        function obj = init(obj,varargin)
            try % Try is to throw all errors as caller
                % Process input (subclasses should use set methods to validate)
                p = inputParser;

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

                % Go through all public properties (removing Hidden and Abstract ones)
                mc = metaclass(obj);
                mps = mc.PropertyList;
                nprops = length(mps);
                for ii = 1:nprops % Need to bypass get methods using the metaprop
                    mp = mps(ii);
%                     mp
%                     mp.DefiningClass
                    if ~mp.Hidden && ~mp.Abstract && ~mp.Constant
                        assert(mp.HasDefault && iscell(mp.DefaultValue) && length(mp.DefaultValue)==2,...
                            'Default value of "%s" should be cell array: {default, validation_function}',mp.Name);
                        addParameter(p,mp.Name,mp.DefaultValue{1},mp.DefaultValue{2});
                    end
                end
                
                parse(p,varargin{:});
                
                if default_in_parser
                    default = p.Results.default;
                end

                % Assign props
                for ii = 1:nprops
                    mp = mps(ii);
                    if ~mp.Hidden && ~mp.Abstract && ~mp.Constant
                        obj.(mp.Name) = p.Results.(mp.Name);
                    end
                end

                % Finally assign default (dont ignore if empty, because
                % subclass might have validation preventing empty, in which
                % case we should error
                obj.value = default;

            catch err
                rethrow(err);
            end
            obj.initialized = true;
        end
    end
    
    methods % UI Stuff
        % This provides on opportunity to format or add to help_text
        % property upon creation. It is called via get.help_text, meaning
        % it will not be bypassed when retrieving obj.help_text.
        % NOTE: https://undocumentedmatlab.com/blog/multi-line-tooltips
        function text = get_help_text(obj,~)
%             try
                summary_text = obj.validationSummary(2);
                if isempty(summary_text)
                    summary_text = '  None'; % indent 2
                end
                summary_text = strrep(summary_text,'>','&gt;');
                summary_text = strrep(summary_text,'<','&lt;');
                if ~isempty(obj.help_text)
                    text = sprintf('<html>%s<br/><pre><font face="courier new" color="blue">Properties:<br/>%s</font>',...
                                     obj.help_text, summary_text);
                else
                    text = sprintf('<html><pre><font face="courier new" color="blue">Properties:<br/>%s</font>',...
                                     summary_text);
                end
                if obj.auto_generated
                    text = [text '<br/><font color="red">This pref was auto generated and deprecated. Consider replacing with class-based pref.</font>'];
                end
                text = strip(strrep(text, newline, '<br/>'));
%             catch err
%                 if isempty(obj.help_text)
%                     text = sprintf('<html><font color="red">%s</font>',...
%                         getReport(err, 'basic'));
%                 else
%                     text = sprintf('<html>%s\n<font color="red">%s</font>',...
%                         obj.help_text, getReport(err, 'basic'));
%                 end
%                 text = strrep(text, newline, '<br/>');
%             end
        end
        function label = get_label(obj)
            % Uses the ui object to make a label (usually '<name> [<unit>]' pair)
%             label = obj.ui.get_label(obj);
            str = strrep(obj.name, '_', ' ');

            if isempty(str)
                str = strrep(obj.property_name, '_', ' ');
            end

            if ~isempty(obj.unit)
                label = sprintf('%s [%s]', str, obj.unit);
            else
                label = str;
            end
        end
        
        % These methods are used to get/set the value and cast it to the
        % correct type before returning. This does not need to validate or
        % clean further!
        % If this cannot be performed, throw an error with error ID set to
        % 'SETTINGS:bad_ui_val'
        function val = get_ui_value(obj)
            val = obj.ui.get_value();
        end
        function obj = set_ui_value(obj,val)
            % Note: not required that val == obj.value
            obj.ui.set_value(val);
        end
        function obj = link_callback(obj,callback)
            % This wraps ui.link_callback; careful overloading
            obj.ui.link_callback({callback,obj});
        end
        
        function [obj,height_px,label_width_px] = make_UI(obj,varargin)
            % This wraps ui.make_UI; careful overloading
            [obj.ui,height_px,label_width_px] = obj.ui.make_UI(obj,varargin{:});
        end
        function obj = adjust_UI(obj,varargin)
            % This wraps ui.adjust_UI; careful overloading
            obj.ui.adjust_UI(varargin{:});
        end
    end
    
    methods     % Get and set methods
        function summary = validationSummary(obj,indent,varargin)
            % Used to construct more helpful error messages when validation fails
            % Displays all properties that aren't hidden or defined in
            % Base.Pref or a superclass thereof. It will also ignore the
            % "ui" abstract property.
            % The varargin inputs are useful if you want to use a different
            % property value for a particular property. For example, if
            % there is an input 'prop1:prop2', the help text that is
            % displayed will show the name of prop1 and the value of prop2.
            % If prop1 doesn't exist or wouldn't normally be shown, that
            % input does nothing.
            mc = metaclass(obj);
            ignore_classes = superclasses('Base.Pref');
            ignore_classes = [ignore_classes ,{'Base.Pref'}];
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
        
        % Functions for changing the validation/clean methods
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
        
        % Functions for changing the methods to write (set) and read (get) the hardware.
        function obj = set.set(obj,val)
            if ~isempty(val)
                assert(isa(val,'function_handle')||ischar(val),...
                    'Custom set function must be a function_handle or char vector');
            end
            obj.set = val;
        end
        function obj = set.get(obj,val)
            if ~isempty(val)
                assert(isa(val,'function_handle')||ischar(val),...
                    'Custom set function must be a function_handle or char vector');
            end
            obj.get = val;
        end
        
        % Functions that actually write (set) and read (get) the hardware, with overhead.
%         function obj = set.value(obj, val)
%             [obj, obj.value] = obj.set_value(val);
%         end
%         function val = get.value(obj)
%             val = obj.get_value(obj.value);
%         end
        function val = set_value(obj, val)
            val = obj.clean(val);
            if ~isempty(obj.custom_clean) && obj.initialized
                val = obj.custom_clean(val,obj);
            end

            obj.validate(val);
            if ~isempty(obj.custom_validate) && obj.initialized
                obj.custom_validate(val,obj);
            end

            if ~isempty(obj.set) && obj.initialized %#ok<*MCSUP>
                val = obj.set(val,obj);
            end

            obj.validate(val);
            if ~isempty(obj.custom_validate) && obj.initialized
                obj.custom_validate(val,obj);
            end
        end
        function val = get_value(obj, val)
            if ~isempty(obj.get) && obj.initialized %#ok<*MCSUP>
                val = obj.get(obj);
            end
        end
        
        % Functions to use when one has access to the pref, but nothing else.
        function val = read(obj)
            val = obj.read_fn();    % Add code to make sure read_fn is valid?
        end
        function tf =  writ(obj, val)
            tf = obj.writ_fn(val);
        end
        function listener = addlistener(obj, event, callback)
            listener = obj.listen_fn(event, callback);
        end
    end
end
