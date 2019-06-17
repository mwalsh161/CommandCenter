classdef Double < Base.pref
    %DOUBLE Any numeric value
    
    properties
        allow_nan = true;
    end
    
    methods
        function obj = Double()
            obj.value = 0;
        end
        function validate(obj,val)
            validateattributes(val,{'numeric'},{'scalar'})
            if ~obj.allow_nan
                assert(~isnan(val),'Attempted to set NaN. allow_nan is set to false.')
            end
        end
    end
    
end