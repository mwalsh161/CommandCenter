classdef ODMR_CTIA_PLL < Experiments.CMOS.CMOS_invisible & Experiments.ODMR.ODMR_invisible
    
    properties
        daq
        minSampling = 2; %minimum sampling time
        triggerVector
        CTIA
        trig_type = 'Internal';
        Display_Data = 'Yes'
        ChipControl
        prefs = {'DriverBias','nAverages','RF_power','start_freq','stop_freq','number_points','freq_step_size',...
            'IntegrationTime','offTime','waitTimeSGswitch_us','NormFreq','CTIAGate','MeasurementTime'...
            'MaxExpectedVoltage','OutputVoltage','Norm_freq'}
    end
    
    properties(SetObservable)
        MaxExpectedVoltage = 2;%V
        OutputVoltage = 2; %V
        IntegrationTime = 30;  %time in microseconds
        CTIAGate = 1;
        Norm_freq = 2.4e9;
        offTime = 30; % in percent
        MeasurementTime = 10; %total measurement time in milliseconds
    end
    
    methods(Access=private)
        function obj = ODMR_CTIA_PLL()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.CMOS.On_Chip.ODMR.CTIA.ODMR_CTIA_PLL();
            end
            obj = Object;
        end
    end
    
    methods(Access=protected)
        function trigNum = determineTrigNum(obj)
            trigNum = round(obj.MeasurementTime*1000./obj.IntegrationTime)*(obj.determineBinsData + obj.determineBinsOff);
        end
        
        function bins = determineBinsData(obj)
            bins = obj.IntegrationTime./obj.minSampling;
        end
        
        function bins = determineBinsOff(obj)
            bins = obj.offTime./obj.minSampling;
        end
        
        function [CTIAGateLine,dummy_pb_line] = determine_PB_hardware_handles(obj)
            CTIAGateLine = obj.CTIAGate-1;
            dummy_pb_line = obj.dummy_pb_line-1;
        end
        
        function determineTriggerVector(obj)
            binsData = ones(1,obj.determineBinsData);
            binsOff = zeros(1,obj.determineBinsOff);
            period = [binsData,binsOff];
            trigVector = [];
            for index = 1:obj.determineTrigNum./numel(period)
                trigVector = [trigVector,period];
            end
            obj.triggerVector = obj.OutputVoltage.*trigVector;
        end
        
        function freq_list = determine_freq_list(obj)
            freq_list = zeros(1,2*obj.number_points);
            freq_list_data = linspace(obj.start_freq,obj.stop_freq,obj.number_points);
            freq_list_norm = ones(1,obj.number_points).*obj.Norm_freq;
            freq_list(1:2:end) = freq_list_data;
            freq_list(2:2:end) = freq_list_norm;
        end
        
        function s=setup_PB_sequence(obj)
            
            [CTIAGateLine,dummy_pb_line] = obj.determine_PB_hardware_handles(); %get the pulsblaster hardware handles
            
            % Make some chanels
            CTIAGateChannel= channel('CTIAGate','color','r','hardware',CTIAGateLine);
            cdummy = channel('dummy','color','k','hardware',dummy_pb_line);
            
            % Make sequence
            s = sequence('CTIA Measurement');
            s.channelOrder = [CTIAGateChannel,cdummy];
            
            % analog trigger duration
            n_CTIA = node(s.StartNode,CTIAGateChannel,'delta',0,'units','us');
            n_CTIA = node(n_CTIA,CTIAGateChannel,'delta',1,'units','us');
            
            % dummy duration
            n_dummy   = node(s.StartNode,cdummy,'delta',0,'units','us');
            n_dummy   = node(n_dummy,cdummy,'delta',2,'units','us');
            
            s.repeat = obj.determineTrigNum;
        end
        
        function initialize_data_acquisition_device(obj,~)
            obj.Ni = Drivers.NIDAQ.dev.instance('dev1');
            VoltageLimIn = [0,obj.MaxExpectedVoltage];
            VoltageLimOut = [0,obj.OutputVoltage];
            obj.determineTriggerVector;
            obj.CTIA = Triggered_CTIA_Measurement.instance(obj.determineTrigNum,obj.triggerVector,VoltageLimIn,VoltageLimOut);
            obj.pulseblaster = Drivers.PulseBlaster.Remote.instance(obj.laser.ip);
            obj.data = [];

        end
        
        function plot_data(obj)
            freq_list = (obj.determine_freq_list)*10^-9; %frequencies in GHz
            freq_list(2:2:end) = [];
            errorbar(freq_list,obj.data.contrast_vector,obj.data.error_vector,'parent',obj.ax)
            xlim(obj.ax,freq_list([1,end]));
            xlabel(obj.ax,'Microwave Frequency (GHz)')
            ylabel(obj.ax,'Normalized Voltage')
        end
        
    end
    
    methods
        function set.IntegrationTime(obj,val)
            assert(mod(val,obj.minSampling) == 0,['IntegrationTime must be divisible by ',num2str(obj.minSampling)])
            obj.IntegrationTime = val;
        end
        
        function set.offTime(obj,val)
            assert(mod(val,obj.minSampling) == 0,['offTime must be divisible by ',num2str(obj.minSampling)])
            obj.offTime = val;
        end
        
        function run(obj,statusH,managers,ax)
            try
                %% set the control voltages
                modules = managers.Sources.modules;
                obj.ChipControl = obj.find_active_module(modules,'CMOS_Chip_Control');
                obj.ChipControl.off;
                obj.ChipControl.DriverBias = obj.DriverBias;
                %turn on all control channels
                obj.ChipControl.on;
                
                %% call the run method of the superclass
                
                run@Experiments.ODMR.ODMR_invisible(obj,statusH,managers,ax);
            catch error
                obj.logger.log(error.message);
                obj.abort;
            end
        end
        
        function abort(obj)
            obj.ChipControl.off;
            try
               obj.CTIA.stopAllTask
            end
            abort@Experiments.ODMR.ODMR_invisible(obj)
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data = GetData@Experiments.ODMR.ODMR_invisible(obj);
                data.DriverBias = obj.DriverBias;
                data.data = obj.data;
                data.MaxExpectedVoltage = obj.MaxExpectedVoltage;
                data.OutputVoltage = obj.OutputVoltage;
                data.IntegrationTime = obj.IntegrationTime;
                data.CTIAGate = obj.CTIAGate;
                data.Norm_freq = obj.Norm_freq;
                data.offTime = obj.offTime; % in percent
                data. MeasurementTime =obj. MeasurementTime;
                data.minSampling = obj.minSampling;
                data.ChipControl.VDD_VCO = obj.ChipControl.VDD_VCO;
                data.ChipControl.V_Capacitor = obj.ChipControl.V_Capacitor;
                data.ChipControl.VDD_Driver = obj.ChipControl.VDD_Driver;
                data.ChipControl.DriverBias = obj.ChipControl.DriverBias;
                data.ChipControl.PhotoDiodeBias = obj.ChipControl.PhotoDiodeBias;
                data.ChipControl.VDD_CTIA_AMP = obj.ChipControl.VDD_CTIA_AMP;
                data.ChipControl.CTIA_Bias = obj.ChipControl.CTIA_Bias;
                
            else
                data = [];
            end
        end
    end
end