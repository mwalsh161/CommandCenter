classdef CalibrateLaserDelay  < Modules.Experiment
    
    properties
        f  %figure where apds counts are streamed to
        ax  %axis for matlabs data
        delay
        ontime
        abort_request = false;
        data;
        pulseblaster
        Ni
        image_axes %figure for data
        laser
        prefs = {'ip','nidaqName','SNR','apdLine','apdBin','maxDelay',...
            'maxCounts','repeatMax','stepSize'}
    end
    
    properties(SetObservable)
        ip = 'localhost';
        nidaqName = 'dev1'
        SNR = 100;% time will be increased until this SNR is reached
        apdLine = 3; %indexed from 1
        apdBin = 0.1; %binning time to collect counts
        maxDelay = 1; %maximum expeceted delay in us
        maxCounts = 1e4;
        repeatMax = 1e6;
        stepSize = 10; %step in ns for each datapoint
    end
    
    methods(Access=private)
        function obj = CalibrateLaserDelay()
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Calibration.CalibrateLaserDelay();
            end
            obj = Object;
        end
        obj.loadPrefs;
    end
    
    methods
        function run(obj,statusH,managers,ax)
            
            obj.abort_request=0;
            %%
            
            modules = managers.Sources.modules;
            obj.laser = obj.find_active_module(modules,'Laser532_PB');
            obj.laser.off;
            %%
            
            obj.Ni = Drivers.NIDAQ.dev.instance(obj.nidaqName);
            obj.Ni.ClearAllTasks;
            %%
            
            obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.ip);
            
            %%
            obj.get_image_axis_handle;
            obj.ax = ax;
            [obj.delay, obj.ontime] = obj.CalibrateDelay();
            
        end
        
        function module_handle = find_active_module(obj,modules,active_class_to_find)
            module_handle = [];
            for index=1:length(modules)
                class_name=class(modules{index});
                num_levels=strsplit(class_name,'.');
                truth_table=contains(num_levels,active_class_to_find);
                if sum(truth_table)>0
                    module_handle=modules{index};
                end
            end
            assert(~isempty(module_handle)&& isvalid(module_handle),['No actice class under ',active_class_to_find,' in CommandCenter as a source!'])
        end
        
        function get_image_axis_handle(obj)
            hObj = findall(0,'name','CommandCenter');
            handles = guidata(hObj);
            obj.image_axes = handles.axImage;
        end
        
        function abort(obj)
            obj.abort_request = true;
            obj.Ni.ClearAllTasks;
            obj.laser.off;
            delete(obj.f)
        end
        
        function data = GetData(obj,~,~)
            data.delay = obj.delay;
            data.ontime = obj.ontime;
        end
    end
end