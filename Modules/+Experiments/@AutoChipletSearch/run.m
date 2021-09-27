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
    galvo_ax = subplot(1,2,1,'parent',panel);
    cam_ax = subplot(1,2,2,'parent',panel);
    
    obj.laser.off;
    obj.whitelight.off;

    try

        for i = 1:obj.chiplet_number(1)
            % scan through chiplet x
            for j = 1:obj.chiplet_number(2)
                % scan through chiplet y

                % Go to camera path
                obj.whitelight.on;
                if managers.Path.active_path ~= "camera" %"camera"
                    managers.Path.select_path('camera')
                end
                
                img = imagesc(nan(obj.camera.resolution(1), obj.camera.resolution(2)),'parent',cam_ax);
                obj.camera.snap(img)
                obj.camera_img = img.CData;
                %image = obj.camera.snapImage();
                figure; imagesc(img.CData);
                %figure; imagesc(image)

                % Focus
                % Just doing one focus type for the moment with the Kinesis stage
                obj.AutoFocus(obj.autofocus_range, obj.autofocus_step_size);
%                 try
%                     obj.AutoFocus(obj.fine_autofocus_range, obj.fine_autofocus_step_size, obj.fine_autofocus_stage);
%                 catch err
%                     % If autofocus doesn't work, try coarse autofocus before giving up
%                     obj.AutoFocus(obj.coarse_autofocus_range, obj.coarse_autofocus_step_size, obj.fine_autofocus_stage);
%                     obj.AutoFocus(obj.fine_autofocus_range, obj.fine_autofocus_step_size, obj.fine_autofocus_stage);
%                 end

                % Center chiplet
                obj.centering_info.shiftinfo = obj.ShiftToCenter;
                
                % Go to confocal scan
                obj.whitelight.off;
                obj.laser.on
                managers.Path.select_path('APD')
                
                % Process image to get the ROI for confocal measurements
                % chiplet_points_cam = importdata('camera_points.txt');
                % chiplet_points_galvo = importdata('galvo_points.txt');
                % mapping_params = obj.GetMappingParams(chiplet_points_cam, chiplet_points_galvo);
                mapping_parameters = [6.218949313978595e-04, 9.321938000411700e-04, -0.784671780923267; -0.001235216086788, 9.167178397291309e-04, 0.333263767338728];
                new_ROI = obj.FindROI(mapping_parameters);
                obj.galvo.ROI = new_ROI;%[-0.3331 0.1825;-0.0061 0.4256]; %obj.FindROI(img.CData, mapping_params); % example to switch ROI
                obj.galvo.resolution = [200 200];
                img = imagesc(nan(obj.galvo.resolution(1), obj.galvo.resolution(2)),'parent',galvo_ax);
                obj.galvo.snap(img); % example of doing galvo scan
                figure; imagesc(img.CData);
%                 
                obj.laser.off
%                 functiontofindthecenter(img)

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
