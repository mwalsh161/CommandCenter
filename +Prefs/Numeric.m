classdef Numeric < Base.Pref & Base.Measurement
    %NUMERIC Any numeric value
    
    properties (Abstract)               % Enforces min and max
        min;
        max;
    end
    
%     properties
%         measurements = {[], @()true};
%     end

    methods (Static)
        function obj = Numeric(varargin)
            obj = obj@Base.Pref(varargin{:});
%             obj = obj.init(varargin{:});
        end
        function tf = isnumeric(~)      % Overloads isnumeric.
            tf = true;
        end
    end
    methods (Hidden)
        function data = measure(obj)    % Hooks the pref up into Base.Measurement
            data = obj.read();
        end
    end
end
