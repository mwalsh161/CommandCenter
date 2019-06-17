classdef Integer < Base.pref
    %INTEGER Allows any integer within max and min limits
    
    properties
        value = 0;
        max = Inf;
        min = -Inf;
    end
    
    methods
        function set.value(obj,val)
            validateattributes(val,{'numeric'},{'integer','scalar'})
            assert(isinteger(val), 'Integer prefs must be integers.')
            assert(val <= obj.max, 'Attempted to set value greater than max.')
            assert(val >= obj.min, 'Attempted to set value less than min.')
            obj.value = val;
        end
    end
    
end