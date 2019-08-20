classdef HMP4040_Source <  Sources.PowerSupplies.PowerSupply_invisible
    % Rhode & Schwarz HMP4040 Power Supply (serial connection type).

    properties(SetObservable,AbortSet)
        Com_Address = 'NONE'; % COM address for serial connection. Is 'NONE' if no connection is desired.
        Channel = {'1','2','3','4'};
        Currents = [.05, .05, .05, .05]; % Memory of what all the voltages are to be saved in prefs
        Voltages = [1 1 1 1]; % Memory of what all the currents are to be saved in prefs
        SourceModes = {'Voltage','Voltage','Voltage','Voltage'} % Memory of what all the Source_Modes are to be saved in prefs
    end

    properties
        power_supply = [];
    end
    
    properties(Constant)
        Power_Supply_Name='HMP4040';
        ChannelNames = {'1','2','3','4'};
    end

    methods(Access=protected)
        function obj = HMP4040_Source()
            obj.connectSerial( obj.Com_Address );
            obj.prefs = {obj.prefs{:},'Com_Address'};
            obj.show_prefs = {obj.show_prefs{:},'Com_Address'};
            obj.loadPrefs;
        end
        
        function success = connectSerial(obj, Com_Address)
            % If using the default non-existant Com_Address, disconnect device
            Com_Address = upper(Com_Address);
            if strcmp(Com_Address,'NONE')
                delete(obj.power_supply);
                obj.power_supply = [];
                obj.power_supply_connected=false;
                success = true;
                return
            end

            % Otherwise try to connect with input Com and instantiate power_supply
            oldSerial = obj.power_supply;
            try
                serial_device = serial(Com_Address);
                obj.power_supply = Drivers.PowerSupplies.HMP4040.instance(obj.Power_Supply_Name,serial_device);
                delete(oldSerial);
                obj.power_supply_connected=true;
                success = true;
            catch ME
                err_message = sprintf('Failed to open device. Error message:\n%s\nMessage identifier:\n%s', ME.message, ME.identifier);
                f = msgbox(err_message);
                
                % If connection fails, keep old instance of power_supply
                % and delete serial device
                delete(serial_device);
                obj.power_supply = oldSerial;
                obj.power_supply_connected=false;
                success = false;
            end
            
            obj.updatePrefs(); % Update values if connection is successful
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
        % If the Com_Address changed, need to attempt to reconnect device with new info
        function set.Com_Address(obj,val)
            val = upper(val);
            success  = obj.connectSerial(val);
            
            if success
                obj.Com_Address = val;
            end
        end

        function arm(obj)
        end
    end
end