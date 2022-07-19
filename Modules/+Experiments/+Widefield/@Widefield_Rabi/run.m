function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;

    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.meta.prefs = obj.prefs2struct;
    obj.meta.freq_list = obj.freq_list;
    obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);

    % Setup run & graphics
    obj.setup_run()


    % Set up signal generator
    obj.SignalGenerator.MWPower = obj.MW_Power;
    obj.SignalGenerator.MWFrequency = obj.MW_freq;
    obj.SignalGenerator.on();

    % Set camera to accept capture on external trigger
    old_trigger = obj.Camera.trigger;
    old_exposure = obj.Camera.exposure;
    obj.Camera.trigger = 'External';
    MW_time = obj.MW_Times_vals(1); % Initialise to first value    
    obj.Camera.exposure = (2*obj.MW_Pad + MW_time + obj.Laser_Time)*obj.samples;

    % Set up laser
    obj.Laser.arm();

    % Open pulse blaster
    obj.pbH.open();

    % Pre-allocate obj.data
    n_MW_times = numel(obj.MW_Times_vals);
    ROI_size = [obj.ROI(1,2)-obj.ROI(1,1), obj.ROI(2,2)-obj.ROI(2,1)];
    cam_ROI_size = [obj.Camera.ROI(1,2)-obj.Camera.ROI(1,1), obj.Camera.ROI(2,2)-obj.Camera.ROI(2,1)];
    obj.data = NaN(obj.averages, n_MW_times, ROI_size(1), ROI_size(2), 2);
    n_pixels_of_interest = numel(obj.pixel_x);
    pixels_of_interest = NaN(obj.averages, n_MW_times, n_pixels_of_interest, 2);

    % Setup graphics
    [ax_im, ~, panel] = obj.setup_image(ax, NaN(cam_ROI_size(1), cam_ROI_size(2)), obj.meta.pixels_of_interest, obj.ROI); % Plot camera image

    [plotH, ax_rabi, ax_intensity] = obj.setup_plotting(panel, obj.MW_Times_vals, n_pixels_of_interest);

    try
        % EXPERIMENT CODE %
        for i = 1:obj.averages
            for j = 1:n_MW_times
                
                % Setup camera and pulse sequence
                MW_time = obj.MW_Times_vals(j);
                exposure = (2*obj.MW_Pad + MW_time + obj.Laser_Time)*obj.samples;
                obj.Camera.exposure = exposure;

                % Load pulse sequence to pulse blaster
                pulseSeq = obj.BuildPulseSequence(MW_time, 0);
                program = pulseSeq.compile();

                % Capture data
                obj.pbH.load(program);
                obj.Camera.snap_only;
                obj.pbH.start;
                im = obj.Camera.get_image;

                % Allocate data
                obj.data(i,j,:,:,1) = im;

                % Pixels of interest
                for k = 1:n_pixels_of_interest
                    pixels_of_interest(i,j,k,1) = im(obj.pixel_x(k), obj.pixel_y(k));
                end

                % Normalisation
                if obj.normalisation
                    % Load pulse sequence to pulse blaster
                    pulseSeq = obj.BuildPulseSequence(MW_time, 1);
                    program = pulseSeq.compile();

                    % Capture data
                    obj.pbH.load(program);
                    obj.Camera.snap_only;
                    obj.pbH.start;
                    im = obj.Camera.get_image;

                    % Allocate data
                    obj.data(i,j,:,:,2) = im;

                    % Pixels of interest
                    for k = 1:n_pixels_of_interest
                        pixels_of_interest(i,j,k,2) = im(obj.pixel_x(k), obj.pixel_y(k));
                    end
                else
                    % If no normalisation, just take first data point
                    obj.data(i,j,:,:,2) = obj.data(i,1,:,:,1);
                    pixels_of_interest(i,j,:,2) = pixels_of_interest(i,1,:,1);
                end

                % Update data
                obj.update_graphics
            end
        end
    catch err
    end
    % CLEAN UP CODE %
    obj.Camera.trigger = old_trigger;
    obj.Camera.exposure = old_exposure;
    obj.SignalGenerator.off();

    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
