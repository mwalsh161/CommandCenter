classdef SMIQ06B < Sources.SignalGenerators.SG_Source_invisible
    %SMIQ serial source class

    methods(Access=protected)
        function obj = SMIQ06B()
            obj.serial = Drivers.SignalGenerators.SMIQ06B.instance('SG');
            
            obj.init();
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

