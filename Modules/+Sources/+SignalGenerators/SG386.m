classdef SG386 < Sources.SignalGenerators.SG_Source_invisible
    % Sources.SignalGenerators.SG386 is the source class for the serial interface to a Standford Research Systems SG386 signal generator.
    
    methods(Access=protected)
        function obj = SG386()
            obj.serial =    Drivers.SignalGenerators.SG386.instance('SG');
            
            obj.init();
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

