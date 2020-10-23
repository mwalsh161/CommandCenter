classdef SMV03 < Drivers.SignalGenerators.SignalGenerator 
    % Matlab Object Class implementing control for SMV03 Signal Generator
    %
    %
    % Primary purpose of this is to control the SG
    %
    % should be named serial in an class that calls this instance
    
    % One instance controls 1 physical device. Multiple instances can exist
    % simultaneously for different hardware channels. If you need two
    % devices to work together, a new class should be designed.
    %
    % State information of the machine is stored on the SG. Can be obtained
    % using the get methods.
    
    properties
        prefs = {'comObjectInfo'};
        comObjectInfo = struct('comType','','comAddress','','comProperties','') 
        comObject;     % USB-Serial/GPIB/Prologix
    end
  
    methods(Static)
        
        function obj = instance(name)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.SignalGenerators.SMV03.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.SignalGenerators.SMV03();
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
        
    end
    
    methods(Access=private)
        function [obj] = SMV03()
            obj.SG_init;
        end
    end
    
    methods(Access=private)
        
        function writeOnly(obj,string)
            fprintf(obj.comObject,string);
            err = obj.getError;
            if ~isempty(err)
                warning(err)
            end
        end
        
        function [output] = writeRead(obj,string)
            output = query(obj.comObject,string);
            err = obj.getError;
            if ~isempty(err)
                warning(err)
            end
        end
        
        function  setListTrig(obj,ListTrig)
            string = sprintf('TRIGGER:SWEEP:SOURCE %s',ListTrig);
            obj.writeOnly(string);
        end
        
        function  setFreqMode(obj,FreqMode)
            switch FreqMode
                case {'FIX','CW'}
                    obj.writeOnly('SOUR:FREQ:MODE FIX');
                case {'LIST'}
                    obj.writeOnly('SOURCE:FREQUENCY:MODE SWEEP');
                    obj.writeOnly('SOURCE:SWEEP:MODE STEP');     %Only STEP modes can be used
                otherwise
                    warning('No frequency mode was set');
            end
        end
        
        function  setPowerMode(obj,PowerMode)
            string = sprintf('SOURce:POWer:MODE %s',PowerMode);
            obj.writeOnly(string);
        end
    end
    methods
        
        
        function setUnitPower(obj)
            obj.writeOnly('UNIT:POWER DBM');
        end
        
        function setFreqCW(obj,Freq)
            obj.setFreqMode('CW');
            string = sprintf(':FREQuency:FIXed %f', Freq);  % Hz
            obj.writeOnly(string);
        end
        
        function  setPowerCW(obj,Power)
            string = sprintf(':POWER:LEVEL:IMMEDIATE:AMPLITUDE %f DBM',Power);
            obj.writeOnly(string);
        end
        
        function  setFreqList(obj,FreqList)
            % In Hz
            step = diff(FreqList);
            if all(step(1)~=step)
                warning('%s can only do fixed spacing sweeps. Continuing with start, stop and npoints.')
            end
            start = FreqList(1);
            stop = FreqList(end);
            if length(FreqList)==1
                step = 0;
            else
                step = (stop-start)/(length(FreqList)-1);
            end
            if step > 3e9
                error('%s can only step between 0 and 3 GHZ',mfilename);
            end
            string = sprintf(':SOURCE:FREQUENCY:START %f HZ',start);
            obj.writeOnly(string);
            string = sprintf(':SOURCE:FREQUENCY:STOP %f HZ',stop);
            obj.writeOnly(string);
            string = sprintf(':SOURCE:SWEEP:FREQUENCY:STEP:LINEAR %f HZ',step);
            obj.writeOnly(string);
        end
        
        function  setPowerList(obj,PowerList)
            error('does not exist for %s',mfilename);
        end
        
        %%
        
        function UnitPower = getUnitPower(obj)
            UnitPower = obj.writeRead('UNIT:POWER?');
            UnitPower = strrep(UnitPower,newline,''); %remove excess carriage returns
        end
        
        function  [Freq]=getFreqCW(obj)
            string = sprintf('FREQ?');  % Hz
            s = obj.writeRead(string);
            Freq = str2double(s);
        end
        
        function  [Power]=getPowerCW(obj)
            string = sprintf('POW?');
            s = obj.writeRead(string);
            Power = str2double(s);
        end
        
        function  [FreqMode]=getFreqMode(obj)
            string = sprintf('FREQ:MODE?');
            s = obj.writeRead(string);
            FreqMode = strrep(s,newline,''); %remove excess carriage returns;
        end
        
        function  [PowerMode]=getPowerMode(obj)
            string = sprintf('POWer:MODE?');
            s = obj.writeRead(string);
            PowerMode = strrep(s,newline,''); %remove excess carriage returns;
        end
        
        function  [MWstate]=getMWstate(obj)
            string = sprintf('OUTPUT:STATE?');
            s = obj.writeRead(string);
            if strcmp(strrep(s,newline,''),'1')
                MWstate = 'On';
            else
                MWstate = 'Off';
            end
        end
        
        function program_list(obj,freq_list,power)
            obj.reset;
            obj.setFreqMode('LIST');
            obj.setListTrig('EXT');
            obj.setFreqList(freq_list);
            assert(all(power(1)==power),'All powers must be same')
            obj.setPowerCW(power(1));
            obj.on;
        end
        
        function select_list(obj,listname)
            error('Not implemented')
        end
        
        %% 
        function  on(obj)
            string = sprintf(':OUTPUT:STATE 1');
            obj.writeOnly(string);
        end
        
        function  off(obj)
            string = sprintf(':OUTPUT:STATE 0');
            obj.writeOnly(string);
        end
        
        function delete(obj)
            fclose(obj.comObject);
            delete(obj.comObject);
        end
        
        function  reset(obj)
            string = sprintf('*RST');
            obj.writeOnly(string);
        end
        
        function errs = getError(obj)
            % Grab errors, but timeout after 1 second
            t = tic;
            errs  = {};
            while toc(t) < 1
                err = strip(query(obj.comObject,'SYSTEM:ERROR?'));
                if contains(err,'No error')
                    break
                end
                errs{end+1} = err;
            end
            errs = strjoin(errs,newline);
        end
        
    end
end