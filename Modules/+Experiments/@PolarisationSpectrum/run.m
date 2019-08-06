function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;
    % Edit here down (save data to obj.data)
    % Tips:
    % - If using a loop, it is good practice to call:
    %     drawnow; assert(~obj.abort_request,'User aborted.');
    %     as frequently as possible
    % - try/catch/end statements useful for cleaning up
    % - You can get a figure-like object (to create subplots) by:
    %     panel = ax.Parent; delete(ax);
    %     ax(1) = subplot(1,2,1,'parent',panel);
    % - drawnow can be used to update status box message and any plots

    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.meta.prefs = obj.prefs2struct;
    obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);
    obj.meta.angles = obj.angle_list; %Angles corresponding to each spectrum

    % Check that rot is not empty and valid
    assert(~isempty(obj.rot) && isvalid(obj.rot),'Motor SN must be a valid number; motor handle may have been deleted. Check motor serial number/APT Config')

    try
        % Home rotation mount
        if ~obj.rot.Homed
            status.String = 'Homing motor'; drawnow;
            
            obj.rot.home();
            pause4Move(obj, obj.motor_home_time);
        end
        
        % Sweep through polarisation and get spectra
        Nangles = length(obj.angle_list);
        obj.data.angle = struct('wavelength',[],'intensity',[],'err',cell(1,Nangles));

        for i = 1:Nangles
            theta = obj.angle_list(i);
            status.String = sprintf( 'Navigating to %g (%i/%i)', theta, ...
                i, Nangles); drawnow;
            obj.rot.move(theta);
            pause4Move(obj, obj.motor_move_time);
            status.String = sprintf( 'Measuring at %g (%i/%i)', theta, ...
                i, Nangles); drawnow;
            
            RunExperiment(obj, managers, obj.spec_experiment, i, ax)
            tempDat = obj.spec_experiment.GetData;
            obj.data.angle(i).wavelength = tempDat.wavelength;
            obj.data.angle(i).intensity = tempDat.intensity;

            % Store data that is likely to change from run to run
            all_fields = fieldnames(tempDat.meta);
            volatile_fields = {'TACQ','TMETA','TFETCH','TLOAD','READOUT_TIME_MS','ACTUAL_TEMP'}; % Fields which will have small fluctuations between runs. Should be updated if Spectrum is changed.
            nonvolatile_fields = setdiff( all_fields, volatile_fields );
            tempDat_nonvolatile = rmfield(tempDat.meta, volatile_fields);
            tempDat_volatile = rmfield(tempDat.meta, nonvolatile_fields);

            obj.meta.volatile(i) = tempDat_volatile;
            

            % Check that the remaining settings for spectrum were not changed within the loop
            if i > 1
                assert(isequal(lastMeta,tempDat_nonvolatile),'Meta data changed in sub-experiment')
            end
            lastMeta = tempDat_nonvolatile

            drawnow; assert(~obj.abort_request,'User aborted');
        end
        
        %Get meta data from spectrum experiment
        obj.meta.spec_meta = tempDat_nonvolatile;
        obj.meta.diamondbase = tempDat.diamondbase;



    catch err
    end
    % CLEAN UP CODE %
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end

% Wait until motor stops moving, or timeout
function pause4Move(obj,maxTime)
t = tic;
while (obj.rot.Moving || ~obj.rot.Homed) && (toc(t) < maxTime)
    drawnow
    if toc(t) > maxTime
        error('Motor timed out while moving')
    end
end
end

% Run spectrum experiment and nicely handle images
function RunExperiment(obj,managers,experiment,site_index,ax)
    [abortBox,abortH] = ExperimentManager.abortBox(class(experiment),@(~,~)obj.abort);
    try
        drawnow; assert(~obj.abort_request,'User aborted');
        if ~isempty(experiment.path) %if path defined, select path
            managers.Path.select_path(experiment.path);
        end
        cla(ax,'reset');
        obj.active_experiment = experiment;
        experiment.run(abortBox,managers,ax);
        obj.active_experiment = [];
    catch exp_err
        obj.data.angles(site_index).err = exp_err;
        delete(abortH);
        rethrow(exp_err)
    end
    delete(abortH);
end