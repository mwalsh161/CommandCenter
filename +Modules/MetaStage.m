classdef MetaStage < Base.Module
    %METASTAGE Wrapper for three Prefs.References
    
    properties(GetObservable, SetObservable)
        X = Prefs.Reference();
        Y = Prefs.Reference();
        Z = Prefs.Reference();
        Target = Prefs.Reference();
        
        key_step_x = Prefs.Double(0.1);
        key_step_y = Prefs.Double(0.1);
        key_step_z = Prefs.Double(0.1);
        joy_step_x = Prefs.Double(0.1);
        joy_step_y = Prefs.Double(0.1);
        joy_step_z = Prefs.Double(0.1);
    end
    properties(SetAccess=immutable)
        name;
        parent;
    end
    properties(Constant,Hidden)
        modules_package = 'MetaStage';
    end
    
    properties(SetObservable, AbortSet)
        show_prefs = {'X', 'Y', 'Z', 'Target'};
        prefs = {'X', 'Y', 'Z', 'Target', 'key_step_x', 'key_step_y', 'key_step_z', 'joy_step_x', 'joy_step_y', 'joy_step_z'};
    end
    methods(Static)
        function obj = instance(name, manager)
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
            obj = Modules.MetaStage(name, manager);
            obj.singleton_id = name;
            Objects(end+1) = obj;

        end
    end
    methods(Access=private)
        function obj = MetaStage(name, manager)
            obj.name = name;
            if ~isempty(manager)
                obj.parent = manager;
            end
            % obj.loadPrefs;
            % obj.namespace = sprintf("MetaStage.%s", name);
        end
    end
end