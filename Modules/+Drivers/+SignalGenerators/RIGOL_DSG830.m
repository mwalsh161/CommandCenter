classdef RIGOL_DSG830 < Drivers.SignalGenerators.SignalGenerator 
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
        
        function obj = instance(name,comObject)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.SignalGenerators.RIGOL_DSG830.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.SignalGenerators.RIGOL_DSG830(comObject);
            obj.singleton_id = name;
            Objects(end+1) = obj;
            
        end
    end
    
    methods(Access=private)
        function [obj] = RIGOL_DSG830(comObject)
            obj.comObject = comObject;
            obj.loadPrefs;
            if ~strcmpi(obj.comObject.status,'open')
                fopen(obj.comObject);
            end
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
        
        
    end
    %see superclass for a description of what the methods do. 
    methods
       %Set methods
       function setStepTrig(obj,StepTrig)
            switch lower(StepTrig)
                case {'external','ext'}
                    string = sprintf(':SOUR:SWE:SWE:TRIG:TYPE EXT');
                case {'bus'}
                    string = sprintf(':SOUR:SWE:SWE:TRIG:TYPE BUS');
                case {'auto'}
                    string = sprintf(':SOUR:SWE:SWE:TRIG:TYPE IMM');
                case {'key'}
                     string = sprintf(':SOUR:SWE:SWE:TRIG:TYPE KEY');
                otherwise
                    error('unknown trig type. Options are ext,bus,auto, and key.')
            end
            obj.writeOnly(string);
        end
        
        function setTrigPolarity(obj,polarity)
            switch lower(polarity)
                case {'pos', 'positive'}
                    trigger = sprintf(':SOURce:INPut:TRIGger:SLOPe POSitive');
                case {'neg','negative'}
                    trigger = sprintf(':SOURce:INPut:TRIGger:SLOPe NEGative');
                otherwise
                    error('unknown polarity. Polarities are POS and NEG.');
            end
            obj.writeOnly(trigger);
        end
        
         function setSweepDirection(obj,direction)
            switch lower(direction)
                case {'forward', 'fwd'}
                    string = sprintf(':SOURce:SWEep:DIRection FWD');
                case {'reverse','rev'}
                    string = sprintf(':SOURce:SWEep:DIRection REV');
                otherwise
                    error('unknown direction. Directions are FWD and REV,');
            end
            obj.writeOnly(string);
         end
        
        function setUnitPower(obj)
            warning('not implemented');
        end
        
        function  setPointTrig(obj,trigType)
            switch lower(trigType)
                case {'external','ext'}
                    string = sprintf(':SOURce:SWEep:POINt:TRIGger:TYPE EXTernal');
                case {'bus'}
                    error('not coded.');
                case {'immediate','imm'}
                    string = sprintf(':SOURce:SWEep:POINt:TRIGger:TYPE IMM');
                otherwise
                    error('unknown trig type. Options are ext and imm.')
            end
             obj.writeOnly(string);
        end
        
        function setLFOutputVoltage(obj,voltage)
            assert(isnumeric(voltage),'voltage must be numeric');
            assert(voltage >= 0 && voltage <= 3, 'voltage must be between 0V and 3V');
            string = sprintf(':SOURce:LFOutput:LEVel %dV',voltage);
            obj.writeOnly(string);
        end
        
        function setLFOutputFrequency(obj,Frequency)
            assert(isnumeric(Frequency),'Frequency must be numeric');
            assert(Frequency >= 0 && Frequency <= 200e3, 'Frequency must be between 0Hz and 200kHz');
            string = sprintf(':SOURce:LFOutput:FREQuency %dHz',Frequency);
            obj.writeOnly(string);
        end
        
        function setLFOutputState(obj, state)
            assert(isbool(state),'State must be a boolean');
            string = sprintf(':SOUR:LFOutput:STATe %d', state);
            obj.writeOnly(string);
        end

        function setPowerUnit(obj)
            string = ['Default is dBm. Include units when setting level if' ...
                'other unit is wanted. Options include dBmV, dBuV, Volts, and Watts.'... 
                'However, this functionality is not currently supported.'];
            warning(string);
        end
        
        function  setFreqCW(obj,Freq)
            assert(isnumeric(Freq),'frequency must be numeric');
            assert(Freq >= 9e3 && Freq <= 3e9, 'frequency must be between 9kHz and 3GHz');
            string = sprintf(':SOURce:FREQuency %f',Freq);
            obj.writeOnly(string);
        end
        
        function  setPowerCW(obj,Power)
            assert(isnumeric(Power),'Power must be numeric');
            assert(Power >= -110 && Power <= 20, 'Power must be between -110dBm and 20dBm');
            string = sprintf(':SOURce:LEVel %f ',Power);
            obj.writeOnly(string);
        end
        
        function setSweepStartFreq(obj, startFreq)
            assert(isnumeric(startFreq),'frequency must be numeric');
            assert(startFreq >= 9e3 && startFreq <= 3e9, 'frequency must be between 9kHz and 3GHz');
            string = sprintf(':SWEep:STEP:STARt:FREQuency %f',startFreq);
            obj.writeOnly(string);
        end
        
        function setSweepStopFreq(obj, stopFreq)
            assert(isnumeric(stopFreq),'frequency must be numeric');
            assert(stopFreq >= 9e3 && stopFreq <= 3e9, 'frequency must be between 9kHz and 3GHz');
            string = sprintf(':SWEep:STEP:STOP:FREQuency %f',stopFreq);
            obj.writeOnly(string);
        end
        
        function  setSweepStartPower(obj,startPower)
            assert(isnumeric(startPower),'Power must be numeric');
            assert(startPower >= -110 && startPower <= 20, 'Power must be between -110dBm and 20dBm');
            string = sprintf(':SWEep:STEP:STARt:LEVel %f ',startPower);
            obj.writeOnly(string);
        end
        
        function  setSweepStopPower(obj,stopPower)
            assert(isnumeric(stopPower),'Power must be numeric');
            assert(stopPower >= -110 && stopPower <= 20, 'Power must be between -110dBm and 20dBm');
            string = sprintf(':SWEep:STEP:STOP:LEVel %f ',stopPower);
            obj.writeOnly(string);
        end
        
        function  setSweepNumPoints(obj,numPoints)
            assert(mod(numPoints,1) == 0,'Number of points must be integer');
            assert(numPoints >= 2 && numPoints <= 65535, 'Number of points must be between 2 and 65535');
            string = sprintf(':SWEep:STEP:POINts %f',numPoints);
            obj.writeOnly(string);
        end
        
        function  setSweepDwellTime(obj,dwell)
            assert(isreal(dwell),'dwell time must be numeric');
            assert(dwell >= 10e-3 && dwell <= 10, 'Dwell time must be between 10ms and 10s');
            string = sprintf(':SWEep:STEP:DWELl %f',dwell);
            obj.writeOnly(string);
        end
        
       function  setSweepMode(obj,mode)
            switch lower(mode)
                case {'continuous'}
                    string = sprintf(':SOURce:SWEep:MODE CONTinue');
                case {'single'}
                    string = sprintf(':SOURce:SWEep:MODE SINGle');
                otherwise
                    error('Unknown sweep mode. Options are "continuous" and "single"');
            end
            obj.writeOnly(string);
        end
        
       function  setSweepType(obj,type)
           switch lower(type)
               case {'freq','frequency'}
                   string = sprintf(':SWEep:STATe FREQuency');
               case {'power','level'}
                   string = sprintf(':SWEep:STATe LEVel');
               otherwise
                   error('unknown sweep type. Types are frequency and power or both.')
           end
            obj.writeOnly(string);
       end

       function executeSweep(obj)
          string = ':SOUR:SWE:EXEC';
          obj.writeOnly(string);
       end
       
        function stopSweep(obj)
            string = sprintf(':SWEep:STATe OFF');
            obj.writeOnly(string);
        end
        
        function setMWState(obj, state)
            assert(isboolean(state),'State must be a boolean');
            string = sprintf(':OUTPut:STATe %d', state);
            obj.writeOnly(string);
        end
        
        %% get methods
        
        function [UnitPower] = getUnitPower(obj)
            UnitPower = 'dBm';
        end
        
        function  trigType = getPointTrig(obj)
            string = sprintf(':SOURce:SWEep:POINt:TRIGger:TYPE?');
            trigType = obj.writeRead(string);
            trigType = strtrim(trigType);
        end
        
        function direction  = getSweepDirection(obj)
            string = sprintf(':SOURce:SWEep:DIRection?');
            direction = obj.writeRead(string);
            direction = strtrim(direction);
        end
        
          function trigType = getStepTrig(obj)
            string = sprintf(':SOUR:SWE:SWE:TRIG:TYPE?');
            trigType = obj.writeRead(string);
            trigType = strtrim(trigType);
        end
        
        function sweepMode = getSweepMode(obj)
            string = sprintf(':SOURce:SWEep:MODE?');
            sweepMode = obj.writeRead(string);
        end
        
        function [Freq] = getFreqCW(obj)
            string = sprintf('FREQ?');
            s = obj.writeRead(string);
            Freq = str2num(s);
        end
        
        
        function  [Power] = getPowerCW(obj)
            string = sprintf('SOURce:LEVel?');
            s = obj.writeRead(string);
            Power= str2num(s);
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
            string = sprintf(':OUTPut:STATe?');
            s = obj.writeRead(string);
            if strcmp(s,'1')
                MWstate = 'On';
            else
                MWstate = 'Off';
            end
        end
        
        function [voltage] = getLFOutputVoltage(obj)
            string = sprintf(':SOUR:LFOutput:LEVel?');
            s = obj.writeRead(string);
            voltage = str2num(s);
        end
        
        function [state] = getLFOutputState(obj)
            string = sprintf(':SOUR:LFOutput:STATe?');
            s = obj.writeRead(string);
            state = str2num(s);
        end
        
       function [frequency] = getLFOutputFrequency(obj)
            string = sprintf(':SOUR:LFOutput:FREQuency ?');
            s = obj.writeRead(string);
            frequency = str2num(s);
        end
        
        %%
        
        function delete(obj)
            obj.reset;
            fclose(obj.comObject);
            delete(obj.comObject);
        end
        
        function on(obj)
            string = sprintf(':OUTPut:STATE ON');
            obj.writeOnly(string);
        end
        
        function off(obj)
            string = sprintf(':OUTPut:STATE Off');
            obj.writeOnly(string);
        end
        
        function program_list(obj,freq_list,power_list)
            obj.setPowerCW(power_list(1));
            obj.setPointTrig('EXT')
            obj.setStepTrig('auto')
            obj.setSweepType('freq');
            obj.setSweepStartFreq(freq_list(1));
            obj.setSweepStopFreq(freq_list(end));
            obj.setSweepNumPoints(numel(freq_list));
            obj.setSweepDwellTime(0.02); %fix later
            obj.executeSweep;
            obj.setSweepMode('continuous');
            obj.off;
        end
        
        function programFrequencySweep(obj, startFreq, stopFreq, numPoints, dwell, mode)
            obj.setSweepType('freq');
            obj.setSweepMode(mode);
            obj.setSweepStartFreq(startFreq);
            obj.setSweepStopFreq(stopFreq);
            obj.setSweepNumPoints(numPoints);
            obj.setSweepDwellTime(dwell);
        end
        
        function programPowerSweep(obj, startPower, stopPower, numPoints, dwell, mode)
            obj.setSweepType('level');
            obj.setSweepMode(mode);
            obj.setSweepStartPower(startPower);
            obj.setSweepStopPower(stopPower);
            obj.setSweepNumPoints(numPoints);
            obj.setSweepDwellTime(dwell);
        end
        
        function resetSweep(obj)
            string = ':SOUR:SWE:RES:ALL';
            obj.writeOnly(string);
        end
   
        function  reset(obj)
            string = sprintf('*RST');
            obj.writeOnly(string);
        end
        
    end
end