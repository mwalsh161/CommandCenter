classdef Keithley2450_Source < Sources.PowerSupplies.PowerSupply_invisible
    % Keithley 2450 power supply source

    properties(SetObservable,GetObservable,AbortSet)
        VISA_address = Prefs.String('NONE','set','set_VISA_address'); % COM address prologix connection. Is 'NONE' if no connection is desired.
        Channel = Prefs.MultipleChoice('1','allow_empty',false,'choices',{'1'},'help_text','Power supply channel to change');
        Currents = [.05]; % Memory of what all the voltages are to be saved in prefs
        Voltages = [1]; % Memory of what all the currents are to be saved in prefs
        SourceModes = {'Voltage'} % Memory of what all the Source_Modes are to be saved in prefs
    end
    
    properties
        power_supply = [];
    end
    
    properties(Constant)
        Power_Supply_Name='Keithley 2450 1';
        ChannelNames = {'1'};
    end
    
    methods(Access=protected)
        function obj = Keithley2450_Source()
            obj.prefs = {obj.prefs{:},'VISA_address'};
            obj.show_prefs = {obj.show_prefs{:},'VISA_address'};
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.PowerSupplies.Keithley2450_Source();
            end
            obj = Object;
        end
    end
    
    methods
        % If the Com_Address changed, need to attempt to reconnect device with new info
        function arm(obj)
        end
        
        % Overloading superclass methods
        function setCurrent(obj,val)
            if obj.Source_Mode == 'Voltage'
                obj.queryPowerSupply('setCurrentLimit',obj.Channel,val);
                obj.Currents(obj.getHWIndex(obj.Channel)) = val;
            elseif obj.Source_Mode == 'Current'
                obj.queryPowerSupply('setCurrent',obj.Channel,val);
                obj.Currents(obj.getHWIndex(obj.Channel)) = val;
            end
        end
        
        function setVoltage(obj,val)
            if obj.Source_Mode == 'Voltage'
                obj.queryPowerSupply('setVoltage',obj.Channel,val);
                obj.Voltages(obj.getHWIndex(obj.Channel)) = val;
            elseif obj.Source_Mode == 'Current'
                obj.queryPowerSupply('setVoltageLimit',obj.Channel,val);
            obj.Voltages(obj.getHWIndex(obj.Channel)) = val;
            end
        end
        
        function val = getCurrent(obj, measure)
            if nargin<2
                measure = true;
            end
            if measure && obj.source_on
                %if on return the actual current being output
                val = obj.queryPowerSupply('measureCurrent',obj.Channel);
            else
                if obj.Source_Mode == 'Voltage'
                    val = obj.queryPowerSupply('getCurrentLimit',obj.Channel);%if the source isn't on return the programmed values
                    obj.Currents(obj.getHWIndex(obj.Channel)) = val;
                elseif obj.Source_Mode == 'Current'
                    val = obj.queryPowerSupply('getCurrent',obj.Channel);%if the source isn't on return the programmed values
                    obj.Currents(obj.getHWIndex(obj.Channel)) = val;
                end
            end
        end
        
        function val = getVoltage(obj, measure)
            if nargin<2
                measure = true;
            end
            if measure && obj.source_on
                %if on return the actual voltage being output
                val = obj.queryPowerSupply('measureVoltage',obj.Channel);
            else
                if obj.Source_Mode == 'Voltage'
                    val = obj.queryPowerSupply('getVoltage',obj.Channel);%if the source isn't on return the programmed values
                    obj.Voltages(obj.getHWIndex(obj.Channel)) = val;
                elseif obj.Source_Mode == 'Current'
                    val = obj.queryPowerSupply('getVoltageLimit',obj.Channel);%if the source isn't on return the programmed values
                    obj.Currents(obj.getHWIndex(obj.Channel)) = val;
                end
            end
        end

        function connectVISA(obj, address)
            try
                comObjectArray = instrfind('Type', 'visa-usb', 'RsrcName', address, 'Tag', '');
                
                % Create the VISA-USB object if it does not exist
                % otherwise use the object that was found.
                if isempty(comObjectArray)
                    comObject = visa('NI', address);
                else
                    if iscell(comObjectArray)
                        for index = 1:numel(comObjectArray)
                            comObject = comObjectArray{index};
                            if strcmpi(comObject.status,'open')
                                break
                            end
                            if index == numel(comObjectArray)
                                fclose(comObjectArray);
                                comObject = comObjectArray(1);
                            end
                        end
                    else
                        comObject = comObjectArray(1);
                    end
                end
                obj.power_supply = Drivers.PowerSupplies.Keithley2450.instance(obj.Power_Supply_Name,comObject);
                obj.power_supply_connected = true;
            catch err
                % Reset to NONE if connection failed
                obj.power_supply_connected = false;
                rethrow(err)
            end
        end
        
        function val = set_VISA_address(obj,val,~)
            new_val = upper(val);

            if ~strcmp(new_val,'NONE')
                try
                    obj.connectVISA(new_val)
                    val = new_val;
                catch err
                    val = 'NONE';
                end
            else
                obj.power_supply_connected = false;
                val = new_val;
            end
        end
    end

end

