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

    panel = ax.Parent; delete(ax); % Get subplots
    % Image processing subplot
    image_ax = subplot(1,2,1,'parent',panel);

    % obj.laser.on;


    try

        for i = 1:obj.chiplet_number(1)
            % scan through chiplet x
            for j = 1:obj.chiplet_number(2)
                % scan through chiplet y

                % Go to camera path
                obj.whitelight.on;
                if managers.Path.active_path ~= "camera"
                    managers.Path.select_path('camera')
                end

                % Focus
                try
                    obj.camera.ContrastFocus(managers, obj.fine_autofocus_range, obj.fine_autofocus_step_size, obj.fine_autofocus_stage, false);
                catch err
                    % If autofocus doesn't work, try coarse autofocus before giving up
                    obj.camera.ContrastFocus(managers, obj.coarse_autofocus_range, obj.coarse_autofocus_step_size, obj.coarse_autofocus_stage, false);
                    obj.camera.ContrastFocus(managers, obj.fine_autofocus_range, obj.fine_autofocus_step_size, obj.fine_autofocus_stage, false);
                end

                % Center chiplet

                % Go to confocal scan
                % obj.whitelight.off;
                % managers.Path.select_path('APD')
                

                % Process image to get points
                img = obj.camera.snap

                % functiontofindthecenter(img)

                % Run experiment at points
                

            end
        end
    catch err
    end
    % CLEAN UP CODE %
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
