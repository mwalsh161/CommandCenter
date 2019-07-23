classdef Integer < Base.pref
    %INTEGER Allows any integer within max and min limits
    
    properties
        allow_nan = true;
        max = Inf;
        min = -Inf;
    end
    
    methods
        function obj = Integer(varargin)
            obj.default = 0;
            obj = obj.init(varargin{:});
        end
        function validate(obj,val)
            validateattributes(val,{'numeric'},{'integer','scalar'})
            if ~obj.allow_nan
                assert(~isnan(val),'Attempted to set NaN. allow_nan is set to false.')
            elseif isnan(val)
                return
            end
            assert(val <= obj.max, 'Cannot set value greater than max.')
            assert(val >= obj.min, 'Cannot set value less than min.')
        end
    end
    
end