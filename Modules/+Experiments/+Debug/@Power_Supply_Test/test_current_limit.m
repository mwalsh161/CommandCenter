function pass = test_current_limit(obj,channel)
%this method tests if the current limit is set correctly. It measures the
%current when the device is turned on. This current should not exceed the established current limit. 

%expectedInput: 
%        -channel: which channel of the power supply to test

%expectedOutput: true or false indicating if the power supply is railing
%against the set current limit

assert(ischar(channel),'channel input must be a character')

obj.serial.setCurrentLimit(channel,obj.Current_Limit)
current_limit = obj.serial.getCurrentLimit(channel);
obj.serial.on;
current = obj.serial.measureCurrent(channel);
delta = current_limit*0.1;
if current > 0
    if current<current_limit+delta && current>current_limit-delta
        %test if the current measured is within +/- 10 percent of the set current
        %limit. If so then it passes
        pass = true;
    else
        pass = false;
    end
    if current < current_limit-delta
        warning(['Your measured current is lower than the set current limit.' ...
            ' Consider increasing your applied voltage or checking your circuit.'])
    end
else
    if current<-current_limit+delta && current>-current_limit-delta
        %test if the current measured is within +/- 10 percent of the set current
        %limit. If so then it passes
        pass = true;
    else
        pass = false;
    end
    if current > -current_limit+delta
        warning(['Your measured current is higher than the set negative current limit.' ...
            ' Consider increasing your applied voltage or checking your circuit.'])
    end
end
obj.serial.off;

end
