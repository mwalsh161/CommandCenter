classdef HMP4040 < Drivers.PowerSupplies.PowerSupplies
    
    properties (SetAccess=private)
        currentLimitEnable = {'Off','Off','Off','Off'};
        voltageLimitEnable = {'Off','Off','Off','Off'};
        sourceMode = {'Voltage','Voltage','Voltage','Voltage'};
        VoltageMem = {5,5,5,5};
        voltLim = {5,5,5,5};
        CurrentMem = {0.05,0.05,0.05,0.05};
        currLim = {0.05,0.05,0.05,0.05};
    end
    
    properties
        deviceID = [];
        comObject = [];
    end
    
    properties (Constant)
        Dual_Polarity='No'
        Number_of_channels='4'
        dev_id = 'HMP4040'
    end
    
    methods(Static)
        
        function obj = instance(name,comObject)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PowerSupplies.HMP4040.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PowerSupplies.HMP4040(comObject);
            obj.deviceId = name;
            Objects(end+1) = obj;
        end
        
    end
    
    methods(Access=private)
        function [obj] = HMP4040(comObject)
            obj.loadPrefs;
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
                    messsage = sprintf('Failed to open device. Error message %s', Me.identifier);
                    f = msgbox(message);
                    rethrow(ME); %rethrow error when trying to open comObject
                end
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
            %after turning on this method determines if the given channel
            %is railing against its limit
            if strcmpi(obj.getState(channel),'off')
               return
            end
            pause(1);
            switch lower(sourceMode)
                case {'current'}
                    limType = 'voltage';
                    [upperLimit,lowerLimit] = obj.getVoltageLimit(channel);
                    measured_value = obj.measureVoltage(channel);
                case {'voltage'}
                    limType = 'current';
                    [upperLimit,lowerLimit] = obj.getCurrentLimit(channel);
                    measured_value = obj.measureCurrent(channel);
                otherwise
                    error('not supported sourceMode. Supported mode: voltage and current.')
            end
            if measured_value > 0
                upperRange = upperLimit*(1.1);
                lowerRange = upperLimit*(0.9);
            elseif  measured_value == 0
                return
            else
                upperRange = lowerLimit*(0.9);
                lowerRange = lowerLimit*(1.1);
            end
            if (measured_value>=lowerRange && measured_value<=upperRange)
                warndlg([obj.dev_id,'''s channel ',channel,' is railing against its ',limType,' limit'],['Limit Hit ',channel],'modal')
            end
        end
        
        function setChannel(obj,channel)
            %this method needs to be called before setting a property
            %lets the supply know which channel you are programming
            string = ['INSTRUMENT:SELECT OUT',channel];
            obj.writeOnly(string);
        end
        
        function turnOnChannel(obj,channel)
            obj.check_channel(channel)
            if strcmpi(obj.currentLimitEnable{str2num(channel)},'Off') || strcmpi(obj.voltageLimitEnable{str2num(channel)},'Off')
                error(['you need to have a voltage limit and a current limit set to turn on channel ',channel])
            end
            if strcmpi(obj.getSourceMode(channel),'Current')
                obj.setVoltageLimit(channel,obj.voltLim{str2num(channel)})
            else
                obj.setVoltage(channel,obj.VoltageMem{str2num(channel)})
            end
            obj.setChannel(channel)
            %before turning on set the right limits. This
            %is neccessary because this supply does not have indepedant
            %voltage limits/voltage settings type interactions. So
            %depending on the desired source mode we loop through and set
            %the right values
            switch obj.getSourceMode(channel)
                %this make sure that for this channel the right
                %properties are set for the corresponding source mode of
                %this channel
                case 'Voltage'
                    obj.setCurrentLimit(channel,obj.getCurrentLimit(channel));
                    obj.setVoltage(channel,obj.getVoltage(channel));
                case 'Current'
                    obj.setVoltageLimit(channel,obj.getVoltageLimit(channel));
                    obj.setCurrent(channel,obj.getCurrent(channel));
                otherwise
                    error('Supported Modes are Voltage and Current.')
            end
            string = sprintf(['OUTPUT:STATE ON ',channel]);
            obj.writeOnly(string);
            obj.testLimit(obj.getSourceMode(channel),channel)
        end
    end
    
    methods
        
        function  setCurrent(obj,channel,current)
            obj.check_channel(channel)
            obj.setChannel(channel)
            assert(isnumeric(current),'current must be data type numeric')
            if current<1e-3
                warning('HMP4040 does not support currents less than 1 mA. Changing current to 1 mA')
                current=1e-3;
            end
            string = ['SOURCE:Current:LEVEL:AMPLITUDE ',num2str(current)];
            obj.writeOnly(string);
            obj.CurrentMem{str2num(channel)} = current;
            obj.testLimit(obj.getSourceMode(channel),channel)
        end
        
        function  setVoltage(obj,channel,voltage)
            obj.check_channel(channel)
            obj.setChannel(channel)
            assert(isnumeric(voltage),'voltage must be data type numeric')
            string = ['SOURCE:VOLTAGE:LEVEL:AMPLITUDE ',num2str(voltage)];
            obj.writeOnly(string)
            obj.VoltageMem{str2num(channel)} = voltage;
            obj.testLimit(obj.getSourceMode(channel),channel)
        end
        
        function setSourceMode(obj,channel,mode)
            obj.check_channel(channel)
            assert(strcmp(mode,'Current') || strcmp(mode,'Voltage'),'Mode must be either Current or Voltage')
            obj.sourceMode{str2num(channel)} = mode;
        end
        
        function setVoltageLimit(obj,channel,volt_limit)
            obj.check_channel(channel)
            obj.setChannel(channel)
            assert(isnumeric(volt_limit),'voltage limit must be data type numeric')
            assert(numel(volt_limit)<=2 ,'voltage limit must be a vector of max length 2')
            if numel(volt_limit) == 2
                warning([obj.dev_id,' only supports symmetrical voltage limits. Voltage limit'...
                    ' will be set to + ',num2str(abs(volt_limit(1))),' volts and 0 volts.']);
            end
            string = ['SOURCE:VOLTAGE:LEVEL:AMPLITUDE ',num2str(volt_limit)];
            obj.writeOnly(string);
            obj.voltLim{str2num(channel)} = volt_limit;
            obj.voltageLimitEnable{str2num(channel)} = 'On';
        end
        
        function setCurrentLimit(obj,channel,current_limit)
            obj.check_channel(channel)
            obj.setChannel(channel)
            assert(isnumeric(current_limit),'current limit must be data type numeric')
            assert(numel(current_limit)<=2 ,'current limit must be a vector of max length 2')
            if numel(current_limit) == 2
                warning([obj.hmp4040dev_id,' only supports symmetrical current limits. Current limit'...
                    ' will be set to + ',num2str(abs(current_limit(1))),' amps and 0 amps.']);
            end
            if current_limit<1e-3
                warning('HMP4040 does not support currents less than 5 mA. Changing current limit to 5 mA')
                current_limit = 5e-3;
            end
            string = ['SOURCE:CURRENT:LEVEL:AMPLITUDE ',num2str(current_limit)];
            obj.writeOnly(string);
            obj.currLim{str2num(channel)} = current_limit;
            obj.currentLimitEnable{str2num(channel)} = 'On';
        end
        
        %%
        function  [voltage] = measureVoltage(obj,channel)
            obj.check_channel(channel)
            obj.setChannel(channel)
            string = 'MEASURE:VOLTAGE?';
            s = obj.writeRead(string);
            voltage = str2num(s(1:end-1));
        end
        
        function  [current] = measureCurrent(obj,channel)
            obj.check_channel(channel)
            obj.setChannel(channel)
            string = 'MEASURE:CURRENT?';
            s = obj.writeRead(string);
            current = str2num(s(1:end-1));
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
            obj.setChannel(channel)
            string = sprintf('OUTPUT:STATE?');
            reply = obj.writeRead(string);
            switch reply(1:end-1)
                case '0'
                    output_state='Off';
                case '1'
                    output_state='On';
            end
            Power_supply_state = output_state;
        end
        
        %%
        
        function  on(obj,varargin)
            narginchk(1,2)
            if nargin>1
               channel = varargin{1};
               obj.check_channel(channel);
               obj.turnOnChannel(channel);
            else
               obj.turnOnChannel('1');
               obj.turnOnChannel('2');
               obj.turnOnChannel('3');
               obj.turnOnChannel('4');
            end
        end
        
        function  off(obj,varargin)
            narginchk(1,2)
            if nargin>1
                channel = varargin{1};
                obj.check_channel(channel)
                obj.setChannel(channel)
                string = sprintf(['OUTPUT:STATE OFF ',channel]);
                obj.writeOnly(string);
            else
                obj.setChannel('1')
                string = sprintf('OUTPUT:STATE OFF: 1');
                obj.writeOnly(string);
                obj.setChannel('2')
                string = sprintf('OUTPUT:STATE OFF 2');
                obj.writeOnly(string);
                obj.setChannel('3')
                string = sprintf('OUTPUT:STATE OFF 3');
                obj.writeOnly(string);
                obj.setChannel('4')
                string = sprintf('OUTPUT:STATE OFF 4');
                obj.writeOnly(string);
            end
        end
        
        function reset(obj)
            obj.off;
            string = sprintf('*RST');
            obj.writeOnly(string);
            obj.currentLimitEnable = {'Off','Off','Off','Off'};
            obj.voltageLimitEnable = {'Off','Off','Off','Off'};
            obj.sourceMode = {'Voltage','Voltage','Voltage','Voltage'};
            
            obj.setCurrentLimit('1',0.05);
            obj.setVoltageLimit('1',5);
            
            obj.setCurrentLimit('2',0.05);
            obj.setVoltageLimit('2',5);
            
            obj.setCurrentLimit('3',0.05);
            obj.setVoltageLimit('3',5);
            
            obj.setCurrentLimit('4',0.05);
            obj.setVoltageLimit('4',5);
        end
        
        function delete(obj)
            obj.reset;
            string = sprintf('SYSTEM:LOCAL '); %set the supply back to local control
            obj.writeOnly(string);
            fclose(obj.comObject);
            delete(obj.comObject);
        end
        
    end
end