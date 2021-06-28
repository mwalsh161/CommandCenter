classdef Double < Prefs.Numeric
    %DOUBLE Any numeric value

    properties (Hidden)
        default = 0;
        ui = Prefs.Inputs.CharField;
    end
    properties
        min = {-Inf, @(a)validateattributes(a,{'numeric'},{'scalar'})};
        max = {Inf, @(a)validateattributes(a,{'numeric'},{'scalar'})};

        allow_nan = {true, @(a)validateattributes(a,{'logical'},{'scalar'})};
        % Digits of precision in UI (truncated if zeros)
        display_precision = {10, @(a)validateattributes(a,{'numeric'},{'integer','positive','scalar'})};
        % Truncate actual value to display_precision
        truncate = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};
    end

    methods
        function obj = Double(varargin)
%             metaclass(obj)
            obj = obj@Prefs.Numeric(varargin{:});
%             obj.init(varargin{:});
        end
        function obj = set_ui_value(obj,val)
            obj.ui.set_value(num2str(val, obj.display_precision));
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
            if ~isnumeric(val) || ~isscalar(val)
                error('Double must be numeric and scalar.')
            end
            if ~obj.allow_nan
                assert(~isnan(val),'Attempted to set NaN. allow_nan is set to false.')
            elseif isnan(val)
                return
            end
            if val > obj.max || val < obj.min
                assert(val <= obj.max, sprintf('Cannot set value greater than max:\n  val = %f %s > %f %s.', val, obj.unit, obj.max, obj.unit))
                assert(val >= obj.min, sprintf('Cannot set value less than min:\n  val = %f %s < %f %s.', val, obj.unit, obj.min, obj.unit))
            end
        end
    end
end
