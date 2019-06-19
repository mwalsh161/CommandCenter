classdef String < Base.pref
    %STRING Allows any character array
    
    properties
        allow_empty = true; % Note, this will error immediately unless default value given when true
    end
    
    methods
        function obj = String(varargin)
            obj.default = '';
            obj = obj.init(varargin{:});
        end
        function validate(obj,val)
            validateattributes(val,{'numeric','logical'},{'scalartext'})
            if ~obj.allow_empty
                assert(~isempty(val),'Attempted to set empty string. allow_empty is set to false.')
            end
        end
    end
    
end