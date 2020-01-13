classdef Numeric < Base.Pref & Base.Measurement
    %NUMERIC Any numeric value

    properties (Abstract)               % Adds min and max
        min;
        max;
    end

    methods (Static, Hidden)
        function obj = Numeric(varargin)
            obj = obj@Base.Pref(varargin{:});

            obj.sizes = struct(obj.property_name, [1 1]);
            obj.names = struct(obj.property_name, obj.name);
            obj.units = struct(obj.property_name, obj.unit);
            obj.scans = struct();   % 1 x 1 data doesn't need scans or prefs.
            obj.prefs = struct();
        end
        function tf = isnumeric(~)      % Overloads isnumeric.
            tf = true;
        end
        function data = measure(obj)    % Hooks the pref up into Base.Measurement
            data = obj.read();
        end
    end
end
