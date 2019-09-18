classdef Integer < Prefs.Double
    %INTEGER Allows any integer within max and min limits
    
    properties
        % See Prefs.Double
    end
    
    methods
        function validate(obj,val)
            validate@Prefs.Double(obj,val);
            % Only further check is integer (allow Inf/NaN as integer)
            if ~isinf(val) || ~isnan(val)
                validateattributes(val,{'numeric'},{'integer'})
            end
        end
    end
    
end