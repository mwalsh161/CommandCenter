classdef MetaStage < Base.Module
    %METASTAGE Wrapper for three Prefs.References
    
    properties(GetObservable, SetObservable)
        x = Prefs.Reference();
        y = Prefs.Reference();
        z = Prefs.Reference();
    end
    properties(SetAccess=immutable)
        name;
    end
    properties(Constant,Hidden)
        modules_package = 'MetaStage';
    end
    
    methods
        function obj = MetaStage(name)
            obj.name = name;
        end
    end
end