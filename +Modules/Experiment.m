classdef Experiment < Base.Module  & Base.Measurement
    %EXPERIMENT Abstract Class for Experiments
    
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
    methods % Opt-in
        function LoadData(obj,data)
            % Given the data struct that is produced in "GetData", you have
            % the option to load it back into memory here
            error('Not implemented');
        end
    end
    methods(Static)
        function varargout = analyze(data,varargin)
            % Assuming data is a struct that is built by the DBManager, the
            % method will attempt to call the appropriate analysis method
            % of data's origin module with data.data
            % NOTE: depending on module used to save the data struct, the
            % data struct may need to be reassembled!
            if ~isfield(data,'origin')
                error('Data struct does not contain origin. Perhaps saved before this update was implemented.')
            end
            origin = data.origin;
            mmc = meta.class.fromName(origin);
            assert(~isempty(mmc),sprintf('Could not find "%s" on path. Make sure CommandCenter is on your path.',origin))
            mask = ismember({mmc.MethodList.Name},'analyze');
            assert(sum(mask)==1,'Impossible! Did not find one analyze method (should have inherited this one).');
            % Verify that method was not this one
            if ~strcmp(mfilename('class'), mmc.MethodList(mask).DefiningClass.Name)
                fn = str2func([origin '.analyze']);
                varargout = cell(1,nargout);
                try
                    [varargout{:}] = fn(data.data,varargin{:});
                    varargout = varargout(1:nargout); % Cut down to requested number from caller
                catch err
                    throwAsCaller(MException('MODULE:analysis',['Unable to call %s.analysis(data.data). ',...
                        'This could be due to a poorly formatted or incorrectly reassembled data struct:\n\n%s'],...
                        origin, getReport(err)));
                    
                end
            else
                error('"%s" does not have an analysis method implemented.',origin);
            end
        end
        function new(experiment_name)
            % Pull templates into correct folder
            thisfolder = fileparts(mfilename('fullpath'));
            root = fullfile(thisfolder,['../Modules/+Experiments/@',experiment_name]);
            assert(~exist(root,'dir'),'Experiment with this name exists!')
            assert(~exist(fullfile(root,'..',[experiment_name '.m']),'file'),'Experiment with this name exists!')
            % Validate filename by trying to make variable with it
            try % Use struct to "sandbox" and make sure no variables are overwritten
                eval(sprintf('test.%s=[];',experiment_name));
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
    
    methods
        function data = measure(obj)
%             data = obj.blank();
            obj.run([], [], [])
            data = GetData(obj, stage, imager);
        end
    end
end

