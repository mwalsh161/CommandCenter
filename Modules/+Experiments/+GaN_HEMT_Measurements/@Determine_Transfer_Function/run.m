function run(obj,statusH,managers,ax)
obj.abort_request = false;
obj.data = [];
obj.ax = ax;
obj.initialize_experiment(managers)  %get initialize drain, gate and measurement device
voltage_list = linspace(obj.start_gate_voltage,obj.stop_gate_voltage,obj.number_points);
%% turn on the gate and drain supply and set their settings
obj.gateSupply.Channel = obj.gateChannel;
obj.gateSupply.Source_Mode = 'Voltage';
obj.gateSupply.Current_Limit = obj.gateCurrentLimit;
obj.gateSupply.Voltage = voltage_list(1);
obj.gateSupply.on;
pause(1)

obj.drainSupply.Channel = obj.drainChannel;
obj.drainSupply.Source_Mode = 'Voltage';
obj.drainSupply.Current_Limit = obj.drainCurrentLimit;
obj.drainSupply.Voltage = obj.Drain_Voltage;
obj.drainSupply.on;
pause(1)

obj.measureDevice.on;

%% iterate through the voltage list and record current flowing through device
for index=1:length(voltage_list)
    assert(~obj.abort_request,'User aborted');
    obj.gateSupply.Voltage = voltage_list(index);%set gate voltage
    pause(1)
    obj.data.drainCurrent(index) = obj.measureDevice.measureCurrent(obj.multimeterChannel);
    %expect drainCurrent to be in Amps
    obj.plot_data(index)
end
%% turn off powersupplies and collect all data

obj.gateSupply.off;
obj.drainSupply.off;
obj.measureDevice.off;
obj.data.gate_voltage_list = voltage_list;

end