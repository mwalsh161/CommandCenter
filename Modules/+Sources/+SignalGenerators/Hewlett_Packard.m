classdef Hewlett_Packard < Sources.SignalGenerators.MW_PB_switch_invisible
    %Hewlett Packard serial source class
    
    methods(Access=protected)
        function obj = Hewlett_Packard()
            obj.serial = Drivers.SignalGenerators.Hewlett_Packard.instance('SG');
            
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
                Object = Sources.SignalGenerators.Hewlett_Packard();
            end
            obj = Object;
        end
    end
   
end



