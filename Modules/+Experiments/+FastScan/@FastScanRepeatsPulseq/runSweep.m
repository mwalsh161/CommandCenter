function runSweep( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;
    
    assert(~isempty(obj.start_V),'Start is empty.');
    assert(~isempty(obj.stop_V),'Stop is empty.');
    assert(obj.start_V<obj.stop_V,'For now, start needs to be less that stop.');
    assert(~isempty(obj.dwell_ms),'Dwell is empty.');
    assert(~isempty(obj.total_time),'Total_time is empty.');
    dwell = obj.dwell_ms*1e-3; % Convert to seconds
    
    ni = Drivers.NIDAQ.dev.instance('Dev1');
    trigger_line = 'trigger'; % out/in
    AO_line = 'SolstisResonator'; %'LED'; % out
    MeasSync = 'GalvoScanSync'; % out
    SweepSync = 'CounterSync'; % out
    APD_line = 'APD1'; % in
    InitSync = 'InitClock'; %out additional CLK
    % Specs from NI 6343 for single AO out
    max_freq = 9e6; % samples/second
    max_buf = 8190; % samples
    
    % Calculated vars (times in seconds)
    nsamples_APD = ceil(obj.total_time/dwell);
    round_total_time = nsamples_APD*dwell;
    buf = min(max_freq*round_total_time,max_buf); % Can't imagine being limited by max_freq, but to be safe
    sweep_vals = linspace(obj.start_V,obj.stop_V,buf)';
    obj.data.meta.actual_total_time = round_total_time;
    obj.data.meta.sweep_buf_N = buf;
    
    % Note actual samples will be 1 less beause of diff
    plt = plot(ax,linspace(obj.start_V,obj.stop_V,nsamples_APD-1),NaN(1,nsamples_APD-1));
    raw_data = NaN(1,nsamples_APD);
    all_data = NaN(obj.repetitions,nsamples_APD-1);
    all_freqs = NaN(obj.repetitions,2);
    % Setup tasks (avoid calling ClearAllTasks)
    previous_tasks = ni.Tasks;
    try
        %%%%%%%%%%%%%%%%%%%%% sweep voltage to intial value
        if obj.start_V==0
            sweepInitVals = [0:0.005:0.01 0.01:-0.005:0]';
        else
            if obj.start_V>0
                sweepInitVals = [0:0.001:obj.start_V]';
            else
                sweepInitVals = [0:-0.001:obj.start_V]';
            end
        end
%         if obj.start_V>0
%             sweepInitVals = [0:0.001:obj.start_V]';
%         else
%             sweepInitVals = [0:-0.001:obj.start_V]';
%         end

        sweep_init_total_time = 0.1;
        
        InitCLK = ni.CreateTask('Initialize sweep CLK');
        InitCLK.ConfigurePulseTrainOut(InitSync,max_buf/sweep_init_total_time,length(sweepInitVals));
        
        sweepInit = ni.CreateTask('Initial Sweep');
        sweepInit.ConfigureVoltageOut({AO_line},sweepInitVals,InitCLK);
        
        sweepInit.Start;
        InitCLK.Start;
        InitCLK.WaitUntilTaskDone;
        
        emmLaser = Sources.msquared.EMM.instance;
        startFreq = emmLaser.getFrequency;
        obj.data.startFreq = startFreq;
        
        sweepInit.Clear;
        InitCLK.Clear;
        %%%%%%%%%%%%%%%%%%%%%
        
        for k=1:obj.repetitions
            %%%
            %obj.PulseBlaster.lines(obj.PBline) = true;
            obj.resLaser.off;
            obj.repumpLaser.on;
            pause(obj.repumpTime*1e-3);
            obj.repumpLaser.off;
            obj.resLaser.on;
            pause(obj.resDelay*1e-3);
            
            %%%%%sweep start_V to stop_V
            pause(0.4);
            all_freqs(2*k-1,1) = emmLaser.getFrequency;
            
            MeasCLK = ni.CreateTask('Measurement PT');
            MeasCLK.ConfigurePulseTrainOut(MeasSync,1/dwell,nsamples_APD);
            MeasCLK.ConfigureStartTrigger(trigger_line);

            counter = ni.CreateTask('Counter');
            counter.ConfigureCounterIn(APD_line,nsamples_APD,MeasCLK);

            SweepCLK = ni.CreateTask('Sweep PT');
            SweepCLK.ConfigurePulseTrainOut(SweepSync,max_buf/round_total_time,buf);
            SweepCLK.ConfigureStartTrigger(trigger_line);

            sweep = ni.CreateTask('Sweep Fun');
            sweep.ConfigureVoltageOut({AO_line},sweep_vals,SweepCLK);
    
            % Arm tasks (CLKs will wait for trigger)
            MeasCLK.Start; counter.Start;
            SweepCLK.Start; sweep.Start;
            % Trigger tasks
            trigger = ni.CreateTask('trigger');
            trigger.ConfigurePulseTrainOut(trigger_line,1e4,1); % 100 us pulse
            trigger.Start;  % Start entire experiment
            
            counter.WaitUntilTaskDone;
            % Readout counter
            ii = 0;
            while ~counter.IsTaskDone || counter.AvailableSamples
                drawnow; assert(~obj.abort_request,'User aborted.');
                n = counter.AvailableSamples;
                raw_data(ii+1:ii+n) = counter.ReadCounter(n);
                plt.YData = diff(raw_data);
                ii = ii + n;
            end
            while ~sweep.IsTaskDone; drawnow; end
            
            all_data(2*k-1,:) = plt.YData;
            pause(0.4);
            all_freqs(2*k-1,2) = emmLaser.getFrequency;
            
            MeasCLK.Clear;
            SweepCLK.Clear;
            sweep.Clear;
            counter.Clear;
            trigger.Clear;
            
            
            %%%%%sweep stop_V to start_V
            obj.resLaser.off;
            obj.repumpLaser.on;
            pause(obj.repumpTime*1e-3);
            obj.repumpLaser.off;
            obj.resLaser.on;
            pause(obj.resDelay*1e-3);
            
            pause(0.4);
            all_freqs(2*k,2) = emmLaser.getFrequency;
            
            MeasCLK = ni.CreateTask('Measurement PT');
            MeasCLK.ConfigurePulseTrainOut(MeasSync,1/dwell,nsamples_APD);
            MeasCLK.ConfigureStartTrigger(trigger_line);

            counter = ni.CreateTask('Counter');
            counter.ConfigureCounterIn(APD_line,nsamples_APD,MeasCLK);

            SweepCLK = ni.CreateTask('Sweep PT');
            SweepCLK.ConfigurePulseTrainOut(SweepSync,max_buf/round_total_time,buf);
            SweepCLK.ConfigureStartTrigger(trigger_line);

            sweep = ni.CreateTask('Sweep Fun');
            sweep.ConfigureVoltageOut({AO_line},flip(sweep_vals),SweepCLK);

            % Arm tasks (CLKs will wait for trigger)
            MeasCLK.Start; counter.Start;
            SweepCLK.Start; sweep.Start;
            % Trigger tasks
            trigger = ni.CreateTask('trigger');
            trigger.ConfigurePulseTrainOut(trigger_line,1e4,1); % 100 us pulse
            trigger.Start;  % Start entire experiment
            
            counter.WaitUntilTaskDone;
            % Readout counter
            ii = 0;
            while ~counter.IsTaskDone || counter.AvailableSamples
                drawnow; assert(~obj.abort_request,'User aborted.');
                n = counter.AvailableSamples;
                raw_data(ii+1:ii+n) = counter.ReadCounter(n);
                plt.YData = diff(raw_data);
                ii = ii + n;
            end
            while ~sweep.IsTaskDone; drawnow; end
            
            plt.YData = flip(plt.YData);
            all_data(2*k,:) = plt.YData;
            pause(0.4);
            all_freqs(2*k,1) = emmLaser.getFrequency;
            
            MeasCLK.Clear;
            SweepCLK.Clear;
            sweep.Clear;
            counter.Clear;
            trigger.Clear;

        end
        
        obj.resLaser.off;
        obj.repumpLaser.off;

        %%%%%%%%%%%%%%%%%%%%% sweep voltage to zero
        if obj.start_V==0
            sweepInitVals = [obj.start_V:0.005:0.01 0.01:-0.005:0]';
        else
            if obj.start_V>0
                sweepInitVals = [obj.start_V:-0.001:0]';
            else sweepInitVals = [obj.start_V:0.001:0]';
            end
        end
        
        InitCLK = ni.CreateTask('End sweep CLK');
        InitCLK.ConfigurePulseTrainOut(InitSync,max_buf/sweep_init_total_time,length(sweepInitVals));
        
        sweepInit = ni.CreateTask('End Sweep');
        sweepInit.ConfigureVoltageOut({AO_line},sweepInitVals,InitCLK);
        
        sweepInit.Start;
        InitCLK.Start;
        InitCLK.WaitUntilTaskDone;
        
        obj.data.startFreq = all_freqs(:,1);
        obj.data.stopFreq = all_freqs(:,2);
        
        sweepInit.Clear;
        InitCLK.Clear;
        %%%%%%%%%%%%%%%%%%%%%
    catch err
    end
    obj.data.counts = all_data;
    
%     FreqAxis = linspace(startFreq,stopFreq,nsamples_APD-1);
%     if ~any(isnan(FreqAxis))
%         plt.XData = FreqAxis;
%     end
    
    newTasks = setdiff(ni.Tasks,previous_tasks);
    for i = 1:length(newTasks)
        newTasks(i).Clear;
    end
    if exist('err','var')
        rethrow(err)
    end
end
