function setupLNScan()
    samples = 200;
    averages = 10;
    timescan = .2;  % seconds
    dwell = timescan/samples;
    voltage = 10;
    bipolar = true;
    
    d = Drivers.NIDAQ.dev.instance('dev1');
    
    d
    
    mzi  =  d.getLine('AO3',  d.OutLines);
    aom =   d.getLine('Z',    d.OutLines);
    
    apd1 =  d.getLine('APD1', d.InLines);
    apd2 =  d.getLine('APD2', d.InLines);     % CC wasn't saving settings. Have to add it again.
    
    tsamples = 2*(samples+1);
    bsamples = 4*(samples+1)-1;
    
    master = Prefs.Time;
    master.name = 'Voltage Scan';
    master.unit = 'V';
    
    if bipolar
        csamples = bsamples;
        V = bipolartriangle(1:bsamples);
        paired = Prefs.Paired([master mzi.get_meta_pref], {@bipolartriangle});
    else
        csamples = tsamples;
        V = triangle(1:tsamples);
        paired = Prefs.Paired([master mzi.get_meta_pref], {@triangle});
    end

    plot(1:csamples, V)
    
    % Not ready yet. %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%%
%     Base.Sweep({apd1}, {paired, Prefs.Time}, {csamples, 1:averages}, struct(), .2/csamples);

    % Bootstrap.     %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%%
    d.ClearAllTasks;
    
    PT = d.CreateTask('LN PulseTrain');
    f = 1/dwell;
    PT.ConfigurePulseTrainOut('GalvoScanSync', f);
    
    APD1 = d.CreateTask('LN APD1');
    APD1.ConfigureCounterIn('APD1', csamples*averages, PT);
    
    APD2 = d.CreateTask('LN APD2');
    APD2.ConfigureCounterIn('APD2', csamples*averages, PT);
    
    MZI = d.CreateTask('LN MZI');
    MZI.ConfigureVoltageOut('AO3', repmat(V, [1 averages])', PT);
    
    PT.Start
    APD1.Start
    APD2.Start
    MZI.Start
    
%     pause(averages*timescan)
    
    APD1.WaitUntilTaskDone()
    APD2.WaitUntilTaskDone()
    
    c1 = diff([0, APD1.ReadCounter(APD1.AvailableSamples)]);
    c2 = diff([0, APD2.ReadCounter(APD2.AvailableSamples)]);
    
    methods(APD1)
    
    size(c1)
    
    % Pad 0 take diff
    
    subplot(1,2,1)
    imagesc(reshape(c1, [csamples, averages]));
    subplot(1,2,2)
    imagesc(reshape(c2, [csamples, averages]));

    
    function v = triangle(t)
        up      = voltage * (t-1)               / samples;
        down    = voltage * (2*(samples+1) - t)   / samples;
        
        isUp = t <= samples+1;
        
        v = up;
        v(~isUp) = down(~isUp);
    end
    function v = bipolartriangle(t)
        begin       = voltage * (t-1)                   / samples;
        middle      = voltage * (2*(samples+1) - t)  / samples;
        endd        = voltage * (t-4*(samples+1)+1)         / samples;
        
        isBegin     = t <= (samples+1);
        isEnd       = t > 3*(samples+1)-1;
        
%         length(t)
%         sum(isBegin)
%         sum(isEnd)
        
        v = middle;
        v(isBegin)  = begin(isBegin);
        v(isEnd)    = endd(isEnd);
    end
end

