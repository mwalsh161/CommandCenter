function pass = bipolar_limit_setting(obj,channel,setting,upperbound_limit,lowerbound_limit)
%this method tests if the current limit is set correctly.It gets the 
%current limit that was set. 

%expectedInput: 
%        -channel: which channel of the power supply to test
%        -setting: current or voltage
%        -upperbound_limit: upper bound limit to set
%        -lowerbound_limit: lower bound limit to set

%expectedOutput: true or false indicating if the power supply set the
%current or voltage limit correctly

assert(ischar(channel),'channel input must be a character')

if strcmpi(setting,'current')
    obj.serial.setCurrentLimit(channel,[upperbound_limit,lowerbound_limit])
    [upperbound,lowerbound] = obj.serial.getCurrentLimit(channel);
    if (upperbound == upperbound_limit) && (lowerbound == lowerbound_limit)
        pass = true;
    else
        pass = false;
    end
elseif strcmpi(setting,'voltage')
    obj.serial.setVoltageLimit(channel,[upperbound_limit,lowerbound_limit])
    [upperbound,lowerbound] = obj.serial.getVoltageLimit(channel);
    if (upperbound == upperbound_limit) && (lowerbound == lowerbound_limit)
        pass = true;
    else
        pass = false;
    end
else
    error('not supported setting. Setting input can be voltage or current.')
end
