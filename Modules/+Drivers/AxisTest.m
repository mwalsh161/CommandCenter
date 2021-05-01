classdef AxisTest < Modules.Driver

    properties
        prefs = {'x', 'y', 'hwp', 'voltage', 'bool', 'read_only'}
    end
    
    properties (GetObservable, SetObservable)
        x = Prefs.Double(0, 'unit', 'um', 'min', 0, 'max', 10, 'name', 'Test x', 'help', 'Prefs.Double Test as a x axis.');
        y = Prefs.Double(0, 'unit', 'um', 'min', 0, 'max', 10, 'name', 'Test y', 'help', 'Prefs.Double Test as a y axis.');

        hwp = Prefs.Double(0, 'unit', 'deg', 'min', 0, 'max', 360, 'name', 'Half Wave Plate', 'help', 'To rotate input polarization.');

        voltage = Prefs.Double(0, 'unit', 'V', 'min', 0, 'max', 50, 'name', 'Stark Voltage', 'help', 'Stark tuning voltage');

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
        function obj = instance(id)
%             mlock;
%             persistent Object
%             if isempty(Object) || ~isvalid(Object)
%                 Object = Drivers.AxisTest();
%             end
%             obj = Object;

            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.AxisTest.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && strcmpi(id, Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.AxisTest(id);
            obj.singleton_id = id;
            Objects(end+1) = obj;
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
