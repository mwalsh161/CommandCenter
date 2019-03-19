function TuneSetpoint(obj,setpoint)
%TuneSetpoint Sets the wavemeter setpoint
%   frequency = desired setpoint in THz or nm

%check if in range
obj.RangeCheck(setpoint);
try
obj.wavemeter.setDeviationChannel(true);
obj.serial.TrackMode = 'off';

obj.wavemeter.setPIDtarget(setpoint);
frequency = obj.wavemeter.getFrequency;
PIDstart = tic;
while sum(abs(setpoint-frequency) < obj.wavemeter.resolution) < 10 %wait until laser settles to frequency
    frequency = [frequency, obj.wavemeter.getFrequency];
    if toc(PIDstart) > obj.TuningTimeout
        obj.locked = false;
        error('Unable to reach setpoint within timeout.')
    end
end
obj.setpoint = setpoint;
obj.locked = true;
catch err
    obj.setpoint = NaN;
    obj.locked = false;
    rethrow(err)
end
