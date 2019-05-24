classdef HMP4040_Source <  Sources.PowerSupplies.PowerSupply_invisible
    %Hewlett Packard MW source class
    properties
        serial
        connectDevice
        comObjectInfo
        prefs = {'Channel','Source_Mode','Voltage','Current_Limit','Current','Voltage_Limit','comObjectInfo'};
        show_prefs = {'Channel','Source_Mode','Voltage','Current_Limit','Current','Voltage_Limit'};
    end
    
    properties(SetAccess=private)
        Power_Supply_Name='HMP4040';
    end
    
    methods(Access=protected)
        function obj = HMP4040_Source()
            obj.loadPrefs;
            obj.connectDevice = establishComObject('PowerSupply',obj.comObjectInfo);
            obj.comObjectInfo = obj.connectDevice.comObjectInfo;
            obj.serial = Drivers.PowerSupplies.HMP4040.instance(obj.Power_Supply_Name,obj.connectDevice.comObject);
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
    
end