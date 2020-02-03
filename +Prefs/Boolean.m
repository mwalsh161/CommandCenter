classdef Boolean < Base.pref
    %BOOLEAN True/False data
    
    methods
        function obj = Boolean(varargin)
            obj.default = false;
            obj = obj.init(varargin{:});
        end
        function validate(obj,val)
            validateattributes(val,{'numeric','logical'},{'binary','scalar'})
        end
        function val = clean(obj,val)
            val = logical(val);
        end
    end
    
end