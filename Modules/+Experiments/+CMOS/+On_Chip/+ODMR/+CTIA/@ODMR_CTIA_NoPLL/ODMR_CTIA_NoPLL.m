classdef ODMR_CTIA_NoPLL < Experiments.CMOS.CMOS_invisible 
    
    properties
        axImage
        data;
        abort_request = false;  % Request flag for abort
        Ni   % NIDAQ
        laser
        pulseblaster
        ax %axis to data axis
        minSampling = 2; %minimum sampling time
        triggerVector
        CTIA
        trig_type = 'Internal';
        Display_Data = 'Yes'
        ChipControl
        prefs = {'DriverBias','nAverages','start_voltage','stop_voltage','number_points',...
            'IntegrationTime','offTime','waitTimeVCOswitch','CTIAGate','MeasurementTime'...
            'MaxExpectedVoltage','OutputVoltage','norm_voltage','VCO_CTRL_Line'...
            ,'LaserOn'}
    end
 
    properties(SetObservable)
        LaserOn = {'Yes','No'};
        nAverages = 5;
        start_voltage = 0;
        stop_voltage = 2;
        number_points = 60; %number of frequency points desired
        dummy_pb_line = 14;  %dummy channel used for dead time during programming the sequence
        waitTimeVCOswitch = 1; %time to wait for SG to step in freq after triggering
        MaxExpectedVoltage = 2;%V
        OutputVoltage = 2; %V
        IntegrationTime = 30;  %time in microseconds
        CTIAGate = 1; %hw line for CTIA gate indexed from 1
        offTime = 30; % in percent
        MeasurementTime = 10; %total measurement time in milliseconds
        norm_voltage = 0; %V
        VCO_CTRL_Line = 'VCO_CTRL_Line';
    end
    
    methods(Access=private)
        function obj = ODMR_CTIA_NoPLL()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.CMOS.On_Chip.ODMR.CTIA.ODMR_CTIA_NoPLL();
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
       
        function plot_data(obj)
            voltage_list = (obj.determine_voltage_list); %frequencies in GHz
            voltage_list(2:2:end) = [];
            yyaxis(obj.ax,'left')
            errorbar(voltage_list,obj.data.contrast_vector,obj.data.error_vector,'parent',obj.ax)
            xlim(obj.ax,voltage_list([1,end]));
            xlabel(obj.ax,'VCO Voltage (V)')
            ylabel(obj.ax,'Normalized Voltage')
            yyaxis(obj.ax,'right')
            plot(voltage_list,obj.data.voltageVector,'r*--','parent',obj.ax)
            hold(obj.ax,'on')
            plot(voltage_list,obj.data.voltageVectorNorm,'k--','parent',obj.ax)
            ylabel(obj.ax,'Voltage (V)')
            hold(obj.ax,'off')
        end
        
         function voltage_list = determine_voltage_list(obj)
            voltage_list = zeros(1,2*obj.number_points);
            voltage_list_data = linspace(obj.start_voltage,obj.stop_voltage,obj.number_points);
            voltage_list_norm = ones(1,obj.number_points).*obj.norm_voltage;
            voltage_list(1:2:end) = voltage_list_data;
            voltage_list(2:2:end) = voltage_list_norm;
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
        function set.IntegrationTime(obj,val)
            assert(mod(val,obj.minSampling) == 0,['IntegrationTime must be divisible by ',num2str(obj.minSampling)])
            obj.IntegrationTime = val;
        end
        
        function set.offTime(obj,val)
            assert(mod(val,obj.minSampling) == 0,['offTime must be divisible by ',num2str(obj.minSampling)])
            obj.offTime = val;
        end
        
        function abort(obj)
            obj.ChipControl.off;
            try
               obj.CTIA.stopAllTask
            end
            obj.abort_request = true;
            obj.ChipControl.off;
            obj.laser.off;
            obj.Ni.WriteAOLines(obj.VCO_CTRL_Line,0);
            obj.pulseblaster.stop;
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                
                data.VCO.voltage_list = obj.determine_voltage_list();
                data.VCO.norm_voltage = obj.norm_voltage;
                data.VCO.VCO_CTRL_Line = obj.VCO_CTRL_Line;
                
                data.LaserOn = obj.LaserOn;
                data.dummy_pb_line = 14;  %dummy channel used for dead time during programming the sequence
                
                data.averages = obj.nAverages;
                data.trig_type = obj.trig_type;
                data.Display_Data = obj.Display_Data;
                data.waitTimeVCOswitch = obj.waitTimeVCOswitch;
                data.data = obj.data;
                
                data.MaxExpectedVoltage = obj.MaxExpectedVoltage;
                data.OutputVoltage = obj.OutputVoltage;
                data.IntegrationTime = obj.IntegrationTime;
                data.CTIAGate = obj.CTIAGate;
                data.offTime = obj.offTime; % in microseconds
                data. MeasurementTime =obj. MeasurementTime;
                data.minSampling = obj.minSampling;
                data.TriggerVector = obj.triggerVector;
                
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