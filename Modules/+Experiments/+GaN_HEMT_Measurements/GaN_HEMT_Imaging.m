classdef GaN_HEMT_Imaging  < Modules.Experiment 
    
    properties(SetObservable)
        Exposure = 30;
        trig_type = {'Internal','DAQ','PulseBlaster'};
        Camera_PB_line = 3;
        Norm_freq = 2e9;
        Display_Data ={'Yes','No'};
        RF_power = -30; %in dBm
        nAverages = 5;
        start_freq = 2.84e9;
        stop_freq = 2.9e9;
        number_points = 60; %number of frequency points desired
        freq_step_size = 1e6; %modification of this changes number_points
        dummy_pb_line = 14;  %dummy channel used for dead time during programming the sequence
        waitTimeSGswitch_us = 5000; %time to wait for SG to step in freq after triggering
        Drain_Voltage = 0;
        Gate_Voltage = -5;
    end
    
    properties (Constant)
      gateCurrentLimit = -10e-6; %Amps-maximum current allowed to flow through the gate 
      drainCurrentLimit = 0.1; %Amps-maximum current allowed to flow through the drain
    end
    
    properties
        data
        gateSupply;
        drainSupply;
        Multimeter;
        
        listeners
        ODMR_handle
        prefs = {'Exposure','trig_type','Camera_PB_line','Norm_freq',...
            'Display_Data','RF_power','nAverages','start_freq','stop_freq',...
            'number_points','freq_step_size','dummy_pb_line',...
            'Drain_Voltage','Gate_Voltage','waitTimeSGswitch_us'}
    end
    
    methods(Access=private)
        function obj = GaN_HEMT_Imaging()
            obj.loadPrefs;
            obj.listeners = addlistener(obj,'start_freq','PostSet',@obj.update_freq_step);
            obj.listeners(end+1) = addlistener(obj,'stop_freq','PostSet',@obj.update_freq_step);
            obj.listeners(end+1) = addlistener(obj,'number_points','PostSet',@obj.update_freq_step);
            obj.ODMR_handle = Experiments.ODMR.ODMR_camera.instance; 

        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.GaN_HEMT_Measurements.GaN_HEMT_Imaging();
            end
            obj = Object;
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
        
        function run(obj,statusH,managers,ax)
            %% set this experiments settings to OMDR
            try
                obj.initializeProperties;
                %% grab sources that are instantiated
                modules = managers.Sources.modules;
                %% turn on the gate and drain supply and set their settings
                obj.gateSupply = obj.ODMR_handle.find_active_module(modules,'Yokogawa');
                obj.gateSupply.Channel = '1';
                obj.gateSupply.Source_Mode = 'Voltage';
                obj.gateSupply.Current_Limit = obj.gateCurrentLimit;
                obj.gateSupply.Voltage = obj.Gate_Voltage;
                obj.gateSupply.on;
                pause(1)
                
                obj.drainSupply = obj.ODMR_handle.find_active_module(modules,'HAMEG');
                obj.drainSupply.Channel = '1';
                obj.drainSupply.Source_Mode = 'Voltage';
                obj.drainSupply.Current_Limit = obj.drainCurrentLimit;
                obj.drainSupply.Voltage = obj.Drain_Voltage;
                obj.drainSupply.on;
                pause(1)
                
                obj.Multimeter =  Drivers.Multimeter.HP_3478A.instance('Multimeter');
                obj.Multimeter.on;
                %% determine electrical parameters of the chip
                
                obj.data.drainCurrent = obj.Multimeter.measureCurrent('1');
                obj.data.gateCurrent =  obj.gateSupply.Current;
                %% run ODMR experiment
                
                obj.ODMR_handle.run(statusH,managers,ax)
            catch
                obj.abort;
            end
        end
        
        function initializeProperties(obj)
            obj.ODMR_handle.Exposure = obj.Exposure;
            obj.ODMR_handle.trig_type = obj.trig_type;
            obj.ODMR_handle.Camera_PB_line = obj.Camera_PB_line;
            obj.ODMR_handle.Norm_freq = obj.Norm_freq;
            obj.ODMR_handle.Display_Data = obj.Display_Data;
            obj.ODMR_handle.RF_power = obj.RF_power;
            obj.ODMR_handle.nAverages = obj.nAverages;
            obj.ODMR_handle.start_freq = obj.start_freq;
            obj.ODMR_handle.stop_freq = obj.stop_freq;
            obj.ODMR_handle.number_points = obj.number_points;
            obj.ODMR_handle.dummy_pb_line = obj.dummy_pb_line;
            obj.ODMR_handle.waitTimeSGswitch_us = obj.waitTimeSGswitch_us;
        end
        
        function abort(obj)
            obj.drainSupply.off;
            obj.gateSupply.off;
            obj.Multimeter.off;
            obj.ODMR_handle.abort;
        end
        
        function data = GetData(obj,~,~)
           data = obj.ODMR_handle.GetData;
           data.drainVoltage = obj.Drain_Voltage;
           data.gateVoltage =  obj.Gate_Voltage;
           data = setstructfields(data,obj.data);
        end
        
      
    end
    
end