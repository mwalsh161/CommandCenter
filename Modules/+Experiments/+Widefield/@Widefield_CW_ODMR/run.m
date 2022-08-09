function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;
    
    % Make sure all prefs (except for pixel of interest) are non-empty
    for i = 1:length(obj.prefs)
        if ~contains(obj.prefs{i},'Pixel_of_Interest')
            assert(~isempty(obj.(obj.prefs{i})),sprintf('%s not specified.',obj.prefs{i}))
        end
    end

    % Make sure x and y coordinates for pixels of interest are the same
    assert(length(obj.pixel_x)==length(obj.pixel_y), 'Length of x and y coordinates of pixels of interest are not the same')

    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.meta.prefs = obj.prefs2struct;
    obj.meta.freq_list = obj.freq_list;
    obj.meta.pixels_of_interest = [obj.pixel_x; obj.pixel_y];
    obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);

    obj.Laser.arm;
    obj.SignalGenerator.MWPower = obj.MW_Power;
    obj.SignalGenerator.MWFrequency = obj.freq_list(1); % Just init to first point even though redundant
    obj.Camera.exposure = obj.Exposure;
    
    % Pre-allocate obj.data
    n = length(obj.freq_list);
    n_pixels_of_interest = length(obj.pixel_x);
    ROI_size = [obj.ROI(1,2)-obj.ROI(1,1), obj.ROI(2,2)-obj.ROI(2,1)] + 1;
    cam_ROI_size = [obj.Camera.ROI(1,2)-obj.Camera.ROI(1,1), obj.Camera.ROI(2,2)-obj.Camera.ROI(2,1)];
    obj.data = NaN(obj.averages,n,2,ROI_size(1),ROI_size(2)); % Data aranged with indices (average #)x(frequency)x(normalisation/data)x(x pixel)x(y pixel)
    pixels_of_interest = NaN(obj.averages, n, n_pixels_of_interest, 2);

    % Setup graphics
    obj.meta.image = obj.Camera.buffered_image;
    [ax_im, ~, panel] = obj.setup_image(ax, obj.meta.image, obj.meta.pixels_of_interest, obj.ROI); % Plot camera image
    [plotH, ax_data] = obj.setup_plotting(panel, obj.freq_list, obj.pixel_x, obj.pixel_y);
    hold(ax_data, 'on')
    current_freqH = plot(ax_data,NaN,NaN,'--r'); % Line to track current frequency
    hold(ax_data, 'off')
    
    try
        obj.SignalGenerator.on;
        for j = 1:obj.averages
            for i = 1:n
                status.String = sprintf('Experiment started\nFrequency %0.3f GHz (%i/%i)\nAverage %i/%i', obj.freq_list(i)/1e9, i, n, j, obj.averages);
                
                % Update line for current frequency
                current_freqH.XData = [1 1]*obj.freq_list(i)/1e9;
                current_freqH.YData = NaN(1,2); % To allow ylim to be calculated
                current_freqH.YData = get(ax_data,'ylim');
                
                drawnow; assert(~obj.abort_request,'User aborted.');
                
                % Normalization
                if obj.MW_freq_norm > 0
                    obj.SignalGenerator.MWFrequency = obj.MW_freq_norm*1e9;
                    im_norm = obj.Camera.snapImage(1);
                    obj.data(j,i,1,:,:) = im_norm(obj.ROI(1,1):obj.ROI(1,2),obj.ROI(2,1):obj.ROI(2,2));
                else
                    obj.SignalGenerator.off;
                    im_norm = obj.Camera.snapImage(1);
                    obj.data(j,i,1,:,:) = im_norm(obj.ROI(1,1):obj.ROI(1,2),obj.ROI(2,1):obj.ROI(2,2));
                    obj.SignalGenerator.on;
                end
                
                % Signal
                obj.SignalGenerator.MWFrequency = obj.freq_list(i);
                im = obj.Camera.snapImage(1);
                obj.data(j,i,2,:,:) = im(obj.ROI(1,1):obj.ROI(1,2),obj.ROI(2,1):obj.ROI(2,2));
                
                % Update pixes of interest
                for k = 1:n_pixels_of_interest
                    pixels_of_interest(j, i, k, 1) = im_norm(obj.pixel_x(k), obj.pixel_y(k));
                    pixels_of_interest(j, i, k, 2) = im(obj.pixel_x(k), obj.pixel_y(k));
                end
                
                % Update plot
                obj.update_graphics(ax_im, plotH, obj.data, im_norm, pixels_of_interest)
            end
        end
    catch err
    end
    obj.SignalGenerator.off;
    obj.Laser.off;
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
