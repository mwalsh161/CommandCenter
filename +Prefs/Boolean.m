classdef Boolean < Base.pref
    %BOOLEAN True/False data
    
    properties
        value = false;
    end
    
    methods
    function set.value(obj,val)
        assert(islogical(val), 'Boolean prefs must be a logical.')
        assert(numel(val)==1, 'Boolean prefs do not support arrays.')
        obj.value = val;
    end
    end
    
end