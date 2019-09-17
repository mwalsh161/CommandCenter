classdef String < Base.pref
    %STRING Allows any character array
    
    properties(Hidden)
        default = '';
        ui = Prefs.Inputs.CharField;
    end
    properties
        % Note, this will error immediately unless default value supplied
        allow_empty = {true, @(a)validateattributes(a,{'logical'},{'scalar'})};
    end
    
    methods
        function validate(obj,val)
            validateattributes(val,{'char','string'},{'scalartext'})
            if ~obj.allow_empty
                assert(~isempty(val),'Cannot set an empty string.')
            end
        end
    end
    
end