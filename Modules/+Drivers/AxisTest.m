classdef AxisTest < Modules.Driver

    properties (GetObservable, SetObservable)
        x = Prefs.Double(0, 'units', 'um', 'min', 0, 'max', 10, 'name', 'Test x', 'help', 'Prefs.Double Test as a x axis');
        y = Prefs.Double(0, 'units', 'um', 'min', 0, 'max', 10, 'name', 'Test y', 'help', 'Prefs.Double Test as a y axis');
        
        bool = Prefs.Boolean(false, 'name', 'Test Boolean');
        read_only = Prefs.Boolean(false, 'name', 'Readonly', 'readonly', true);
    end

    methods (Access=private)
        function obj = AxisTest(varargin)
% 			obj.x = Base.Axis(obj, 'x', 'setx', '', [0 10], 'V', 'Axis Test X', 'um', @(x)(x*2), @(x)(x/2));
% 			obj.y = Base.Axis(obj, 'y', 'sety', '', [0 5], 'V', 'Axis Test Y');
        end
    end

    methods (Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Drivers.AxisTest();
            end
            obj = Object;
        end
    end

	methods
        function val = set_x(obj, x, ~)
            obj.x = x;
            
            val = obj.x;
        end
        function val = set_y(obj, y, ~)
            obj.y = y;
            
            val = obj.y;
        end
%         function set.x(obj, x)
%             'herex1'
%             x
%             obj.x = x;
%         end
%         function set.y(obj, y)
%             'herey1'
%             y
%             obj.y = y;
%         end
	end
end
