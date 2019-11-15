function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;

    % Make sure all prefs are non-empty
    for i = 1:(length(obj.prefs)-4)
        assert(~isempty(obj.(obj.prefs{i})),sprintf('%s not specified.',obj.prefs{i}))
    end

    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.meta.prefs = obj.prefs2struct;
    obj.meta.freq_list = obj.freq_list;
    obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);

    % Turn on biasing
    assert(obj.PowerSupply.power_supply_connected, 'Power supply not connected') % Do not proceed if power supply disconnected
    if ~obj.keep_bias_on
        obj.PowerSupply.on();
    end

    ctr = Drivers.Counter.instance(obj.APD_line, obj.APD_Sync_line);
    obj.Laser.arm;
    obj.SignalGenerator.MWPower = obj.MW_Power_dBm;
    obj.SignalGenerator.MWFrequency = obj.freq_list(1); % Just init to first point even though redundant
    obj.VDD_VCO = polyval( obj.VDD_VCO_cal, obj.SignalGenerator.MWFrequency);
    % Pre-allocate obj.data
    n = length(obj.freq_list);
    obj.data = NaN(obj.averages,n,2);

    % Turn on microwave control line
    assert(~isempty(obj.PulseBlaster),'No IP set!')
    obj.PulseBlaster.lines(obj.MW_Control_line) = true;

    % Setup graphics
    y = NaN(1,n);
    hold(ax,'on');
    plotH(1) = plot(obj.freq_list/1e9*obj.freq_multiplication, y,'color', 'k','parent',ax);
    current_freqH = plot(ax,NaN,NaN,'--r');
    ylabel(ax,'ODMR (normalized)');
    
    yyaxis(ax, 'right')
    cs = lines(2);
    plotH(2) = plot(obj.freq_list/1e9*obj.freq_multiplication, y,...
        'color', cs(1,:),'linestyle','-','parent',ax);
    plotH(3) = plot(obj.freq_list/1e9*obj.freq_multiplication, y,...
        'color', cs(2,:),'linestyle','-','parent',ax);
    legend(plotH,{'Normalized (left)','Signal (right)','Normalization (right)'})
    ylabel(ax,'Counts (cps)');
    xlabel(ax,'Frequency (GHz)');
    yyaxis(ax, 'left');
    try
        obj.SignalGenerator.on;
        obj.Laser.on;
        for j = 1:obj.averages
            status.String = sprintf('Experiment started\nAverage %i',j);
            for i = 1:n
                current_freqH.XData = [1 1]*obj.freq_list(i)/1e9*obj.freq_multiplication;
                current_freqH.YData = NaN(1,2); % To allow ylim to be calculated
                current_freqH.YData = get(ax,'ylim');
                drawnow; assert(~obj.abort_request,'User aborted.');
                % Normalization
                if obj.MW_freq_norm_GHz > 0
                    obj.SignalGenerator.MWFrequency = obj.MW_freq_norm_GHz*1e9/obj.freq_multiplication;
                    obj.VDD_VCO = polyval( obj.VDD_VCO_cal, obj.SignalGenerator.MWFrequency);
                    obj.data(j,i,1) = ctr.singleShot(obj.Exposure_ms, 1);
                else
                    obj.SignalGenerator.off;
                    obj.data(j,i,1) = ctr.singleShot(obj.Exposure_ms, 1);
                    obj.SignalGenerator.on;
                end
                % Signal
                obj.SignalGenerator.MWFrequency = obj.freq_list(i); % Just init to first point
                obj.VDD_VCO = polyval( obj.VDD_VCO_cal, obj.SignalGenerator.MWFrequency);
                obj.data(j,i,2) = ctr.singleShot(obj.Exposure_ms, 1);

                % Update plot
                averagedData = squeeze(nanmean(obj.data,1));
                norm   = averagedData(:, 1);
                signal = averagedData(:, 2);
                data = 2 * signal ./ (signal + norm);
                plotH(1).YData = data;
                plotH(2).YData = signal;
                plotH(3).YData = norm;
            end
        end
    catch err
    end
    obj.SignalGenerator.off;
    obj.Laser.off;

    % Turn microwave control off
    obj.PulseBlaster.lines(obj.MW_Control_line) = false;

    % Turn off biasing
    if ~obj.keep_bias_on
        obj.PowerSupply.off();
    end

    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
