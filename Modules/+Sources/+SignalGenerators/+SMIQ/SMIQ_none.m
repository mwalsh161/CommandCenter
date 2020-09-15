classdef SMIQ_none < Sources.SignalGenerators.SG_Source_invisible
    %SMIQ serial source class
    
    properties(Constant)
        SG_name='Signal Generator 1';
    end
    
    methods(Access=protected)
        function obj = SMIQ_none()
            obj.serial = Drivers.SignalGenerators.SMIQ06B.instance(obj.SG_name); 
            obj.loadPrefs;
            obj.MWFrequency = obj.serial.getFreqCW;
            obj.MWPower = obj.serial.getPowerCW;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.SignalGenerators.SMIQ.SMIQ_none();
            end
            obj = Object;
        end
    end
    
    methods
        function delete(obj)
        end
    end
end

