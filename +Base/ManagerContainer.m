classdef ManagerContainer < handle
    %MANAGERCONTAINER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Path
        DB
        Experiment
        Sources
        MetaStage
        Stages
        Imaging
        Logger
        handles
        timeout     % Set in CommandCenter opening fcn
        inactivity = false;  % Inactivity flag
        error_dlg   % Used to add new errors to same dlg (if not closed)
        warn_dlg    % Used to add new warnings to samd dlg (if not closed)
    end
    
    methods
        function delete(obj)
            things = {obj.DB,obj.Experiment,obj.Sources,obj.Stages,obj.Imaging,obj.Path,obj.MetaStage};
            for i = 1:numel(things)
                if isobject(things{i}) && isvalid(things{i})
                    delete(things{i})
                end
            end
        end
    end
    
end

