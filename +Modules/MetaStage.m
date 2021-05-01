classdef MetaStage < Base.Module
    %METASTAGE Wrapper for three Prefs.References
    
    properties(GetObservable, SetObservable)
        X = Prefs.Reference();
        Y = Prefs.Reference();
        Z = Prefs.Reference();
        
        poll = Prefs.Button('Update Positions');
        
        key_step_x = Prefs.Double();
        key_step_y = Prefs.Double();
        key_step_z = Prefs.Double();
        
        joy_step_x = Prefs.Double();
        joy_step_y = Prefs.Double();
        joy_step_z = Prefs.Double();
    end
    properties(SetAccess=immutable)
        name;
    end
    properties(Constant,Hidden)
        modules_package = 'MetaStage';
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