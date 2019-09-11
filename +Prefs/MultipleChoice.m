classdef MultipleChoice < Base.pref
    %MULTIPLECHOICE Select among a set of options
    %   The default value is '', which corresponds to the display name
    %   empty_val, which, if allow_empty is true, is automatically prepended
    %   to choices.
    %   Similar to Prefs.String, if no default value is supplied and
    %   allow_empty is false, it will error upon instantiation.
    
    properties(Hidden)
        default = [];
        ui = Prefs.Inputs.DropDownField;
    end
    properties
        choices = {{}, @iscell};
        % Note, this will error immediately unless default value supplied
        allow_empty = {true, @(a)validateattributes(a,{'logical'},{'scalar'})};
        % Value displayed for empty option
        empty_val = {'<None>', @(a)validateattributes(a,{'char'},{'vector'})};
    end
    properties(SetAccess=private,Hidden) % Hidden hides from validation_summary
        choices_strings = {}; % Used in Prefs.Inputs.DropDownField
    end
    properties(Access=private)
        dont_validate = true; % Used to bypass validation in constructor
    end
    
    methods
        function obj = MultipleChoice(varargin)
            obj = obj@Base.pref(varargin{:});
            if obj.allow_empty
                obj.choices = [{obj.empty_val} obj.choices];
            end
            obj.choices_strings = obj.arb2string(obj.choices);
            obj.dont_validate = false;
            obj.validate(obj.value); % validate
        end
        function validate(obj,val)
            if obj.dont_validate
                return
            end
            if obj.allow_empty && isempty(val)
                return
            end
            for i = 1:length(obj.choices)
                if isequal(val,obj.choices{i}); return; end
            end
            error('MULTIPLECHOICE:unrecognizedChoice',...
                ['Expected input to match one of these values:',...
                '\n\n%s\n\nThe input, %s, did not match any of the valid values.'],...
                obj.arb2string_join(obj.choices,', '), obj.arb2string_join({val},', '))
        end
        function val = get_ui_value(obj)
            [~,I] = obj.ui.get_value();
            val = obj.choices{I};
            if isequal(val,obj.empty_val)
                val = '';
            end
        end
        function set_ui_value(obj,val)
            if obj.allow_empty && isempty(val)
                val = obj.empty_val;
            end
            obj.validate(val); % Guarantees we will find it
            I = 0;
            for i = 1:length(obj.choices)
                I = I + 1;
                if isequal(val,obj.choices{i}); break; end
            end
            obj.ui.set_value(I);
        end
        function summary = validation_summary(obj,indent)
            temp = obj.choices;
            obj.choices = obj.arb2string_join(temp, ', ');
            summary = validation_summary@Base.pref(obj,indent);
            obj.choices = temp;
        end
    end
    methods(Static)
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