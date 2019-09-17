classdef Double < Base.pref
    %DOUBLE Any numeric value
    
    properties(Hidden)
        default = 0;
        ui = Prefs.Inputs.CharField;
    end
    properties
        allow_nan = {true, @(a)validateattributes(a,{'logical'},{'scalar'})};
        max = {Inf, @(a)validateattributes(a,{'numeric'},{'scalar'})};
        min = {-Inf, @(a)validateattributes(a,{'numeric'},{'scalar'})};
        % Digits of precision in UI (truncated if zeros)
        display_precision = {10, @(a)validateattributes(a,{'numeric'},{'integer','positive','scalar'})};
        % Truncate actual value to display_precision
        truncate = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};
    end
    
    methods
        function set_ui_value(obj,val)
            obj.ui.set_value(num2str(val,obj.display_precision));
        end
        function val = get_ui_value(obj)
            valstr = obj.ui.get_value();
            val = str2num(valstr); %#ok<ST2NM> % str2num will evaluate expressions 
            if isempty(val) % Let validation throw the error
                val = valstr;
            end
        end
        function val = clean(obj,val)
            if obj.truncate
                val = str2double(num2str(val,obj.display_precision));
            end
        end
        function validate(obj,val)
            validateattributes(val,{'numeric'},{'scalar'})
            if ~obj.allow_nan
                assert(~isnan(val),'Attempted to set NaN. allow_nan is set to false.')
            elseif isnan(val)
                return
            end
            assert(val <= obj.max, 'Cannot set value greater than max.')
            assert(val >= obj.min, 'Cannot set value less than min.')
        end
    end
    
end