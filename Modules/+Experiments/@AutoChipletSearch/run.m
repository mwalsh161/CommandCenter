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
%                     managers.Path.select_path('camera')
                    managers.Path.select_path('camera')
                end
                
                %img = imagesc(nan(obj.camera.resolution(1), obj.camera.resolution(2)),'parent',image_ax);
                %obj.camera.snap(img)
                image = obj.camera.snapImage();
                %figure; imagesc(img.CData);
                figure; imagesc(image)

%                 % Focus
%                 try
%                     obj.camera.ContrastFocus(managers, obj.fine_autofocus_range, obj.fine_autofocus_step_size, obj.fine_autofocus_stage, false);
%                 catch err
%                     % If autofocus doesn't work, try coarse autofocus before giving up
%                     obj.camera.ContrastFocus(managers, obj.coarse_autofocus_range, obj.coarse_autofocus_step_size, obj.coarse_autofocus_stage, false);
%                     obj.camera.ContrastFocus(managers, obj.fine_autofocus_range, obj.fine_autofocus_step_size, obj.fine_autofocus_stage, false);
%                 end

                % Center chiplet
                

                % Go to confocal scan
                obj.whitelight.off;
                obj.laser.on
%               managers.Path.select_path('APD')
                managers.Path.select_path('APD')
                

                % Process image to get points
                chiplet_points_cam = [578 277; 551 283; 550 285; 555 284; 404 408; 402 417; 567 637; 574 634; 580 647; 589 638; 597 633; 594 628;754 503; 743 497; 739 510; 669 566; 685 579; 481 341];
                chiplet_points_galvo = [45 36; 40 40; 40 40; 40 40; 50 169; 50 169; 153 160; 154 156; 159 157; 159 157; 159 157; 159 157; 151 28; 149 28; 150 35; 152 90; 159 90; 47 102];
                % image = img.CData;
                % chiplet_points_cam = importdata('camera_points.txt');
                % chiplet_points_galvo = importdata('galvo_points.txt');
                % mapping_params = obj.GetMappingParams(chiplet_points_cam, chiplet_points_galvo);
                mapping_parameters = [6.218949313978595e-04, 9.321938000411700e-04, -0.784671780923267; -0.001235216086788, 9.167178397291309e-04, 0.333263767338728];

                m1 = mapping_parameters(1,1);
                n1 = mapping_parameters(1,2);
                l1 = mapping_parameters(1,3);
                m2 = mapping_parameters(2,1);
                n2 = mapping_parameters(2,2);
                l2 = mapping_parameters(2,3);
            
                image_cam_edge = edge(image, 'Canny', 0.2);
                se = strel('sphere',5);
                image_cam_dilate = imdilate(image_cam_edge, se);
                image_cam_filtered = bwareafilt(image_cam_dilate,1);
                stats = regionprops(image_cam_filtered,'Centroid', 'Orientation', 'Extrema');
                
                figure
                imshow(image_cam_edge)
                figure
                imshow(image_cam_dilate)  
                imshow(image_cam_filtered)
                hold on
                scatter(stats.Extrema(:,1), stats.Extrema(:,2), 'green','d', 'filled')
            
                threshold_dist = 10;
                points = zeros(4,2);
                n_points = 0;
                for i = 1 : length(stats.Extrema)
                    for j = i + 1 :length(stats.Extrema)
                        delta_x = stats.Extrema(i, 1) - stats.Extrema(j, 1);
                        delta_y = stats.Extrema(i, 2) - stats.Extrema(j, 2);
                        if delta_x == 0 || delta_y == 0
                            n_points = n_points + 1;
                            points(n_points,:) = [(stats.Extrema(i, 1) + stats.Extrema(j, 1))/2, (stats.Extrema(i, 2) + stats.Extrema(j, 2))/2];
                        elseif norm([delta_x, delta_y]) < threshold_dist
                            n_points = n_points + 1;
                            points(n_points, :) = [(stats.Extrema(i, 1) + stats.Extrema(j, 1))/2, (stats.Extrema(i, 2) + stats.Extrema(j, 2))/2];
                        end
                    end
                end
            
                points_galvo = zeros(4, 2);
                n_point = 1;
                for point = 1 : length(points)
                    points_galvo(n_point, :) = [m1, n1; m2, n2] * [points(n_point, 1); points(n_point, 2)] + [l1; l2];
                    n_point = n_point + 1;
                end
            
                chiplet_center_galvo = mean(points_galvo, 1);
                n_point = 1;
                for point = 1 : length(points)
                    if points_galvo(n_point, 1) < chiplet_center_galvo(1)
                        points_galvo(n_point, 1) = points_galvo(n_point, 1) - 0.15;
                    else
                        points_galvo(n_point, 1) = points_galvo(n_point, 1) + 0.15;
                    end
                    n_point = n_point + 1;
                end
            
                %new_ROI = [min(points_galvo(:,1)), max(points_galvo(:,1));min(points_galvo(:,2)),max(points_galvo(:,2))]

                %if any(new_ROI > 1)
                %    error('new_ROI exceeded the range.')
                %end
                new_ROI = obj.FindROI(image, mapping_parameters);
                obj.galvo.ROI = new_ROI;%[-0.3331 0.1825;-0.0061 0.4256]; %obj.FindROI(img.CData, mapping_params); % example to switch ROI
                obj.galvo.resolution = [200 200];
                img = imagesc(nan(obj.galvo.resolution(1), obj.galvo.resolution(2)),'parent',image_ax);
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
