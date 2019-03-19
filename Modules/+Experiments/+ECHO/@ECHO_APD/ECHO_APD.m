classdef ECHO_APD <  Experiments.ECHO.ECHO_invisible
    
    properties (SetObservable)
        APD_PB_line = 3; %indexed from 1
        disp_mode = {'verbose','fast'};
    end
    
    properties
      f  %data figure that you stream to
      prefs = {'CW_freq','RF_power','nAverages','Integration_time'...
          ,'laser_read_time','piTime','start_time','stop_time','number_points'...
          'time_step_size','APD_PB_line','disp_mode','padding','reInitializationTime'}    
    end
    
    methods(Access=private)
        function obj = ECHO_APD
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.ECHO.ECHO_APD();
            end
            obj = Object;            
        end
    end
    
    methods(Access=protected)
        
        function plot_data(obj)
            time_list = obj.determine_time_list();
            errorbar(time_list,obj.data.contrast_vector,obj.data.error_vector,'parent',obj.ax);
            xlim(obj.ax,time_list([1,end]));
            xlabel(obj.ax,'Microwave on Time (ns)')
            ylabel(obj.ax,'Normalized Fluorescence')
        end
        
        function [laser_hw,APD_hw,MW_switch_hw] = determine_PB_hardware_handles(obj)
            laser_hw = obj.Laser.PBline-1;
            
            APD_hw = obj.APD_PB_line-1;
            
            MW_switch_hw = obj.RF.MW_switch_PB_line-1;
        end
        
        function initialize_data_acquisition_device(obj,~)
            obj.Ni = Drivers.NIDAQ.dev.instance('Dev1');
            obj.Ni.ClearAllTasks;
            obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.RF.ip);
        end
        
    end
    methods
        
        function abort(obj)
            delete(obj.f);
            obj.Ni.ClearAllTasks;
            abort@Experiments.ECHO.ECHO_invisible(obj);
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data.APDcounts = obj.data;
                GetData@Experiments.ECHO.ECHO_invisible(obj);
            else
                data = [];
            end
        end
    end
end