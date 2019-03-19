function TuneCoarse(obj,target)
%LASERMOVE Give a target frequency, moves the laser motor to that target frequency
%   target = frequency in THz

%check if in range
obj.RangeCheck(target);

err = [];
obj.locked = false; %whether errored or not, should no longer be locked
try    
    FineThresh = max(obj.wavemeter.resolution,obj.resolution);
    CorThresh = 30*FineThresh;
    laserloc = obj.getFrequency;
    LaserFreqSet = laserloc; %first laser setpoint is presumed to be where the laser is measured to be
    if abs(laserloc - target) < FineThresh %already close enough
        return
    end
    
    obj.wavemeter.setDeviationChannel(false);
    obj.TunePercent(50);
    
    Pgain = 0.75; %gain on P for this P-only PID controller
    
    laserloc = obj.getFrequency;
    
    t = tic;
    while abs(laserloc - target) > FineThresh %threshold for catching NV in scan
        assert(toc(t) < obj.TuningTimeout,'Tuning timed out');
        if abs(laserloc - target) > CorThresh %coarse threshold
            LaserFreqSet = LaserFreqSet-Pgain*(laserloc- target); %take difference, use to set again
        else %we're close; use small steps
            LaserFreqSet = LaserFreqSet - FineThresh*sign(laserloc-target)/2; %small 10 GHz step in correct direction
        end
        obj.serial.Wavelength = obj.c/LaserFreqSet; %command to set wavelength needs to be in nm
        %get laser location again
        laserloc = obj.getFrequency;
    end
    
    obj.serial.TrackMode = 'on'; %just to keep this variable up to date (obj.serial.Wavelength turns TrackMode on!)
    obj.setpoint = target;
catch err
    obj.setpoint = NaN;
    rethrow(err)
end

end