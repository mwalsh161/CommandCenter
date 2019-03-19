classdef HP_none < Sources.Signal_Generator.SG_Source_invisible
    %Hewlett Packard serial source class
    
    properties
        prefs = {'MWFrequency','MWPower'};
    end
    
    properties(SetAccess=private, SetObservable)
        SG_name='Signal Generator 1';
    end
    
    methods(Access=protected)
        function obj = HP_none()
            obj.serial = Drivers.SignalGenerators.Hewlett_Packard.instance(obj.SG_name); 
            obj.loadPrefs;
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Signal_Generator.Hewlett_Packard.HP_none();
            end
            obj = Object;
        end
    end
    
    methods
        function delete(obj)
        end
    end
end

