classdef PowerSupply_invisible < Modules.Source
    %SuperClass for MW sources
    
    properties(SetObservable,SetObservable)
        prefs = {'Channel','Source_Mode','Voltage','Current_Limit','Current','Voltage_Limit'};
        Source_Mode = {'Voltage','Current'}
        Channel = '1';
        Current_Limit = 0.1; %Amps
        Voltage_Limit = 1;   %Voltage
        Current = 0.05; %Amps
        Voltage = 0.1;  %Voltage
    end
    
    properties(SetAccess=private, SetObservable, AbortSet)
        source_on=false;
    end
    
    properties(SetAccess=private,Hidden)
        listeners
        path_button
    end

    properties(Abstract)
        power_supply % Handle to the power supply driver
    end
    
    methods
        function obj = PowerSupply_invisible()
            obj.listeners = addlistener(obj,'Channel','PostSet',@obj.updateValues);
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.PowerSupplies.PowerSupply_invisible();
            end
            obj = Object;
        end
        
    end
    
    methods
        %% set methods
        
        function set.Channel(obj,val)
            channel = str2num(val);
            assert(~isempty(channel),'channel must be an integer')
            assert(mod(channel,1)==0,'channel must be an integer')
            max_channel = str2num(obj.power_supply.Number_of_channels);
            if channel>max_channel
                error([' Attempted to set a channel that is greater than'...
                    ' the maximum number of channels supported: ',obj.power_supply.Number_of_channels]);
            end
            if channel < 0
                error('Channel must be positive')
            end
            obj.Channel = val;
        end
        
        function set.Source_Mode(obj,val)
            %debugging happens @ driver level
            obj.power_supply.setSourceMode(obj.Channel,val); 
            obj.Source_Mode = val;
        end
        
        function set.Current(obj,val)
            %debugging happens @ driver level
            obj.power_supply.setVoltageLimit(obj.Channel,obj.Voltage_Limit);
            obj.power_supply.setCurrent(obj.Channel,val);
            obj.Current = val;
        end
        
        function set.Voltage(obj,val)

            %debugging happens @ driver level
%             obj.power_supply.setCurrentLimit(obj.Channel,obj.Current_Limit);
            obj.power_supply.setVoltage(obj.Channel,val);
            obj.Voltage = val;
        end
        
        function set.Current_Limit(obj,val)

            %debugging happens @ driver level
            obj.power_supply.setCurrentLimit(obj.Channel,val);
            obj.Current_Limit = val;
        end
        
        function set.Voltage_Limit(obj,val)
            obj.power_supply.setVoltageLimit(obj.Channel,val);
            obj.Voltage_Limit = val;
        end
        %% get methods because these properties are interdependant. 
        
        function val = get.Current(obj)
            if obj.source_on 
                %if on return the actual current being output
                val = obj.power_supply.measureCurrent(obj.Channel);
            else
                val = obj.power_supply.getCurrent(obj.Channel);%if the source isn't on return the programmed values
            end
        end
        
        function val = get.Voltage(obj)

            if obj.source_on 
                %if on return the actual voltage being output
                val = obj.power_supply.measureVoltage(obj.Channel);
            else
                val = obj.power_supply.getVoltage(obj.Channel);%if the source isn't on return the programmed values
            end
        end

        function val = get.Source_Mode(obj)
           val = obj.power_supply.getSourceMode(obj.Channel); 
        end
        
        function val = get.Current_Limit(obj)
            val = obj.power_supply.getCurrentLimit(obj.Channel);
        end
        
        function val = get.Voltage_Limit(obj)
           val = obj.power_supply.getVoltageLimit(obj.Channel);
        end
        %%
        
        function delete(obj)
            delete(obj.listeners)
            obj.power_supply.delete;
        end
        
        function on(obj)
            obj.power_supply.on;
            obj.source_on=1;
        end
        
        function off(obj)
            obj.power_supply.off;
            obj.source_on=0;
        end

        
        function updateValues(obj,~,~)
            %% triggers after user switches channel. Properties are linked so
            %first get them from the driver by calling get methods
            if obj.source_on == 0
                sourceMode = obj.Source_Mode;
                Current_Limit = obj.Current_Limit;
                Voltage_Limit = obj.Voltage_Limit;
                Current = obj.Current;
                Voltage = obj.Voltage;
                %% reassign their values
                obj.Source_Mode = sourceMode;
                obj.Current_Limit = Current_Limit;
                obj.Voltage_Limit = Voltage_Limit;
                obj.Current = Current;
                obj.Voltage = Voltage;
            end
        end
        
    end
end

