function TuneSetpoint(obj,setpoint)
%TuneSetpoint Sets the wavemeter setpoint
%   frequency = desired setpoint in THz or nm

obj.tuning = true;
try
    for n = 0:obj.TuneSetpointAttempts
        obj.percent_setpoint = NaN;
        obj.wavemeter.setDeviationChannel(true);
        obj.serial.TrackMode = 'off';
        
        obj.wavemeter.setPIDtarget(setpoint);
        frequency = obj.wavemeter.getFrequency;
        PIDstart = tic;
        while sum(abs(setpoint-frequency) < obj.wavemeter.resolution) < 10 %wait until laser settles to frequency
            frequency = [frequency, obj.wavemeter.getFrequency];
            if toc(PIDstart) > obj.TuningTimeout
                if n > obj.TuneSetpointAttempts
                    error('Unable to complete tuning within timeout (%i attempts).',obj.TuneSetpointAttempts);
                end
                obj.TuneCoarse(setpoint)
                continue
            end
        end
        break
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
