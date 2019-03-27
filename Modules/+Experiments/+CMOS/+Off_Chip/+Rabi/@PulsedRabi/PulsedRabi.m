classdef PulsedRabi < Experiments.CMOS.CMOS_invisible 
    
    properties
        Ni
        pulseblaster
        listeners
        RF
        data;
        abort_request = false;  % Request flag for abort
        laser
        ChipControl
        prefs = {'CW_freq','nAverages','start_time','stop_time','number_points','time_step_size'...
            'LaseronTime','deadTime','padding','dummyLine','deviceName','AnalogChannelName','CounterSyncName'...
            'MinVoltage','MaxVoltage','DAQSamplingFrequency','Nsamples','IntegrationTime','MWDummy'}    
    end
 
    properties(SetObservable)
        CW_freq = 2.697e9;
        nAverages = 5;
        start_time = 14; %ns
        stop_time = 1014; %ns
        number_points = 61; %number of frequency points desired
        time_step_size = 2; %ns
        LaseronTime = 500; %ns
        padding = 1000; %ns 
        deadTime = 100; %ns
        dummyLine = 10; %indexed from 1
        deviceName = 'dev1';
        AnalogChannelName = 'AI';    
        CounterSyncName = 'CounterSync';
        MinVoltage = 0; %Volts
        MaxVoltage = 1; %Volts
        DAQSamplingFrequency = 1/(0.9e-6);%in Hz
        Nsamples = 1e6; %
        IntegrationTime = 0.1; %seconds
        MWDummy = 13;
    end
    
    properties(Constant)
       %Minimum duration that the pulseblaster can handle.
        minDuration = 14; %nanoseconds
    end
    
    methods(Access=private)
        function obj = PulsedRabi()
            obj.loadPrefs;
            obj.listeners = addlistener(obj,'start_time','PostSet',@obj.update_time_step_size);
            obj.listeners(end+1) = addlistener(obj,'stop_time','PostSet',@obj.update_time_step_size);
            obj.listeners(end+1) = addlistener(obj,'number_points','PostSet',@obj.update_time_step_size);
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.CMOS.Off_Chip.Rabi.PulsedRabi();
            end
            obj = Object;
        end
    end
    
    methods(Access=protected)
        
        function time_list = determine_time_list(obj)
            time_list = linspace(obj.start_time,obj.stop_time,obj.number_points);
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
        
          function set.start_time(obj,val)
            assert(isnumeric(val),'start_time must be a of type numeric.')
            assert(val>0,'start_time must be positive.')
            assert(~logical(mod(val,1)),'start_time must be an integer.')
            if ~isequal(val,obj.start_time)
                obj.start_time = val;
            end
        end
        
        function set.stop_time(obj,val)
            assert(isnumeric(val),'stop_time must be a of type numeric.')
            assert(val>0,'stop_time must be positive.')
            assert(~logical(mod(val,1)),'stop_time must be an integer.')
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
                obj.number_points = numel(obj.start_time:val:obj.stop_time);
            catch err
                warning('Error when attempting to change time_step_size')
                error(err.message)
            end
            if val == mean(diff(obj.determine_time_list))
                obj.time_step_size = val;
            end
        end
        
        function update_time_step_size(obj,~,~)
            step_size = mean(diff(obj.determine_time_list));
            if ~isequal(step_size,obj.time_step_size)
                obj.time_step_size = step_size;
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
            
            data.data = obj.data;
            
            data.pulseblaster.timeList = obj.determine_time_list;
            data.pulseblaster.deadTime = obj.deadTime;
            data.pulseblaster.padding = obj.padding;
            data.pulseblaster.dummyLine = obj.dummyLine;
            data.pulseblaster.LaseronTime = obj.LaseronTime;
            data.pulseblaster.IntegrationTime = obj.IntegrationTime;
            data.pulseblaster.MWDummy = obj.MWDummy;

            data.RF.CW_freq = obj.CW_freq;
            
            data.ChipControl = obj.ChipControl;
            
            data.DAQ.deviceName = obj.deviceName;
            data.DAQ.channelName = obj.AnalogChannelName;
            data.DAQ.CounterSyncName = obj.CounterSyncName;
            data.DAQ.MinVoltage = obj.MinVoltage;
            data.DAQ.MaxVoltage = obj.MaxVoltage;
            data.DAQ.DAQSamplingFrequency = obj.DAQSamplingFrequency;
            data.DAQ.Nsamples = obj.Nsamples;

        end
    end
end