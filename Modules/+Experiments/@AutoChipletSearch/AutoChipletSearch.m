classdef AutoChipletSearch < Modules.Experiment
    %AutoChipletSearch Description of experiment
    % Useful to list any dependencies here too

    properties(SetObservable,AbortSet)
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
                scatter(D(7:end,D(7:end,2),'g+','parent',image_ax) % target spectrum point
            end

            points = D(7:end,:)
        end
    end
end
