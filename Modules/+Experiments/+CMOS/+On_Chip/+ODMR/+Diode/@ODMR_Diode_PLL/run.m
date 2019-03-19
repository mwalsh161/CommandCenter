function run(obj,statusH,managers,ax)
try
    %% 
    obj.trig_type = 'Internal';
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS');
    obj.ChipControl.off;
    obj.ChipControl.DriverBias = obj.DriverBias;
    %turn on all control channels
    obj.ChipControl.on;
    %% call the run method of the superclass
    
    run@Experiments.ODMR.ODMR_invisible(obj,statusH,managers,ax);
catch error
    obj.logger.log(error.message);
    obj.abort;
end
end