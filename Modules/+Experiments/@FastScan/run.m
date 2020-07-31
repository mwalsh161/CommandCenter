function run( obj,status,managers,ax )
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
    AO_line = 'LED'; % out
    MeasSync = 'Widefield Lens'; % out
    SweepSync = 'sync'; % out
    APD_line = 'APD1'; % in
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
    % Setup tasks (avoid calling ClearAllTasks)
    previous_tasks = ni.Tasks;
    try
        MeasCLK = ni.CreateTask('Measurement PT');
        MeasCLK.ConfigurePulseTrainOut(MeasSync,1/dwell,nsamples_APD);
        MeasCLK.ConfigureStartTrigger(trigger_line);
        
        counter = ni.CreateTask('Counter');
        counter.ConfigureCounterIn(APD_line,nsamples_APD,MeasCLK);

        SweepCLK = ni.CreateTask('Sweep PT');
        SweepCLK.ConfigurePulseTrainOut(SweepSync,max_buf/round_total_time,buf);
        SweepCLK.ConfigureStartTrigger(trigger_line);

        sweep = ni.CreateTask('Sweep Fun');
        sweep.ConfigureVoltageOutClkTiming({AO_line},sweep_vals,SweepCLK);
        
        % Arm tasks (CLKs will wait for trigger)
        MeasCLK.Start; counter.Start;
        SweepCLK.Start; sweep.Start;
        % Trigger tasks
        trigger = ni.CreateTask('trigger');
        trigger.ConfigurePulseTrainOut(trigger_line,1e4,1); % 100 us pulse
        trigger.Start;  % Start entire experiment
        
        % Readout counter
        ii = 0;
        while ~counter.IsTaskDone || counter.AvailableSamples
            drawnow; assert(~obj.abort_request,'User aborted.');
            n = counter.AvailableSamples;
            raw_data(ii+1:ii+n) = counter.ReadCounter(n);
            plt.YData = diff(raw_data);
        end
        while ~sweep.IsTaskDone; drawnow; end
    catch err
    end
    obj.data.counts = plt.YData;
    newTasks = setdiff(ni.Tasks,previous_tasks);
    for i = 1:length(newTasks)
        newTasks(i).Clear;
    end
    if exist('err','var')
        rethrow(err)
    end
end
