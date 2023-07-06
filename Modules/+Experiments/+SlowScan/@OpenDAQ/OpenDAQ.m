classdef OpenDAQ < Modules.Experiment
    %OpenDAQ

    properties(SetObservable,GetObservable,AbortSet)
        DAQ_dev =  Prefs.String('Dev1',     'help', 'NIDAQ Device.');
        DAQ_line = Prefs.String('laser',    'help', 'NIDAQ laser line.');
        DAQ_apd =  Prefs.String('APD1',     'help', 'NIDAQ detector line.');

        dwell_ms = Prefs.Double(50)

        overshoot_voltage = Prefs.Double(.5)

        wavemeter_channel = 6;
    end
    properties(SetObservable,GetObservable,AbortSet)
        voltages = 'linspace(1,9,1601)';
    end
    properties(SetAccess=private,Hidden)
        taskScan            % Task handle to scan voltage out
        taskPulseTrain      % Task to control timing
        taskCounter         % Task to control counter
    end
    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = Open()
            obj.scan_points = eval(obj.voltages);
            obj.prefs = [{'voltages'}, obj.prefs];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end
    
    methods
        function setup()
            % Set Pulse Train
            numpoints = length(obj.scan_points);
            obj.taskPulseTrain = obj.nidaq.CreateTask('OpenDAQPulseTrain');
            freq = 1000 / obj.dwell_ms;
            try
                obj.taskPulseTrain.ConfigurePulseTrainOut(obj.ext_sync,freq,numpoints+1);
            catch err
                obj.taskPulseTrain.Clear
                rethrow(err)
            end
            % Set Voltage out to galvos
            obj.taskScan = obj.nidaq.CreateTask('OpenDAQScan');
            try
                obj.taskScan.ConfigureVoltageOutClkTiming({obj.DAQ_line},obj.scan_points,obj.taskPulseTrain);
            catch err
                obj.taskPulseTrain.Clear
                obj.taskScan.Clear
                rethrow(err)
            end
            % Set Counter from APD
            obj.taskCounter = obj.nidaq.CreateTask('OpenDAQCounter');
            try
                obj.taskCounter.ConfigureCounterIn(obj.count_in,numpoints+1,obj.taskPulseTrain);
            catch err
                obj.taskPulseTrain.Clear
                obj.taskScan.Clear
                obj.taskCounter.Clear
                rethrow(err)
            end
        end
        function clear_tasks(obj)
            obj.taskScan.Clear;
            obj.taskCounter.Clear;
            obj.taskPulseTrain.Clear;
        end
        function abort(obj)
            obj.clear_tasks();
        end
        function run(obj,status,managers,ax)
            obj.setup();
            assert(isvalid(obj.taskPulseTrain),'No scan setup!')

            % Move to start
            current = 0;
            
            for i = 1:length(obj.dev.OutLines)
                if strcmp(obj.dev.OutLines(i).name, obj.DAQ_line)
                    current = obj.dev.OutLines(i).state;
                end
            end
          
            resonator_tune_speed = .1;
            numberSteps = floor(abs(current-obj.overshoot_voltage)/resonator_tune_speed);
            direction = sign(obj.overshoot_voltage-current);
            
            for i = 1:numberSteps
                newval = current + (i)*direction*resonator_tune_speed;
                obj.dev.WriteAOLines(obj.DAQ_line, newval);
                pause(.1)
            end
            obj.dev.WriteAOLines(obj.DAQ_line, obj.overshoot_voltage);

            % Data
            rawdata = NaN(1, length(obj.scan_points) + 1)
            obj.data.counts = NaN * obj.scan_points
            obj.data.freqs_measured = [];
            obj.data.freq_times = [];

            % Plotting
            yyaxis(ax, 'left')
            p = plot(ax, obj.scan_points, obj.data.counts)
            yyaxis(ax, 'right')
            p2 = plot(ax, [], [])
            total_time = length(obj.scan_points) * obj.dwell_ms / 1000
            start_v = obj.scan_points(1)
            span_v = obj.scan_points(end) - start_v

            % Arm output/data lines
            obj.taskCounter.Start;
            obj.taskScan.Start;

            % Trigger to go!
            obj.taskPulseTrain.Start;
            t = tic

            ii = 0;
            while isvalid(obj.taskCounter) && (~obj.taskCounter.IsTaskDone || obj.taskCounter.AvailableSamples)
                SampsAvail = obj.taskCounter.AvailableSamples;
                % Change to counts per second
                counts = obj.taskCounter.ReadCounter(SampsAvail);
                rawdata(ii+1:ii+SampsAvail) = counts;
                obj.data.counts = diff(rawdata)
                ii = ii + SampsAvail;

                obj.data.freqs_measured = [
                    obj.data.freqs_measured 
                    hw.com('wavemeter', 'GetFrequencyNum', obj.wavemeter_channel, 0)
                ];
                obj.data.freq_times = [obj.data.freq_times toc(t)];
                
                % Update plots
                p.YData = obj.data.counts
                p2.XData = start_v + span_v * (obj.data.freq_times / total_time)
                p2.YData = obj.data.freqs_measured

                drawnow;
            end

            if ~isvalid(obj.taskCounter)
                return
            end

            % Wait for pulse train to complete, then clean up.
            obj.taskPulseTrain.WaitUntilTaskDone;
            obj.clear_tasks;
        end
        function set.voltages(obj,val)
            numeric_vals = str2num(val); %#ok<ST2NM> str2num uses eval but is more robust for numeric input
            obj.scan_points = numeric_vals;
            obj.voltages = val;
        end
    end
end
