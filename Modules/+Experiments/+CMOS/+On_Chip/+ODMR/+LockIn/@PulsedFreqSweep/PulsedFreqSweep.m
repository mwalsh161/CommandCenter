classdef PulsedFreqSweep < Experiments.CMOS.CMOS_invisible 
    
    properties
        Photodiode
        pulseblaster
        listeners
        RF
        opticalPower
        powerMeter
        data;
        abort_request = false;  % Request flag for abort
        laser
        ax %axis to data axis
        ChipControl
        LockIn
        prefs = {'nAverages','start_freq','stop_freq','number_points','freq_step_size'...
            'waitSGSwitch','MWonTime','LaseronTime','ExtRefTrigImp','CurrentGain','padding'...
            'Sensitivity','DetectionHarmonic','TimeConstant','Slope','Sync','GroundingType'...
            'Channel','ChannelMode','DataChanel1','PowerMeter',...
            'Mode','FMChannel','deadTime'}      
    end
 
    properties(SetObservable)
        nAverages = 5;
        start_freq = 2.84e9;
        stop_freq = 2.9e9;
        number_points = 61; %number of frequency points desired
        freq_step_size = 1e6;
        waitSGSwitch = 1; %time to wait for SG to step in freq after triggering
        MWonTime = 1000; %time in ns
        LaseronTime = 500; %ns
        ExtRefTrigImp = {'50ohms','1meg'}
        CurrentGain = {'1uA','10nA'}
        Sensitivity = 0;
        DetectionHarmonic = 1;
        TimeConstant = 8;
        Slope = {'6','12','18','24'}
        Sync = {'on','off'}
        GroundingType = {'ground','float'}
        Channel = {'1','2'}
        ChannelMode = {'ro','xy'}
        DataChanel1 = {'1','2','3','4'}
        PowerMeter = {'Yes','No'}
        AutoScale = {'Yes','No'}
        Mode = {'voltage','current'}
        FMChannel = 1;
        padding = 1000; %ns 
        deadTime = 100; %ns
    end
    
    properties(Constant)
       %Minimum duration that the pulseblaster can handle.
        minDuration = 14; %nanoseconds
    end
    
    methods(Access=private)
        function obj = PulsedFreqSweep()
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
                Object = Experiments.CMOS.On_Chip.ODMR.LockIn.PulsedFreqSweep();
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
            
            data.data.dataVector = obj.data.dataVector;
            data.data.dataVectorError = obj.data.dataVectorError;
            data.data.raw_data = obj.data.raw_data;
            
            data.PowerMeter.opticalPower = obj.opticalPower;
            
            data.RF.freq_list = obj.determine_freq_list();
            data.RF.MWonTime = obj.MWonTime;
            
            data.ChipControl = obj.ChipControl;
           
            data.LockIn.ExtRefTrigImp = obj.ExtRefTrigImp;
            data.LockIn.CurrentGain = obj.CurrentGain;
            data.LockIn.Sensitivity = obj.Sensitivity;
            data.LockIn.DetectionHarmonic = obj.DetectionHarmonic;
            data.LockIn.TimeConstant = obj.TimeConstant;
            data.LockIn.Slope = obj.Slope;
            data.LockIn.Sync = obj.Sync;
            data.LockIn.GroundingType = obj.GroundingType;
            data.LockIn.Channel = obj.Channel;
            data.LockIn.ChannelMode = obj.ChannelMode;
            data.LockIn.Mode = obj.Mode;
            data.LockIn.ENBW = obj.LockIn.getNoiseBandwidth;
            data.LockIn.inputRange =obj.LockIn.getVoltageInputRange;
        end
        
    end
end