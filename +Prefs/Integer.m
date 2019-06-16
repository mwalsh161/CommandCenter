classdef Integer < Base.pref
    %INTEGER Allows any integer within max and min limits
    
    properties
        value = 0;
        max = Inf;
        min = -Inf;
    end
    
    methods
        function set.value(obj,val)
            assert(isinteger(val), 'Integer prefs must be integers.')
            assert(numel(val)==1, 'Integer prefs do not support arrays.')
            assert(val <= obj.max, 'Attempted to set value greater than max.')
            assert(val >= obj.min, 'Attempted to set value less than min.')
            obj.value = val;
        end
    end
    
end