classdef Double < Base.pref
    %DOUBLE Any numeric value
    
    properties
        ui = Prefs.Inputs.CharField;
        allow_nan = true;
        max = Inf;
        min = -Inf;
        display_precision = 10; % Digits of precision in UI (truncated if zeros)
        truncate = false; % Truncate actual value to display_precision
    end
    
    methods
        function obj = Double(varargin)
            obj.default = 0;
            obj = obj.init(varargin{:});
        end
        function set_ui_value(obj,val)
            obj.ui.set_value(num2str(val,obj.display_precision));
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