classdef Database < Base.Module
    %MODULE Abstract Class for Modules.
    %   Simply enforces required properties. For future use.
    
    properties(Abstract,SetAccess=private)
        % If set to true, CommandCenter will call the save methods after every snap and experiment.
        %   If false, the save button will have to be pressed. Note, that
        %   if set to true, pressing the save button will not call this
        %   function again!
        autosave
    end
    properties(Constant,Hidden)
        modules_package = 'Databases';
    end
    
    methods(Abstract)
        % Saving an image
        SaveIm(image_struct,ax,active_module,notes)
        
        % Saving experiment data
        SaveExp(data,ax,active_module,notes)
    end
    
end

