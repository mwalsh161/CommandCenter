classdef PowerSupply_invisible < Modules.Source
    %SuperClass for power supply sources
    % ***IMPORTANT NOTE***** Experiments should use getVal methods, not corresponding Val property, to get true power supply setting, as these can theoretically be different from the properties if the user manually sets them on the power supply
    
    properties(SetObservable,AbortSet)
        prefs = {'Channel','Source_Mode','Voltage','Current_Limit','Current','Voltage_Limit'};
        Source_Mode = {'Voltage','Current'}
        Current_Limit = 0.1; %Amps
        Voltage_Limit = 1;   %Voltage
        Current = 0.05; %Amps
        Voltage = 0.1;  %Voltage
    end
    
    properties(SetAccess=private, SetObservable)
        source_on=false;
    end
    
    properties(SetAccess=private,Hidden)
        listeners
        path_button
    end

    properties(SetAccess=protected)
        power_supply_connected=false;
    end

    properties(Abstract)
        power_supply % Handle to the power supply driver
    end
    
    properties(Abstract,Constant)
        Channel % cell array of strings of power supply channel names (e.g. {'1','2'})
        Power_Supply_Name % Name of the power supply
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

    methods(Access=protected)
        function output = queryPowerSupply(obj,command,varargin)
            % Only attempt to pass command to power_supply if device is connected
            if obj.power_supply_connected
                % Perform power_supply specified by command (string), with varargin as arguments
                obj.power_supply.(command)(varargin{:})
            end
        end
    end
    
    methods
        function obj = PowerSupply_invisible()
            obj.listeners = addlistener(obj,'Channel','PostSet',@obj.updateValues);
        end
        
        %% set methods
                
        function set.Source_Mode(obj,val)
            %debugging happens @ driver level
            obj.queryPowerSupply('setSourceMode',obj.Channel,val); 
            obj.Source_Mode = val;
        end
        
        function set.Current(obj,val)
            %debugging happens @ driver level
            obj.queryPowerSupply('setVoltageLimit',obj.Channel,obj.Voltage_Limit);
            obj.queryPowerSupply('setCurrent',obj.Channel,val);
            obj.Current = val;
        end
        
        function set.Voltage(obj,val)

            %debugging happens @ driver level
            %obj.power_supply.setCurrentLimit(obj.Channel,obj.Current_Limit);
            obj.queryPowerSupply('setVoltage',obj.Channel,val);
            obj.Voltage = val;
        end
        
        function set.Current_Limit(obj,val)

            %debugging happens @ driver level
            obj.queryPowerSupply('setCurrentLimit',obj.Channel,val);
            obj.Current_Limit = val;
        end
        
        function set.Voltage_Limit(obj,val)
            obj.queryPowerSupply('setVoltageLimit',obj.Channel,val);
            obj.Voltage_Limit = val;
        end

        %% get methods because these properties are interdependant. 
        
        function val = getCurrent(obj)
            if obj.source_on 
                %if on return the actual current being output
                val = obj.queryPowerSupply('measureCurrent',obj.Channel);
            else
                val = obj.queryPowerSupply('getCurrent',obj.Channel);%if the source isn't on return the programmed values
            end
        end
        
        function val = getVoltage(obj)

            if obj.source_on 
                %if on return the actual voltage being output
                val = obj.queryPowerSupply('measureVoltage',obj.Channel);
            else
                val = obj.queryPowerSupply('getVoltage',obj.Channel);%if the source isn't on return the programmed values
            end
        end

        function val = getSource_Mode(obj)
           val = obj.queryPowerSupply('getSourceMode',obj.Channel); 
        end
        
        function val = getCurrent_Limit(obj)
            val = obj.queryPowerSupply('getCurrentLimit',obj.Channel);
        end
        
        function val = getVoltage_Limit(obj)
           val = obj.queryPowerSupply('getVoltageLimit',obj.Channel);
        end


        %% generic control functions

        function delete(obj)
            delete(obj.listeners);
            delete(obj.power_supply);
            obj.power_supply_connected=false;
        end
        
        function on(obj)
            obj.queryPowerSupply('on');
            obj.source_on=1;
        end
        
        function off(obj)
            obj.queryPowerSupply('off');
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

