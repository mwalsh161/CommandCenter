function run(obj,status,managers,ax)
obj.abort_request = false;
obj.fatal_flag = false;
nexps = length(obj.experiments);
assert(all(cellfun(@ischar,obj.patch_functions)),'One or more patch function is not a valid handle.');
assert(length(obj.patch_functions) == nexps,'Number of patch functions does not match number of experiments.')
assert(~isempty(obj.imaging_source),'No imaging source selected, please select one and re-run.')

if isempty(managers.Imaging.modules) || isempty(managers.Stages.modules)
    error('%s requires both active Imaging and Stages modules',class(obj))
end
if length(managers.Imaging.modules)>1
    answer = questdlg(sprintf('%s is current active imaging module; use this module for tracking?',class(managers.Imaging.active_module)), ...
        'Tracking Imaging Module', ...
        'Yes','No','Yes');
    assert(~strcmp(answer,'No'),'Select desired module as active imaging module and rerun')
end
if length(managers.Stages.modules)>1
    answer = questdlg(sprintf('%s is current active stage module; use this module for tracking?',class(managers.Stages.active_module)), ...
        'Tracking Stage Module', ...
        'Yes','No','Yes');
    assert(~strcmp(answer,'No'),'Select desired module as active stage module and rerun')
end
obj.imaging_source.arm; % Arm imaging source for experiment
% Initialize with whatever data user chose
if obj.continue_experiment
    assert(~isempty(obj.data),'No data from memory, try loading experiment from file (in Save Settings panel)!')
    if ~isempty(obj.analysis)
        status.String = 'Checking analysis file'; drawnow;
        obj.primary_validate_analysis(); % Run experiment's validation
    end
    % Tag all this data as not new by incrementing continued flag
    nsites = length(obj.data.sites);
    for i = 1:nsites
        status.String = sprintf('Incrementing continued flag on loaded data (%i/%i).',i,nsites);
        drawnow limitrate;
        for j = 1:length(obj.data.sites(i).experiments)
            obj.data.sites(i).experiments(j).continued = obj.data.sites(i).experiments(j).continued + 1;
        end
    end
else % Start a new experiment
    assert(isempty(obj.analysis),'Analysis loaded. Did you mean to continue an experiment?')
    obj.data = [];
    sites = obj.AcquireSites(managers);
    if obj.imaging_source.source_on
        obj.imaging_source.off;
    end
    obj.data.image.image = sites.image;
    obj.data.image.meta = sites.meta;
    for i = 1:size(sites.positions,1)
        obj.data.sites(i).position = sites.positions(i,:);
        obj.data.sites(i).experiments = struct('name',{},'prefs',{},'err',{},'completed',{},'skipped',{},'continued',{},'redo_requested',{});
    end
end

%set up looping if breadth or depth
nsites = length(obj.data.sites);
switch obj.run_type
    case obj.SITES_FIRST
        [Y,X] = meshgrid(1:nexps,1:nsites);
    case obj.EXPERIMENTS_FIRST
        [X,Y] = meshgrid(1:nsites,1:nexps);
    otherwise
        error('Unknown run_type %s',obj.run_type)
end
run_queue = [X(:),Y(:)];
obj.reset_meta();
obj.meta.prefs = obj.prefs2struct;
obj.meta.errs = struct('site',{},'exp',{},'err',{});
obj.meta.tstart = datetime('now');
dP = [0,0,0]; % Cumulative tracker offset
runstart = tic;
obj.PreRun(status,managers,ax);
err = [];
try
    for repetition = 1:obj.repeat
        for i=1:size(run_queue,1)
            try
                site_index = run_queue(i,1);
                exp_index = run_queue(i,2);
                status.String = sprintf('Searching for next experiment to run\nSite: %i/%i\nExperiment: %i/%i...',site_index,nsites,exp_index,nexps);
                drawnow limitrate;
                assert(~obj.abort_request,'User aborted'); % Allows aborting before running any experiments
                experiment = obj.experiments(exp_index); %grab experiment instance
                mask = ismember({obj.data.sites(site_index).experiments.name},class(experiment));
                last_attempt = min([[obj.data.sites(site_index).experiments(mask).continued] Inf]); % Abort could leave a gap (Inf for first time through)
                prev_mask = and(mask,[obj.data.sites(site_index).experiments.continued]==last_attempt); % Previous run
                % Check redo flag for this site and this experiment
                redo = false;
                if ~isempty(obj.analysis) && ~isempty(obj.analysis.sites(site_index,exp_index).redo)
                    try
                        redo = logical(obj.analysis.sites(site_index,exp_index).redo);
                        assert(all(islogical(redo)) && isscalar(redo),'Redo flag from analysis file must be a logical scalar value if it exists.');
                    catch redo_err
                        redo = false;
                        warning('AUTOEXP:analysis','Site %i, Experiment Index: %i: %s',site_index,exp_index,redo_err.message)
                    end
                    for j = find(prev_mask) % Update previous run's redo flag
                        obj.data.sites(site_index).experiments(j).redo_requested = redo;
                    end
                end
                if ~redo && (any(prev_mask) && all([obj.data.sites(site_index).experiments(prev_mask).completed] &...
                                               not([obj.data.sites(site_index).experiments(prev_mask).skipped])))
                    % If no redo request and there are any from last run,
                    % and all of them are completed and not skipped,
                    % then skip running again. Remember, any([]) == false
                    obj.logger.log(sprintf('Skipping site %i, experiment %s',site_index,class(experiment)),obj.logger.DEBUG);
                    continue
                end
                if isempty(obj.patch_functions{exp_index})
                    params = struct; %initialize as empty struct, which has size 1 but no fields
                else
                    params = obj.(obj.patch_functions{exp_index})(obj.data.sites(site_index),site_index);%get parameters as determined from prior experiments at this site
                end
                if ~isempty(params)
                    managers.Stages.move([obj.data.sites(site_index).position(1)+dP(1),...
                                          obj.data.sites(site_index).position(2)+dP(2),...
                                          obj.data.sites(site_index).position(3)+dP(3)]); %move to site
                    if exp_index==1
                        % This is to get a metric reading, the thresh of false, instructs tracker to not perform track
                        [dx,dy,dz,metric] = track_func(managers,obj.imaging_source,false);
                        if ~all(isnan([dx,dy,dz]))
                            obj.fatal_flag = true;
                            error('Fatal: Tracker should not have tracked on first track of experiment!');
                        end
                        obj.tracker(end+1,:) = [dx,dy,dz,metric,toc(runstart),site_index];
                    end
                    for j = 1:length(params)
                        obj.data.sites(site_index).experiments(end+1).name = class(experiment);
                        obj.data.sites(site_index).experiments(end).continued = 0;
                        obj.data.sites(site_index).experiments(end).prefs = struct();
                        obj.data.sites(site_index).experiments(end).err = [];
                        obj.data.sites(site_index).experiments(end).completed = false;
                        obj.data.sites(site_index).experiments(end).skipped = false;
                        obj.data.sites(site_index).experiments(end).redo_requested = false;
                    end
                else
                    % No need to move stage if nothing to do here
                    obj.data.sites(site_index).experiments(end+1).name = class(experiment);
                    obj.data.sites(site_index).experiments(end).continued = 0;
                    obj.data.sites(site_index).experiments(end).prefs = struct();
                    obj.data.sites(site_index).experiments(end).err = [];
                    obj.data.sites(site_index).experiments(end).completed = true;
                    obj.data.sites(site_index).experiments(end).skipped = true;
                    obj.data.sites(site_index).experiments(end).redo_requested = false;
                end
                niter = length(params);
                for j=1:niter
                    local_exp_index = length(obj.data.sites(site_index).experiments)-length(params)+j; % So sorry
                    try
                        fields = fieldnames(params(j)); %grab list of parameter names
                        for k = 1:length(fields) %write all parameters to experiment
                            if ~ismember(fields{k},experiment.prefs)
                                warning('Parameter %s is not preference of %s, and thus may not be saved.',fields{k},class(experiment));
                            end
                            experiment.(fields{k}) = params(j).(fields{k});
                        end
                        msg = sprintf('Running iteration %i/%i of %s on site %i/%i',j,niter,class(experiment),site_index,nsites);
                        obj.logger.log(msg,obj.logger.DEBUG)
                        status.String = msg;
                        drawnow;
                        obj.data.sites(site_index).experiments(local_exp_index).prefs = experiment.prefs2struct;
                        obj.data.sites(site_index).experiments(local_exp_index).tstart = datetime('now');
                        if ~isempty(obj.prerun_functions{exp_index})
                            obj.(obj.prerun_functions{exp_index})(experiment);
                        end
                        RunExperiment(obj,managers,experiment,ax)
                        obj.data.sites(site_index).experiments(local_exp_index).data = experiment.GetData;
                        obj.data.sites(site_index).experiments(local_exp_index).tstop = datetime('now');
                        obj.data.sites(site_index).experiments(local_exp_index).dP = dP;
                        obj.data.sites(site_index).experiments(local_exp_index).completed = true;
                        drawnow; assert(~obj.abort_request,'User aborted');
                        
                        %track
                        curr_time = toc(runstart);
                        if curr_time >= obj.min_tracking_dt
                            if curr_time >= obj.max_tracking_dt
                                [dx,dy,dz,metric] = track_func(managers,obj.imaging_source,true);
                                obj.tracker(end+1,:) = [dx,dy,dz,metric,curr_time,site_index];
                            else
                                last_track = find(obj.tracker(:,6)==site_index,1,'last');
                                [dx,dy,dz,metric] = track_func(managers,obj.imaging_source,obj.tracking_threshold*obj.tracker(last_track,4));
                                obj.tracker(end+1,:) = [dx,dy,dz,metric,curr_time,site_index];
                            end
                            if any(isnan([dx,dy,dz]))
                                obj.fatal_flag = true;
                                error('Fatal: Tracker returned NaN value during tracking routine! A value of 0 should be returned if no update is necessary.');
                            end
                            dP = dP + [dx, dy, dz];
                        else % Update metric
                            [dx,dy,dz,metric] = track_func(managers,obj.imaging_source,false);
                            if ~all(isnan([dx,dy,dz]))
                                obj.fatal_flag = true;
                                error('Fatal: Tracker called in non-track mode, but still tracked.');
                            end
                            obj.tracker(end+1,:) = [dx,dy,dz,metric,curr_time,site_index];
                        end
                    catch param_err
                        if obj.fatal_flag
                            rethrow(param_err);
                        end
                        obj.data.sites(site_index).experiments(local_exp_index).err = param_err;
                        err_struct.site = site_index;
                        err_struct.exp = exp_index;
                        err_struct.err = param_err;
                        obj.meta.errs(end+1) = err_struct;
                    end
                end
            catch queue_err
                if obj.fatal_flag
                    rethrow(queue_err);
                end
                err_struct.site = site_index;
                err_struct.exp = exp_index;
                err_struct.err = queue_err;
                obj.meta.errs(end+1) = err_struct;
                obj.logger.logTraceback(sprintf('Error on queue index %i (repetition %i): %s',i,repetition,queue_err.message),...
                        queue_err.stack,Base.Logger.ERROR);
            end
            drawnow; assert(~obj.abort_request,'User aborted');
        end
    end
catch err
end
obj.meta.tstop = datetime('now');
obj.meta.tracker = obj.tracker;
obj.PostRun(status,managers,ax)
obj.continue_experiment = false;
if ~isempty(err)
    rethrow(err)
end
end


function [dx,dy,dz,metric] = track_func(managers,imaging_source,track_thresh)
imaging_source.on;
[dx,dy,dz,metric] = Experiments.AutoExperiment.AutoExperiment_invisible.Track(managers.Imaging,managers.Stages,track_thresh);
imaging_source.off;
end

function RunExperiment(obj,managers,experiment,ax)
[abortBox,abortH] = ExperimentManager.abortBox(class(experiment),@(~,~)obj.abort);
try
    drawnow; assert(~obj.abort_request,'User aborted');
    if ~isempty(experiment.path) %if path defined, select path
        managers.Path.select_path(experiment.path);
    end
    obj.current_experiment = experiment;
    cla(ax,'reset');
    subplot(1,1,1,ax); % Re-center
    experiment.run(abortBox,managers,ax);
    obj.current_experiment = [];
catch exp_err
    delete(abortH);
    rethrow(exp_err)
end
delete(abortH);
end
