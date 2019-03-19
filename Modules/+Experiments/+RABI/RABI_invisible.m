classdef RABI_invisible  < Modules.Experiment 
    
    properties
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
    end
    
    properties (SetObservable)
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
    end
    
    properties(Constant)
       %Minimum duration that the pulseblaster can handle.
        minDuration = 14; %nanoseconds
    end
    
    methods
        function obj = RABI_invisible()
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
                Object = Experiments.RABI.RABI_invisible();
            end
            obj = Object;
        end
        
        function module_handle=find_active_module(modules,active_class_to_find)
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
    end
    
    methods (Access=private)
        function [laser_hw,APD_hw,MW_switch_hw]=determine_PB_hardware_handles(obj)
            error('Not Implemented')
        end
    end
    
    methods (Access=protected)
        
        function time_list = determine_time_list(obj)
           
            time_list = linspace(obj.start_time,obj.stop_time,obj.number_points);
         
        end
        
        function intitialize_SG(obj,managers)
            %load in SG
            modules = managers.Sources.modules;
            obj.RF = obj.find_active_module(modules,'Signal_Generator');
            obj.RF.serial.reset;
            obj.RF.serial.setUnitPower;
            obj.RF.MWPower = obj.RF_power;
            obj.RF.MWFrequency = obj.CW_freq;
            obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.RF.ip);
        end
        
        function initialize_laser(obj,managers)
            modules = managers.Sources.modules;
            Laser_handle=obj.find_active_module(modules,'Green_532Laser');
            obj.Laser =Laser_handle;
            obj.Laser.off;
        end
        
        function initialize_data_acquisition_device(obj,managers)
            error('Have not implemented how you will acquire data. See method named initialize_data_acquisition_device!')
        end
        
    end
    
    methods
        
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
        
        function update_time_step(obj,~,~)
            time_step_size = (obj.stop_time-obj.start_time)/obj.number_points;
            if ~isequal(time_step_size,obj.time_step_size)
                obj.time_step_size = time_step_size;
            end
        end
        
        function set.laser_read_time(obj,val)
            assert(isnumeric(val),'laser_read_time must be of dataType numeric.')
            assert(val>obj.minDuration*1000,['laser_read_time must be greater than the ',num2str(obj.minDuration*1000)])
            if val > 400
                button = questdlg('Are you sure you want to set laser duration to greater than 400 ns?');
                if strcmp(button,'Yes')
                    obj.laser_read_time = val;
                end
            else
                obj.laser_read_time = val;
            end
        end
        
        function run(obj,statusH,managers,ax)
            obj.abort_request = false;
            obj.ax = ax;
            obj.initialize_experiment(obj,managers)
            obj.start_experiment(statusH,managers,ax);
            obj.RF.serial.reset;
            obj.Laser.off;
        end
        
        function initialize_experiment(obj,statusH,managers,ax)
            obj.intitialize_SG(managers);
            obj.initialize_laser(managers)
            obj.initialize_data_acquisition_device(managers);
        end
        
        function start_experiment(statusH,managers,ax)
            error('start_experiment not implemented.')
        end
        
        function plot_data(obj,ax,index,cur_nAverage)
            error('plot data is not implemented!')
        end
        
        function data = GetData(obj,~,~)
            data.RF.handle = obj.RF;
            data.RF.amp = obj.RF_power;
            data.RF.freq =obj.CW_freq;
            data.averages = obj.nAverages;
            data.PB.time_list = obj.determine_time_list;
            data.PB.laser_on_time = obj.laser_read_time;
            data.sequence = obj.sequence;
            data.Integration_time = obj.Integration_time;
            data.reInitializationTime = obj.reInitializationTime;
            data.padding = obj.padding;
        end
        
        function abort(obj)
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