classdef String < Base.pref
    %STRING Allows any character array
    
    properties
        value = '';
    end
    
    methods
        function set.value(obj,val)
            assert(ischar(val), 'String prefs must be character arrays.')
            obj.value = val;
        end
    end
    
end