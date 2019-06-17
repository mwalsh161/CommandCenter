classdef Integer < Base.pref
    %INTEGER Allows any integer within max and min limits
    
    properties
        max = Inf;
        min = -Inf;
    end
    
    methods
        function obj = Integer()
            obj.value = 0;
        end
        function validate(obj,val)
            validateattributes(val,{'numeric'},{'integer','scalar'})
            assert(val <= obj.max, 'Cannot set value greater than max.')
            assert(val >= obj.min, 'Cannot set value less than min.')
        end
    end
    
end