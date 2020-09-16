classdef SMIQ06B < Sources.SignalGenerators.MW_PB_switch_invisible
    %SMIQ serial source class

    methods(Access=protected)
        function obj = SMIQ06B()
            obj.serial = Drivers.SignalGenerators.SMIQ06B.instance('SG');
            
            obj.loadPrefs;
            
            obj.frequency = obj.serial.getFreqCW;
            obj.power =     obj.serial.getPowerCW;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.SignalGenerators.SMIQ06B();
            end
            obj = Object;
        end
    end
end

