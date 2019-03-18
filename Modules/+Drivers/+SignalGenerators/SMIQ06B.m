classdef SMIQ06B < Drivers.SignalGenerators.SignalGenerator & Modules.Driver
    
    properties
        
        Protocol;      % USB-Serial/GPIB/TCPIP/Prologix string
        
        ComDriver;     % USB-Serial/GPIB/TCPIP/Prologix 
        
        ListTrig='EXT';
        
        % These two numbers are for Learning the list. When these two
        % numbers matches, Learning is executed.
        FreqListNum = 0;
        PowerListNum = 0;
        
        % If List is Learned, than Learned is 1
        Learned = 0;

    end
    
    methods(Static)
        
        function obj = instance(varargin)
            mlock;

            persistent Object

            if isempty(Object) || ~isvalid(Object)

                if nargin==0
                    Object = Drivers.SignalGenerators.SMIQ06B(); % For the default setting : Prologix
                else
                    inputArg = varargin;
                    Object = Drivers.SignalGenerators.SMIQ06B(inputArg); % For the default setting : Prologix
                end

            end
            obj = Object;
        end
        
    end

    
    methods(Access=private)

        function [obj] = SMIQ06B(varargin)

            if nargin==0
                prompt = {'Enter Protocol:'};
                dlg_title = 'SMIQ Communication Setting';
                num_lines = 1;
                defaultans = {'Prologix'};
                answer = inputdlg(prompt,dlg_title,num_lines,defaultans);
                
                obj.Protocol = answer{1};
            else
                inputArg = varargin{1};
                obj.Protocol = inputArg{1};
            end
            
            switch obj.Protocol,
                case 'Prologix',
                    if nargin==0
                        obj.ComDriver = Drivers.Prologix.instance();
                    elseif size(inputArg,2)==4
                        SerialPort = inputArg{2};
                        GPIBbus = inputArg{3};
                        GPIBnum = inputArg{4};
                        obj.ComDriver = Drivers.Prologix.instance(SerialPort,GPIBbus,GPIBnum);
                    else
                        error('Argument is not correct, SMIQ04B needs (Proglogix,COM#,GPIBbus,GPIBnum), or without any for manual GUI setting');
                    end

    %                    If GPIB-Prologix is not working, use this.
    %                    obj.writeOnly('++auto 1');      %Read after Write, 
    %                    obj.writeOnly('++read eoi');    %Read until hitting EOI

                case 'USB-serial'
                    error('Not implemented yet. Ask Chuck (choihr@mit.edu)');

                case 'gpib',
                    GPIBdriver = varargin{2};
                    GPIBbus = varargin{3};
                    GPIBnum = varargin{4};
                    
                    error('Not implemented yet. Ask Chuck (choihr@mit.edu)');
                case 'tcpip',
                    IPAddress = varargin{2};
                    TCPPort = varargin{3};
                    ComDriver = tcpip(obj.IPAddress,obj.TCPPort);

                    error('Not implemented yet. Ask Chuck (choihr@mit.edu)');
                otherwise,
                    error('Not supported protocol.');
            end
            
            obj.MWOff;
            obj.setUnitPower;         %Power Unit is set to DBM
            obj.setListTrig(obj.ListTrig);

            obj.setFreqMode('FIX');
            obj.setPowerMode('FIX');
        end
    end
    
    methods
        
        function setUnitPower(obj)
            obj.writeOnly('UNIT:POWER DBM');
        end
        
        
        function delete(obj)
            obj.ComDriver.delete();
        end
        
        function writeOnly(obj,string)
            obj.ComDriver.writeOnly(string);
        end

        
        function [output] = writeRead(obj,string)
            output = obj.ComDriver.writeRead(string);
        end

        function  setFreqCW(obj,Freq)
            obj.FreqCW = Freq;
            string = sprintf(':FREQuency:FIXed %f',Freq);
            obj.writeOnly(string);            
        end
        
        function  setPowerCW(obj,Power)
            obj.PowerCW = Power;
            string = sprintf(':POWER:LEVEL:IMMEDIATE:AMPLITUDE %f DBM',Power);
            obj.writeOnly(string);            
        end
        
        function  setFreqMode(obj,FreqMode)
            switch FreqMode
                case {'FIX','CW'},
                    obj.writeOnly('SOUR:FREQ:MODE FIX');
                    obj.FreqMode = 'FIX';
                case {'LIST'}
                    obj.writeOnly('SOUR:FREQ:MODE LIST');
                    obj.writeOnly('SOURCE:LIST:MODE STEP');     %Only STEP modes can be used
                    obj.FreqMode = FreqMode;
                otherwise
                    warning('No frequency mode was set');
            end
        end
        
        function  setPowerMode(obj,PowerMode)
            obj.PowerMode = PowerMode;
            string = sprintf('SOURce:POWer:MODE %s',PowerMode);
            obj.writeOnly(string);        
        end

        function  setListTrig(obj,ListTrig)
            obj.ListTrig = ListTrig;
            string = sprintf('TRIGGER:LIST:SOURCE %s',ListTrig);
            obj.writeOnly(string);   
        end
        
        function  setFreqList(obj,FreqList)
            
            obj.DeleteListFreq();
            obj.Learned=0;
            
            obj.writeOnly('*WAI');
            
            obj.FreqList = FreqList;
            
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
                string = [':LIST:FREQUENCY ',string]; 
                obj.writeOnly(string);
            end            
            obj.writeOnly('*WAI');
            
            obj.FreqListNum=obj.FreqListNum+1;
            
        end
        
        function  setPowerList(obj,PowerList)
            
            obj.DeleteListPower();
            obj.Learned=0;

            obj.writeOnly('*WAI');

            obj.PowerList = PowerList;
            
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
                obj.writeOnly(string);
            end           
            obj.writeOnly('*WAI');

            obj.PowerListNum=obj.PowerListNum+1;
        end
        
        
        function  [Freq]=getFreqCW(obj)
            string = sprintf('FREQ?');
            s = obj.writeRead(string);
            obj.FreqCW = str2num(s);
            Freq = obj.FreqCW;
            
            disp(sprintf('Freq CW : %f',Freq));
        end
        
        
        function  [Power]=getPowerCW(obj)
            string = sprintf('POW?');
            s = obj.writeRead(string);
            obj.PowerCW = str2num(s);
            Power = obj.PowerCW;
            
            disp(sprintf('Power CW : %f',Power));
        end
        
        
        function  [FreqMode]=getFreqMode(obj)
            string = sprintf('FREQ:MODE?');
            s = obj.writeRead(string);
            obj.FreqMode = s;
            FreqMode = obj.FreqMode;
            
            disp(sprintf('Freq Mode : %s',FreqMode));
        end
        
        
        function  [PowerMode]=getPowerMode(obj)
            string = sprintf('POWer:MODE?');
            s = obj.writeRead(string);
            obj.PowerMode = s;
            PowerMode = obj.PowerMode;
            
            disp(sprintf('Power Mode : %s',PowerMode));
        end
        
        function  [FreqList]=getFreqList(obj)
            string = sprintf('LIST:FREQ?');
            s = obj.writeRead(string);
            obj.FreqList = str2num(s);
            FreqList = obj.FreqList;
        end
        
        
        function  [PowerList]=getPowerList(obj)
            string = sprintf('LIST:POWer?');
            s = obj.writeRead(string);
            obj.PowerList = str2num(s);
            PowerList = obj.PowerList;
        end

        
        function  [MWstate]=getMWstate(obj)
            string = sprintf('OUTPUT:STATE?');
            s = obj.writeRead(string);
            obj.MWstate = s;
            MWstate = obj.MWstate;

            disp(sprintf('MW state : %s',MWstate));
        end

        
        function  exeCW(obj)
            if ~(strcmp(PowerMode,'LIST'))
                disp('Power Mode is not List Mode, execution fail');
                return;
            elseif ~(strcmp(FreqMode,'LIST'))
                disp('Freq Mode is not List Mode, execution fail');
                return;
            end
            obj.MWOn;
        end
        
        
        function  exeLIST(obj)
            if ~(strcmp(PowerMode,'LIST'))
                disp('Power Mode is not List Mode, execution fail');
                return;
            elseif ~(strcmp(FreqMode,'LIST'))
                disp('Freq Mode is not List Mode, execution fail');
                return;
            end
            
            if ~(obj.FreqListNum==0)
                if obj.FreqListNum==obj.PowerListNum
                    obj.ListLearn();
                    obj.Learned=1;
                end
            end
            
            if obj.Learned==0
                disp('List is not Learned');
                return;
            end
            
        end
        
        
        %% Class Helper functions, shouldn't be used directly.

        
        function  MWOn(obj)
            obj.MWstate='ON';
            string = sprintf(':OUTPUT:STATE 1');
            obj.writeOnly(string);
        end
           
        
        function  MWOff(obj)
            obj.MWstate='OFF';
            string = sprintf(':OUTPUT:STATE 0');
            obj.writeOnly(string);
        end       


        function DeleteListFreq(obj)
            string  = sprintf('LIST:DELete:FREQ');
            obj.writeOnly(string);
        end

        function DeleteListPower(obj)
            string  = sprintf('LIST:DELete:POWer');
            obj.writeOnly(string);
        end
        
        
        function  ListLearn(obj)
            string = sprintf('SOURCE:LIST:LEARN');
            obj.writeOnly(string);
        end

        
    end
end