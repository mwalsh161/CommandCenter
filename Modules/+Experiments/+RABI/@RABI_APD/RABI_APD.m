classdef RABI_APD <  Modules.Experiment
    
    properties (SetObservable)
        APD_PB_line = 3; %indexed from 1
        disp_mode = {'verbose','fast'};
        CW_freq = 2.87e9;
        RF_power = -30; %dbm
        nAverages = 5;
        Integration_time = 30;  % time for each data point is this value times nAverages (in milliseconds)
        laser_read_time = 300; %ns
        start_time = 14; %ns
        stop_time = 1014; %ns
        number_points = 100;
        time_step_size = 10;%ns
        reInitializationTime = 1000; %ns ; time taken to reiniatilze the NV to zero after measurement
        padding = 1000; %ns padding between items in the pulse sequence
        laserDelay = 810; %ns
    end
    
    properties(Constant)
        %Minimum duration that the pulseblaster can handle.
        minDuration = 14; %nanoseconds
    end
    
    properties
        f  %data figure that you stream to
        data;
        listeners;
        abort_request = false;  % Request flag for abort
        ax
        RF   % RF generator handle
        Ni   % NIDAQ
        stage
        Laser
        pulseblaster
        sequence
        MW_on_time
        prefs = {'CW_freq','RF_power','nAverages','Integration_time'...
            ,'laser_read_time','start_time','stop_time','number_points'...
            'time_step_size','APD_PB_line','disp_mode','reInitializationTime','padding','laserDelay'}
    end
    
    methods(Access=private)
        function obj = RABI_APD
            obj.loadPrefs;
            obj.listeners = addlistener(obj,'start_time','PostSet',@obj.update_time_step);
            obj.listeners(end+1) = addlistener(obj,'stop_time','PostSet',@obj.update_time_step);
            obj.listeners(end+1) = addlistener(obj,'number_points','PostSet',@obj.update_time_step);
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.RABI.RABI_APD();
            end
            obj = Object;
        end
    end
    
    methods(Access=protected)
        
        function module_handle = find_active_module(obj,modules,active_class_to_find)
            module_handle=[];
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
        
        function update_time_step(obj,~,~)
            time_step_size = (obj.stop_time-obj.start_time)/obj.number_points;
            if ~isequal(time_step_size,obj.time_step_size)
                obj.time_step_size = time_step_size;
            end
        end
        
    end
    
    methods
        
        function set.laser_read_time(obj,val)
            assert(isnumeric(val),'laser_read_time must be of dataType numeric.')
            assert(val>obj.minDuration,['laser_read_time must be greater than the ',num2str(obj.minDuration)])
            obj.laser_read_time = val;
        end
        
        function set.start_time(obj,val)
            assert(isnumeric(val),'start_time must be a of type numeric.')
            assert(val>=obj.minDuration,sprintf('start_time must be greater than %d.',obj.minDuration))
            if ~isequal(val,obj.start_time)
                obj.start_time = val;
            end
        end
        
        function set.stop_time(obj,val)
            assert(isnumeric(val),'stop_time must be a of type numeric.')
            assert(val>obj.minDuration,sprintf('stop_time must be greater than %d.',obj.minDuration))
            if ~isequal(val,obj.stop_time)
                obj.stop_time = val;
            end
        end
        
        function set.number_points(obj,val)
            assert(isnumeric(val),'number_points must be a of type numeric.')
            assert(val>0,'number_points must be positive.')
            assert(~logical(mod(val,1)),'number_points must be an integer.')
            if ~isequal(val,obj.number_points)
                obj.number_points = val;
            end
        end
        
        function set.time_step_size(obj,val)
            assert(isnumeric(val),'time_step_size must be a of type numeric.')
            assert(val>0,'time_step_size must be positive.')
            try
                obj.number_points = (obj.stop_time-obj.start_time)./(val);
            catch err
                warning('Error when attempting to change time_step_size')
                error(err.message)
            end
            obj.time_step_size = val;
        end
        
        
        function abort(obj)
            
            delete(obj.f);
            obj.Ni.ClearAllTasks;
            
            obj.abort_request = true;
            obj.RF.off;
            obj.RF.serial.reset;
            obj.Laser.off;
            
        end
        
        function delete(obj)
            delete(obj.listeners)
        end
        
    end
    
end

    
