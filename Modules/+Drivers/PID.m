classdef PID < Modules.Driver
    %PID
    
    properties (GetObservable, SetObservable)
        control =       Prefs.Reference();
        value =         Prefs.Reference();
        setpoint =      Prefs.Double();
        tolerance =     Prefs.Double();
        
        P =             Prefs.Double(1, 'min', 0);
%         I =             Prefs.Double(1, 'min', 0);
%         D =             Prefs.Double(1, 'min', 0);
        
        tick =          Prefs.Button();
        loop =          Prefs.Button();
        
        set_autoloop =  Prefs.Boolean();
        plot =          Prefs.Boolean();
    end
    
    % Constructor functions
    methods (Static)
        function obj = instance(name)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PID.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PID(name);
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
    end
    methods (Access=private)
        function obj = PID(name)
            
        end
    end
    
    methods
        
    end
end
