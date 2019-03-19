classdef ODMR_invisible  < Modules.Experiment 
    
    properties
        data;
        listeners; %listerners for handling interdepedancy of properties
        abort_request = false;  % Request flag for abort
        RF   % RF generator handle
        Ni   % NIDAQ
        stage
        laser
        pulseblaster
        ax %axis to data axis
    end
    
    properties(SetObservable)
        RF_power = -30; %in dBm
        nAverages = 5;
        start_freq = 2.84e9;
        stop_freq = 2.9e9;
        number_points = 60; %number of frequency points desired
        freq_step_size = 1e6; %modification of this changes number_points
        dummy_pb_line = 14;  %dummy channel used for dead time during programming the sequence
        waitTimeSGswitch_us = 5000; %time to wait for SG to step in freq after triggering
    end
    
    methods
        function obj = ODMR_invisible()
            obj.listeners = addlistener(obj,'start_freq','PostSet',@obj.update_freq_step);
            obj.listeners(end+1) = addlistener(obj,'stop_freq','PostSet',@obj.update_freq_step);
            obj.listeners(end+1) = addlistener(obj,'number_points','PostSet',@obj.update_freq_step);
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.ODMR.ODMR_invisible();
            end
            obj = Object;
        end
    end
    
    methods (Access=protected)
        function freq_list=determine_freq_list(obj)
            error('Not Implemented')
        end
        
        function intitialize_SG(obj,managers)
            %load in SG
            modules = managers.Sources.modules;
            obj.RF = obj.find_active_module(modules,'Signal_Generator');
%             obj.RF.serial.reset;
            obj.RF.serial.setUnitPower;
            freq_list = obj.determine_freq_list();
            switch obj.trig_type
                case 'Internal'
                    obj.RF.MWPower = obj.RF_power;
                    obj.RF.MWFrequency = freq_list(1);
                case [{'DAQ'},{'PulseBlaster'}]
                    power_list=obj.RF_power.*ones(1,length(freq_list));
                    obj.RF.serial.program_list(freq_list,power_list)
                    obj.RF.off;
                otherwise
                    error('Trigger type not recognized.')
            end
        end
        
        function initialize_laser(obj,managers)
            modules = managers.Sources.modules;
            obj.laser = obj.find_active_module(modules,'Green_532Laser');
            obj.laser.off;
        end
        
        function initialize_data_acquisition_device(obj,managers)
            error('Have not implemented how you will acquire data. See method named initialize_data_acquisition_device!')
        end
        
        function s=setup_PB_sequence(obj)
            error('Not Implemented')
        end
        
        function plot_data(obj,ax,index,cur_nAverage)
            error('Not Implemented')
        end
        
        function [laser_hw,APD_hw,MW_switch_hw,SG_trig_hw]=determine_PB_hardware_handles(obj)
            error('Not Implemented')
        end
    end
    
    methods

        function set.start_freq(obj,val)
            assert(isnumeric(val),'start_freq must be a of type numeric.')
            assert(val>0,'start_freq must be positive.')
            assert(~logical(mod(val,1)),'start_freq must be an integer.')
            if ~isequal(val,obj.start_freq)
                obj.start_freq = val;
            end
        end
        
        function set.stop_freq(obj,val)
            assert(isnumeric(val),'stop_freq must be a of type numeric.')
            assert(val>0,'stop_freq must be positive.')
            assert(~logical(mod(val,1)),'stop_freq must be an integer.')
            if ~isequal(val,obj.stop_freq)
                obj.stop_freq = val;
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
        
        function set.freq_step_size(obj,val)
            assert(isnumeric(val),'freq_step_size must be a of type numeric.')
            assert(val>0,'freq_step_size must be positive.')
            try
                obj.number_points = (obj.stop_freq-obj.start_freq)./(val);
            catch err
                warning('Error when attempting to change freq_step_size')
                error(err.message)
            end
            obj.freq_step_size = val;
        end
        
        function update_freq_step(obj,~,~)
            step_size = (obj.stop_freq-obj.start_freq)/obj.number_points;
            if ~isequal(step_size,obj.freq_step_size)
                obj.freq_step_size = step_size;
            end
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
        
        function start_experiment_CW(obj,statusH,managers,ax)
            error('CW method not implemented!')
        end
        
        function start_experiment_EXT(obj,statusH,managers,ax)
            error('EXT method for ODMR not implemented!')
        end
        
        function run(obj,statusH,managers,ax)
            obj.abort_request=0;
            obj.ax = ax;
            obj.initialize_experiment(managers)
            switch obj.trig_type
                case 'Internal'
                    obj.start_experiment_CW
                case {'DAQ'}
                    error('DAQ triggering not implemented!')
                case {'PulseBlaster'}
                    obj.start_experiment_Ext_PB
                otherwise
                    error('Trigger type not recognized.')
            end
%             obj.RF.serial.reset;
            obj.laser.off;
        end
        
        function initialize_experiment(obj,managers)
            obj.intitialize_SG(managers);
            obj.initialize_laser(managers)
            obj.initialize_data_acquisition_device(managers);
        end
        
        function abort(obj)
            obj.abort_request = true;
%             obj.RF.off;
%             obj.RF.serial.reset;
            obj.laser.off;
        end
        
        function delete(obj)
            delete(obj.listeners);
        end
        
        function data = GetData(obj,~,~)
            data.RF.freq = obj.determine_freq_list();
            data.RF.amp = obj.RF_power;
            data.RF.freq_step_size  = obj.freq_step_size;
            data.averages = obj.nAverages;
        end
        
        
    end
    
end