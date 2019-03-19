classdef HAMEG_Source <  Sources.PowerSupplies.PowerSupply_invisible
    %Hewlett Packard MW source class
    properties
        serial
        prefs = {'Channel','Source_Mode','Voltage','Current_Limit','Current','Voltage_Limit'};
    end
    
    properties(SetAccess=private)
        Power_Supply_Name='HAMEG 1';
    end
    
    methods(Access=protected)
        function obj = HAMEG_Source()
            obj.serial = Drivers.PowerSupplies.HAMEG.instance(obj.Power_Supply_Name);
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.PowerSupplies.HAMEG_Source();
            end
            obj = Object;
        end
    end
    
end

