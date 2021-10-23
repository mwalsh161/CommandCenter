classdef Keithley2450 < Modules.Driver
    
    properties
        comObject = []; % should be a visa connection
    end
    
    properties (Constant)
        Dual_Polarity = true;
        Number_of_channels = 1;
        dev_id = 'Keithley2450';
        pauseTime = 0.1; %time in seconds set to allow for power supply to set properties
    end
    
    methods(Static)
        function obj = instance(name,comObject)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PowerSupplies.Keithley2450.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PowerSupplies.Keithley2450(comObject);
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
    end
    
    methods(Access=private)
        function [obj] = Keithley2450(comObject)
            if ~isempty(obj.comObject) %if the comObject is empty don't do anything
                if isvalid(obj.comObject) %and it is vlaid
                    if strcmpi(obj.comObject.Status,'open') %and is open
                        fclose(obj.comObject); %then close and delete it
                        delete(obj.comObject);
                    end
                end
            end
            obj.comObject = comObject; %replace old comObject handle with new user-supplied one
            
            %If it is closed then try to open
            if strcmpi(obj.comObject.Status,'closed')
                try
                    fopen(obj.comObject);
                catch ME
                    err_message = sprintf('Failed to open device. Error message:\n%s\nMessage identifier:\n%s', ME.message, ME.identifier);
                    f = msgbox(err_message);
                    rethrow(ME); %rethrow error when trying to open comObject
                end
            end
        end
    end
    
    methods
        
        function  setMeasurement_Mode(obj,measurement_type)
            switch measurement_type
                case {'Current','Curr','curr','current'}
                    obj.writeOnly('SENS:FUNC "CURR"');
                    obj.writeOnly('SENS:CURR:RANG:AUTO ON');
                    obj.writeOnly('SENS:CURR:UNIT AMP');
                    obj.writeOnly('SENS:CURR:OCOM ON');
                case {'Voltage','Volt','volt','voltage'}
                    obj.writeOnly('SENS:FUNC "VOLT"');
                    obj.writeOnly('SENS:VOLT:RANG:AUTO ON');
                    obj.writeOnly('SENS:VOLT:UNIT VOLT');
                    obj.writeOnly('SENS:VOLT:OCOM ON');
                case {'Resistance','Res','res','resistance'}
                    obj.writeOnly('SENS:FUNC "RES"');
                    obj.writeOnly('SENS:RES:RANG:AUTO ON');
                    obj.writeOnly('SENS:RES:UNIT OHM');
                    obj.writeOnly('SENS:RES:OCOM ON');
                otherwise
                    error([measurement_type,' is not a supported measurement type!'])
            end
        end
        
        function writeOnly(obj,string)
            fprintf(obj.comObject,string);
        end
        
        function [output] = writeRead(obj,string)
            output = query(obj.comObject,string);
        end
        
        function testLimit(obj,sourceMode)
            sourceMode = upper(sourceMode);
            switch sourceMode
                case 'CURRENT'
                    [upperLimit,lowerLimit] = obj.getVoltageLimit('1');
                    measured_value = obj.measureVoltage('1');
                case 'VOLTAGE'
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

        function check_channel(obj,channel)
            assert(ischar(channel),'Channel input must be a string!')
            assert(strcmp(channel,'1'),'Keithley 2450 only supports channel inputs of ''1''!')
        end
        
        function setVoltageRange(obj,channel,range)
            obj.check_channel(channel)
            possibleValues = num2cell([]);
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
            possibleValues = num2cell([]);
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
            string = sprintf(':SOUR:CURR %f',current);
            obj.writeOnly(string);
            pause(obj.pauseTime)
        end
        
        function setVoltage(obj,channel,voltage)
            obj.check_channel(channel)
            assert(isnumeric(voltage),'voltage must be data type numeric')
            obj.setSourceMode(channel,'Voltage');
            string = sprintf(':SOUR:VOLT %f',voltage);
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
            string = sprintf(':SOUR:CURR:VLIM %f', abs(volt_limit(1)));
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
            string = sprintf(':SOUR:VOLT:ILIM %f', abs(current_limit(1)));
            obj.writeOnly(string);
            obj.setSourceMode(channel,'Voltage');
            pause(obj.pauseTime)
        end
        
        function  setSourceMode(obj,channel,source_type)
            obj.check_channel(channel)
            switch upper(source_type)
                case 'CURRENT'
                    obj.writeOnly(':SOUR:FUNC CURR');
                    obj.setMeasurement_Mode('Voltage')
                case 'VOLTAGE'
                    obj.writeOnly(':SOUR:FUNC VOLT');
                    obj.setMeasurement_Mode('Current')
                otherwise
                    error([source_type,' is not a supported source type!'])
            end
            pause(obj.pauseTime)
        end
        
        %%
        
        function  [voltage] = measureVoltage(obj,channel)
            obj.check_channel(channel)
            voltage = obj.writeRead(':MEAS:VOLT?');
            voltage = str2double(voltage);
        end

        
        function  [current] = measureCurrent(obj,channel)
            obj.check_channel(channel)
            current = obj.writeRead(':MEAS:CURR?');
            current = str2double(current);
        end
        
        function current = getCurrent(obj,channel)
            % Get set value
            obj.check_channel(channel)
            obj.setSourceMode(channel,'Current');
            string = sprintf(':SOUR:CURR:LEV?');
            s = obj.writeRead(string);
            current = str2double(s(1:end-1));
        end
        
        function voltage = getVoltage(obj,channel)
            % Get set value
            obj.check_channel(channel)
            obj.setSourceMode(channel,'Voltage');
            string = sprintf(':SOUR:CURR:LEV?');
            s = obj.writeRead(string);
            voltage = str2double(s(1:end-1));
        end
        
        function [upperlim,lowerlim]  = getCurrentLimit(obj,channel)
            obj.check_channel(channel)
            string = sprintf(':SOUR:VOLT:ILIM?');
            s = obj.writeRead(string);
            Current_Limit = str2double(s(1:end-1));
            upperlim = Current_Limit;
            lowerlim = -Current_Limit;
        end
        
        function [upperlim,lowerlim] = getVoltageLimit(obj,channel)
            obj.check_channel(channel)
            string = sprintf(':SOUR:CURR:VLIM?');
            s = obj.writeRead(string);
            VoltLim = str2double(s(1:end-1));
            upperlim = VoltLim;
            lowerlim = -VoltLim;
        end
        
        function sourceMode = getSourceMode(obj,channel)
            obj.check_channel(channel)
            string = sprintf(':SOUR:FUNC?');
            sourceMode = obj.writeRead(string);
            sourceMode = sourceMode(1:end-1);
            if strcmp(sourceMode,'VOLT')
                sourceMode = 'Voltage';
            else
                sourceMode = 'Current';
            end
        end
        
        function state  = getState(obj,channel)
            obj.check_channel(channel)
            string = sprintf(':OUTP:STAT?');
            s = obj.writeRead(string);
            state = str2double(s(1:end-1));
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
            
            obj.writeOnly(':OUTP:STAT 1 ');
            %check if your hitting a device limit
            sourceMode = obj.getSourceMode(channel);
            obj.testLimit(sourceMode);
            
        end
        
        function off(obj,varargin)
            narginchk(1,2)
            if nargin>1
                warning('Keithley 2450 does not support selective channel turning off. All channels will turn off.')
            end
            string = sprintf(':OUTP:STAT 0 ');
            obj.writeOnly(string);
        end
        
        function delete(obj)
            obj.reset;
            %string = sprintf('SYSTEM:LOCAL '); %set the supply back to local control
            obj.writeOnly(string);
            fclose(obj.comObject);
            delete(obj.comObject);
        end
        
        function reset(obj)
            obj.off;
            obj.writeOnly('*RST');
        end
    end
end
