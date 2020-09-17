classdef SMV03 < Sources.SignalGenerators.SG_Source_invisible
    % SMV03 serial source class
    
    methods(Access=protected)
        function obj = SMV03()
            obj.serial =    Drivers.SignalGenerators.SMV03.instance('SG');
            
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
                Object = Sources.SignalGenerators.SMV03();
            end
            obj = Object;
        end
    end
end

