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
    
    methods
        function obj = Boolean(varargin)
            obj = obj@Prefs.Numeric(varargin{:});
            if isempty(obj.units)
                obj.units = '0/1';
            end
        end
        function validate(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'})
        end
        function val = clean(obj,val)
            val = logical(val);
        end
    end
    
end