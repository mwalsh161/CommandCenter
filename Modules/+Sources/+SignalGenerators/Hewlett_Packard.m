classdef Hewlett_Packard < Sources.SignalGenerators.SG_Source_invisible
    %Hewlett Packard serial source class
    
    methods(Access=protected)
        function obj = Hewlett_Packard()
            obj.serial = Drivers.SignalGenerators.Hewlett_Packard.instance('SG');
            
            obj.init();
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.SignalGenerators.Hewlett_Packard();
            end
            obj = Object;
        end
    end
   
end



