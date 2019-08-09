classdef HMP4040_Source <  Sources.PowerSupplies.PowerSupply_invisible
    % Rhode & Schwarz HMP4040 Power Supply

    properties(SetObservable,AbortSet)
        Com_Address = 'none'; % Is 'None' if no connection is desired
        Primary_Address = 0; % Is 0 if no connection is desired
    end

    properties
        power_supply = [];
    end
    
    properties(Constant)
        Power_Supply_Name='HMP4040';
        Number_of_channels=4;
    end

    methods(Access=protected)
        function obj = HMP4040_Source()
            obj.connectSerial( obj.Com_Address, obj.Primary_Address);
            obj.prefs = {obj.prefs{:},'Com_Address','Primary_Address'};
            obj.loadPrefs;
        end
        
        function success = connectSerial(obj, Com_Address, Primary_Address)
            % If using the default non-existant Com_Address/Primary_Address, disconnect device
            if strcmp(Com_Address,'none') || (Primary_Address == 0)
                delete(obj.power_supply);
                obj.power_supply = [];
                obj.power_supply_connected=false;
                success = true;
                return
            end

            % Otherwise try to connect with input Com/Primary_Address and instantiate power_supply
            oldSerial = obj.power_supply;
            try
                prologix_device = prologix(Com_Address, Primary_Address);
                obj.power_supply = Drivers.PowerSupplies.HMP4040.instance(obj.Power_Supply_Name,prologix_device);
                delete(oldSerial);
                obj.power_supply_connected=true;
                success = true;
            catch ME
                err_message = sprintf('Failed to open device. Error message:\n%s\nMessage identifier:\n%s', ME.message, ME.identifier);
                f = msgbox(err_message);
                
                % If connection fails, keep old instance of power_supply
                obj.power_supply = oldSerial;
                obj.power_supply_connected=false;
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