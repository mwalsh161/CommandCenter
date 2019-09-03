classdef String < Base.pref
    %STRING Allows any character array
    
    properties
        ui = Prefs.Inputs.CharField;
        allow_empty = true; % Note, this will error immediately unless default value supplied
    end
    
    methods
        function obj = String(varargin)
            obj.default = '';
            obj = obj.init(varargin{:});
        end
        function validate(obj,val)
            validateattributes(val,{'char','string'},{'scalartext'})
            if ~obj.allow_empty
                assert(~isempty(val),'Cannot set an empty string.')
            end
        end
    end
    
end