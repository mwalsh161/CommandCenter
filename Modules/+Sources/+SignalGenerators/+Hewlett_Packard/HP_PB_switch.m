classdef HP_PB_switch < Sources.SignalGenerators.MW_PB_switch_invisible
    %Hewlett Packard serial source class
    
    properties(Constant)
        SG_name='Signal Generator 1';
    end
    
    methods(Access=protected)
        function obj = HP_PB_switch()
            obj.serial = Drivers.SignalGenerators.Hewlett_Packard.instance(obj.SG_name);
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
                Object = Sources.SignalGenerators.Hewlett_Packard.HP_PB_switch();
            end
            obj = Object;
        end
    end
   
end



