classdef Yokogawa_Source < Sources.PowerSupplies.PowerSupply_invisible
    %Hewlett Packard MW source class

    properties(SetObservable,GetObservable,AbortSet)
        Com_Address = 'NONE'; % COM address prologix connection. Is 'NONE' if no connection is desired.
        Primary_Address = 'NONE'; % Primary address for prologix connection. Is 'NONE' if no connection is desired.
        Channel = Prefs.MultipleChoice('1','allow_empty',false,'choices',{'1'},'help_text','Power supply channel to change','set','changeChannel');
        Currents = [.05]; % Memory of what all the voltages are to be saved in prefs
        Voltages = [1]; % Memory of what all the currents are to be saved in prefs
        SourceModes = {'Voltage'} % Memory of what all the Source_Modes are to be saved in prefs
    end
    
    properties
        power_supply = [];
    end
    
    properties(Constant)
        Power_Supply_Name='Yokogawa 1';
        ChannelNames = {'1'};
    end
    
    methods(Access=protected)
        function obj = Yokogawa_Source()
            obj.connectSerial( obj.Com_Address, obj.Primary_Address );
            obj.prefs = {obj.prefs{:},'Com_Address','Primary_Address'};
            obj.show_prefs = {obj.show_prefs{:},'Com_Address','Primary_Address'};
            obj.loadPrefs;
        end

        function success = connectSerial(obj, Com_Address, Primary_Address)
             % If using the default non-existant Com_Address, disconnect device
             Com_Address = upper(Com_Address);
             Primary_Address = upper(Primary_Address);
             if strcmp(Com_Address,'NONE') || strcmp(Primary_Address,'NONE')
                 delete(obj.power_supply);
                 obj.power_supply = [];
                 obj.power_supply_connected=false;
                 success = true;
                 return
             end
             
             Primary_Address = str2num(Primary_Address);
             
             % Otherwise try to connect with input Com and instantiate power_supply
             oldSerial = obj.power_supply;
             try
                 serial_device = prologix(Com_Address,Primary_Address);
                 obj.power_supply = Drivers.PowerSupplies.Yokogawa.instance(obj.Power_Supply_Name,serial_device);
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
                Object = Sources.PowerSupplies.Yokogawa_Source();
            end
            obj = Object;
        end
    end
    
    methods
        % If the Com_Address changed, need to attempt to reconnect device with new info
        function set.Com_Address(obj,val)
            val = upper(val);
            success  = obj.connectSerial(val, obj.Primary_Address);
            
            if success
                obj.Com_Address = val;
            end
        end
        function set.Primary_Address(obj,val)
            val = upper(val);
            success  = obj.connectSerial(obj.Com_Address, val);
            
            if success
                obj.Primary_Address = val;
            end
        end
        function val = changeChannel(obj,val,pref)
            obj.updateValues();
        end
        function arm(obj)
        end
    end

end

