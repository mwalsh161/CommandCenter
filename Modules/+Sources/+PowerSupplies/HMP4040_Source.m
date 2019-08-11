classdef HMP4040_Source <  Sources.PowerSupplies.PowerSupply_invisible
    % Rhode & Schwarz HMP4040 Power Supply

    properties(SetObservable,AbortSet)
        Com_Address = 'None'; % Is 'None' if no connection is desired
        Primary_Address = 0; % Is 0 if no connection is desired
        Channel = {'1','2','3','4'}; % List of channel names
    end

    properties
        power_supply = [];
    end
    
    properties(SetAccess=private,Constant)
        Power_Supply_Name='HMP4040';
    end

    methods(Access=protected)
        function obj = HMP4040_Source()
            obj.connectSerial( obj.Com_Address, obj.Primary_Address);
            obj.prefs = {obj.prefs{:},'Com_Address','Primary_Address'};
            obj.loadPrefs;
        end
        
        function success = connectSerial(obj, Com_Address, Primary_Address)
            % If using the default non-existant Com_Address/Primary_Address, disconnect device
            if (Com_Address == 'None') || (Primary_Address == 0)
                delete(obj.power_supply);
                obj.power_supply = [];
                power_supply_connected=false;
                success = true;
                return
            end

            % Otherwise try to connect with input Com/Primary_Address and instantiate power_supply
            oldSerial = obj.power_supply;
            try
                prologix_device = prologix(Com_Address, Primary_Address);
                obj.power_supply = Drivers.PowerSupplies.HMP4040.instance(obj.Power_Supply_Name,prologix_device);
                delete(oldSerial);
                power_supply_connected=true;
                success = true;
            catch
                % If connection fails, keep old instance of power_supply
                obj.power_supply = oldSerial;
                power_supply_connected=false;
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