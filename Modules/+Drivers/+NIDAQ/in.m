classdef in < handle & Base.Measurement
    %DAQin is a handle class for input lines for NIDAQ
    %   Makes it more convenient to modify properties of its state
    
    properties(SetAccess=immutable)
        dev                            % Drivers.NIDAQ.dev object
        type                           % digital/analog
        line                           % Physical Line name [see nidaqmx help]
        name                           % Alias - name used in MATLAB
    end
    
    properties
        selftask
        selfpulsetrain
        dwell = 0
    end

    methods(Access=private)
        function check(obj)
            lineparts = strsplit(obj.line,'/');
            lname = lineparts{end};
            if numel(lname)>2 && strcmp(lname(1:3),'CTR')
                % Counters are ok, and should not go through test below.
                return
            end
            task = obj.dev.CreateTask('InTest');
            try
                if obj.type(1) == 'd'
                    task.CreateChannels('DAQmxCreateDIChan',obj,'',obj.dev.DAQmx_Val_ChanPerLine);
                else
                    task.CreateChannels('DAQmxCreateAIVoltageChan',obj,'',obj.dev.DAQmx_Val_Cfg_Default,0, 1,obj.dev.DAQmx_Val_Volts ,[]);
                end
            catch err
                task.Clear;
                rethrow(err)
            end
            task.Clear;
        end
    end
    
    methods(Access={?Drivers.NIDAQ.dev})
        function obj = in(dev,line,name)
            assert(length(name)>=1,'Must have a line name')
            % Determine type of channel
            if lower(line(1))=='a'
                obj.type = 'analog';
            else
                obj.type = 'digital';
            end
            mname = [lower(dev.DeviceChannel) '_' lower(line)];
            
            % Fix name to include device id
            obj.dev = dev;
            obj.line = ['/' dev.DeviceChannel '/' upper(line)];
            obj.name = name;
            obj.check;
            
            switch obj.type
                case 'analog'
                    unit = 'V';
                case 'digital'
                    unit = 'cts/sec';
            end
            
            obj.measurements = Base.Meas(   'name', obj.name,...
                                            'field', strrep(lower(line), '/', '_'),...
                                            'size', [1 1], ...
                                            'unit', unit);
        end
        function str = text(obj)
            ch = strsplit(obj.line,'/');
            ch = strjoin(ch(3:end),'/');
            str = [obj.name ': ' ch];
        end
    end
    methods
        function val = measure(obj)
            switch obj.type
                case 'analog'
                    val = obj.dev.ReadAILine(obj.name);
                case 'digital'
                    val = obj.measureCounter(.1);
                    % Assume counter for now.
%                     val = obj.dev.ReadDILine(obj.name);
                case 'counter'
            end
        end
        function str = encodeReadable(obj, isHTML, isSimple)
            if nargin < 2
                isHTML = false;
            end
            if nargin < 3
                isSimple = false;
            end
            
            str = obj.dev.encodeReadable(isHTML, isSimple);
        end
    end
    methods (Access=private)
        function val = measureCounter(obj, dwell)
            nsamples = 1;
            
            if isempty(obj.selftask) || ~isvalid(obj.selftask) || isempty(obj.selfpulsetrain) || ~isvalid(obj.selfpulsetrain)
                % Blocking function that will take nsamples, each with the
                % specified dwell time.
                % Returns array of size 1x(nsamples).
                % dwell is in s.
                if nargin < 3
                    nsamples = 1;
                end
                assert(nsamples>0,'Number of samples must be greater than 0.')
                nsamples = nsamples + 1;
                % Configure clock (pulse train)
                obj.selfpulsetrain = obj.dev.CreateTask([obj.line ' Counter singleShot PulseTrain']); %#ok<*PROPLC>
                f = 1/dwell;
                obj.selfpulsetrain.ConfigurePulseTrainOut('CounterSync', f, nsamples);
                obj.dwell = dwell;
                
                % Configure Counter
                try
                    obj.selftask = obj.dev.CreateTask([obj.line ' Counter CounterObj']);
                catch err
                    obj.selfpulsetrain.Clear;
                    rethrow(err)
                end
            
                obj.selftask.ConfigureCounterIn(obj.name,nsamples,obj.selfpulsetrain);
            else
                obj.selftask.Stop;
                obj.selfpulsetrain.Stop;
            end
            
            if isempty(obj.dwell) || obj.dwell ~= dwell
                f = 1/dwell;
                obj.selfpulsetrain.ConfigurePulseTrainOut('CounterSync', f, nsamples);
                obj.dwell = dwell;
            end
            
            try
                % Start counter (waits for pulse train), then start pulse train
                obj.selftask.Start;
                obj.selfpulsetrain.Start;
            catch err
                obj.selfpulsetrain.Clear;
                obj.selftask.Clear;
                rethrow(err)
                return
            end
            
            % Wait until finished, then read data.
            obj.selfpulsetrain.WaitUntilTaskDone;
            data = obj.selftask.ReadCounter(obj.selftask.AvailableSamples);
            val = diff(data)/dwell;
            
            try
                obj.selftask.Stop;
                obj.selfpulsetrain.Stop;
            catch err
                obj.selfpulsetrain.Clear;
                obj.selftask.Clear;
                rethrow(err)
                return
            end
        end
    end
    
end

