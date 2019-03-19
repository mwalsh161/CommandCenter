classdef HAMEG < Drivers.PowerSupplies.PowerSupplies
    
    properties (SetAccess=private)
        currentLimitEnable = {'Off','Off'};
        voltageLimitEnable = {'Off','Off'};
        sourceMode = {'Voltage','Voltage'};
        VoltageMem = {5,5};
        voltLim = {5,5};
        CurrentMem = {0.05,0.05};
        currLim = {0.05,0.05};
    end
    
    properties
        prefs = {'comObjectInfo'};
        comObjectInfo = struct('comType','','comAddress','','comProperties','')
        comObject;     % USB-Serial/GPIB/Prologix
    end
    
    properties (Constant)
        Dual_Polarity='No'
        Number_of_channels='2'
        dev_id = 'HAMEG'
        pauseTime = 0.5 %time in seconds set to allow for power supply to set properties
    end
    
    methods(Static)
        
        function obj = instance(name)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PowerSupplies.HAMEG.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PowerSupplies.HAMEG();
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
        
    end
    
    methods(Access=private)
        function [obj] = HAMEG()
            obj.loadPrefs;
            display('setting comInfo for HAMEG.')
            %establish connection
            [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] = ...
                Connect_Device(obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties);
            
            obj.comObject.Terminator = 'CR';
            try
                %try to open comObject if you fail then call
                %Connect_Device to ask user. They may have changed com
                %Address or changed their comType
                fopen(obj.comObject);
            catch
                [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] ...
                    = Connect_Device;
                fopen(obj.comObject);
            end
            obj.reset;
        end
    end
    
    methods(Access=private)
        function check_channel(obj,channel)
            assert(ischar(channel),'Channel input must be a string!')
            channels=num2str(1:str2num(obj.Number_of_channels));
            possible_channels=strsplit(channels,' ');
            assert(~isempty(strmatch(channel,possible_channels)) ,[channel,' is not a supported channel!'])
        end
        
        function writeOnly(obj,string)
            fprintf(obj.comObject,string);
        end
        
        function [output] = writeRead(obj,string)
            output = query(obj.comObject,string);
        end
        
        function testLimit(obj,sourceMode,channel)
            switch lower(sourceMode)
                case 'current'
                    [upperLimit,lowerLimit] = obj.getVoltageLimit(channel);
                    measured_value = obj.measureVoltage(channel);
                case 'voltage'
                    [upperLimit,lowerLimit] = obj.getCurrentLimit(channel);
                    measured_value = obj.measureCurrent(channel);
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
                warndlg([obj.dev_id,'''s channel ',channel,' is railing against its ',sourceMode,' limit'])
            end
        end
        
    end
    
    methods
        
        function  setCurrent(obj,channel,current)
            obj.check_channel(channel)
            assert(isnumeric(current),'current must be data type numeric')
            if strcmpi(obj.getState(channel),'on')
                error('Cannot set properties when on.')
            end
            if current<1e-3
                warning('HAMEG does not support currents less than 1 mA. Changing current to 1 mA')
                current=1e-3;
            end
            string=sprintf('TRI:%f',current);
            obj.writeOnly(string);
            obj.CurrentMem{str2num(channel)} = current;
            pause(obj.pauseTime)
        end
        
        function  setVoltage(obj,channel,voltage)
            obj.check_channel(channel)
            assert(isnumeric(voltage),'voltage must be data type numeric')
            obj.check_channel(channel)
            if strcmpi(obj.getState(channel),'on')
                error('Cannot set properties when on.')
            end
            string=sprintf(['SU',channel,':%f'],voltage);
            obj.writeOnly(string);
            obj.VoltageMem{str2num(channel)} = voltage;
            pause(obj.pauseTime)
        end
        
        function setVoltageLimit(obj,channel,volt_limit)
            obj.check_channel(channel)
            assert(isnumeric(volt_limit),'voltage limit must be data type numeric')
            assert(numel(volt_limit)<=2 ,'voltage limit must be a vector of max length 2')
            if numel(volt_limit) == 2
                warning([obj.dev_id,' only supports symmetrical voltage limits. Voltage limit'...
                    ' will be set to + ',num2str(abs(volt_limit(1))),' volts and 0 volts.']);
            end
            obj.check_channel(channel)
            if strcmpi(obj.getState(channel),'on')
                error('Cannot set properties when on.')
            end
            string=sprintf(['SU',channel,':%f'],volt_limit);
            obj.writeOnly(string);
            obj.voltLim{str2num(channel)} = volt_limit;
            obj.voltageLimitEnable{str2num(channel)} = 'On';
            pause(obj.pauseTime)
        end
        
        function  setCurrentLimit(obj,channel,current_limit)
            obj.check_channel(channel)
            assert(isnumeric(current_limit),'current limit must be data type numeric')
            assert(numel(current_limit)<=2 ,'current limit must be a vector of max length 2')
            if numel(current_limit) == 2
                warning([obj.dev_id,' only supports symmetrical current limits. Current limit'...
                    ' will be set to + ',num2str(abs(current_limit(1))),' amps and 0 amps.']);
            end
            if current_limit<1e-3
                warning('HAMEG does not support currents less than 1 mA. Changing current limit to 1 mA')
                current_limit=1e-3;
            end
            if strcmpi(obj.getState(channel),'on')
                error('Cannot set properties when on.')
            end
            string=sprintf(['SI',channel,':%f'],current_limit);
            obj.writeOnly(string);
            obj.currLim{str2num(channel)} = current_limit;
            obj.currentLimitEnable{str2num(channel)} = 'On';
            pause(obj.pauseTime)
        end
        
        function setSourceMode(obj,channel,mode)
            obj.check_channel(channel)
            assert(strcmp(mode,'Current') || strcmp(mode,'Voltage'),'Mode must be either Current or Voltage')
            if strcmpi(obj.getState(channel),'on')
                error('Cannot set properties when on.')
            end
            obj.sourceMode{str2num(channel)} = mode;
            pause(obj.pauseTime)
        end
        
        %%
        function  [voltage] = measureVoltage(obj,channel)
            obj.check_channel(channel)
            string=['MU',channel];
            s = obj.writeRead(string);
            strings=strsplit(s,':');
            voltage=strings{2};
            voltage=str2num(voltage(1:end-2));
        end
        
        function  [current] = measureCurrent(obj,channel)
            obj.check_channel(channel)
            string=['MI',channel];
            s = obj.writeRead(string);
            strings=strsplit(s,':');
            current=strings{2};
            current=str2num(current(1:end-2));
        end
        %%
        
        function sourceMode = getSourceMode(obj,channel)
            obj.check_channel(channel)
            sourceMode = obj.sourceMode{str2num(channel)};
        end
        
        function [upperlim,lowerlim]  = getCurrentLimit(obj,channel)
            obj.check_channel(channel)
            upperlim = obj.currLim{str2num(channel)};
            lowerlim = 0;
        end
        
        function [upperlim,lowerlim] = getVoltageLimit(obj,channel)
            obj.check_channel(channel)
            upperlim = obj.voltLim{str2num(channel)};
            lowerlim = 0;
        end
        
        function current = getCurrent(obj,channel)
            obj.check_channel(channel)
            current = obj.CurrentMem{str2num(channel)};
        end
        
        function voltage = getVoltage(obj,channel)
            obj.check_channel(channel)
            voltage = obj.VoltageMem{str2num(channel)};
        end
        
        function  [Power_supply_state] = getState(obj,channel)
            obj.check_channel(channel)
            string = sprintf('STAT');
            reply = obj.writeRead(string);
            states=strsplit(reply,' ');
            switch states{1}
                case 'OP0'
                    output_state='Off';
                case 'OP1'
                    output_state='On';
            end
            Power_supply_state = output_state;
        end
       
        function  on(obj,varargin)
            narginchk(1,2)
            if nargin>1
                error('Hameg does not support selective channel turning on. All channels will turn on.')
            else
                for channel = 1 : str2num(obj.Number_of_channels)
                    %before turning on set the right limits. This
                    %is neccessary because this supply does not have indepedant
                    %voltage limits/voltage settings type interactions. So
                    %depending on the desired source mode we loop through and set
                    %the right values
                    
                    channel = num2str(channel);
                    switch obj.getSourceMode(channel)
                        %this make sure that for this channel the right
                        %properties are set for the corresponding source mode of
                        %this channel
                        case 'Voltage'
                            obj.setCurrentLimit(channel,obj.getCurrentLimit(channel));
                            obj.setVoltage(channel,obj.getVoltage(channel)) ;
                        case 'Current'
                            obj.setVoltageLimit(channel,obj.getVoltageLimit(channel));
                            obj.setCurrent(channel,obj.getCurrent(channel));
                        otherwise
                            error('Supported Modes are Voltage and Current.')
                    end
                end
                %% turn on all the channel
                string = sprintf('OP1');
                obj.writeOnly(string);
                pause(obj.pauseTime)
                %% test if a channel is railing
                for channel = 1 : str2num(obj.Number_of_channels)
                    channel = num2str(channel);
                    obj.testLimit(obj.getSourceMode(channel),channel);
                end
            end
        end
        
        function  off(obj,varargin)
            narginchk(1,2)
            if nargin>1
                warning('Hameg does not support selective channel turning off. All channels will turn off.')
            end
            string = sprintf('OP0');
            obj.writeOnly(string);
        end
        
        function reset(obj)
            obj.off;
            string = sprintf('*RST');
            obj.writeOnly(string);
            
            obj.currentLimitEnable = {'Off','Off'};
            obj.voltageLimitEnable = {'Off','Off'};
            obj.sourceMode = {'Voltage','Voltage'};
            
            obj.setCurrentLimit('1',0.05);
            obj.setVoltageLimit('1',5);
            
            obj.setCurrentLimit('2',0.05);
            obj.setVoltageLimit('2',5);
        end
        
        function delete(obj)
            obj.reset;
            string = sprintf('SYSTEM:LOCAL '); %set the supply back to local control
            obj.writeOnly(string);
            fclose(obj.comObject);
            delete(obj.comObject);
            pause(1);
        end
    end
end