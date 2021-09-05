classdef AutoChipletSearch < Modules.Experiment
    %AutoChipletSearch Does a measurement on an array of chiplets
    % Useful to list any dependencies here too

    properties(SetObservable,GetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        chiplet_spacing = Prefs.DoubleArray([65 65], 'units','um','help_text','Array of x and y spacing of chiplets');
        chiplet_number = Prefs.DoubleArray([2 2], 'units','um','help_text','Number of chiplets along x and y');
        
        fine_autofocus_stage = Prefs.ModuleInstance('help_text','Stage that does fine autofocusing (probably piezo)');
        fine_autofocus_range = Prefs.DoubleArray([0 1], 'units', 'um', 'help_text', 'Range around current stage position that autofocus will search to find focus');
        fine_autofocus_step_size = Prefs.Double(0.1, 'units', 'um', 'help_text','Step size to use for fine autofocusing','min',0);
        
        coarse_autofocus_stage = Prefs.ModuleInstance('help_text','Stage that does coarse autofocusing (probably setpper)');
        coarse_autofocus_range = Prefs.DoubleArray([-1 1], 'units', 'um', 'help_text', 'Range around current stage position that autofocus will search to find focus');
        coarse_autofocus_step_size = Prefs.Double(0.1, 'units', 'um', 'help_text','Step size to use for autofocusing','min',0);
        
        camera = Prefs.ModuleInstance('help_text','White light camera imaging module for focusing');
        galvo = Prefs.ModuleInstance('help_text','Galvo scanning imaging module for confocal scanning');
        laser = Prefs.ModuleInstance('help_text','laser used for galvo confocal scanning');
        whitelight = Prefs.ModuleInstance('help_text','White light used for camera focusing');
        
        experiment = Prefs.ModuleInstance('help_text','Experiment to run at each point')
    end
    properties
        prefs = {'chiplet_spacing','chiplet_number','fine_autofocus_stage','fine_autofocus_range','fine_autofocus_step_size','coarse_autofocus_stage','coarse_autofocus_range','coarse_autofocus_step_size','camera','galvo'};
        %show_prefs = {};   % Use for ordering and/or selecting which prefs to show in GUI
        %readonly_prefs = {}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
        data = [] % Useful for saving data from run method
        meta = [] % Useful to store meta data in run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = AutoChipletSearch()
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        run(obj,status,managers,ax) % Main run method in separate file

        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function dat = GetData(obj,stageManager,imagingManager)
            % Callback for saving methods
            meta = stageManager.position;
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        function points = find_chiplet_spots(n_channels,n_points,image,image_ax)
            % Takes an image of a single chiplet with n_channel waveguides as an input and outputs a set of n_points points in to perform experiment at
            % Plots the image detection results given the input panel if supplied

            C=corner(image.image); %get all the corner points from galvo scan
            if isvalid(image_ax)
                imagesc(image.image,'parent',image_ax);
                colormap(image_ax,'bone')
                axis(image_ax,'image');
                set(image_ax,'YDir','normal');
                hold(image_ax, 'on')
                scatter(C(:,1),C(:,2),'r*','parent',image_ax) %show the galvo point with the image
            end

            imagex=max(size(image.image(:,1)));
            imagey=max(size(image.image(1,:)));
            ximage=image.ROI(1,1):(image.ROI(2,1)-image.ROI(1,1))/(imagex-1):image.ROI(2,1);
            yimage=image.ROI(1,2):(image.ROI(2,2)-image.ROI(1,2))/(imagex-1):image.ROI(2,2);

            %fitting with a line nearly parallel to x axis, y=(k-nK/2)x/tiltK+i
            nK=100;
            tiltK=1000;
            errmax=5; %frame point tolerence

            %Convolution of the gaussian along y for fitting the long line region in galvo scan
            % Find the first frame axis by sweeping intercept and slopes of lines, and finding one that best aligns with corners
            for i=1:imagey
                for k=1:nK
                    for j=1:size(C(:,1))
                        s0(i,k,j)=exp(-(C(j,2)-(k-nK/2)/tiltK*C(j,1)-i)^2/2);
                    end
                    s1(i,k)=sum(s0(i,k,:));
                end
            end

            % Find 2nd best fit (assuming that frame doesn't change slope)
            [i0,k0]=find(s1==max(max(s1))); %fit the best y=(k0-nK/2)x/tiltK+i0;
            for i=1:imagey
                for j=1:size(C(:,1))
                    s2(i,j)=exp(-(C(j,2)-(k0-nK/2)/tiltK*C(j,1)-i)^2/2);
                end
                s3(i)=sum(s2(i,:)');
            end

            [p1,p2]=findpeaks(s3);
            p1(p1==max(p1))=0; %remove the best fit from y=(k0-nK/2)x/tiltK+i0;
            i1=p2(find(p1==max(p1)));
            %Using the same slope k0, find the other frame with the best fit y=(k0-nK/2)x/tiltK+i1;
            out=[i0,i1,-(k0-nK/2)/tiltK]
            % Try to get the four corner of the frame ([x1, y1],[x2, y2], [x3, y3],
            % [x4, y4])
            x1=imagey;
            x2=0;
            for j=1:size(C(:,1))
            if (C(j,2)-(k0-nK/2)/tiltK*C(j,1)-i0)^2<errmax^2
                x1=min(x1,C(j,1));
                if x1==C(j,1)
                    j1=j;
                end
                x2=max(x2,C(j,1));
                if x2==C(j,1)
                    j2=j;
                end
            end
            end
            x3=imagey;
            x4=0;
            for j=1:size(C(:,1))
            if (C(j,2)-(k0-nK/2)/tiltK*C(j,1)-i1)^2<errmax^2
                x3=min(x3,C(j,1));
                if x3==C(j,1)
                    j3=j;
                end
                x4=max(x4,C(j,1));
                if x4==C(j,1)
                    j4=j;
                end
            end
            end

            D(1,1)=x1;
            D(1,2)=C(j1,2);
            D(2,1)=x2;
            D(2,2)=C(j2,2);
            D(3,1)=x3;
            D(3,2)=C(j3,2);
            D(4,1)=x4;
            D(4,2)=C(j4,2);

            D(5,1)=(D(1,1)+D(3,1))/2; % frame center 1 x
            D(5,2)=(D(1,2)+D(3,2))/2; % frame center 1 y
            D(6,1)=(D(2,1)+D(4,1))/2; % frame center 2 x
            D(6,2)=(D(2,2)+D(4,2))/2; % frame center 2 y

            for i=1:n_channel
                D(6+i,1)=D(5,1)+(D(6,1)-D(5,1))*i/(n_channel+1);
                D(6+i,2)=D(5,2)+(D(6,2)-D(5,2))*i/(n_channel+1); % add n_points support later here
            end

            % Linear interpolation of the target point
            if isvalid(image_ax)
                scatter(D(1:6,1),D(1:6,2),'g*','parent',image_ax) % frame
                scatter(D(7:end),D(7:end,2),'g+','parent',image_ax) % target spectrum point
            end

            points = D(7:end,:);
        end

        function new_ROI = FindROI(obj, mapping_parameters)%mapping_parameters
            % Find the region of interest in galvo voltages from the camera image and the mapping parameters describing the tranformation relation between camera and galvo images
            % image := grey scale camera image
            % mapping_parameters := [m1, n1, l1, m2, n2, l2] transformation parameters,
            % The galvo image coordinate (a,b) is related to the camera image coordinate (x,y) through:
            % (a,b) = [m1,n1;m2,n2]*[x,y]+[l1,l2]
            image = obj.camera.snapImage();
            figure; imagesc(image)

            m1 = mapping_parameters(1,1);
            n1 = mapping_parameters(1,2);
            l1 = mapping_parameters(1,3);
            m2 = mapping_parameters(2,1);
            n2 = mapping_parameters(2,2);
            l2 = mapping_parameters(2,3);
        
            image_cam_edge = edge(image, 'Canny', 0.2);
            se = strel('sphere',6);
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
                    points_galvo(n_point, 1) = points_galvo(n_point, 1) - 0.1;
                else
                    points_galvo(n_point, 1) = points_galvo(n_point, 1) + 0.1;
                end
                n_point = n_point + 1;
            end
        
            new_ROI = [min(points_galvo(:,1)), max(points_galvo(:,1));min(points_galvo(:,2)),max(points_galvo(:,2))];
        end
        
        function mapping_params = GetMappingParams(chiplet_points_cam,chiplet_points_galvo)

            len_img_galvo = 200;
        
            % ROI defined for the galvo scan
            ROI = [-0.3500 0.1825; -0.0061 0.4256];
        
            len = ROI(1, 2) - ROI(1, 1);
            wid = ROI(2, 2) - ROI(2, 1);
        
            % Calculate the galvo voltages for the chiplet corners
            chiplet_points_voltage_x = chiplet_points_galvo(:,1) / len_img_galvo .* len + ROI(1, 1);
            chiplet_points_voltage_y = chiplet_points_galvo(:,2) / len_img_galvo .* wid + ROI(2, 1);
        
            chiplet_points_camera_x = chiplet_points_cam(:, 1);
            chiplet_points_camera_y = chiplet_points_cam(:, 2);
        
            ft = fittype( 'm1 * x + n1 * y + l1', 'independent', {'x', 'y'}, 'dependent', 'z' );
            [fitresult1, gof1] = fit([chiplet_points_camera_x, chiplet_points_camera_y], chiplet_points_voltage_x, ft);
        
            ft = fittype( 'm2 * x + n2 * y + l2', 'independent', {'x', 'y'}, 'dependent', 'z' );
            [fitresult2, gof2] = fit([chiplet_points_camera_x, chiplet_points_camera_y], chiplet_points_voltage_y, ft);
        
            % calculate the transformation matrix variables from camera pixels to galvo voltages
            mapping_params(1,1) = fitresult1.m1;
            mapping_params(1,2) = fitresult1.n1;
            mapping_params(1,3) = fitresult1.l1;  
            mapping_params(2,1) = fitresult2.m2;
            mapping_params(2,2) = fitresult2.n2;
            mapping_params(2,3) = fitresult2.l2;
        end        
    end
end
