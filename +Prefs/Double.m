classdef Double < Base.pref
    %DOUBLE Any numeric value
    
    properties
        value = false;
    end
    
    methods
    function set.value(obj,val)
        assert(isnumeric(val), 'Double prefs must be a logical.')
        assert(numel(val)==1, 'Double prefs do not support arrays.')
        obj.value = val;
    end
    end
    
end