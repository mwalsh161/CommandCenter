function run(obj,statusH,managers,ax)
            try
                %% initialize some values
                obj.ax = ax;
                obj.abort_request = false;
                
                hObj = findall(0,'name','CommandCenter');
                handles = guidata(hObj);
                obj.axImage = handles.axImage;
            
                 %% get laser
                modules = managers.Sources.modules;
                obj.laser = obj.find_active_module(modules,'Green_532Laser');
                obj.laser.off;
                %% set the control voltages
                modules = managers.Sources.modules;
                obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
                obj.ChipControl.off;
                obj.ChipControl.DriverBias = obj.DriverBias;
                %turn on all control channels
                obj.ChipControl.on;
                %%
                obj.Ni = Drivers.NIDAQ.dev.instance('dev1');
                VoltageLimIn = [0,obj.MaxExpectedVoltage];
                VoltageLimOut = [0,obj.OutputVoltage];
                obj.determineTriggerVector;
                obj.CTIA = Triggered_CTIA_Measurement.instance(obj.determineTrigNum,obj.triggerVector,VoltageLimIn,VoltageLimOut);
                obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.laser.ip);
                obj.data = [];
                obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,0);
               %% run ODMR experiment
                obj.start_experiment_CW;
            catch error
                obj.logger.log(error.message);
                obj.abort;
            end
        end