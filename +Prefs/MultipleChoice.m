classdef MultipleChoice < Base.Pref %Prefs.Numeric
    % MULTIPLECHOICE Select among a set of options.
    %   These options, set in choices, can be *anything*. This is parsed into UI by arb2string(choices).
    %   The default value is '', which corresponds to the display name
    %   empty_val, which, if allow_empty is true, is automatically prepended
    %   to choices.
    %   Similar to Prefs.String, if no default value is supplied and
    %   allow_empty is false, it will error upon instantiation.

    properties (Hidden)
        min = 1;
        max = 1;
    end

    properties (Hidden)
        default = [];
        ui = Prefs.Inputs.DropDownField;
    end
    properties
        choices = {{}, @(a)validate_or(a, {{'cell'},{'vector'}}, ...
                           {{'cell'},{'size',[0,0]}}) }
        % Note, this will error immediately unless default value supplied
        allow_empty = {true, @(a)validateattributes(a,{'logical'},{'scalar'})};
        % Value displayed for empty option
        empty_val = {'<None>', @(a)validateattributes(a,{'char'},{'vector'})};
    end
    properties (Dependent, Hidden) % Hidden hides from validationSummary
        choices_strings = {}; % Used in Prefs.Inputs.DropDownField
    end
    properties (SetAccess=immutable, Hidden)
        initialized = false;
    end

    methods
        function obj = MultipleChoice(varargin)
            obj = obj@Base.Pref(varargin{:});
%             obj = obj@Prefs.Numeric(varargin{:});
            obj.max = numel(obj.choices);
%             assert(obj.max == numel(obj.choices));
            obj.initialized = true;
        end
        function obj = set.allow_empty(obj,val)
            if obj.initialized
                assert(~val && isempty(obj.choices), 'If allow_empty is set to false, there must be at least one choice to choose from.');
            end

            obj.allow_empty = val;

            if obj.initialized
                assert(~val && ~isempty(obj.value), 'allow_empty cannot be changed if the value if the Pref.MultipleChoice is currently empty.');
            end
        end
        function obj = set.choices(obj,val)
            if obj.initialized
                assert(~isempty(val) || obj.allow_empty, 'Choice cannot be set to empty if empty is disallowed.');

                % Ensure it is of the expected shape
                if size(val,1) ~= 1
                    val = val';
                end
                obj.choices = val;

                obj.max = length(val);

                if ~obj.initialized %#ok<MCSUP>
                    return
                end
                % Make sure current value is consistent
                try
                    obj.validate(obj.value);
                catch
                    str_val = obj.arb2string({obj.value});
                    if obj.allow_empty %#ok<MCSUP>
                        obj.value = [];
                        warning('New choices in "%s" prohibit value "%s", changed to empty.',obj.name,str_val{1});
                    else
                        warning('New choices in "%s" prohibit value "%s", changing to first option.',obj.name,str_val{1});
                        obj.value = val{1};
                    end
                end
            else
                obj.choices = val;
            end
        end
        function val = get.choices_strings(obj)
            val = obj.arb2string(obj.choices);
            if obj.allow_empty
                val = [{obj.empty_val} val];
            end
        end
        function validate(obj,val)
            if isempty(val) && obj.allow_empty
                return
            end
            for i = 1:length(obj.choices)
                if isequal(val, obj.choices{i}); return; end
            end
            error('MULTIPLECHOICE:unrecognizedChoice',...
                ['Expected input to match one of these values:',...
                '\n\n%s\n\nThe input, %s, did not match any of the valid values.'],...
                obj.arb2string_join(obj.choices,', '), obj.arb2string_join({val},', '))
        end
        function val = clean(obj, val)
            if isnumeric(val)
                if isempty(val) || isnan(val) || val == 0
                    val = [];
                elseif val <= length(obj.choices) && val == round(val)
                    val = obj.choices{val};
                end
            end
        end
        function val = get_ui_value(obj)
            [~,I] = obj.ui.get_value();
            if obj.allow_empty
                if I == 1 % empty was selected
                    val = [];
                    return
                end
                I = I - 1;
            end
            val = obj.choices{I};
        end
        function obj = set_ui_value(obj,val)
            obj.validate(val);
            I = 0;
            for i = 1:length(obj.choices)
                % Arbitrary types are allowed, so need to explicitly check
                % them all rather than a strcmp or ismember call
                if isequal(val,obj.choices{i})
                    I = i; break;
                end
            end
            if obj.allow_empty
                % This should result in the above for loop failing to find
                % anything since the empty value is not stored in choices.
                % Hence, I = 0. Adding 1 gets us the empty value. If it is
                % found in the list because either 1) the user literally
                % put an empty val in their choices or 2) it was a
                % non-empty choice, we need to increment regardless to
                % "skip" the empty value position in the dropdown.
                % NOTE: this preferentially selects the user's value if
                % empty is an option.
                I = I + 1;
            end
            obj.ui.set_value(I);
        end
        function summary = validationSummary(obj,indent)
            % Swap choices to the UI values briefly for the user to see
            summary = validationSummary@Base.Pref(obj,indent,'choices:choices_strings');
        end
    end
    methods (Static)
        function strings = arb2string(strings)
            % Cell array of arbitrary MATLAB types to char vector
            for i = 1:length(strings)
                if isnumeric(strings{i}) || islogical(strings{i})
                    strings{i} = sprintf('%g',strings{i});
                elseif ~ischar(strings{i}) % Use class type instead
                    strings{i} = ['<' class(strings{i}) '>'];
                end
            end
        end
        function string = arb2string_join(choices,delim)
            % Cell array of arbitrary MATLAB types to char vector
            for i = 1:length(choices)
                if isnumeric(choices{i}) || islogical(choices{i})
                    choices{i} = sprintf('%g',choices{i});
                elseif ischar(choices{i})
                    choices{i} = ['''', choices{i}, ''''];
                else % Use class type instead
                    choices{i} = ['<' class(choices{i}) '>'];
                end
            end
            string = strjoin(choices,delim);
        end
    end

end
