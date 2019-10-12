classdef Boolean < Base.pref
    %BOOLEAN True/False data
    
    properties(Hidden)
        default = false;
        ui = Prefs.Inputs.BooleanField;
    end
    
    methods
        function obj = Boolean(varargin)
            obj = obj@Base.pref(varargin{:});
        end
        function validate(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'})
        end
        function val = clean(obj,val)
            val = logical(val);
        end
    end
    
end