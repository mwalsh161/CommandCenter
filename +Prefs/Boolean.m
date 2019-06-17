classdef Boolean < Base.pref
    %BOOLEAN True/False data
    
    properties
        value = false;
    end
    
    methods
        function obj = Boolean()
            obj.value = false;
        end
        function validate(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'})
        end
        function val = clean(obj,val)
            val = logical(val);
        end
    end
    
end