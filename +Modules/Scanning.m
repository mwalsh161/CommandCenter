classdef Scanning < Base.Module% & Base.Data
    %SCANNING Abstract Class for Scanning.
    %   Simply enforces required properties. For future use.
    
    properties(Abstract,SetAccess=private)
        % NOTE: if using the database option, it will look here for the
        % properties that the database requires that are unique to this
        % datatype. Make sure they are set prior to any chance of being
        % saved!
    end
    properties(Constant,Hidden)
        modules_package = 'Scanning';
    end
    properties
        path = '';
    end
    events
        save_request        % When fired, CC will cycle through autosave first, then manual save modules
    end
    
    methods(Abstract)
        % Execute the experiment code (this should have a way to check for abort!)
        %   statusH is a handle to a text field that displays when run is
        %   pressed.
        %   managers is a wrapper that contains all the managers
        run(obj,statusH,managers,ax)
        
        % This should abort the currently running experiment.
        abort(obj)
        
        % Return the data object to be saved. Ideally a structure, not a class.
        data = GetData(obj,stage,imager)
    end
    methods % Opt-in
        function LoadData(obj,data)
            % Given the data struct that is produced in "GetData", you have
            % the option to load it back into memory here
            error('Not implemented');
        end
    end
end

