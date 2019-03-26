classdef ODMR_DAQ_Pulsed < Experiments.CMOS.CMOS_invisible
    
    properties
        Pulseblaster
        laser
        listeners
        data;
        abort_request = false;  % Request flag for abort
        Ni   % NIDAQ
        ChipControl
        RF
        prefs = {'nAverages','start_freq','stop_freq','number_points','normFreq'...
            'freq_step_size','waitSGSwitch','deviceName',...
            'AnalogChannelName','DigitalChannelName','CounterSyncName',...
            'MinVoltage','MaxVoltage','LaserOnTime','MWOnTime','DelayTime'...
            'dummyTime','MWPulsed','DAQSamplingFrequency','Nsamples','IntegrationTime'}
    end
    
    properties(SetObservable)
        nAverages = 5;
        start_freq = 2.84e9;
        stop_freq = 2.9e9;
        number_points = 61; %number of frequency points desired
        normFreq = 2e9;
        freq_step_size = 1e6;
        waitSGSwitch = 1; %time to wait for SG to step in freq after triggering
        deviceName = 'dev1';
        AnalogChannelName = 'AI';
        DigitalChannelName = 'DI';
        CounterSyncName = 'CounterSync';
        MinVoltage = 0; %Volts
        MaxVoltage = 1; %Volts
        LaserOnTime = 1000; %us
        MWOnTime = 1000; %us
        DelayTime = 1000; %us
        dummyTime = 1; %us
        MWPulsed = {'yes','no','off'}
        DAQSamplingFrequency = 1/(0.9e-6);%in Hz
        Nsamples = 1e6;
        IntegrationTime = 1; %seconds
    end
    
    methods(Access=private)
        function obj = ODMR_DAQ_Pulsed()
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
                Object = Experiments.CMOS.Off_Chip.ODMR.ODMR_DAQ_Pulsed();
            end
            obj = Object;
        end
    end
    
    methods(Access=protected)
        
        function freq_list=determine_freq_list(obj)
            freq_list1 = linspace(obj.start_freq,obj.stop_freq,obj.number_points);
            freq_list = zeros(1,2*obj.number_points);
            freq_list(1:2:end) = freq_list1;
            freq_list(2:2:end) = obj.normFreq;
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
            
            data.data = obj.data;
            
            data.DAQ.deviceName = obj.deviceName;
            data.DAQ.AnalogChannelName = obj.AnalogChannelName;
            data.DAQ.DigitalChannelName = obj.DigitalChannelName;
            data.DAQ.CounterSyncName = obj.CounterSyncName;
            data.DAQ.DAQSamplingFrequency = obj.DAQSamplingFrequency;
            data.DAQ.Nsamples = obj.Nsamples;

            data.DAQ.MinVoltage = obj.MinVoltage; %Volts
            data.DAQ.MaxVoltage = obj.MaxVoltage; %Volts
            
            data.RF.freq_list = obj.determine_freq_list();
            
            data.ChipControl.VDD_VCO = obj.ChipControl.VDD_VCO;
            data.ChipControl.VDD_Driver = obj.ChipControl.VDD_Driver;
            data.ChipControl.DriverCore = obj.ChipControl.DriverCore;
            data.ChipControl.DriverBoundary = obj.ChipControl.DriverBoundary;
            data.ChipControl.VDDCP = obj.ChipControl.VDDCP;
            data.ChipControl.VDDPLL = obj.ChipControl.VDDPLL;
            
            data.PulseBlaster.LaserOnTime = obj.LaserOnTime;
            data.PulseBlaster.MWTime = obj.MWOnTime;
            data.PulseBlaster.DelayTime = obj.DelayTime;
            data.PulseBlaster.dummyTime = obj.dummyTime;
            data.PulseBlaster.MWPulsed = obj.MWPulsed;
            data.PulseBlaster.IntegrationTime = obj.IntegrationTime;

        end
        
    end
end