function TuneSetpoint(obj,setpoint)
%TuneSetpoint Sets the wavemeter setpoint
%   frequency = desired setpoint in THz or nm

if obj.debug
    f_debug = UseFigure([mfilename('class') '.TuneSetpoint'],'name','TuneSetpoint',true);
    figure(f_debug); % Bring to front (and gcf)
    ax_debug(1) = subplot(3,1,1,'parent',f_debug);
    ax_debug(2) = subplot(3,1,2,'parent',f_debug);
    ax_debug(3) = subplot(3,1,3,'parent',f_debug);
    hold(ax_debug(1),'on'); hold(ax_debug(2),'on'); hold(ax_debug(3),'on');
    set(ax_debug(2:3),'yscale','log');
    p_debug(1,1) = plot(ax_debug(1),[0 1], [setpoint setpoint],'--k');
    p_debug(1,2) = plot(ax_debug(1),NaN, NaN,'.-');
    ylabel(ax_debug(1),'Frequency (THz)');
    % Convert THz -> MHz for derivative plot (factor 1000*1000)
    yyaxis(ax_debug(2),'left');
    p_debug(2,1) = plot(ax_debug(2),[0 1], obj.wavemeter.resolution*1000*1000*[1 1],'--k');
    p_debug(2,2) = plot(ax_debug(2),NaN, NaN,'.-');
    ylabel(ax_debug(2),'|F-setpoint| (MHz)');
    yyaxis(ax_debug(2),'right');
    p_debug(4,2) = plot(ax_debug(2),NaN, NaN,'.-');
    ylabel(ax_debug(2),'Regulation Signal (V)');
    p_debug(3,1) = plot(ax_debug(3),[0 1], obj.wavemeter.resolution*1000*1000*[1 1],'--k');
    p_debug(3,2) = plot(ax_debug(3),NaN, NaN,'.-');
    ylabel(ax_debug(3),'|dF| (MHz)');
    xlabel(ax_debug(3),'Time (s)')
    debug_clk = tic;
    all_volt = [];
    all_freq = [];
    all_ts = [];
end
obj.tuning = true;
try
    for n = 0:obj.TuneSetpointAttempts
        obj.percent_setpoint = NaN;
        obj.wavemeter.setDeviationChannel(true);
        obj.serial.TrackMode = 'off';
        
        obj.wavemeter.setPIDtarget(setpoint);
        frequency = obj.wavemeter.getFrequency;
        if obj.debug
            all_volt(end+1) = obj.wavemeter.getDeviationVoltage;
            all_freq(end+1) = frequency; %#ok<*AGROW>
            all_ts(end+1) = toc(debug_clk);
        end
        PIDstart = tic;
        % wait until laser settles to frequency
        n_points = obj.TuneSetpointNPoints;
        while (length(frequency)<=n_points || ...
              ~all(abs(diff(frequency(end-n_points:end))) < obj.wavemeter.resolution)) && ...
              toc(PIDstart) < obj.TuningTimeout
            frequency = [frequency, obj.wavemeter.getFrequency];
            if obj.debug
                all_volt(end+1) = obj.wavemeter.getDeviationVoltage;
                all_freq(end+1) = frequency(end);
                all_ts(end+1) = toc(debug_clk);
                p_debug(1,1).XData(2) = all_ts(end);
                p_debug(2,1).XData(2) = all_ts(end);
                p_debug(3,1).XData(2) = all_ts(end);
                p_debug(1,2).XData = all_ts;
                p_debug(1,2).YData = all_freq;
                p_debug(2,2).XData = all_ts;
                p_debug(2,2).YData = abs(all_freq-setpoint)*1000*1000;
                p_debug(3,2).XData = all_ts(2:end);
                p_debug(3,2).YData = abs(diff(all_freq))*1000*1000;
                p_debug(4,2).XData = all_ts;
                p_debug(4,2).YData = all_volt;
                drawnow limitrate;
            end
        end
        if abs(frequency(end) - setpoint) > obj.wavemeter.resolution
            if n >= obj.TuneSetpointAttempts
                error('Unable to complete tuning within timeout (%i attempts).',obj.TuneSetpointAttempts);
            else
                obj.wavemeter.ClearPIDHistory; % Clear any DC error in I term
                obj.TuneCoarse(setpoint)
                continue % Try again
            end
        else
            break % Done
        end
    end
    obj.setpoint = setpoint;
    obj.locked = true;
    obj.tuning = false;
catch err
    obj.setpoint = NaN;
    obj.locked = false;
    obj.tuning = false;
    rethrow(err)
end
