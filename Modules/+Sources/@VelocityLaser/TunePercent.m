function TunePercent(obj,ppercent)
%TunePercent Sets the piezo percentage
%   ppercent = desired piezo percentage from 0 to 100

assert(ppercent >=0 && ppercent <= 100, 'TunePercent input must be between 0 and 100');
voltage = -ppercent/100*diff(obj.Vrange)+obj.Vrange(2);

err = [];
obj.tuning = true;
try
    obj.wavemeter.setDeviationChannel(false); %PID must be off before manually setting voltage
    obj.wavemeter.setDeviationVoltage(voltage);
    obj.percent_setpoint = ppercent;
catch err
    obj.percent_setpoint = NaN;
end
obj.setpoint = NaN; % No longer know where it is
obj.locked = false;
obj.tuning = false;
if ~isempty(err)
    rethrow(err)
end

end

