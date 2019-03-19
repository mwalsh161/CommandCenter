classdef Experiment < Base.Module
    %MODULE Abstract Class for Modules.
    %   Simply enforces required properties. For future use.
    
    properties(Abstract,SetAccess=private)
        % NOTE: if using the database option, it will look here for the
        % properties that the database requires that are unique to this
        % datatype. Make sure they are set prior to any chance of being
        % saved!
    end
    properties(Constant,Hidden)
        modules_package = 'Experiments';
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
    
    methods(Static)
        function new(experiment_name)
            % Pull templates into correct folder
            thisfolder = fileparts(mfilename('fullpath'));
            root = fullfile(thisfolder,['../Modules/+Experiments/@',experiment_name]);
            assert(~exist(root,'dir'),'Experiment with this name exists!')
            assert(~exist(fullfile(root,'..',[experiment_name '.m']),'file'),'Experiment with this name exists!')
            % Validate filename by trying to make variable with it
            try % Use struct to "sandbox" and make sure no variables are overwritten
                eval(sprintf('test.%s=[]',experiment_name));
            catch err
                errordlg('Not a valid MATLAB class name!','New Experiment');
                return;
            end
            mkdir(root);
            try
            % Class definition
            fid = fopen(fullfile(root,[experiment_name '.m']),'w');
            fidTemplate = fopen(fullfile(thisfolder,'Experiment.template'),'r');
            TEMPLATE = fread(fidTemplate,'*char')';
            fclose(fidTemplate);
            TEMPLATE = strrep(TEMPLATE,'!TEMPLATENAME!',experiment_name);
            fprintf(fid,'%s',TEMPLATE);
            fclose(fid);

            % Run method
            fid = fopen(fullfile(root, 'run.m'),'w');
            fidTemplate = fopen(fullfile(thisfolder,'Experiment.run.template'),'r');
            TEMPLATE = fread(fidTemplate,'*char')';
            fclose(fidTemplate);
            fprintf(fid,'%s',TEMPLATE);
            fclose(fid);

            % Instance method
            fid = fopen(fullfile(root, 'instance.m'),'w');
            fidTemplate = fopen(fullfile(thisfolder,'instance.template'),'r');
            TEMPLATE = fread(fidTemplate,'*char')';
            fclose(fidTemplate);
            TEMPLATE = strrep(TEMPLATE,'!TEMPLATENAME!',experiment_name);
            TEMPLATE = strrep(TEMPLATE,'!TEMPLATEMODULE!','Experiments');
            fprintf(fid,'%s',TEMPLATE);
            fclose(fid);
            opentoline(fullfile(root, 'run.m'),18);
            catch err
                rmdir(root,'s');
                rethrow(err);
            end
        end
    end
end

