classdef ODMR_DAQ_NoPulsed < Experiments.CMOS.CMOS_invisible 
    
    properties
        listeners
        data;
        abort_request = false;  % Request flag for abort
        Ni   % NIDAQ
        ChipControl
        RF
        prefs = {'nAverages','start_freq','stop_freq','number_points',...
            'freq_step_size','IntegrationTime','waitSGSwitch','deviceName',...
           'channelName','MinVoltage','MaxVoltage'}
    end
 
   properties(SetObservable)
        nAverages = 5;
        start_freq = 2.84e9;
        stop_freq = 2.9e9;
        number_points = 61; %number of frequency points desired
        freq_step_size = 1e6;
        waitSGSwitch = 1; %time to wait for SG to step in freq after triggering
        deviceName = 'dev1';
        channelName = 'AI8';
        IntegrationTime = 10; %milliseconds
        MinVoltage = 0; %volts
        MaxVoltage = 1; %volts
    end
    
    methods(Access=private)
        function obj = ODMR_DAQ_NoPulsed()
            obj.loadPrefs;
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
                Object = Experiments.CMOS.Off_Chip.ODMR.ODMR_DAQ_NoPulsed();
            end
            obj = Object;
        end
    end
    
    methods(Access=protected)
        
        function freq_list=determine_freq_list(obj)
            freq_list = linspace(obj.start_freq,obj.stop_freq,obj.number_points);
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
                obj.number_points = numel(obj.start_freq:val:obj.stop_freq);
            catch err
                warning('Error when attempting to change freq_step_size')
                error(err.message)
            end
            if val == mean(diff(obj.determine_freq_list))
                obj.freq_step_size = val;
            end
        end
        
        function update_freq_step(obj,~,~)
            step_size = mean(diff(obj.determine_freq_list));
            if ~isequal(step_size,obj.freq_step_size)
                obj.freq_step_size = step_size;
            end
        end
        
        function delete(obj)
            delete(obj.listeners);
        end
        
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            data = [];
            
            data.averages = obj.nAverages;
            data.waitSGSwitch = obj.waitSGSwitch;
            data.IntegrationTime = obj.IntegrationTime;
            
            data.data = obj.data;
            
            data.DAQ.deviceName = obj.deviceName;
            data.DAQ.channelName = obj.channelName;
            
            data.RF.freq_list = obj.determine_freq_list();
            
            data.ChipControl.VDD_VCO = obj.ChipControl.VDD_VCO;
            data.ChipControl.VDD_Driver = obj.ChipControl.VDD_Driver;
            data.ChipControl.DriverCore = obj.ChipControl.DriverCore;
            data.ChipControl.DriverBoundary = obj.ChipControl.DriverBoundary;
            data.ChipControl.VDDCP = obj.ChipControl.VDDCP;
            data.ChipControl.VDDPLL = obj.ChipControl.VDDPLL;

        end
        
    end
end