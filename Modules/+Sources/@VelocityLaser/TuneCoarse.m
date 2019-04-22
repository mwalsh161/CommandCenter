function TuneCoarse(obj,target)
%LASERMOVE Give a target frequency, moves the laser motor to that target
%frequency. It does so by going through the setMotorFrequency method, which
%uses a calibration between the frequency as read by the wavemeter to the
%wavelength as set by the laser's hardware

%   target = frequency in THz

%check if in range
obj.RangeCheck(target);

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
    Pgain = 0.9; %gain on P for this P-only PID controller
    obj.setMotorFrequency(target);
    laserloc = obj.getFrequency;
    LaserFreqSet = laserloc; %first laser setpoint is presumed to be where the laser is measured to be
    
    t = tic;
    while abs(laserloc - target) > FineThresh %threshold for catching NV in scan
        assert(toc(t) < obj.TuningTimeout,'Unable to complete tuning within timeout.');
        if abs(laserloc - target) > CorThresh %coarse threshold
            LaserFreqSet = LaserFreqSet-Pgain*(laserloc- target); %take difference, use to set again
        else %we're close; use small steps
            LaserFreqSet = LaserFreqSet - FineThresh*sign(laserloc-target)/2; %small 10 GHz step in correct direction
        end
        obj.setMotorFrequency(LaserFreqSet); %command to set wavelength needs to be in nm
        %get laser location again
        laserloc = obj.getFrequency;
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