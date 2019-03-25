classdef SMIQ_PB_switch < Sources.SignalGenerators.MW_PB_switch_invisible
    %SMIQ serial source class

    properties(Constant)
        SG_name='Signal Generator 1';
    end
    
    methods(Access=protected)
        function obj = SMIQ_PB_switch()
            obj.serial = Drivers.SignalGenerators.SMIQ06B.instance(obj.SG_name);
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
                Object = Sources.SignalGenerators.SMIQ.SMIQ_PB_switch();
            end
            obj = Object;
        end
    end
end

