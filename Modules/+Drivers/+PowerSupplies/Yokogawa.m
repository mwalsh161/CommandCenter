classdef Yokogawa < Drivers.PowerSupplies.PowerSupplies
    
    properties
        prefs = {'comObjectInfo'};
        comObjectInfo = struct('comType','','comAddress','','comProperties','')
        comObject;     % USB-Serial/GPIB/Prologix
    end
    
    properties (Constant)
        Dual_Polarity='Yes'
        Number_of_channels='1'
        dev_id = 'Yokogawa'
        pauseTime = 0.5 %time in seconds set to allow for power supply to set properties
    end
    
    methods(Static)
        function obj = instance(name)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PowerSupplies.Yokogawa.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PowerSupplies.Yokogawa();
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
    end
    
    methods(Access=private)
        function [obj] = Yokogawa()
            obj.loadPrefs;
            display('setting comInfo for Yokogawa.')

            %establish connection
            [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] = ...
                Connect_Device(obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties);
            
            try
                %try to open comObject if you fail then call
                %Connect_Device to ask user. They may have changed com
                %Address or changed their comType
                fopen(obj.comObject);
            catch error
                [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] ...
                    = Connect_Device;
                fopen(obj.comObject);
            end
            obj.reset;
        end
    end
    
    methods(Access=private)
        
        function  setMeasurement_Mode(obj,measurement_type)
            switch measurement_type
                case {'Current','Curr','curr','current'}
                    string = sprintf('SENS:FUNC Curr ');
                    obj.writeOnly(string);
                case {'Voltage','Volt','volt','voltage'}
                    string = sprintf('SENS:FUNC Volt ');
                    obj.writeOnly(string);
                case {'Resistance','Res','res','resistance'}
                    string = sprintf('SENS:FUNC Res ');
                    obj.writeOnly(string);
                otherwise
                    error([measurement_type,' is not a supported measurement type!'])
            end
        end
        
        function value=Measure(obj)
            string = sprintf('FETC?');
            s = obj.writeRead(string);
            value = str2num(s);
        end
        
        function  setTrigger_type(obj,Trigger_type)
            switch Trigger_type
                case 'IMM'
                    string = sprintf(':TRIG:SOUR IMM');
                    obj.writeOnly(string);
                otherwise
                    error('Only Immediate (Imm) trigger allowed!')
            end
        end
        
        function check_channel(obj,channel)
            assert(ischar(channel),'Channel input must be a string!')
            assert(strcmp(channel,'1'),'Yokogawa only supports channel inputs of ''1''!')
        end
        
        function writeOnly(obj,string)
            fprintf(obj.comObject,string);
        end
        
        function [output] = writeRead(obj,string)
            output = query(obj.comObject,string);
        end
        
        function state = current_limit_state(obj)
            string = sprintf(':SOURce:CURRent:PROTection?');
            s = obj.writeRead(string);
            current_limit_setting = s(1:end-1);
            if current_limit_setting == '1'
                state = 'on';
            else
                state = 'off';
            end
        end
        
        function state = voltage_limit_state(obj)
            string = sprintf(':SOURce:Voltage:PROTection?');
            s = obj.writeRead(string);
            voltage_limit_setting = s(1:end-1);
            if voltage_limit_setting == '1'
                state = 'on';
            else
                state = 'off';
            end
        end
        
        function testLimit(obj,sourceMode)
            switch sourceMode
                case {'current','Current','CURRENT'}
                    [upperLimit,lowerLimit] = obj.getVoltageLimit('1');
                    measured_value = obj.measureVoltage('1');
                case {'voltage','VOLTAGE','Voltage'}
                    [upperLimit,lowerLimit] = obj.getCurrentLimit('1');
                    measured_value = obj.measureCurrent('1');
                otherwise
                    error('not supported sourceMode. Supported mode: voltage and current.')
            end
            if measured_value > 0
                upperRange = upperLimit*(1.1);
                lowerRange = upperLimit*(0.9);
            else
                upperRange = lowerLimit*(0.9);
                lowerRange = lowerLimit*(1.1);
            end
            if (measured_value>lowerRange && measured_value<upperRange)
                warndlg([obj.dev_id,'''s channel 1 is railing against its ',sourceMode,' limit'])
            end
        end
    end
    
    methods
        
        function setVoltageRange(obj,channel,range)
            obj.check_channel(channel)
            possibleValues = num2cell([110,60,30,20,12,2,0.2]);
            switch range
                case {'Auto','auto','AUTO'}
                    string = sprintf(':SOURce:Volt:RANGE:AUTO 1');
                    obj.writeOnly(string);
                case possibleValues
                    string = sprintf(':SOURce:Volt:RANGE: %f',range(1));
                    obj.writeOnly(string);
                otherwise
                    options = sprintf('%d,',possibleValues{:});
                    msg = 'Unsupported range value. Supported values: Auto,';
                    error([msg,options])
            end
            pause(obj.pauseTime)
        end
        
        function setCurrentRange(obj,channel,range)
            obj.check_channel(channel)
            possibleValues = num2cell([3,2,1,0.5,0.2,0.02,0.002,0.0002,0.00002]);
            switch range
                case {'Auto','auto','AUTO'}
                    string = sprintf(':SOURce:Current:RANGE:AUTO 1');
                    obj.writeOnly(string);
                case possibleValues
                    string = sprintf(':SOURce:Current:RANGE: %f',range(1));
                    obj.writeOnly(string);
                otherwise
                    options = sprintf('%d,',possibleValues{:});
                    msg = 'Unsupported range value. Supported values: Auto,';
                    error([msg,options])
            end
            pause(obj.pauseTime)
        end
        
        function setCurrent(obj,channel,current)
            obj.check_channel(channel)
            assert(isnumeric(current),'current must be data type numeric')
            obj.setSourceMode(channel,'Current');
            string = sprintf(':SOURce:CURRent:LEVel %f',current);
            obj.writeOnly(string);
            pause(obj.pauseTime)
        end
        
        function setVoltage(obj,channel,voltage)
            obj.check_channel(channel)
            assert(isnumeric(voltage),'voltage must be data type numeric')
            obj.setSourceMode(channel,'Voltage');
            string = sprintf(':SOURce:Voltage:LEVel %f',voltage);
            obj.writeOnly(string);
            pause(obj.pauseTime)
        end
        
        function setVoltageLimit(obj,channel,volt_limit)
            obj.check_channel(channel)
            assert(isnumeric(volt_limit),'voltage limit must be data type numeric')
            assert(numel(volt_limit)<=2 ,'voltage limit must be a vector of max length 2')
            if numel(volt_limit) == 2
                warning([obj.dev_id,' only supports symmetrical voltage limits. Voltage limit'...
                    ' will be set to +/- ',num2str(abs(volt_limit(1))),' volts.']);
            end
            string = sprintf(':SOURce:VOLT:PROT:ULIM %f', abs(volt_limit(1)));
            obj.writeOnly(string);
            obj.setSourceMode(channel,'Current');
            pause(obj.pauseTime)
        end
        
        function setCurrentLimit(obj,channel,current_limit)
            obj.check_channel(channel)
            assert(isnumeric(current_limit),'current limit must be data type numeric')
            assert(numel(current_limit)<=2 ,'current limit must be a vector of max length 2')
            if numel(current_limit) == 2
                warning([obj.dev_id,' only supports symmetrical current limits. Current limit'...
                    ' will be set to +/- ',num2str(abs(current_limit(1))),' amps.']);
            end
            string = sprintf(':SOURce:CURR:PROT:ULIM %f', abs(current_limit(1)));
            obj.writeOnly(string);
            obj.setSourceMode(channel,'Voltage');
            pause(obj.pauseTime)
        end
        
        function  setSourceMode(obj,channel,source_type)
            obj.check_channel(channel)
            switch lower(source_type)
                case 'current'
                    string = sprintf(':SOURce:FUNCtion CURRent');
                    obj.writeOnly(string);
                case 'voltage'
                    string = sprintf(':SOURce:FUNCtion VOLT');
                    obj.writeOnly(string);
                otherwise
                    error([source_type,' is not a supported source type!'])
            end
            pause(obj.pauseTime)
        end
        
        %%
        
        function  [voltage] = measureVoltage(obj,channel)
            obj.check_channel(channel)
            obj.setMeasurement_Mode('Voltage');
            voltage=obj.Measure;
            if abs(voltage) > 1e5
                pause(obj.pauseTime) %not sure why I need this
                voltage=obj.Measure;
            end
        end
        
        function  [current] = measureCurrent(obj,channel)
            obj.check_channel(channel)
            obj.setMeasurement_Mode('Current');
            current=obj.Measure;
            if abs(current) > 1e5
              pause(obj.pauseTime) %not sure why I need this
              current=obj.Measure;
            end
        end
        %%
        
        function  [Current_Range]=getCurrentRange(obj,channel)
            obj.check_channel(channel)
            %test if AUTO
            string = sprintf(':SOURce:Current:RANGE:AUTO?');
            s = obj.writeRead(string);
            if ~s(1:end-1)
                string = sprintf(':SOURce:CURRent:RANGe?');
                s = obj.writeRead(string);
                Current_Range = str2num(s(1:end-1));
            else
                Current_Range = 'Auto';
            end
        end
        
        function [Volt_Range]=getVoltageRange(obj,channel)
            obj.check_channel(channel)
            %test if AUTO
            string = sprintf(':SOURce:Voltage:RANGE:AUTO?');
            s = obj.writeRead(string);
            if ~s(1:end-1)
                string = sprintf(':SOURce:Voltage:RANGe?');
                s = obj.writeRead(string);
                Volt_Range = str2num(s(1:end-1));
            else
                Volt_Range = 'Auto';
            end
        end
        
        function current = getCurrent(obj,channel)
            obj.check_channel(channel)
            obj.setSourceMode(channel,'Current');
            string = sprintf(':SOURce:CURRent:LEVel?');
            s = obj.writeRead(string);
            current = str2num(s(1:end-1));
        end
        
        function voltage = getVoltage(obj,channel)
            obj.check_channel(channel)
            obj.setSourceMode(channel,'Voltage');
            string = sprintf(':SOURce:Voltage:LEVel?');
            s = obj.writeRead(string);
            voltage = str2num(s(1:end-1));
        end
        
        function [upperlim,lowerlim]  = getCurrentLimit(obj,channel)
            obj.check_channel(channel)
            string = sprintf(':SOUR:CURR:PROT:ULIM?');
            s = obj.writeRead(string);
            Current_Limit = str2num(s(1:end-1));
            upperlim = Current_Limit;
            lowerlim = -Current_Limit;
        end
        
        function [upperlim,lowerlim] = getVoltageLimit(obj,channel)
            obj.check_channel(channel)
            string = sprintf(':SOURce:VOLTAGE:PROT:ULIM?');
            s = obj.writeRead(string);
            VoltLim = str2num(s(1:end-1));
            upperlim = VoltLim;
            lowerlim = -VoltLim;
        end
        
        function sourceMode = getSourceMode(obj,channel)
            obj.check_channel(channel)
            string = sprintf(':SOURce:FUNCtion?');
            sourceMode = obj.writeRead(string);
            sourceMode = sourceMode(1:end-1);
            if strcmp(sourceMode,'VOLT')
                sourceMode = 'Voltage';
            else
                sourceMode = 'Current';
            end
        end
        
        function [Power_supply_state]  = getState(obj,channel)
            obj.check_channel(channel)
            string = sprintf(':OUTP:STAT?');
            s = obj.writeRead(string);
            state = str2num(s(1:end-1));
            if state==0
                Power_supply_state = 'Off';
            else
                Power_supply_state = 'On';
            end
        end
        
        %%

        function on(obj,varargin)
            %test to make sure that the current and voltage limit are set
            %before allowing the user to turn the power supply on.
            narginchk(1,2)
            if nargin > 1
                channel = varagin{1};
                obj.check_channel(channel)
            else
                channel = '1';
            end
            curr_lim_state = obj.current_limit_state;
            volt_lim_state = obj.voltage_limit_state;
            if strcmpi(curr_lim_state,'On') && strcmpi(volt_lim_state,'On')
                string = sprintf(':OUTP:STAT 1 ');
                obj.writeOnly(string);
            else
                error('you need to have a voltage limit and a current limit set to turn on.')
            end
            %check if your hitting a device limit
            sourceMode = obj.getSourceMode(channel);
            obj.testLimit(sourceMode);
            
        end
        
        function off(obj,varargin)
            narginchk(1,2)
            if nargin>1
                warning('Yokogawa does not support selective channel turning off. All channels will turn off.')
            end
            string = sprintf(':OUTP:STAT 0 ');
            obj.writeOnly(string);
        end
        
        function delete(obj)
            obj.reset;
            string = sprintf('SYSTEM:LOCAL '); %set the supply back to local control
            obj.writeOnly(string);
            fclose(obj.comObject);
            delete(obj.comObject);
        end
        
        function reset(obj)
            obj.off;
            string = sprintf('*RST');
            obj.writeOnly(string);
            obj.setVoltageLimit('1',5);
            obj.setCurrentLimit('1',0.05);
            obj.setCurrentRange('1','Auto')
            obj.setVoltageRange('1','Auto')
            obj.setTrigger_type('IMM')
        end
    end
end