classdef SR865_LockInAmplifier < Modules.Driver
    % Matlab Object Class implementing control for Hewlett_Packard
    % Signal Generator
    %
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
                Objects = Drivers.SR865_LockInAmplifier.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.SR865_LockInAmplifier();
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
    end
    
    methods(Access=private)
        function [obj] = SR865_LockInAmplifier()
            obj.loadPrefs;
            display('setting comInfo for SR865 lock-in amplifier.')
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
                    fopen(obj.comObject);
                catch
                    %this is only called if you change a device property
                    %after the intiial connection (ex: change GPIB
                    %address). This allows you to establish a new
                    %connection.
                    [obj.comObject,obj.comObjectInfo.comType,obj.comObjectInfo.comAddress,obj.comObjectInfo.comProperties] ...
                        = Connect_Device;
                    fopen(obj.comObject);
                end
            end
            obj.reset; %set SR865_LockInAmplifier to a known state
            obj.setMode('Remote');
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
    
    methods
        
        function setMode(obj,mode)
            assert(ischar(mode),'Mode must be a character')
            switch lower(mode)
                case 'local'
                    string = sprintf('LOCL %d',2);
                case 'remote'
                    string = sprintf('LOCL %d',1);
                otherwise
                    error('Unknown control mode. Mode must be local or remote.')
            end
        end
        
        function setTBMode(obj,mode)
            narginchk(2, 2)
            if ischar(mode)
                mode = lower(mode);
            end
            switch mode
                case {0, 'auto'}
                    string = sprintf('TBMODE AUTO');
                case {1,'internal'}
                    string = sprintf('TBMODE 1');
                otherwise
                    error('Unknown TBMode. Supported modes are auto or internal.')
            end
            obj.writeOnly(string);
        end
        
        function setPhase(obj,phase)
            narginchk(2, 2)
            assert(isnumeric(phase),'phase must be of type numeric')
            assert(phase >= -360000 , 'phase must be greater than -360000')
            assert(phase <= 360000, 'phase must be less than 360000')
            string = sprintf('PHAS %d',phase);
            obj.writeOnly(string)
        end
        
        function setRefSource(obj,refSource)
            narginchk(2, 2)
            if ischar(refSource)
                refSource = lower(refSource);
            end
            switch refSource
                case {'internal',0,'0'}
                    string = sprintf('RSRC %d',0);
                case {'external',1,'1'}
                    string = sprintf('RSRC %d',1);
                case {'dual',2,'2'}
                    string = sprintf('RSRC %d',2);
                case {'chop',3,'3'}
                    string = sprintf('RSRC %d',3);
                otherwise
                    error('Unknown refSource. refSource must be internal or external.')
            end
            obj.writeOnly(string)
        end
        
        function setExtRefTrigImp(obj,mode)
            if ischar(mode)
                mode = lower(mode);
            end
            switch mode
                case {0,50,'50ohms'}
                    string = 'REFZ 50';
                case {1,1e6,'1m','1meg'}
                    string = 'REFZ 1M';
                otherwise
                    error('Unknown mode. Available modes are 50 ohms or 1 Megaohms')
            end
            obj.writeOnly(string);
        end
        
        function setSignalMode(obj,mode)
            narginchk(2, 2)
            assert(ischar(mode),'mode must be a character')
            switch lower(mode)
                case {'voltage'}
                    string = sprintf('IVMD VOLT');
                case {'current'}
                    string = sprintf('IVMD CURR');
                otherwise
                    error('unknown signal mode. Signal Mode must be current or voltage')
            end
            obj.writeOnly(string);
        end
        
        function setVoltageInputMode(obj,mode)
            narginchk(2, 2)
            if ischar(mode)
                mode = lower(mode);
            end
            switch mode
                case {0,'a'}
                    string = 'ISRC A';
                case {1,'a-b'}
                    string = 'ISRC A-B';
                otherwise
                    error('Unknown voltage input mode. Available modes are A or A-B.')
            end
            obj.writeOnly(string);
        end
        
        function setVoltageInputCoupling(obj,coupling)
            narginchk(2, 2)
            if ischar(coupling)
                coupling = lower(coupling);
            end
            switch coupling
                case {0,'ac'}
                    string = 'ICPL AC';
                case {1,'dc'}
                    string = 'ICPL DC';
                otherwise
                    error('Unknown coupling.Available couplings are ac or dc.')
            end
            obj.writeOnly(string)
        end
        
        function setVoltageInputRange(obj,range)
            narginchk(2, 2)
            availableRanges = [1,0.3,0.1,0.03,0.01];
            assert(isnumeric(range),'range must be numeric')
            assert(ismember(range,availableRanges),['Range must be either: '...
                num2str(availableRanges), 'V']);
            index = find(range == availableRanges);
            string = sprintf('IRNG %d',index-1);
            obj.writeOnly(string);
        end
        
        function setCurrentGain(obj,resistance)
            narginchk(2, 2)
            if ischar(resistance)
                resistance = lower(resistance);
            end
            switch resistance
                case {'1meg','1ua',0,1e6,1e-6}
                    string = 'ICUR 0';
                case {'100meg','10na',1,100e6,10e-9}
                    string = 'ICUR 1';
                otherwise
                    error('Unknown CurrentGain input value. Available options are 1meg or 100meg')
            end
            obj.writeOnly(string)
        end
        
        function setSensitivity(obj,sensitivity)
            % This method sets the sensitivity. The parameter i
            % selects a sensitivity below.
            % i sensitivity
            %
            %             i sensitivity i sensitivity
            %             0 1 V [uA]                                  15 10 uV [pA]
            %             1 500 mV [nA]                               16 5 uV [pA]
            %             2 200 mV [nA]                               17 2 uV [pA]
            %             3 100 mV [nA]                               18 1 uV [pA]
            %             4 50 mV [nA]                                19 500 nV [fA]
            %             5 20 mV [nA]                                20 200 nV [fA]
            %             6 10 mV [nA]                                21 100 nV [fA]
            %             7 5 mV [nA]                                 22 50 nV [fA]
            %             8 2 mV [nA]                                 23 20 nV [fA]
            %             9 1 mV [nA]                                 24 10 nV [fA]
            %             10 500 uV [pA]                              25 5 nV [fA]
            %             11 200 uV [pA]                              26 2 nV [fA]
            %             12 100 uV [pA]                              27 1 nV [fA]
            %             13 50 uV [pA]
            %             14 20 uV [pA]
            
            narginchk(2, 2)
            assert(isnumeric(sensitivity),'sensitivity must be numeric')
            string = sprintf('SCAL %d',sensitivity);
            obj.writeOnly(string)
        end
        
        function setReferenceFrequency(obj,freq)
            narginchk(2, 2)
            assert(numel(freq) ==1,'freq must be a single number')
            assert(isnumeric(freq),'Reference Frequency must be numeric');
            assert(strcmpi(obj.getRefSource,'internal'),' source must be set to internal');
            assert(freq >= 0.001 , 'Reference Frequency must be greater than 0.001')
            assert(freq <= 4e6, ['Reference Frequency must be less than than ',num2str(4e6)])
            string = sprintf('FREQ %d',freq);
            obj.writeOnly(string)
        end
        
        function setTriggerMode(obj,trigMode)
            %0 is sine zero crossing
            %1 is ttl rising edge
            %2 is ttl falling egde
            narginchk(2, 2)
            if ischar(trigMode)
                trigMode = lower(trigMode);
            end
            switch trigMode
                case {0,'0','sine'}
                    string = sprintf('RTRG %d',0);
                case {1,'1','ttl-pos'}
                    string = sprintf('RTRG %d',1);
                case {2,'2','ttl-neg'}
                    string = sprintf('RTRG %d',2);
                otherwise
                    error('unknown trigMode. Trigmodes are 0,1,2.')
            end
            obj.writeOnly(string)
        end
        
        function setDetectionHarmonic(obj,harmonic)
            narginchk(2, 2)
            assert(isnumeric(harmonic),'harmonic must be a number')
            assert(harmonic >= 1,'harmonic is an integer greater than 1')
            assert(harmonic <= 99 ,'harmonic is an integer less than 99.')
            string = sprintf('HARM %d',harmonic);
            obj.writeOnly(string)
        end
        
        function setHarmDual(obj,harmonic)
            narginchk(2, 2)
            assert(isnumeric(harmonic),'harmonic must be a number')
            assert(harmonic >= 1,'harmonic is an integer greater than 1')
            assert(harmonic <= 99 ,'harmonic is an integer less than 99.')
            string = sprintf('HARMDUAL %d',harmonic);
            obj.writeOnly(string)
        end
        
        function setAmplitudeOutput(obj,amplitude)
            narginchk(2, 2)
            assert(isnumeric(amplitude),'AmplitudeOutput must be numeric');
            assert(amplitude >= 1e-9,'minimum AmplitudeOutput must be greater than 1 nV')
            assert(amplitude <= 2,'AmplitudeOutput must be less than 2 V')
            string = sprintf('SLVL %d',amplitude);
            obj.writeOnly(string)
        end
        
        function setSineDCLevel(obj,dc_level)
            narginchk(2, 2)
            assert(isnumeric(dc_level),'dc_level must be numeric');
            assert(dc_level >= -5,'minimum dc_level must be greater than -5 V')
            assert(dc_level <= 5,'dc_level must be less than 5 V')
            string = sprintf('SOFF %d',dc_level);
            obj.writeOnly(string)
        end
        
        function setSineOutDCMode(obj,mode)
            narginchk(2, 2)
            if ischar(mode)
                mode = lower(mode);
            end
            switch mode
                case {0,'common'}
                    string = sprintf('REFM %d',0);
                case {1,'difference'}
                    string = sprintf('REFM %d',1);
                otherwise
                    error('Unknown SineOutDCMode. SineOutDCMode are common or difference.')
            end
            obj.writeOnly(string)
        end
        
        function setTimeConstant(obj,timeConstant)
            % This method sets the time constant. The parameter i
            % selects a time constant below.
            %             i time constant
            % 0 1 ?s             8 10 ms                       16 100 s
            % 1 3 ?s             9 30 ms                       17 300 s
            % 2 10 ?s            10 100 ms                     18 1 ks
            % 3 30 ?s            11 300 ms                     19 3 ks
            % 4 100 ?s           12 1 s                        20 10 ks
            % 5 300 ?s           13 3 s                        21 30 ks
            % 6 1 ms             14 10 s
            % 7 3 ms             15 30 s
            
            narginchk(2, 2)
            assert(isnumeric(timeConstant),'timeConstant must be numeric')
            string = sprintf('OFLT %d',timeConstant);
            obj.writeOnly(string);
        end
        
        function setSlope(obj,slope)
            % This method sets the low pass filter slope. The
            % parameter i selects 6 dB/oct (i=0), 12 dB/oct (i=1), 18 dB/oct (i=2) or
            % 24 dB/oct (i=3).
            narginchk(2, 2)
            assert(isnumeric(slope),'slope must be numeric')
            switch slope
                case {0,6}%db/oct
                    string = sprintf('OFSL %d',0);
                case {1, 12}
                    string = sprintf('OFSL %d',1);
                case {2,18}
                    string = sprintf('OFSL %d',2);
                case {3,24}
                    string = sprintf('OFSL %d',3);
                otherwise
                    error(['Unknown slope set value. Possible '...
                        'values are: %d db/oct,%d db/oct,%d db/oct'...
                        ',%d db/oct'],6,12,18,24)
            end
            obj.writeOnly(string);
        end
        
        function setSync(obj,sync)
            narginchk(2, 2)
            if ischar(sync)
                sync = lower(sync);
            end
            switch sync
                case {0,'off'}
                    string = sprintf('SYNC OFF');
                case {1, 'on'}
                    string = sprintf('SYNC ON');
                otherwise
                    error('Unknown sync option. Sync must be on or off')
            end
            obj.writeOnly(string);
        end
        
        function setAUXOut(obj,port,voltage)
            narginchk(3, 3)
            assert(isnumeric(port),'port must be numeric');
            assert(ismember(port,[1:4]),'available ports are 1 through 4.')
            assert(isnumeric(voltage),'voltage must be numeric');
            assert(voltage >= -10.5,'voltage must be greater than or equal to -10.5 V');
            assert(voltage <= 10.5,'voltage must be less than or equal to 10.5 V');
            string = sprintf('AUXV %d, %d V',port-1,voltage);
            obj.writeOnly(string);
        end
        
         function setCaptureRate(obj,varargin)
             %possible input is the rate. If no rate is supplied assume
             %maximum rate is requested.
             if nargine > 1
                 n = varargin{1};
                 assert(n >= 0,' n must be bigger than 0');
                 assert(n <= 20,'n must be less than 20');
                 string = sprintf('CAPTURERATE %d',n);
             else
                 string = sprintf('CAPTURERATE %d',0);
             end
            obj.writeOnly(string);
         end
        
         function setGroundingType(obj,groundType)
             switch lower(groundType)
                 case {'gro','ground',1}
                     string = 'IGND 1';
                 case {'flo','float',0}
                     string = 'IGND 0';
                 otherwise
                     error('Unknown groundType. Available options ground or float.')
             end
            obj.writeOnly(string);
         end
        
         function setChannelMode(obj,channel,mode)
             assert(isnumeric(channel),'channel must be numeric')
             string = 'COUT';
             switch channel
                 case {1}
                     string = [string,' 0'];
                 case {2}
                     string = [string,' 1'];
                 otherwise
                     error('Channel must be 1 or 2')
             end
             switch lower(mode)
                 case {'xy',0}
                     string = [string,', 0'];
                 case {'ro',1}
                     string = [string,', 1'];
                 otherwise
                     error('Unknown Mode. Modes must be XY or RO.')
             end
             obj.writeOnly(string);
         end
         
         function setChannelExpand(obj,mode,setting)
             string = 'CEXP';
             switch lower(mode)
                 case {'x',0}
                     string = [string,' 0'];
                 case {'y',1}
                     string = [string,' 1'];
                 case {'r',2}
                     string = [string,' 2'];
                 otherwise
                     error('Supported modes are x,y or r.')
             end
             switch lower(setting)
                 case {'off',0}
                     string = [string,', 0'];
                 case {'x10',1}
                     string = [string,', 1'];
                 case {'x100',2}
                     string = [string,', 2'];
                 otherwise
                     error('Unknown Mode. Modes must be off,x10, or x100.')
             end
             obj.writeOnly(string);
         end
        %% get methods
        function freq = getActualDetectionFrequency(obj)
            string = 'FREQDET?';
            s = obj.writeRead(string);
            freq = str2num(s(1:end-1));
        end
        
        function mode = getTBMode(obj)
            string = 'TBMODE?';
            s = obj.writeRead(string);
            mode = str2num(s(1:end-1));
            if mode == 0
                mode = 'auto';
            else
                mode = 'internal';
            end
        end
        
        function source = getTimeBaseSource(obj)
           string = 'TBSTAT?';
           s = obj.writeRead(string);
           source = str2num(s(1:end-1));
           if source == 0
               source = 'external';
           else
               source = 'internal';
           end
        end
        
        function phase = getPhase(obj)
           string = 'PHAS?';
           s = obj.writeRead(string);
           phase = str2num(s(1:end-1));
        end
        
        function refSource = getRefSource(obj)
            string = 'RSRC?';
            s = obj.writeRead(string);
            refSourceIndex = str2num(s(1:end-1));
            types = {'internal','external','dual','chop'};
            refSource = types{refSourceIndex + 1};
        end
        
        function mode = getExtRefTrigImp(obj)
           string = 'REFZ?'; 
           s = obj.writeRead(string); 
           modeIndex = str2num(s(1:end-1));
           impedVec = {50,1e6};
           mode = impedVec{modeIndex + 1};
        end
        
        function mode = getSignalMode(obj)
           string = 'IVMD?';
           s = obj.writeRead(string);
           modeIndex = str2num(s(1:end-1));
           modeOptions = {'voltage','current'};
           mode = modeOptions{modeIndex + 1};
        end
        
        function mode = getVoltageInputMode(obj)
           string = 'ISRC?';
           s = obj.writeRead(string);
           modeIndex = str2num(s(1:end-1));
           modes = {'A','A - B'};
           mode = modes{modeIndex + 1};
        end
        
        function coupling = getVoltageInputCoupling(obj)
            string = 'ICPL?';
            s = obj.writeRead(string);
            couplingIndex = str2num(s(1:end-1));
            options = {'AC','DC'};
            coupling = options{couplingIndex + 1};
        end
        
        function range = getVoltageInputRange(obj)
            string = 'IRNG?';
            s = obj.writeRead(string);
            index = str2num(s(1:end-1));
            availableRanges = [1,0.3,0.1,0.03,0.01];
            range = availableRanges( index + 1);
        end
        
        function Gain = getCurrentGain(obj)
           string = 'ICUR?';
           s = obj.writeRead(string);
           index = str2num(s(1:end-1));
           gains = [1e6,100e6];
           Gain = gains(index + 1);
        end
        
        function sensitivity = getSensitivity(obj)
            string = 'SCAL?';
            s = obj.writeRead(string);
            sensitivity = str2num(s(1:end-1));
        end
        
        function refFreq = getReferenceFrequency(obj)
           string = 'FREQ?';
           s = obj.writeRead(string);
           refFreq = str2num(s(1:end-1)); 
        end
        
        function trigMode = getTriggerMode(obj)
           string = 'RTRG?';
           s = obj.writeRead(string);
           index = str2num(s(1:end-1));
           trigModes = {'sine','ttl-pos','ttl-neg'};
           trigMode = trigModes{index + 1};
        end
        
        function harmonic = getDetectionHarmonic(obj)
           string = 'HARM?';
           s = obj.writeRead(string);
           harmonic = str2num(s(1:end-1));
        end
        
        function harmonic = getHarmDual(obj)
            string = 'HARMDUAL?';
            s = obj.writeRead(string);
            harmonic = str2num(s(1:end-1));
        end
        
        function amplitude = getAmplitudeOutput(obj)
           string = 'SLVL?';
           s = obj.writeRead(string);
           amplitude = str2num(s(1:end-1));
        end
        
        function dc_level = getSineDCLevel(obj)
           string = 'SOFF?';
           s = obj.writeRead(string);
           dc_level = str2num(s(1:end-1));
        end
        
        function dcMode = getSineOutDCMode(obj)
           string = 'REFM?';
           s = obj.writeRead(string);
           dcModeIndex = str2num(s(1:end-1));
           options = {'common','difference'};
           dcMode = options{dcModeIndex + 1};
        end
        
        function timeConstant = getTimeConstant(obj)
           string = 'OFLT?';
           s = obj.writeRead(string);
           timeConstant = str2num(s(1:end-1));
        end
        
        function slope = getSlope(obj)
           string = 'OFSL?';
           s = obj.writeRead(string);
           index = str2num(s(1:end-1));
           options = [6,12,18,24];
           slope = options(index + 1);
        end
        
        function sync = getSync(obj)
           string = 'SYNC?';
           s = obj.writeRead(string);
           index = str2num(s(1:end-1));
           options = {'off','on'};
           sync = options{index + 1};
        end
        
        function voltage = getAUXOut(obj,port)
            string = sprintf('OAUX? %d',port-1);
            s = obj.writeRead(string);
            voltage = str2num(s(1:end-1));
        end
        
        function bandwidth = getNoiseBandwidth(obj)
           string = 'ENBW?';
           s = obj.writeRead(string);
           bandwidth = str2num(s(1:end-1));
        end
        
        function data = getDataChannelValue(obj,port)
            assert(isnumeric(port),'port must be numeric')
            assert(ismember(port,[1:4]),'port must be between 1 to 4')
            string = sprintf('OUTR? %d',port-1);
            s = obj.writeRead(string);
            data = str2num(s(1:end-1));
        end
        
        function rate = getMaxCaptureRate(obj)
            string = 'CAPTURERATEMAX?';
            s = obj.writeRead(string);
            rate = str2num(s(1:end-1));
        end
        
        function rate = getCaptureRate(obj)
            string = 'CAPTURERATE?';
            s = obj.writeRead(string);
            rate = str2num(s(1:end-1));
        end
        
        function groundType = getGroundingType(obj)
            string = 'IGND?';
            s = obj.writeRead(string);
            groundTypeIndex = str2num(s(1:end-1));
            options = {'float','ground'};
            groundType = options{groundTypeIndex + 1};
        end
        
        function mode = getChannelMode(obj,channel)
             assert(isnumeric(channel),'channel must be numeric')
             string = 'COUT?';
             switch channel
                 case {1}
                     string = [string,' 0'];
                 case {2}
                     string = [string,' 1'];
                 otherwise
                     error('Channel must be 1 or 2')
             end
             s = obj.writeRead(string);
             modeIndex = str2num(s(1:end-1));
             options = {'xy','ro'};
             mode = options{modeIndex + 1};
        end
         
        function setting = getChannelExpand(obj,mode)
             string = 'CEXP?';
             switch lower(mode)
                 case {'x',0}
                     string = [string,' 0'];
                 case {'y',1}
                     string = [string,' 1'];
                 case {'r',2}
                     string = [string,' 2'];
                 otherwise
                     error('Supported modes are x,y or r.')
             end
             s = obj.writeRead(string);
             index = str2num(s(1:end-1));
             options = {'off','x10','x100'};
             setting = options{index + 1}; 
         end
        %%
        
        function AutoScale(obj)
            string = 'ASCL';
            obj.writeOnly(string);
        end
        
        function AutoRange(obj)
            string = 'ARNG';
            obj.writeOnly(string);
        end
        
        function AutoOffset(obj,mode)
            string = 'OAUT';
            switch lower(mode)
                case {'x',0}
                    string = [string,' 0'];
                case {'y',1}
                    string = [string,' 1'];
                case {'r',2}
                    string = [string,' 2'];
                otherwise
                    error('Supported modes are x,y or r.')
            end
            obj.writeOnly(string);
        end
        
        function AutoPhase(obj)
            string = 'APHS';
            obj.writeOnly(string);
        end    
        %% 
        function start(obj,acqMode,startType)
            string = 'CAPTURESTART';
            switch lower(acqMode)
                case {'oneshot','one',0}
                    string = [string,' ONE'];
                case {'continous','cont',1} 
                     string = [string,' CONT'];
                otherwise
                    error('unknown acqMode. Available modes are oneshot or continous')
            end
            switch lower(startType)
                case {'imm','immediate',0}
                    string = [string,', IMM'];
                case {'trig','trigstart',1} 
                     string = [string,', TRIG'];
                case {'samp','samppertrig',2}
                    string = [string,', SAMP'];
                otherwise
                    error(['Unknown startType. Available modes are '...
                        'immediate, trigstart, or samppertrig'])
            end
            obj.writeOnly(string);
        end
        
        function stop(obj)
            string = 'CAPTURESTOP';
            obj.writeOnly(string);
        end
        
        function data = returnData(obj,varargin)
            if nargin > 1
                n = varargin{1};
            else
                n = 0;
            end
            string = sprintf('CAPTUREVAL? %d',n);
            s = obj.writeRead(string);
            data = str2num(s(1:end-1));
        end
        
        function delete(obj)
            obj.reset;
            obj.setMode('Local');
            fclose(obj.comObject);
            delete(obj.comObject);
        end
        
        function on(obj)
            string = sprintf(':OUTP:STATE ON');
            obj.writeOnly(string);
        end
        
        function off(obj,varargin)
            string = sprintf(':OUTP:STATE Off');
            obj.writeOnly(string);
        end
        
        function  reset(obj)
            string = sprintf('*RST');
            obj.writeOnly(string);
        end
        
    end
end