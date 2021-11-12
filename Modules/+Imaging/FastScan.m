classdef FastScan < Modules.Imaging
    
    properties
        maxROI = [0 10; 1 1000];
        % NOTE: my_string should be added at end as setting, but not saved like pref
        %prefs = {'fyi','my_module','my_integer','my_double','old_style','my_logical','fn_based','cell_based','source','imager'};
%         prefs = {'file','old_style','fyi','my_old_array','my_array','my_array2','my_module','my_integer','my_double','my_logical'};
       % show_prefs = {'fyi','my_integer','my_double'};
       % readonly_prefs = {''} % Should result in deprecation warning if use
    end
    properties(GetObservable,SetObservable)
        laser = Prefs.String('laser');
        repump = Prefs.String('pvcam power');
        detector = Prefs.String('APD1');
        sync = Prefs.String('GalvoScanSync');
        %ADD PATH PROPERTY
        dwell = Prefs.Double(1, 'units', 'ms')
        
%         voltage_start = Prefs.Double(0, 'units', 'V', 'min', 0, 'max', 10)
%         voltage_end =   Prefs.Double(10, 'units', 'V', 'min', 0, 'max', 10)
        
        bins =          Prefs.Integer(1000, 'set', 'set_bins', 'min', 2)
        up_percent =    Prefs.Double(10, 'units', '%', 'set', 'set_up_percent', 'min', 0, 'max', 100, ...
                                        'help_text', 'Percent of the scan to use for repump')
        up_bins =       Prefs.Integer(0, 'readonly', true, 'help_text', 'Number of bins for the repump and "Zig"')
        down_bins =     Prefs.Integer(0, 'readonly', true, 'help_text', 'Number of bins for the data and "Zag"')
        
        display_movmean =   Prefs.Integer(1, 'min', 1, 'help_text', 'Averaging of the bins such that data can be displayed on a screen with limited pixels.')
        
        reset =         Prefs.Boolean(false, 'set', 'resetData', 'help_text', 'Erase all data.')
        use_expt_axes = Prefs.Boolean(true, 'help_text', 'Uses the experiment axes to plot summary data. Useful in vertical mode.')
        
        repump_cw =     Prefs.Boolean(  'help_text', 'If this is checked, repump will be always on.');
        
        repump_next =   Prefs.Boolean(true,  'help_text', 'Whether to repump next scan. Resets to false afterwards unless always or nosig say otherwise.');
        repump_always = Prefs.Boolean(  'help_text', 'If true');
        repump_nosig =  Prefs.Boolean('readonly', true, 'help_text', 'NotImplemented');
        
        restart_centered = Prefs.Boolean('readonly', true, 'help_text', 'NotImplemented');
        
        resolution = [1000 100];                 % Pixels
        ROI = [0 10; 1 100];
        continuous = false;
    end
    
    properties
        data = []
        freqs = []
    end
    
    methods(Access=private)
        function obj = FastScan()
            obj.loadPrefs;
            obj.set_bins(obj.bins)
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.FastScan();
            end
            obj = Object;
        end
    end
    methods
        function val = set_bins(obj, val, ~)
            obj.up_bins = round(val * obj.up_percent / 100);
            obj.down_bins = val - obj.up_bins;
        end
        function val = set_up_percent(obj, val, ~)
            obj.up_bins = round(obj.bins * val / 100);
            obj.down_bins = obj.bins - obj.up_bins;
        end
        function checkData(obj)
            if ~all(size(obj.data) == [obj.ROI(2,2), obj.bins])
                obj.resetData();
            end
        end
        function val = resetData(obj, ~, ~)
            obj.data = NaN(obj.ROI(2,2), obj.bins);
            val = false;
        end
        function set.ROI(obj,val)
            % Update ROI without going outside maxROI
            val(1,1) = max(obj.maxROI(1,1),val(1,1)); %#ok<*MCSUP>
            val(1,2) = min(obj.maxROI(1,2),val(1,2));
            val(2,1) = 1;
            val(2,2) = min(obj.maxROI(2,2),val(2,2));
            
            % Now make sure no cross over
            val(1,2) = max(val(1,1),val(1,2));
            val(2,2) = max(val(2,1),val(2,2));
            obj.ROI = val;
        end
        function focus(obj,ax,stageHandle)
        end
        function snap(obj,im,~, ~)
            im.Parent.XLabel.String = 'Voltage [V]';
            im.Parent.YLabel.String = 'Scan [#]';
            im.Parent.XDir = 'reverse';
            im.Parent.YDir = 'normal';
            im.Parent.DataAspectRatioMode = 'auto';
            
            obj.checkData()
            obj.fastscan(im)
        end
        function startVideo(obj,im)
            obj.continuous = true;
            while obj.continuous
                obj.snap(im,true);
                drawnow;
            end
        end
        function stopVideo(obj)
            obj.continuous = false;
        end
    end
    
    methods
        function frequencyCalibration(obj)
            ni = Drivers.NIDAQ.dev.instance('Dev1');
            wm = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu',2); %cwave on ch 2

            obj.freqs = [];
            for i = 0:100
                disp(['Setting voltage ' num2str(i/10)])
                ni.WriteAOLines('laser',i/10)
                pause(1);
                obj.freqs(i) = wm.getFrequency;
                pause(1); 
            end 
            for i = 100:-1:0
                ni.WriteAOLines('laser',i/10)
                pause(.01); 
            end 

%             figure; plot(freq);
%             xlabel('Applied voltage, V/10');
%             ylabel('Measured frequency, THz');
        end
        function fastscan(obj, im)
            obj.data = circshift(obj.data, 1);
            obj.data(1,:) = NaN;
            
            % Variables that govern the shape of our output.
%             vi = obj.voltage_start;             % Initial voltage
%             vf = obj.voltage_end;               % Final voltage
            vi = obj.ROI(1,1);
            vf = obj.ROI(1,2);
            
            ub = obj.up_bins;
            db = obj.down_bins;
            tb = (ub + db);         % Total bins
            
            dwell = obj.dwell/1000;           % Dwell per bin
            
            % Generate the lists that we will output.
            alist = [linspace(vi, vf, ub+1) linspace(vf, vi, db+1)]';    % linspace(,,N+1) such that bin width is correct. Remove the two extra points next.
            alist(ub+1) = [];   % Remove the duplicated point at the center.
            alist(end) = [];    % Remove the duplicated point at the end.
            
            if obj.repump_cw
                dlist = ones(1, tb);
            elseif obj.repump_next
                dlist = [ones(1, ub) zeros(1, db)];
                obj.repump_next = false;
            else
                dlist = zeros(1, tb);
            end
            if obj.repump_always
                obj.repump_next = true;
            end
            
            im.XData = [vf + (vf-vi)*ub/tb, vi];
            im.Parent.XLim = [min(im.XData), max(im.XData)];
            axExp = [];
            if obj.use_expt_axes
                axExp = findobj(im.Parent.Parent.Parent.Children, 'Tag', 'panel_exp').Children(1);
                
                if length(axExp.Children) == 1
                    summary = axExp.Children;
                else
                    hold(axExp, 'off');
                    summary = plot(axExp, NaN, NaN);
                end
                
                axExp.XLabel.String = 'Voltage [V]';
                axExp.YLabel.String =  'Mean Signal [cts]';
                
                summary.XData = linspace(im.XData(1), im.XData(2), obj.bins);
                axExp.XLim = [min(im.XData), max(im.XData)];
                axExp.XDir = 'reverse';
%                 summary.YData = NaN * summary.XData;
            end
            
            % Configure tasks
            ni = Drivers.NIDAQ.dev.instance('Dev1');
            ni.ClearAllTasks();
            
            % Configure pulsetrain (timebase)
            freq = 1/dwell;
            taskPulseTrain = ni.CreateTask('FastScanPulseTrain');
            try
                taskPulseTrain.ConfigurePulseTrainOut(obj.sync, freq, tb+1);        % One extra point for diff'ing; the counter outputs cts since start.
                taskPulseTrain.Verify();
            catch err
                taskPulseTrain.Clear
                rethrow(err)
            end

            % Configure analog output (tuning)
            taskAnalog = ni.CreateTask('FastScanAnalog');
            try
                taskAnalog.ConfigureVoltageOutClkTiming(obj.laser, alist, taskPulseTrain);      % DAQmx_Val_AllowRegen is on by default, so the buffer will loop back on this list.
                taskAnalog.Verify();
            catch err
                taskPulseTrain.Clear
                taskAnalog.Clear
                rethrow(err)
            end

            % Configure digital output (repump)
            taskDigital = ni.CreateTask('FastScanDigital');
            try
                taskDigital.ConfigureDigitalOut(obj.repump, dlist', taskPulseTrain);     % DAQmx_Val_AllowRegen is on by default, so the buffer will loop back on this list.
                taskDigital.Verify();
            catch err
                taskPulseTrain.Clear
                taskAnalog.Clear
                taskDigital.Clear
                rethrow(err)
            end

            % Configure counter input (APD)
            taskCounter = ni.CreateTask('FastScanCounter');
            try
                taskCounter.ConfigureCounterIn(obj.detector, tb+1, taskPulseTrain);      % One extra point for diff'ing; the counter outputs cts since start.
                taskCounter.Verify();
            catch err
                taskPulseTrain.Clear
                taskAnalog.Clear
                taskDigital.Clear
                taskCounter.Clear
                rethrow(err)
            end

            % Start tasks
            taskAnalog.Start();
            taskDigital.Start();
            taskCounter.Start();
            
            taskPulseTrain.Start();

            raw = NaN(tb+1,1);
            ii = 0;
            while isvalid(taskCounter) && (~taskCounter.IsTaskDone || taskCounter.AvailableSamples)
                SampsAvail = taskCounter.AvailableSamples;
                % Change to counts per second
                raw(ii+1:ii+SampsAvail) = taskCounter.ReadCounter(SampsAvail);
                obj.data(1, 1:(length(raw)-1)) = diff(raw);
                im.CData = movmean(obj.data, obj.display_movmean, 2, 'omitnan');
                im.Parent.DataAspectRatioMode
                if ~isempty(axExp)
                    summary.YData = nanmean(obj.data, 1);
                    %summary.XData = 1:length(summary.YData);
                end
                
                drawnow
%                 im.AlphaData = ~isnan(obj.data); % Slow?
%                 raw(ii+1:ii+SampsAvail) = counts;
%                 data = reshape(diff(raw),[ub+db, scans]);
                ii = ii + SampsAvail;
            end

            if obj.repump_nosig
                nosig = false;
                % Check nosig ! obj.data(1, :)
                
                if nosig
                    obj.repump_next = true
                end
            end
        end
    end
end





