function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;

    % Make sure all prefs are non-empty
    for i = 1:length(obj.prefs)
        assert(~isempty(obj.(obj.prefs{i})),sprintf('%s not specified.',obj.prefs{i}))
    end

    % Setup sources 
    %ctr = Drivers.Counter.instance(obj.APD_line, obj.APD_Sync_line);
    obj.Laser.arm;
    obj.SignalGenerator.MWPower = obj.MW_Power;
    obj.freq_list = linspace(obj.sweep_start_freq, obj.sweep_end_freq, obj.sweep_Npts);
    % Pre-allocate obj.data
    obj.data = NaN(obj.averages,obj.sweep_Npts);
    odmr = NaN(obj.averages,obj.sweep_Npts);
    
    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.meta.prefs = obj.prefs2struct;
    obj.meta.freq_list = obj.freq_list;
    obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);

    % Setup graphics
    y = NaN(1,obj.sweep_Npts);
    hold(ax,'on');
    plotH(1) = plot(obj.freq_list, y,'color', 'k','parent',ax); % ODMR signal
    ylabel(ax,'ODMR (normalized)');
    
    yyaxis(ax, 'right')
    cs = lines(1);
    plotH(2) = plot(obj.freq_list, y,...
        'color', cs(1,:),'linestyle','-','parent',ax); % Actual signal
    legend(plotH,{'Normalized (left)','Signal (right)'})
    ylabel(ax,'Counts (cps)');
    xlabel(ax,'Frequency (GHz)');
    yyaxis(ax, 'left');

    % Bullshit plot to extract pulsesequence data
    f = figure('visible','off','name',mfilename);
    a = axes('Parent',f);
    p = plot(NaN,'Parent',a);

    try
        % Initialise pulse sequence
        apdPS = APDPulseSequence(obj.nidaqH,obj.pbH,sequence('placeholder'));  % Object for APD counting
        pulseSeq = obj.BuildPulseSequence();
        pulseSeq.repeat = obj.sweep_Npts; % Pulse sequence triggers sg to next freq step
        apdPS.seq = pulseSeq;
        
        obj.SignalGenerator.on;
        %obj.Laser.on;
        for j = 1:obj.averages
            status.String = sprintf('Experiment started\nAverage %i/%i',j,obj.averages);
            drawnow; assert(~obj.abort_request,'User aborted.');

            % Normalization
            %if obj.MW_freq_norm_GHz > 0
            %    obj.SignalGenerator.MWFrequency = obj.MW_freq_norm_GHz*1e9;
            %    obj.data(j,i,1) = ctr.singleShot(obj.Exposure_ms, 1);
            %else
            %    obj.SignalGenerator.off;
            %    obj.data(j,i,1) = ctr.singleShot(obj.Exposure_ms, 1);
            %    obj.SignalGenerator.on;
            %end

            obj.SignalGenerator.f_sweep(obj.sweep_start_freq*1e6, obj.sweep_end_freq*1e6, obj.sweep_Npts) % Initialise frequency sweep in signal generator
            apdPS.start(obj.sweep_Npts); % Run pulse sequence
            pause( obj.sweep_Npts*(obj.Exposure + obj.Trig_Time + obj.APD_Delay)/1e3)
            apdPS.stream(p); % Collect data
            dat = p.YData;

            % Update plot
            obj.data(j,:) = dat;
            odmr(j,:) = 2*dat./(dat+dat(1)); % Use first frequency point as normalisation
            averageODMR = squeeze(nanmean(odmr,1));
            averagedData = squeeze(nanmean(obj.data,1));
            plotH(1).YData = averageODMR;
            plotH(2).YData = averagedData;
        end
    catch err
    end
    obj.SignalGenerator.off;
    obj.Laser.off;
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
