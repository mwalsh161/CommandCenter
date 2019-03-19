classdef Yokogawa_Source < Sources.PowerSupplies.PowerSupply_invisible
    %Hewlett Packard MW source class

    properties
        serial
        
        prefs = {'Channel','Source_Mode','Voltage','Current_Limit','Current','Voltage_Limit'};
    end
    
    properties(SetAccess=private)
        Power_Supply_Name='Yokogawa 1';
    end
    
    methods(Access=protected)
        function obj = Yokogawa_Source()
            obj.serial = Drivers.PowerSupplies.Yokogawa.instance(obj.Power_Supply_Name);
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.PowerSupplies.Yokogawa_Source();
            end
            obj = Object;
        end
    end
    
end

