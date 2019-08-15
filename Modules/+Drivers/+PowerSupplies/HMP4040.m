classdef HMP4040 < Modules.Driver
    
    properties (SetAccess=private)
        sourceMode = {'Voltage','Voltage','Voltage','Voltage'}; % Source mode (only used to determine whether railing against current or voltage produces warning)
    end
    
    properties
        deviceName = [];
        comObject = []; % Should be a serial connector; all methods defined accordingly
    end
    
    properties (Constant)
        Dual_Polarity=false;
        Number_of_channels=4;
        dev_id = 'HMP4040';
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
            obj.deviceName = name;
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
                    err_message = sprintf('Failed to open device. Error message:\n%s\nMessage identifier:\n%s', ME.message, ME.identifier);
                    f = msgbox(err_message);
                    rethrow(ME); %rethrow error when trying to open comObject
                end
            end
        end

        function check_channel(obj,channel)
            assert(ischar(channel),'Channel input must be a string!')
            channels=num2str(1:obj.Number_of_channels);
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
            %Determines if the given channel is railing against its limit (which will be the current if in voltage mode, or the voltage if in current mode)
            pause(1);
            obj.setChannel(channel)
            status = obj.writeRead('STAT:QUES:INST:ISUM1:COND?'); % Query channel status
            if strcmp(status(1),'0')
                return % Short circuit if channel off
            end
            railing = false;

            % Determine if railing best on whether current/voltage mode set
            switch obj.getSourceMode(channel)
                case {'current'}
                    limType = 'voltage';
                    if strcmp(status(1),'2')
                        railing = true;
                    end
                case {'voltage'}
                    limType = 'current';
                    if strcmp(status(1),'1')
                        railing = true;
                    end
                otherwise
                    error('not supported sourceMode. Supported mode: voltage and current.')
            end
            warndlg([obj.dev_id,'''s channel ',channel,' is railing against its ',limType,' limit'],['Limit Hit ',channel],'modal')
        end
        
        function setChannel(obj,channel)
            %this method needs to be called before setting a property
            %lets the supply know which channel you are programming
            obj.check_channel(channel)
            string = ['INSTRUMENT:SELECT OUT',channel];
            obj.writeOnly(string);
        end
        
        function turnOnChannel(obj,channel)
            obj.setChannel(channel)
            string = ['OUTPUT:STATE ON ',channel]   ;
            obj.writeOnly(string);
            obj.testLimit(obj.getSourceMode(channel),channel)
        end
    end
    
    methods
        
        function  setCurrent(obj,channel,current)
            obj.setChannel(channel)
            assert(isnumeric(current),'current must be data type numeric')
            if current<1e-3
                warning('HMP4040 does not support currents less than 1 mA. Changing current to 1 mA')
                current=1e-3;
            end
            string = ['SOURCE:Current:LEVEL:AMPLITUDE ',num2str(current)];
            obj.writeOnly(string);
            obj.testLimit(obj.getSourceMode(channel),channel)
        end
        
        function  setVoltage(obj,channel,voltage)
            obj.setChannel(channel)
            assert(isnumeric(voltage),'voltage must be data type numeric')
            string = ['SOURCE:VOLTAGE:LEVEL:AMPLITUDE ',num2str(voltage)];
            obj.writeOnly(string)
            obj.testLimit(obj.getSourceMode(channel),channel)
        end
        
        function setSourceMode(obj,channel,mode)
            obj.check_channel(channel)
            assert(strcmp(mode,'Current') || strcmp(mode,'Voltage'),'Mode must be either Current or Voltage')
            obj.sourceMode{str2num(channel)} = mode;
            obj.testLimit((obj.getSourceMode(channel),channel);
        end
        
        %%
        function  [voltage] = measureVoltage(obj,channel)
            obj.setChannel(channel)
            s = obj.writeRead('MEASURE:VOLTAGE?');
            voltage = str2num(s(1:end-1));
        end
        
        function  [current] = measureCurrent(obj,channel)
            obj.setChannel(channel)
            s = obj.writeRead('MEASURE:CURRENT?');
            current = str2num(s(1:end-1));
        end
        %%
        
        function sourceMode = getSourceMode(obj,channel)
            obj.setchannel(channel)
            sourceMode = obj.sourceMode{str2num(channel)};
         end
        
        function current = getCurrent(obj,channel)
            obj.setschannel(channel)
            current = obj.writeRead('CURRENT?');
        end
        
        function voltage = getVoltage(obj,channel)
            obj.setchannel(channel)
            voltage = obj.writeRead('VOLT?');
        end
        
        function  [Power_supply_state] = getState(obj,channel)
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
            obj.writeOnly('*RST');
            obj.off;
            obj.sourceMode = {'Voltage','Voltage','Voltage','Voltage'};
            
            obj.setCurrent('1',0.05);
            obj.setVoltage('1',5);
            
            obj.setCurrent('2',0.05);
            obj.setVoltage('2',5);
            
            obj.setCurrent('3',0.05);
            obj.setVoltage('3',5);
            
            obj.setCurrent('4',0.05);
            obj.setVoltage('4',5);
        end
        
        function delete(obj)
            string = sprintf('SYSTEM:LOCAL '); %set the supply back to local control
            obj.writeOnly(string);
            if ~isempty(obj.comObject) && isvalid(obj.comObject)
                fclose(obj.comObject);
                delete(obj.comObject);
            end
        end
        
    end
end