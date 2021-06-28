classdef MetaStage < Base.Module
    %METASTAGE Wrapper for three Prefs.References
    
    properties(GetObservable, SetObservable)
        X = Prefs.Reference();
        Y = Prefs.Reference();
        Z = Prefs.Reference();
        
        key_step_x = .1; % Prefs.Double();
        key_step_y = .1; % Prefs.Double();
        key_step_z = .1; % Prefs.Double();
        
        joy_step_x = .1; % Prefs.Double();
        joy_step_y = .1; % Prefs.Double();
        joy_step_z = .1; % Prefs.Double();
    end
    properties(SetAccess=immutable)
        name;
    end
    properties(Constant,Hidden)
        modules_package = 'MetaStage';
        
        show_prefs = {'X', 'Y', 'Z'};
    end
    
    methods(Static)
        function obj = instance(name)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Modules.MetaStage.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(name,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Modules.MetaStage(name);
            obj.singleton_id = name;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = MetaStage(name)
            obj.name = name;
        end
    end
end