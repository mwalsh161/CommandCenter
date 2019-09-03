classdef Integer < Prefs.Double
    %INTEGER Allows any integer within max and min limits
    
    properties
        % See Prefs.Double
    end
    
    methods
        function obj = Integer(varargin)
            obj.default = 0;
            obj = obj.init(varargin{:});
        end
        function validate(obj,val)
            validate@Prefs.Double(obj,val);
            % Only further check is integer
            validateattributes(val,{'numeric'},{'integer'})
        end
    end
    
end