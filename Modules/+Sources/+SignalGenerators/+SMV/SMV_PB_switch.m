classdef SMV_PB_switch < Sources.SignalGenerators.MW_PB_switch_invisible
    %SMIQ serial source class
    
    properties(Constant)
        SG_name='Signal Generator 2';
    end
    
    methods(Access=protected)
        function obj = SMV_PB_switch()
            obj.serial = Drivers.SignalGenerators.SMV03.instance(obj.SG_name);
            obj.loadPrefs;
            obj.MW_switch_on = 'yes';
            obj.MWFrequency = obj.serial.getFreqCW;
            obj.MWPower = obj.serial.getPowerCW;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.SignalGenerators.SMV.SMV_PB_switch();
            end
            obj = Object;
        end
    end
end

