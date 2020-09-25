classdef AutoExperiment_invisible < Modules.Experiment
    % AutoExperiment_invisible is the superclass for looping through experiments
    % across many emitters.
    %
    % Subclasses need to create the abstract patch_functions property and
    % assign the "experiments" property in the constructor. The
    % AcquireSites abstract method must also be created. Subclasses may
    % find it useful to take advantage of some static helper methods
    % defined here as well.
    %
    % It is safe for subclasses to add any meta data to obj.meta. This
    % property is programmed to be immutable to subclasses. This can be
    % done in pre/post/patch functions (or anything with access to obj).
    %
    % This set of experiments takes an optional analysis mat file. The file
    % contents should have the following form at the minimum:
    %    sites <- struct of shape N x m where N is number of sites, and m
    %    sites(N,m).redo <- boolean specifying if that experiment should be
    %                       redone upon a continue experiment run
    %    Upon loading, this will be obj.analysis.sites
    % The file can have anything else within sites or outside of the sites
    % field. Reference the subclass documentation for more info.
    % A subclass can define "validate_analysis(obj)" that errors
    % if the analysis is not formatted for that particular experiment. This
    % is called after validating the above condition.
    %   This is only called if the user supplied the file and is the first
    %   thing called in the run method.

    properties
        prefs = {'run_type','site_selection','tracking_threshold','min_tracking_dt','max_tracking_dt','imaging_source','repeat'};
        show_prefs = {'analysis_file','continue_experiment','experiments','run_type','site_selection','tracking_threshold','min_tracking_dt','max_tracking_dt','imaging_source','repeat'};
    end
    properties(Abstract)
        patch_functions %cell array of method names in subclass definition that take input (site,site_index). Run before experiment group.
        prerun_functions %cell array of method names in subclass definition that take input (experiment). Run immediately before experiment's run method
    end
    properties(SetAccess=protected,Hidden)
        data = [] % struct with fields: sites (1xN struct), image (1 struct)
        meta = struct() % Useful to store meta data in run method [THIS IS IMMUTABLE in that once a field is set it can't be changed]
        tracker = zeros(1,6); %array of (# experiments)*(# sites) by 6 --> (dx,dy,dz,tracking metric,datenum time,site index)
        abort_request = false; % Flag that will be set to true upon abort
        err_thresh = 10; %if have err_thresh many errors during run, experiment overall will error and quit
        fatal_flag = false; % if true, an error becomes fatal
        current_experiment = []; %this will be a copy of the handle to the current experiment, to be used for passing things like aborts between experiments
        analysis = [];
    end
    properties(SetObservable, GetObservable)
        experiments = Prefs.ModuleInstance(Modules.Experiment.empty(0),'n',Inf,'inherits',{'Modules.Experiment'},'readonly',true);
        run_type = Prefs.MultipleChoice(Experiments.AutoExperiment.AutoExperiment_invisible.SITES_FIRST,...
                    'choices',{Experiments.AutoExperiment.AutoExperiment_invisible.SITES_FIRST,...
                               Experiments.AutoExperiment.AutoExperiment_invisible.EXPERIMENTS_FIRST});
        site_selection = Prefs.MultipleChoice('Peak finder','choices',{'Peak finder','Grid','Manual sites','Load from file'});
        imaging_source = Prefs.ModuleInstance(Modules.Source.empty(0),'inherits',{'Modules.Source'});
        tracking_threshold = Prefs.Double(Inf,'min',0,'help','tracking metric will be normalized to 1');
        min_tracking_dt = Prefs.Double(Inf,'min',0,'unit','sec','help','tracker won''t run twice within this amount of time');
        max_tracking_dt = Prefs.Double(Inf,'min',0,'unit','sec','help','if tracking_threshold isn''t hit, tracker will still run after this amount of time');
        repeat = Prefs.Integer(1,'min',1,'allow_nan',false);
        continue_experiment = Prefs.Boolean(false,'set','set_continue_experiment');
        analysis_file = Prefs.File('filter_spec','*.mat','help','Used in patch functions instead of fitting last result. This also ignores SpecPeakThresh.',...
                                     'custom_validate','validate_file');
    end
    properties(Constant,Hidden)
        SITES_FIRST = 'All Sites First';
        EXPERIMENTS_FIRST = 'All Experiments First';
    end
    methods(Static)
        function sites = SiteFinder_Confocal(managers,imaging_source,site_selection)
            % Finds positions of peaks in image; if manual input, plots image and allows user input
            % Returns struct sites, with fields:
            %   image = image used in finding sites
            %   positions = [Nx2] array of positions
            %   manual_input = boolean, true if positions were user-supplied
            %   meta = empty if manual_input, else UserData from imfindpeaks
            persistent last_path
            if isempty(last_path)
                last_path = '';
            end
            sites = struct('image',[],'positions',[],'input_method',site_selection,'meta',[]);

            if strcmp(site_selection,'Load from file')
                [file,path] = uigetfile('*.mat','Site Selection',last_path);
                    if isequal(file,0)
                        error('Site selection aborted')
                    else
                        last_path = path;
                        temp = load(fullfile(path,file));
                        f = fieldnames(temp);
                        assert(numel(f)==1,...
                            sprintf('The mat file containing sites should only contain a single variable, found:\n\n%s',...
                            strjoin(f,', ')))
                        sites.positions = temp.(f{1});
                        sites.meta.path = fullfile(path,file);
                        recvd = num2str(size(sites.positions),'%i, ');
                        assert(size(sites.positions,2)==2,...
                            sprintf('Only supports loading x, y coordinates (expected Nx2 array, received [%s]).',recvd(1:end-1)));
                    end
                sites.positions = [sites.positions, NaN(size(sites.positions,1),1)];
                return
            end

            if isempty(managers.Imaging.current_image)
                source_on = imaging_source.source_on;
                imaging_source.on;
                sites.image = managers.Imaging.snap; %take image snapshot
                if ~source_on
                    imaging_source.off;
                end
            else
                sites.image = managers.Imaging.current_image.info;
            end

            f = figure;
            ax_temp = axes('parent',f);
            imH = imagesc(sites.image.ROI(1,:),sites.image.ROI(2,:),sites.image.image,'parent',ax_temp);
            colormap(ax_temp,managers.Imaging.set_colormap);
            set(ax_temp,'ydir','normal')
            axis(ax_temp,'image')
            switch site_selection
                case 'Peak finder'
                    title('Drag red region to set thresholds, then close adjustment window when done.')
                    [scatterH,panelH] = imfindpeaks(imH); %returns array of NV locations
                    uiwait(panelH);
                    sites.positions = [scatterH.XData',scatterH.YData'];
                    sites.meta = scatterH.UserData;
                case 'Grid'
                    sites = Experiments.AutoExperiment.AutoExperiment_invisible.select_grid_sites(sites,ax_temp);
                case 'Manual sites'
                    title(sprintf('Click on all positions\nDrag to adjust\nRight click on point to get menu to delete.\n\nRight click on image to finish (DO NOT CLOSE!)'))
                    imH.UserData.h = [];
                    imH.ButtonDownFcn = @im_clicked;
                    uiwait(f);
                    sites.positions = NaN(0,2);
                    for i = 1:length(imH.UserData.h)
                        if isvalid(imH.UserData.h(i))
                            sites.positions(end+1,:) = imH.UserData.h(i).getPosition;
                        end
                    end
            end
            % Add in column of NaNs for Z (this will prevent setting Z when
            % moving to emitter position; Track can still modify global Z
            % if desired.
            sites.positions = [sites.positions, NaN(size(sites.positions,1),1)];
            close(f)
            assert(~isempty(sites.positions),'No positions!')
            function im_clicked(hObj,eventdata)
                if eventdata.Button ~= 1
                    uiresume;
                    return
                end
                h = impoint(hObj.Parent,eventdata.IntersectionPoint(1:2));
                if isempty(hObj.UserData.h)
                    hObj.UserData.h = h;
                else
                    hObj.UserData.h(end+1) = h;
                end
            end
        end
        sites = select_grid_sites(sites,ax_temp)
        varargout = view(varargin);
        function [dx,dy,dz,metric] = Track(Imaging,Stages,thresh)
            %this runs at end of each experiment and should return:
            %   dx = change in x
            %   dy = change in x
            %   dz = change in x
            %   metric = whatever metric used to track (e.g. fluorescence)
            dx = NaN; dy = NaN; dz = NaN; % Case when told to explicitly not track
            if ~islogical(thresh)
                dx = 0; dy = 0; dz = 0;
            end
            metric = NaN;
        end
    end
    methods(Access=private)
        function reset_meta(obj)
            % The only function allowed to delete obj.meta; used to reset between runs
            obj.meta = struct();
        end
    end
    methods(Abstract)
        sites = AcquireSites(obj,managers)
    end
    methods
        function obj = AutoExperiment_invisible()
            obj.run_type = obj.SITES_FIRST;
            obj.loadPrefs;
            assert(all(cellfun(@(x)ismethod(obj,x)||isempty(x),obj.patch_functions)),'One or more named patch_function do not have corresponding methods.') %make sure all patch functions are valid
            assert(all(cellfun(@(x)ismethod(obj,x)||isempty(x),obj.prerun_functions)),'One or more named prerun_functions do not have corresponding methods.') %make sure all prerun functions are valid
        end
        run(obj,statusH,managers,ax)
        function delete(obj)
            % Clean up all experiments now to ensure no odd behavior when
            % CC cleans everything up on shut down (race conditions)
            delete(obj.experiments);
        end
        function abort(obj)
            obj.fatal_flag = true;
            obj.abort_request = true;
            if ~isempty(obj.current_experiment)
                obj.current_experiment.abort;
            end
            obj.logger.log('Abort requested');
        end
        function validate_analysis(obj)
        end
        function PreRun(obj,status,managers,ax)
        end
        function PostRun(obj,status,managers,ax)
        end
        function set.meta(obj,val)
            % To make it immutable, we will go through each field in val
            % and add it to obj.meta if it is new, otherwise we error.
            assert(isstruct(val),'obj.meta must be a struct!');
            st = dbstack(1,'-completenames'); % omit this call in stack
            % Allow obj.reset_meta to do anything
            if strcmp(st(1).name,'AutoExperiment_invisible.reset_meta')
                obj.meta = val;
                return
            end
            fields = fieldnames(val);
            to_add = false(size(fields));
            for i = 1:length(fields)
                if isfield(obj.meta,fields{i}) && ~matrix_starts_with(val.(fields{i}),obj.meta.(fields{i}))
                    sz = ''; % Provide additional error help
                    if numel(obj.meta,fields{i}) > 1
                        sz = '(';
                        for ind = size(obj.meta.(fields{i}))
                            sz = [sz sprintf('1:%i,',ind)];
                        end
                        sz(end) = ')'; % Replace last "," with the closing paren
                    end
                    error('Field "%s%s" already exists in obj.meta!',fields{i},sz);
                else % Not a field yet
                    to_add(i) = true;
                end
            end
            % Now that there weren't errors, update meta
            obj.meta = val;
        end
    end
    methods(Sealed)
        function dat = GetData(obj,~,~)
            % Callback for saving methods
            dat.data = obj.data;
            dat.meta = obj.meta;
        end
        function LoadData(obj,data)
            % Not grabbing the meta data as that will be re-assigned
            assert(isfield(data,'data'),'No field "data"; likely wrong experiment');
            assert(isfield(data.data,'image'),'No field "data.image"; likely wrong experiment');
            assert(isfield(data.data,'sites'),'No field "data.sites"; likely wrong experiment');
            assert(~isempty(data.data.sites),'No sites data in loaded experiment');
            obj.data = data.data;
            obj.continue_experiment = true;
        end
        function primary_validate_analysis(obj)
            % Already checked (on load):
            %   "sites" exists as a field
            %   Number of experiments in sites is good
            % Now that obj.data should be loaded, can check lengths
            n_analysis_sites = size(obj.analysis.sites,1);
            n_data_sites = length(obj.data.sites);
            assert(n_analysis_sites==n_data_sites,...
                    sprintf('Found %i analysis entries, but %i sites. These should be equal.',...
                    	n_analysis_sites,n_data_sites));
            obj.validate_analysis();
        end
        function val = set_continue_experiment(~,val,~)
            %val is boolean; true = continue experiment, false = start anew
            pan = get(gcbo,'parent'); %grab handle to settings panel
            site_sel = findobj(pan,'tag','site_selection');
            if isempty(site_sel) || ~isvalid(site_sel)
                return;
            end
            if val
                set(site_sel,'enable','off'); %require use of old sites, so disable site selection
            else
                set(site_sel,'enable','on');
            end
        end
        function validate_file(obj,val,~)
            % We will validate and set the analysis prop here
            if ~isempty(val)
                flag = exist(val,'file');
                if flag == 0
                    error('Could not find "%s"!',val)
                end
                if flag ~= 2
                    error('File "%s" must be a mat file!',val)
                end
                dat = load(val);
                names = fieldnames(dat);
                if ~ismember('sites',names)
                    error('Loaded mat file should have at least a "sites" field; found\n%s',strjoin(names,', '));
                end
                if ~isfield(dat.sites,'redo')
                    error('The struct "sites" should have a "redo" field.');
                end
                if ~isstruct(dat.sites) || size(dat.sites,2) ~= length(obj.experiments)
                    error('Loaded variable from file should be an Nx%i struct.',length(obj.experiments));
                end
                obj.analysis = dat;
            else
                obj.analysis = [];
            end
        end
    end
end
