classdef MultipleChoice < Base.pref
    %MULTIPLECHOICE Select among a set of options
    %   The default value is empty_val, which if allow_empty is true is
    %   automatically prepended to choices.
    
    properties
        choices = {};
        allow_empty = true; % Note, this will error immediately unless default value supplied
        empty_val = '<None>'; % Value displayed for empty option
        ui = Prefs.Inputs.DropDownField;
    end
    properties(SetAccess=private,Hidden) % Hidden hides from validation_summary
        choices_strings = {}; % Used in Prefs.Inputs.DropDownField
    end
    
    methods
        function obj = MultipleChoice(varargin)
            obj.default = obj.none_val;
            obj = obj.init(varargin{:});
%             if ~obj.allow_empty
%                 obj.choices(1) = [];
%                 obj.validate(obj.value); % Re-validate
%             end
            obj.choices_strings = obj.arb2string(obj.choices);
        end
        function validate(obj,val)
            for i = 1:length(obj.choices)
                if isequal(val,obj.choices{i})
                    return
                end
            end
            error('MULTIPLECHOICE:unrecognizedChoice',...
                ['Expected input to match one of these values:',...
                '\n\n%s\n\nThe input, ''%s'', did not match any of the valid values.'],...
                obj.arb2string_join(obj.choices,', '), obj.arb2string_join({val},', '))
        end
        function val = get_ui_value(obj)
            valstr = obj.ui.get_value();
            if strcmpi(valstr,'nan')
                val = NaN;
                return
            end
            val = str2double(valstr);
            if isnan(val)
                error('SETTINGS:bad_ui_val','Cannot convert "%s" to numeric value.',valstr)
            end
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