classdef ODMR_Diode_LockIn_No_Normalization < Experiments.CMOS.CMOS_invisible 
    
    properties
        opticalPower
        powerMeter
        cur_nAverage
        panel
        data;
        abort_request = false;  % Request flag for abort
        Ni   % NIDAQ
        laser
        pulseblaster
        ax %axis to data axis
        trig_type = 'Internal';
        Display_Data = 'Yes'
        ChipControl
        LockIn
        prefs = {'DriverBias','PhotoDiodeBias','nAverages','start_voltage','stop_voltage','number_points',...
            'waitTimeVCOswitch','VCO_CTRL_Line','frequency','dutyCycle','ExtRefTrigImp','CurrentGain'...
            'Sensitivity','DetectionHarmonic','TimeConstant','Slope','Sync','GroundingType'...
            'Channel','ChannelMode','DataChanel','PBDummyLine','PowerMeter','AutoScale'}      
    end
 
    properties(SetObservable)
        PhotoDiodeBias = 1e-3;
        nAverages = 5;
        start_voltage = 0;
        stop_voltage = 2;
        number_points = 60; %number of frequency points desired
        waitTimeVCOswitch = 1; %time to wait for SG to step in freq after triggering
        VCO_CTRL_Line = 'VCO_CTRL_Line';
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
        DataChanel = {'1','2','3','4'}
        PBDummyLine = 14; %index from 0
        frequency = 1e3;
        dutyCycle = 0.5;
        PowerMeter = {'Yes','No'}
        AutoScale = {'Yes','No'}
    end
    
    methods(Access=private)
        function obj = ODMR_Diode_LockIn_No_Normalization()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.CMOS.On_Chip.ODMR.LockIn.ODMR_Diode_LockIn_No_Normalization();
            end
            obj = Object;
        end
    end
    
    methods(Access=protected)
       
    
         function voltage_list = determine_voltage_list(obj)
            voltage_list = zeros(1,obj.number_points);
            voltage_list = linspace(obj.start_voltage,obj.stop_voltage,obj.number_points);
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
      
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                
                data.VCO.voltage_list = obj.determine_voltage_list();
                data.VCO.VCO_CTRL_Line = obj.VCO_CTRL_Line;
                                
                data.averages = obj.nAverages;
                data.trig_type = obj.trig_type;
                data.Display_Data = obj.Display_Data;
                data.waitTimeVCOswitch = obj.waitTimeVCOswitch;
                data.data = obj.data;
                data.opticalPower = obj.opticalPower;
                
                data.ChipControl.VDD_VCO = obj.ChipControl.VDD_VCO;
                data.ChipControl.V_Capacitor = obj.ChipControl.V_Capacitor;
                data.ChipControl.VDD_Driver = obj.ChipControl.VDD_Driver;
                data.ChipControl.DriverBias = obj.ChipControl.DriverBias;
                data.ChipControl.PhotoDiodeBias = obj.ChipControl.PhotoDiodeBias;
                
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
                
            else
                data = [];
            end
        end
    end
end