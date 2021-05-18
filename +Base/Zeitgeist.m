classdef Zeitgeist < Base.Module
    
    properties(Constant, Hidden)
        modules_package = 'Sweeping';
    end
    
    methods (Static)
        function singleton = instance
            mlock
            persistent local
            if isempty(local) || ~isvalid(local)
                local = Base.Zeitgeist;
            end
            singleton = local;
        end
        function t = time
            t = Prefs.Time;
        end
    end
    
    methods (Access=private)
        function obj = Zeitgeist()
            
        end
    end
end