function run(obj,statusH,managers,ax)
try
    %% initialize some values
    obj.ax = ax;
    obj.abort_request = false;
    %% get laser
    modules = managers.Sources.modules;
    obj.laser = obj.find_active_module(modules,'Green_532Laser');
    obj.laser.off;
    %% set the control voltages
    modules = managers.Sources.modules;
    obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
    obj.ChipControl.off;
    obj.ChipControl.DriverBias = obj.DriverBias;
    obj.ChipControl.CTIA_Bias = obj.PhotoDiodeBias;  %temporary
    %turn on all control channels
    obj.ChipControl.on;
    %%
    obj.Ni = Drivers.NIDAQ.dev.instance('dev1');
    obj.data = [];
    obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,0);
    %% run ODMR experiment
    obj.start_experiment_CW;
catch error
    obj.logger.log(error.message);
    obj.abort;
end
end