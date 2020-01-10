classdef Numeric < Base.Pref
    %NUMERIC Any numeric value
    
    properties (Abstract)               % Adds min and max
        min;
        max;
    end
    
    methods (Static, Hidden)
        function obj = Numeric(varargin)
            obj = obj@Base.Pref(varargin{:});
        end
        function tf = isnumeric(~)      % Overloads isnumeric.
            tf = true;
        end
    end
end
