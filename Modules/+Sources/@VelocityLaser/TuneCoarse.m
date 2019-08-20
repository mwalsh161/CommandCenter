function TuneCoarse(obj,target)
%LASERMOVE Give a target frequency, moves the laser motor to that target
%frequency. It does so by going through the setMotorFrequency method, which
%uses a calibration between the frequency as read by the wavemeter to the
%wavelength as set by the laser's hardware

% A P-only PID algorithm is used until an out of range error is thrown, at
% which point the algorithm transitions to a binary search until setpoint
% achieved or an impossibility is determined.

%   target = frequency in THz

err = [];
obj.locked = false; %whether errored or not, should no longer be locked
obj.tuning = true;
try    
    FineThresh = max(obj.wavemeter.resolution,obj.resolution);
    CorThresh = 30*FineThresh;
    laserloc = obj.getFrequency;
    if abs(laserloc - target) < FineThresh %already close enough
        return
    end
    obj.wavemeter.setDeviationChannel(false);
    obj.TunePercent(50);
    Pgain = 0.5; %gain on P for this P-only PID controller
    range = [NaN,NaN]; % range for binary search
    obj.setMotorFrequency(target);
    laserloc = obj.getFrequency;
    LaserFreqSet = [NaN,obj.getFrequency]; % [current, previous]
    
    t = tic;
    PIDflag = true;
    while abs(laserloc - target) > FineThresh
        assert(toc(t) < obj.TuningTimeout,'Unable to complete tuning within timeout.');
        LaserFreqSet(1) = LaserFreqSet(1) + Pgain*(target - LaserFreqSet(2)); %take difference, use to set again
        % set and get laser location again
        try
            obj.setMotorFrequency(NextLaserFreqSet(1));
        catch err
            if contains(err.message,'Out of Range')
                LaserFreqSet(1) = mean(LaserFreqSet);
                obj.setMotorFrequency(NextLaserFreqSet(1));
            else
                rethrow(err);
            end
        end
        LaserFreqSet(1) = LaserFreqSet(2);
        LaserFreqSet(2) = obj.getFrequency;
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