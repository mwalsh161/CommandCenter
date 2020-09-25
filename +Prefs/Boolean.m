classdef Boolean < Prefs.Numeric
    %BOOLEAN True/False data

    properties (Hidden)
        min = false;
        max = true;
    end

    properties (Hidden)
        default = false;
        ui = Prefs.Inputs.BooleanField;
    end
    properties
        allow_nan = {false, @(a)validateattributes(a,{'logical'},{'scalar'})};
    end

    methods
        function obj = Boolean(varargin)
            obj = obj@Prefs.Numeric(varargin{:});
            if isempty(obj.unit)
                obj.unit = '0/1';
            end
        end
        function validate(obj,val)
            if isnan(val)
                assert(obj.allow_nan, 'Attempted to set NaN. However, this is verboten as allow_nan is set to false.')
            else
                validateattributes(val,{'numeric','logical'},{'binary','scalar'})
            end
        end
        function val = clean(obj,val)
            if ~isnan(val)
                val = logical(val);
            end
        end
    end

end
