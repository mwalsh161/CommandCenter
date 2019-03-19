function pass = test_voltage_limit(obj,channel)
%this method tests if the  limit is set correctly. It measures the
%voltage when the device is turned on. This voltage should not exceed the established voltage limit. 

%expectedInput: 
%        -channel: which channel of the power supply to test

%expectedOutput: true or false indicating if the power supply is railing
%against the set voltage limit

assert(ischar(channel),'channel input must be a character')

obj.serial.setVoltageLimit(channel,obj.Volt_Limit)
voltage_limit = obj.serial.getVoltageLimit(channel);
obj.serial.on;
voltage = obj.serial.measureVoltage(channel);
delta = voltage_limit*0.1;
if voltage > 0
    if voltage<voltage_limit+delta && voltage>voltage_limit-delta
        %test if the voltage measured is within +/- 10 percent of the set voltage
        %limit. If so then it passes
        pass = true;
    else
        pass = false;
    end
    if voltage < voltage_limit-delta
        warning(['Your measured voltage is lower than the set voltage limit.' ...
            ' Consider increasing your applied current or checking your circuit.'])
    end
else
    if voltage<-voltage_limit+delta && voltage>-voltage_limit-delta
        %test if the voltage measured is within +/- 10 percent of the set voltage
        %limit. If so then it passes
        pass = true;
    else
        pass = false;
    end
    if voltage > -voltage_limit+delta
        warning(['Your measured voltage is higher than the set negative voltage limit.' ...
            ' Consider increasing your applied current or checking your circuit.'])
    end
end
obj.serial.off;

end
