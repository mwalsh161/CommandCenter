function TuneCoarse(obj,target)
%LASERMOVE Give a target frequency, moves the laser motor to that target
%frequency. It does so by going through the setMotorFrequency method, which
%uses a calibration between the frequency as read by the wavemeter to the
%wavelength as set by the laser's hardware

%   target = frequency in THz

Pgain = 0.5; %gain on P for this P-only PID controller
FineThresh = max(obj.wavemeter.resolution,obj.resolution);
in_bound_flag = true;
obj.locked = false; %whether errored or not, should no longer be locked
obj.tuning = true;
if obj.debug
    f_debug = UseFigure(class(obj,'class_name'),'name','TuneCoarse',true);
    figure(f_debug); % Bring to front (and gcf)
    ax_debug = axes('parent',f);
    hold(ax_debug,'on');
    p_debug(1) = plot(ax_debug,[0 1], [target target],'--k');
    p_debug(2) = plot(ax_debug,NaN, NaN,'.-');
    p_debug(3) = plot(ax_debug,NaN, NaN,'.-');
    p_debug(4) = plot(ax_debug,NaN, NaN,'k*');
    legend(p_debug,{'Target','SetPoint','Last Measured','Out of Range'});
    ylabel(ax_debug,'Frequency (THz)');
    xlabel(ax_debug,'Iteration')
end
try    
    % Take laser out of PID mode, and set it to the middle of piezo range
    obj.wavemeter.setDeviationChannel(false);
    obj.TunePercent(50);
    freq = [target, obj.getFrequency];
    % Begin PID algorithm
    t = tic;
    while abs(freq(2) - target) > FineThresh
        assert(toc(t) < obj.TuningTimeout,'Unable to complete tuning within timeout.');
        if obj.debug
            p_debug(2).YData = [p_debug(2).YData freq(1)];
            p_debug(3).YData = [p_debug(3).YData freq(2)];
            x_debug = 1:length(p_debug(2).YData);
            p_debug(1).XData = x_debug([1 end]);
            p_debug(2).XData = x_debug;
            p_debug(3).XData = x_debug;
        end
        try
            obj.setMotorFrequency(freq(1));
            in_bound_flag = true; % Must be back in bounds
        catch sub_err
            if contains(sub_err.message,'Out of Range') && in_bound_flag
                if obj.debug
                    plot(ax_debug,x_debug(end), freq(1),'k*');
                end
                temp = mean(freq);
                if temp > freq(1) && temp >= target % Near the low end of range
                    in_bound_flag = false;
                elseif temp < freq(1) && temp <= target % Near the high end of range
                    in_bound_flag = false;
                end
                freq(1) = temp;
                continue
            end
            rethrow(sub_err);
        end
        freq(2) = obj.getFrequency;
        % "Logical beginning" of PID algorithm loop
        freq(1) = freq(1) + Pgain*(target - freq(2)); %take difference, use to set again
    end
    obj.setpoint = target;
    obj.tuning = false;
catch err
    obj.setpoint = NaN;
    obj.tuning = false;
    rethrow(err)
end
obj.tuning = false;

end