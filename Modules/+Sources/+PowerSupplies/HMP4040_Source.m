classdef HMP4040_Source <  Sources.PowerSupplies.PowerSupply_invisible
    %Hewlett Packard MW source class
    properties
        serial
        prefs = {'Channel','Source_Mode','Voltage','Current_Limit','Current','Voltage_Limit'};
        connectDevice
    end
    
    properties(SetAccess=private)
        Power_Supply_Name='HMP4040';
    end
    
    methods(Access=protected)
        function obj = HMP4040_Source()
            obj.connectDevice = establishComObject('PowerSupply');
            obj.serial = Drivers.PowerSupplies.HMP4040.instance(obj.Power_Supply_Name,obj.connectDevice.comObject);
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.PowerSupplies.HMP4040_Source(); %Object.serial.comObject mysteriously closes here
            end
            obj = Object;
        end
    end
    
    methods
        function  delete(obj)
            fclose(obj.connectDevice.comObject);
            fdelete(obj.connectDevice.comObject)
        end
    end
end