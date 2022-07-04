classdef Counter < Modules.Driver
    %COUNTER Setup and read a counter on NIDAQ
    %   Sets up infinite counter, and samples at the end of each dwell time
    
    properties
        dwell = 1;              % ms (clock speed of PulseTrain).  Takes effect at start.
        update_rate = 0.1;      % s (time between Matlab reading DAQ).  Takes effect at start.
        WindowMax = 60;         % Max axes width in seconds
        prefs = {'dwell','update_rate','WindowMax', 'count'};
        readonly_prefs = {'count'};
    end
    properties(SetObservable, GetObservable)
        count = Prefs.Double(0, 'readonly', true);                % Counts per second. For other modules to inspect.

    end
    properties(Access=private)
        timerH                  % Handle to timer
        PulseTrainH             % NIDAQ task PulseTrain
        CounterH                % NIDAQ task Counter
    end
    properties(SetAccess=private,SetObservable)
        running = false;
    end
    properties(SetAccess=private,Hidden)
        callback                % Callback function for counter stream
        fig                     % Handle to viewer figure
        ax                      % Handle to viewer axis
        plt                     % Handle to plot
        textH                   % Handle to axes text
    end
    properties(SetAccess=immutable)
        nidaq                   % Nidaq handle
        lineIn                  % DAQ input line
        lineOut                 % External Sync
    end
        
    methods(Access=protected)
        function obj = Counter(lineIn,lineOut)
            obj.nidaq = Drivers.NIDAQ.dev.instance('Dev1');
            obj.lineIn = lineIn;
            obj.lineOut = lineOut;
            % Check that lines exist, if not open nidaq view
            lines = {lineIn,lineOut};
            types = {'in','out'};
            msg = {};
            for i = 1:numel(lines)
                try
                    obj.nidaq.getLines(lines{i},types{i});
                catch err
                    msg{end+1} = err.message;
                end
            end
            if ~isempty(msg)
                obj.nidaq.view;
                error('Add lines below, and load again.\n%s',strjoin(msg,'\n'))
            end
            obj.loadPrefs;

        end
        function stopTimer(obj,varargin)
            if isvalid(obj)
                stop(obj.timerH);
                delete(obj.timerH);
                obj.timerH = [];
                obj.CounterH.Clear;
                obj.PulseTrainH.Clear;
                obj.callback = [];
                obj.running = false;
            end
        end
        function cps(obj,varargin)
            % Reads Counter Task
            if ~isvalid(obj.CounterH)
                obj.stopTimer()
            end
            nsamples = obj.CounterH.AvailableSamples;
            if nsamples
                counts = mean(diff(obj.CounterH.ReadCounter(nsamples)));
                counts = counts/(obj.dwell/1000);
                obj.callback(counts,nsamples)
            end
            obj.count = counts;
        end
        function updateView(obj,counts,samples)
            % Default GUI callback
            counts = round(counts);
            title(obj.ax,sprintf('%i CPS (%i Samples Averaged)',counts,samples))
            x = get(obj.plt,'xdata');
            y = get(obj.plt,'ydata');
            xmax = round(obj.WindowMax/obj.update_rate);
            if numel(x) > xmax
                delta = numel(x)-xmax;
                y = [y(1+delta:end) counts];
                x = [x(1+delta:end) x(end)+obj.update_rate];
            else
                y(end+1) = counts;
                x(end+1) = x(end)+obj.update_rate;
            end
            set(obj.plt,'xdata',x,'ydata',y);
            xlim = [x(1) x(end)+(x(end)-x(1))*0.1];
            set(obj.ax,'xlim',xlim)
            set(obj.textH,'string',sprintf('%i',counts))
            drawnow limitrate;
        end
    end
    methods(Static)
        function obj = instance(lineIn,lineOut)
            mlock;
            id = [lineIn,lineOut]; 
            % Using cell `id` directly may lead to numerous problems in encoding preferences. 
            % Should use char array concatenation instead.
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.Counter.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(id,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.Counter(lineIn,lineOut);
            obj.singleton_id = id; 
            Objects(end+1) = obj;
        end
    end
    methods
        function delete(obj)
            obj.reset;
            if ~isempty(obj.fig)&&isvalid(obj.fig)
                delete(obj.fig)
            end
        end
        function data = singleShot(obj,dwell,nsamples)
            % Blocking function that will take nsamples, each with the
            % specified dwell time.
            % Returns array of size 1x(nsamples).
            % dwell is in ms.
            if nargin < 3
                nsamples = 1;
            end
            assert(nsamples>0,'Number of samples must be greater than 0.')
            nsamples = nsamples + 1;
            dwell = dwell/1000; % ms to s
            % Configure clock (pulse train)
            PulseTrainH = obj.nidaq.CreateTask('Counter singleShot PulseTrain'); %#ok<*PROPLC>
            f = 1/dwell;
            PulseTrainH.ConfigurePulseTrainOut(obj.lineOut,f,nsamples);
            % Configure Counter
            try
                CounterH = obj.nidaq.CreateTask('Counter CounterObj');
            catch err
                PulseTrainH.Clear;
                rethrow(err)
            end
            try
            CounterH.ConfigureCounterIn(obj.lineIn,nsamples,PulseTrainH);
            % Start counter (waits for pulse train), then start pulse train
            CounterH.Start;
            PulseTrainH.Start;
            catch err
                PulseTrainH.Clear;
                CounterH.Clear;
                rethrow(err)
            end
            % Wait until finished, then read data.
            PulseTrainH.WaitUntilTaskDone;
            data = CounterH.ReadCounter(CounterH.AvailableSamples);
            data = diff(data)/dwell;
            PulseTrainH.Clear;
            CounterH.Clear;
        end
        function start(obj,Callback)
            % Callback will be called every update_rate with first argument
            % is cps, second argument is number of samples read.
            % If no callback is used, a default one will be used.
            if nargin < 2
                if isempty(obj.fig)
                    obj.view;
                else
                    figure(obj.fig);  % Bring to foreground
                end
                Callback = @obj.updateView;
            end
            if ~isempty(obj.timerH)
                return  % Silently fail
            end
            obj.timerH = timer('ExecutionMode','fixedRate','name','Counter',...
                'period',obj.update_rate,'timerfcn',@obj.cps);
            obj.callback = Callback;
            dwell = obj.dwell/1000; % ms to s
            try
                obj.PulseTrainH = obj.nidaq.CreateTask('Counter PulseTrain');
            catch
                err = [];
                
               try
                   obj.PulseTrainH = obj.nidaq.GetTaskByName('Counter PulseTrain');
               catch err
                   
               end
               
               if ~isempty(err)
                   rethrow(err)
               end
            end
            f = 1/dwell; %#ok<*PROP>
            try
                obj.PulseTrainH.ConfigurePulseTrainOut(obj.lineOut,f);
            catch err
                obj.reset
                rethrow(err)
            end
            obj.CounterH = obj.nidaq.CreateTask(['Counter CounterObj ' obj.lineIn]);
            try
                continuous = true;
                buffer = f*obj.update_rate;
                obj.CounterH.ConfigureCounterIn(obj.lineIn,buffer,obj.PulseTrainH,continuous)
            catch err
                obj.reset
                rethrow(err)
            end
            obj.PulseTrainH.Start;
            obj.CounterH.Start;
            start(obj.timerH)
            obj.running = true;
        end
        
        function stop(obj)
            if ~isempty(obj.timerH)
                obj.stopTimer()
            end
        end
        function reset(obj)
            if ~isempty(obj.timerH)
                if isvalid(obj.timerH)&&strcmp(obj.timerH.Running,'on')
                    obj.stopTimer()
                end
                obj.timerH = [];
            else
                if ~isempty(obj.CounterH)&&isvalid(obj.CounterH)
                    obj.CounterH.Clear;
                end
                if ~isempty(obj.PulseTrainH)&&isvalid(obj.PulseTrainH)
                    obj.PulseTrainH.Clear
                end
            end
        end
        
        % Callbacks from GUI
        function closeReq(obj,varargin)
            if ~isempty(obj.fig)&&isvalid(obj.fig)
                obj.reset;
                delete(obj.fig)
                obj.fig = [];
            end
        end
        function updateDwellCallback(obj,hObj,varargin)
            val = str2double(get(hObj,'string'));
            obj.dwell = val;
            if ~isempty(obj.timerH)
                obj.stopTimer()
                obj.start()
            end
        end
        function updateRateCallback(obj,hObj,varargin)
            val = str2double(get(hObj,'string'));
            oldVal = obj.update_rate;
            obj.update_rate = val;
            try
                if ~isempty(obj.timerH)
                    stop(obj.timerH)
                    obj.timerH.Period = val;
                    start(obj.timerH)
                end
            catch err
                obj.update_rate = oldVal;
                rethrow(err)
            end
        end
        function updateWindowMax(obj,hObj,varargin)
            val = str2double(get(hObj,'string'));
            obj.WindowMax = val;
        end
    end
end

