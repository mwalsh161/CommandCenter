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
    obj.meta.angles = obj.angles; %Angles corresponding to each spectrum

    % Check that rot is not empty and valid
    assert(~isempty(obj.rot) && isvalid(obj.rot),'Motor SN must be a valid number.')

    try
        % Home rotation mount
        if ~obj.rot.Homed
            status.String = 'Homing motor'; drawnow;
            
            obj.rot.home()
            pause4Move(5)
        end
        
        % Sweep through polarisation and get spectra
        Nangles = length(obj.angle_list);
        obj.data.angle = struct('wavelength',[],'intensity',[],'err',cell(1,Nangles));
        for i = 1:Nangles
            theta = obj.angle_list(i);
            status.String = sprintf( 'Navigating to %g (%i/%i)', theta, ...
                i, Nangles); drawnow;
            obj.rot.move(theta)
            pause4Move(5)
            status.String = sprintf( 'Measuring at %g (%i/%i)', theta, ...
                i, Nangles); drawnow;
            
            RunExperiment(obj, managers, obj.spec_experiment, i, ax)
            tempDat = obj.spec_experiment.GetData;
            obj.data.angle(i).wavelength = tempDat.wavelength;
            obj.data.angle(i).intensity = tempDat.intensity;
            drawnow; assert(~obj.abort_request,'User aborted');
        end
        
        %Get meta data from spectrum experiment
        obj.meta.spec_meta = tempData.meta;
        obj.meta.diamondbase = tempData.diamondBase;



    catch err
    end
    % CLEAN UP CODE %
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end

% Wait until motor stops moving, or timeout
function pause4Move(maxTime)
tic
while obj.rot.Moving && (toc < maxTime)
    drawnow
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
        experiment.run(abortBox,managers,ax);
    catch exp_err
        obj.data.sites(site_index).experiments(end).err = exp_err;
        delete(abortH);
        rethrow(exp_err)
    end
    delete(abortH);
end