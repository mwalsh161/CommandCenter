function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;

    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.setup_run(managers)
    obj.meta.MW_Times = obj.MW_Times_vals;

    % Set up signal generator
    obj.SignalGenerator.MWPower = obj.MW_Power;
    obj.SignalGenerator.MWFrequency = obj.MW_freq*1e6;
    obj.SignalGenerator.on();

    % Set camera to accept capture on external trigger
    status.String = 'Camera loading';
    drawnow;
    if ~obj.Camera.initialized % Ensure camera is loaded
        obj.Camera.reload_toggle();
    end
    old_exposure = obj.Camera.exposure;
    old_trigger = obj.Camera.trigger;
    obj.Camera.trigger = 'External';
    MW_time = max(obj.MW_Times_vals); % Initialise to largest value    
    obj.Camera.exposure = (obj.camera_trig_time + 2*obj.camera_trig_delay + (2*obj.MW_Pad + MW_time + obj.Laser_Time)*obj.samples)/1000; % Exposure in ms

    % Set up laser
    obj.Laser.arm();

    % Open pulse blaster
    obj.pbH.open();

    % Pre-allocate obj.data
    n_MW_times = numel(obj.MW_Times_vals);
    ROI_size = [obj.ROI(1,2)-obj.ROI(1,1), obj.ROI(2,2)-obj.ROI(2,1)] + 1;
    cam_ROI_size = [obj.Camera.ROI(1,2)-obj.Camera.ROI(1,1), obj.Camera.ROI(2,2)-obj.Camera.ROI(2,1)];
    obj.data = NaN(obj.averages, n_MW_times, ROI_size(1), ROI_size(2), 2);
    n_pixels_of_interest = numel(obj.pixel_x);
    pixels_of_interest = NaN(obj.averages, n_MW_times, n_pixels_of_interest, 2);

    % Setup graphics
    [ax_im, ~, panel] = obj.setup_image(ax, zeros(cam_ROI_size(1), cam_ROI_size(2)), obj.meta.pixels_of_interest, obj.ROI); % Plot camera image

    [plotH, ax_rabi, ~] = obj.setup_plotting(panel, obj.MW_Times_vals, n_pixels_of_interest);
    hold(ax_rabi, 'on')
    current_freqH = plot(ax_rabi,NaN,NaN,'--r'); % Line to track current MW time
    hold(ax_rabi, 'off')

    try
        % EXPERIMENT CODE %
        for i = 1:obj.averages
            for j = 1:n_MW_times
                
                % Setup camera and pulse sequence
                MW_time = obj.MW_Times_vals(j);
                
                % Update line for current frequency
                current_freqH.XData = [1 1]*MW_time;
                current_freqH.YData = NaN(1,2); % To allow ylim to be calculated
                current_freqH.YData = get(ax_rabi,'ylim');
                
                
                status.String = sprintf('MW Time %0.3f us (%i/%i)\nAverage %i/%i', MW_time, j, n_MW_times, i, obj.averages);
                drawnow;

                % Load pulse sequence to pulse blaster
                pulseSeq = obj.BuildPulseSequence(MW_time, 0);
                program = pulseSeq.compile();

                % Capture data
                obj.pbH.load(program);
                obj.Camera.snap_only;
                obj.pbH.start;
                pause(obj.Camera.exposure/1000)
                im = obj.Camera.get_image;

                % Allocate data
                obj.data(i,j,:,:,1) = im(obj.ROI(1,1):obj.ROI(1,2),obj.ROI(2,1):obj.ROI(2,2));

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
                    obj.data(i,j,:,:,2) = im(obj.ROI(1,1):obj.ROI(1,2),obj.ROI(2,1):obj.ROI(2,2));

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
                obj.update_graphics(ax_im, plotH, obj.data, pixels_of_interest, im);
                drawnow; assert(~obj.abort_request,'User aborted.');
            end
        end
    catch err
    end
    % CLEAN UP CODE %
    obj.Camera.trigger = old_trigger;
    obj.Camera.exposure = old_exposure;
    obj.SignalGenerator.off();
    obj.pbH.close();

    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
