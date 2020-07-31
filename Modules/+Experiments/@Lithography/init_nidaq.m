function init_nidaq(obj,voltages)
% Make the clock an open collector
obj.task.PulseTrain = obj.ni.CreateTask('LithoPulseTrain');
numpoints = size(voltages,1);
% We want 1/2 the dwell time, since our new trigger clock is
% forced to be half the frequency of the pulse train.
freq = 1/(obj.dwell*1e-3);  % Use dwell time in ms to get Hz
try
    obj.task.PulseTrain.ConfigurePulseTrainOut(obj.trigger,freq,numpoints);
catch err
    obj.task.PulseTrain.Clear
    rethrow(err)
end
% Set Voltage out to galvos
obj.task.Galvos = obj.ni.CreateTask('LithoPositions');
try
    obj.task.Galvos.ConfigureVoltageOutClkTiming({obj.x,obj.y,obj.z},voltages,obj.task.PulseTrain);
catch err
    obj.task.PulseTrain.Clear
    obj.task.Galvos.Clear
    rethrow(err)
end
end