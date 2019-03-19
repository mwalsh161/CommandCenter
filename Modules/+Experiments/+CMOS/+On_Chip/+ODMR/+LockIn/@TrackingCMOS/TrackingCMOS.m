classdef TrackingCMOS < Experiments.CMOS.CMOS_invisible 
    
    properties
        calibrationMatrix = [];
        listeners
        RF
        opticalPower
        powerMeter
        data;
        abort_request = false;  % Request flag for abort
        laser
        ChipControl
        LockIn
        prefs = {'freq1','freq2','freq3','meanValue1','meanValue2','meanValue3','number_points','Calibrate',...
            'waitSGSwitch','ExtRefTrigImp','CurrentGain','frequency','OutputVoltage'...
            'Sensitivity','DetectionHarmonic','TimeConstant','Slope','Sync','GroundingType'...
            'Channel','ChannelMode','DataChanel1','DataChanel2','PowerMeter','AutoScale',...
            'Mode','ModulationDeviation','FMChannel','VoltageMode','PhaseTransition','filename'}      
    end
 
    properties(SetObservable)
        freq1 = 2.75e9;
        freq2 = 2.75e9;
        freq3 = 2.75e9;
        meanValue1 = 0;
        meanValue2 = 0;
        meanValue3 = 0;
        number_points = 61; %number of frequency points desired
        Calibrate = {'yes','no'}
        waitSGSwitch = 1; %time to wait for SG to step in freq after triggering
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
        DataChanel2 = {'1','2','3','4'}
        PowerMeter = {'Yes','No'}
        AutoScale = {'Yes','No'}
        frequency = 1e3;
        Mode = {'voltage','current'}
        ModulationDeviation = 1e6;
        FMChannel = 1;
        OutputVoltage = 3;
        VoltageMode = {'A','A-B'}
        PhaseTransition = 50;
        filename = 'C:\Users\QPG\Dropbox (MIT)\CMOS_Project_Shared_MCD\Magnetic_Sensor_V2_Measurements\data\demo\FM_Split\calibration\M_Matrix.mat'
    end
    
    methods(Access=private)
        function obj = TrackingCMOS()
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.CMOS.On_Chip.ODMR.LockIn.TrackingCMOS();
            end
            obj = Object;
        end
    end
    
    methods(Access=protected)

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

        function set.number_points(obj,val)
            assert(isnumeric(val),'number_points must be a of type numeric.')
            assert(val>0,'number_points must be positive.')
            assert(~logical(mod(val,1)),'number_points must be an integer.')
            if ~isequal(val,obj.number_points)
                obj.number_points = val;
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
            
            data.waitSGSwitch = obj.waitSGSwitch;
            data.calibrationMatrix = obj.calibrationMatrix;
            
            data.data = obj.data;
           
            data.PowerMeter.opticalPower = obj.opticalPower;
            
            data.RF.freq1 = obj.freq1;
            data.RF.freq2 = obj.freq2;
            data.RF.freq3 = obj.freq3;
            data.RF.meanValue1 = obj.meanValue1;
            data.RF.meanValue2 = obj.meanValue2;
            data.RF.meanValue3 = obj.meanValue3;
            data.RF.ModulationDeviation = obj.ModulationDeviation;
            data.RF.ModulationFrequency = obj.frequency;
            
            
            data.ChipControl.VDD_VCO = obj.ChipControl.VDD_VCO;
            data.ChipControl.VDD_Driver = obj.ChipControl.VDD_Driver;
            data.ChipControl.DriverCore = obj.ChipControl.DriverCore;
            data.ChipControl.DriverBoundary = obj.ChipControl.DriverBoundary;
            data.ChipControl.VDDCP = obj.ChipControl.VDDCP;
            data.ChipControl.VDDPLL = obj.ChipControl.VDDPLL;
           
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
            data.LockIn.VoltageMode = obj.VoltageMode;

        end
        
    end
end