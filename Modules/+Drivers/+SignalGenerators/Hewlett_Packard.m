classdef Hewlett_Packard < Drivers.SignalGenerators.SignalGenerator 
    % Matlab Object Class implementing control for Hewlett_Packard
    % Signal Generator
    %ESG
    % Primary purpose of this is to control the SG
    %
    % One instance controls 1 physical device. Multiple instances can exist
    % simultaneously for different hardware channels. If you need two
    % devices to work together, a new class should be designed.
    %
    % State information of the machine is stored on the SG. Can be obtained
    % using the get methods.
    
    properties 
        prefs = {'comObjectInfo'};
        comObjectInfo = struct('comType','','comAddress','','comProperties','') %this property stores comInformation
        %to change comport information after instantiation call instance of
        %this class and change using comObject property. To make sure it is
        %permanant you can call Connect Devices again and set outputs to
        %the appropriate fields of comObjectInfo
        comObject;     % Serial/GPIB/Prologix
    end
  
    methods(Static)
        
        function obj = instance(name)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.SignalGenerators.Hewlett_Packard.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.SignalGenerators.Hewlett_Packard();
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
    end
    
    methods(Access=private)
        function [obj] = Hewlett_Packard()
            obj.loadPrefs;
            display('setting comInfo for Hewlett_Packard.')
            if isempty(obj.comObjectInfo.comType)&& isempty(obj.comObjectInfo.comAddress)&& isempty(obj.comObjectInfo.comProperties)
                %first time connecting should run the helperfunction
                %Connect_Device to establish your connection
                [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] = Connect_Device;
            else
                try
                    %this is used for connecting every time after the first
                    %time
                    [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] = ...
                        Connect_Device(obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties);
                catch
                    %this is only called if you change a device property
                    %after the intiial connection (ex: change GPIB
                    %address). This allows you to establish a new
                    %connection.
                    [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] ...
                        = Connect_Device;
                end
            end
            fopen(obj.comObject);
            obj.reset; %set the SG to a known state
        end
    end
    
    methods (Access=private)
        
        function writeOnly(obj,string)
            fprintf(obj.comObject,string);
        end
        
        function [output] = writeRead(obj,string)
            output = query(obj.comObject,string);
        end
        
        function  setListTrig(obj,ListTrig)
            if strcmp(ListTrig,'EXT')
                string = sprintf(':SOURce:LIST:TRIGger:SOURce EXTernal');
                obj.writeOnly(string);
            else
                error('Only EXT trig property is allowed')
            end
        end
        
        function  setFreqList(obj,FreqList)
            FreqMode = obj.getFreqMode;
            
            if strcmp(FreqMode,'LIST')
                setFreqMode(obj,'CW'); %set to CW first
                warning('Changed Signal Generator Frequency Mode to CW for programming')
            end
            obj.writeOnly('*WAI');
            NumberOfPoints = length(FreqList);
            clear string;
            if NumberOfPoints > 0
                for i = 1:NumberOfPoints
                    if i == 1
                        string = sprintf('%f',FreqList(i));
                    else
                        string = [string sprintf(',%f',FreqList(i))];
                    end
                end
                string = [':SOURce:LIST:FREQuency ',string];
                obj.writeOnly('*WAI');
                obj.writeOnly(string);
            end
        end
        
        function  setPowerList(obj,PowerList)
            PowerMode = obj.getPowerMode;
            
            if strcmp(PowerMode,'LIST')
                setPowerMode(obj,'FIX'); %set to CW first
                warning('Changed Signal Generator Power Mode to FIX for programming')
            end
            obj.writeOnly('*WAI');
            NumberOfPoints = length(PowerList);
            clear string;
            if NumberOfPoints > 0
                for i = 1:NumberOfPoints
                    if i == 1
                        string = sprintf('%f',PowerList(i));
                    else
                        string = [string sprintf(',%f',PowerList(i))];
                    end
                end
                string = ['SOURCE:LIST:POWER ',string];
                obj.writeOnly('*WAI');
                obj.writeOnly(string);
            end
        end
        
        function  exeLIST(obj)
            PowerMode = obj.getPowerMode;
            FreqMode = obj.getFreqMode;
            ListTrig = obj.getListTrig;
            
            if ~(strcmp(PowerMode,'LIST'))
                setPowerMode(obj,'LIST')
            end
            
            if ~(strcmp(FreqMode,'LIST'))
                setFreqMode(obj,'LIST')
                error('Setting the Signal Generator to List mode')
            end
            
            if ~strcmp(ListTrig,'EXT')
                setListTrig(obj,'EXT')
                error('Changed trigger mode to EXT')
            end
            
            obj.start_list;
            
        end
        
        function start_list(obj)
            string = sprintf(':INITiate:CONTinuous:ALL 1');
            obj.writeOnly(string);
            obj.on
        end
        
        function [ListTrig] = getListTrig(obj)
            string = sprintf(':SOURce:LIST:TRIGger:SOURce?');
            s = obj.writeRead(string);
            ListTrig = s(1:end-1);
        end
        
        
    end
    %see superclass for a description of what the methods do. 
    methods
        function  setFreqMode(obj,FreqMode)
            switch FreqMode
                case {'FIX','CW'}
                    obj.writeOnly(':SOURce:FREQuency:MODE CW');
                case {'LIST'}
                    obj.writeOnly(':SOURce:FREQuency:MODE LIST');
                    obj.writeOnly('SOURCE:LIST:MODE STEP');     %Only STEP modes can be used
                otherwise
                    error('No frequency mode was set. Only CW and LIST mode available.');
            end
        end
        
        function  setPowerMode(obj,PowerMode)
            switch PowerMode
                case {'FIX','CW'}
                    PowerMode = 'FIX';
                    string = sprintf(':SOURce:POWer:MODE %s',PowerMode);
                    obj.writeOnly(string);
                case {'LIST'}
                    string = sprintf(':SOURce:POWer:MODE %s',PowerMode);
                    obj.writeOnly(string);
                otherwise
                    error('No power mode was set. Only Fixed (FIX) and LIST mode available.');
            end
        end
        
        function setModulationDeviation(obj,channel,deviation,unit)
            switch channel
                case {1}
                    string = sprintf(':SOURCE:FM1:DEVIATION %d %s',deviation,unit);
                    
                case {2}
                    string = sprintf(':SOURCE:FM2:DEVIATION %d %s',deviation,unit);
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
            obj.writeOnly(string);
        end
        
        function setModulationFreq(obj,channel,modFreq,unit)
            switch channel
                case {1}
                    string = sprintf(':SOURCE:FM1:INTERNAL:FREQUENCY %d %s',modFreq,unit);
                    
                case {2}
                    string = sprintf(':SOURCE:FM2:INTERNAL:FREQUENCY %d %s',modFreq,unit);
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
            obj.writeOnly(string);
            
        end
        
        function turnModulationOn(obj,channel)
            switch channel
                case {1}
                    string = sprintf(':SOURCE:FM1:STATE ON');
                    
                case {2}
                    string = sprintf(':SOURCE:FM2:STATE ON');
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
            obj.writeOnly(string);
            
        end
        
        function setLFOutputVoltage(obj,voltage)
            assert(isnumeric(voltage),'voltage must be numeric');
            string = sprintf(':SOUR:LFO:AMPL %dV',voltage);
            obj.writeOnly(string);
        end
        
        function outputModulationFreq(obj)
            string = sprintf(':SOURce:LFOutput:SOURce INT');
            obj.writeOnly(string);
            string = sprintf(':SOURce:LFOutput:STATe ON');
            obj.writeOnly(string);
        end
        
        function turnModulationOff(obj,channel)
            switch channel
                case {1}
                    string = sprintf(':SOURCE:FM1:STATE OFF');
                    
                case {2}
                    string = sprintf(':SOURCE:FM2:STATE OFF');
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
            obj.writeOnly(string);
        end
        
        function setUnitPower(obj)
            warning('It is dbm by default. Cannot be changed!')
        end
        
        function  setFreqCW(obj,Freq)
            string = sprintf(':SOURCE:FREQUENCY:CW %f',Freq);
            obj.writeOnly(string);
        end
        
        function  setPowerCW(obj,Power)
            string = sprintf(':POWER:LEVEL:IMMEDIATE:AMPLITUDE %f DBM',Power);
            obj.writeOnly(string);
        end
        
        function setFMMode(obj,channel,mode)
            assert(ischar(mode),'mode must be numeric')
            switch channel
                case {1}
                    string = sprintf(':SOURCE:FM1:SOURCE %s?',mode);
                    
                case {2}
                    string = sprintf(':SOURCE:FM2:SOURCE %s?',mode);
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
            obj.writeOnly(string);
        end
        
        function setFMCoupling(obj,channel,mode)
             assert(ischar(mode),'mode must be numeric')
            switch channel
                case {1}
                    string = sprintf(':SOURce:FM1:EXTernal:COUPling %s?',mode);
                    
                case {2}
                    string = sprintf(':SOURce:FM2:EXTernal:COUPling %s?',mode);
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
            obj.writeOnly(string); 
        end

        function turnModulationOnAll(obj)
            string = sprintf(':OUTPut:MODulation:STATe ON');
            obj.writeOnly(string);
        end
        
        function turnModulationOffAll(obj)
            string = sprintf(':OUTPut:MODulation:STATe OFF');
            obj.writeOnly(string);
        end
        
        %% get methods
        function state = getModulationStateTotal(obj)
            string = sprintf(':OUTPut:MODulation:STATe?');
            s = obj.writeRead(string);
            mode = str2num(s(1:end-1));
            switch mode
                case {1}
                    state = 'on';
                    
                case {0}
                    state = 'off';
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
        end
        
         function mode = getFMMode(obj,channel)
            assert(ischar(mode),'mode must be numeric')
            switch channel
                case {1}
                    string = sprintf(':SOURCE:FM1:SOURCE?');
                    
                case {2}
                    string = sprintf(':SOURCE:FM2:SOURCE?');
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
            s = obj.writeRead(string);
            mode = str2num(s(1:end-1));
        end
        
        function mode = getFMCoupling(obj,channel)
             assert(ischar(mode),'mode must be numeric')
            switch channel
                case {1}
                    string = sprintf(':SOURce:FM1:EXTernal:COUPling?');
                    
                case {2}
                    string = sprintf(':SOURce:FM2:EXTernal:COUPling?');
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
            s = obj.writeRead(string);
            mode = str2num(s(1:end-1));
        end
        
        function UnitPower = getUnitPower(obj)
            UnitPower = 'dBm';
        end
        
        function [Freq] = getFreqCW(obj)
            FreqMode = obj.getFreqMode;
            if  strcmp(FreqMode,'LIST')
                error('You are in LIST MODE. SWITCH to CW.')
            end
            string = sprintf('FREQ?');
            s = obj.writeRead(string);
            Freq = str2num(s(2:end-1));
        end
        
        
        function  [Power] = getPowerCW(obj)
            string = sprintf('POW?');
            s = obj.writeRead(string);
            Power= str2num(s(1:end-1));
        end
        
        
        function  [FreqMode] = getFreqMode(obj)
            string = sprintf('FREQ:MODE?');
            s = obj.writeRead(string);
            FreqMode = s(1:end-1);
        end
        
        
        function  [PowerMode] = getPowerMode(obj)
            string = sprintf('POWer:MODE?');
            s = obj.writeRead(string);
            PowerMode = s(1:end-1);
        end
        
        function  [FreqList] = getFreqList(obj)
            string = sprintf('LIST:FREQ?');
            s = obj.writeRead(string);
            FreqList = str2num(s);
        end
        
        
        function  [PowerList] = getPowerList(obj)
            string = sprintf(':SOURce:LIST:POWer?');
            s = obj.writeRead(string);
            PowerList = str2num(s);
        end
        
        function  [MWstate] = getMWstate(obj)
            string = sprintf(':OUTP:STATE?');
            s = obj.writeRead(string);
            if strcmp(s(1:end-1),'1')
                MWstate = 'On';
            else
                MWstate = 'Off';
            end
        end
        
        function deviation = getModulationDeviation(obj,channel)
            switch channel
                case {1}
                    string = sprintf(':SOURCE:FM1:DEVIATION?');
                    
                case {2}
                    string = sprintf(':SOURCE:FM2:DEVIATION?');
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
            s = obj.writeRead(string);
            deviation = str2num(s(1:end-1));
        end
        
        function modFreq = getModulationFreq(obj,channel)
            switch channel
                case {1}
                    string = sprintf(':SOURCE:FM1:INTERNAL:FREQUENCY?');
                    
                case {2}
                    string = sprintf(':SOURCE:FM2:INTERNAL:FREQUENCY?');
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
            s = obj.writeRead(string);
            modFreq = str2num(s(1:end-1));
        end
      
        function modState = getModulationState(obj,channel)
            switch channel
                case {1}
                    string = sprintf(':SOURCE:FM1:STATE?');
                    
                case {2}
                    string = sprintf(':SOURCE:FM2:STATE?');
                    
                otherwise
                    error('Only channels 1 and 2 allowed')
            end
            s = obj.writeRead(string);
            if strcmp(s(1:end-1),'1')
                modState = 'On';
            else
                modState = 'Off';
            end
        end
        
        function voltage = getLFOutputVoltage(obj)
            string = sprintf(':SOUR:LFO:AMPL ?');
            s = obj.writeRead(string);
            voltage = str2num(s(1:end-1));
        end
        
        function state = getOutputModulationFreq(obj)
            string = sprintf(':SOURce:LFOutput:STATe?');
            s = obj.writeRead(string);
             if strcmp(s(1:end-1),'1')
                modState = 'On';
            else
                modState = 'Off';
            end
        end
        
        %%
        
        function delete(obj)
            obj.reset;
            fclose(obj.comObject);
            delete(obj.comObject);
        end
        
        function on(obj)
            string = sprintf(':OUTP:STATE ON');
            obj.writeOnly(string);
        end
        
        function off(obj)
            string = sprintf(':OUTP:STATE Off');
            obj.writeOnly(string);
        end
        
        function program_list(obj,freq_list,power_list)
            obj.setListTrig('EXT')
            obj.setFreqList(freq_list);
            obj.setPowerList(power_list);
            obj.setFreqMode('LIST');
            obj.setPowerMode('LIST');
            obj.exeLIST;
            obj.off;
        end
        
        function  reset(obj)
            string = sprintf('*RST');
            obj.writeOnly(string);
        end
        
    end
end