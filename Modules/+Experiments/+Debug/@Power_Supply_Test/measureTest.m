function pass = measureTest(obj,channel,setting,setValue,measureValue)
%this method tests a measurement. 

%expectedInput: 
%        -channel: which channel of the power supply to test
%        -setting: current or voltage
%        -setValue: value to be set
%        -measureValue: value to be measured

%expectedOutput: true or false indicating if the power supply set the
%correct value
%% 

assert(ischar(channel),'channel input must be a character')

if strcmpi(setting,'current')
    obj.serial.setCurrent(channel,setValue);
    obj.serial.on;
    Value = obj.serial.measureCurrent(channel);
elseif strcmpi(setting,'voltage')
    obj.serial.setVoltage(channel,setValue);
    obj.serial.on;
    Value = obj.serial.measureVoltage(channel);
    
else
    error('not supported setting. Setting input can be voltage or current.')
end

obj.serial.off;
delta = measureValue*0.1;
if Value>0
    if Value<measureValue+delta && Value>measureValue-delta
        %test if the value measured is within +/- 10 percent of the set
        %value. If so then it passes.
        pass = true;
    else
        pass = false;
    end
else
    if Value>measureValue+delta && Value<measureValue-delta
        %test if the value measured is within +/- 10 percent of the set
        %value. If so then it passes.
        pass = true;
    else
        pass = false;
    end
end

end
