classdef HMP4040_Source <  Sources.PowerSupplies.PowerSupply_invisible
    %Hewlett Packard MW source class

    properties(SetObservable,AbortSet)
        prefs = {'Channel','Source_Mode','Voltage','Current_Limit','Current','Voltage_Limit','Com_Address','Primary_Address'};
        Com_Address = 'Not Connected';
        Primary_Address = 1;
    end

    properties
        power_supply = [];
    end
    
    properties(SetAccess=private)
        Power_Supply_Name='HMP4040';
    end

    methods(Access=protected)
        function obj = HMP4040_Source()
            obj.connectSerial( obj.Com_Address, obj.Primary_Address);
            %obj.loadPrefs;
        end
        
        function success = connectSerial(obj, Com_Address, Primary_Address)
            oldSerial = obj.power_supply;
            try
                prologix_device = prologix(Com_Address, Primary_Address);
                obj.power_supply = Drivers.PowerSupplies.HMP4040.instance(obj.Power_Supply_Name,prologix_device);
                success = true;
            catch
                obj.power_supply = oldSerial;
                success = false;
            end
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.PowerSupplies.HMP4040_Source();
            end
            obj = Object;
        end
    end

    methods
        % If the Com_Address or Primary_Address changed, need to attempt to reconnect device with new info
        function set.Com_Address(obj,val)
            success  = obj.connectSerial(val,obj.Primary_Address);
            
            if success
                obj.Com_Address = val;
            end
        end

        function set.Primary_Address(obj,val)
            success = obj.connectSerial(obj.Com_Address,val);
            
            if success
                obj.Primary_Address = val;
            end
        end
    end
end