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
    obj.SignalGenerator.power = obj.MW_Power;
    obj.SignalGenerator.frequency = obj.freq_list(1); % Just init to first point even though redundant
    obj.Camera.exposure = obj.Exposure;
    % Pre-allocate obj.data
    n = length(obj.freq_list);
    n_pts = length(obj.pixel_x);

    % Setup graphics
    % Plot camera image
    obj.Laser.on;
    initial_im = obj.Camera.snapImage(1);
    img_size = size(initial_im);
    
    panel = ax.Parent;
    ax_im = subplot(1,2,1,'parent',panel);
    imagesc(  initial_im, 'parent', ax_im)
    set(ax_im,'dataAspectRatio',[1 1 1])
    hold(ax_im,'on');
    cs = lines(n_pts);
    
    obj.data = NaN(obj.averages,n,2,img_size(1),img_size(2)); % Data aranged with indices (average #)x(frequency)x(normalisation/data)x(x pixel)x(y pixel)

    % Plot data
    y = NaN(1,n);
    ax_data = subplot(1,2,2,'parent',panel);
    hold(ax_data,'on');
    plotH(1) = plot(obj.freq_list/1e9, y, 'Linewidth', 3, 'color', 'k','parent',ax_data);
    current_freqH = plot(ax_data,NaN,NaN,'--r');
    ylabel(ax_data,'ODMR (normalized)');
    yyaxis(ax_data, 'right')
    plotH(2) = plot(obj.freq_list/1e9, y,...
        'color', 'k','linestyle','--','parent',ax_data);
    plotH(3) = plot(obj.freq_list/1e9, y,...
        'color', 'k','linestyle',':','parent',ax_data);
    legend([plotH(1), plotH(2), plotH(3)],{'Normalized (left)','Signal (right)','Normalization (right)'}, 'AutoUpdate','off');
    ylabel(ax_data,'Counts (cps)');
    xlabel(ax_data,'Frequency (GHz)');
    yyaxis(ax_data, 'left');

    % Plot points of interest
    for i = 1:n_pts
        plotH(1+3*i) = plot(obj.freq_list/1e9, y, '-', 'Linewidth', 3, 'color',cs(i,:), 'parent',ax_data);
        yyaxis(ax_data, 'right');
        plotH(2+3*i) = plot(obj.freq_list/1e9, y,':', 'color',cs(i,:), 'parent',ax_data);
        plotH(3+3*i) = plot(obj.freq_list/1e9,y,'--', 'color',cs(i,:), 'parent',ax_data);
        yyaxis(ax_data, 'left');
        plot(obj.pixel_x(i), obj.pixel_y(i), 'o', 'color', cs(i,:), 'parent', ax_im)
    end
    try
        obj.SignalGenerator.on;
        for j = 1:obj.averages
            status.String = sprintf('Experiment started\nAverage %i',j);
            for i = 1:n
                current_freqH.XData = [1 1]*obj.freq_list(i)/1e9;
                current_freqH.YData = NaN(1,2); % To allow ylim to be calculated
                current_freqH.YData = get(ax_data,'ylim');
                drawnow; assert(~obj.abort_request,'User aborted.');
                % Normalization
                if obj.MW_freq_norm > 0
                    obj.SignalGenerator.frequency = obj.MW_freq_norm*1e3;
                    obj.data(j,i,1,:,:) = obj.Camera.snapImage(1);
                else
                    obj.SignalGenerator.off;
                    obj.data(j,i,1,:,:) = obj.Camera.snapImage(1);
                    obj.SignalGenerator.on;
                end
                % Signal
                obj.SignalGenerator.frequency = obj.freq_list(i);
                obj.data(j,i,2,:,:) = obj.Camera.snapImage(1);

                % Update plot
                averagedData = squeeze(nanmean(obj.data,1));
                norm   = squeeze(averagedData(:, 1,:,:));
                signal = squeeze(averagedData(:, 2,:,:));
                data = 2 * signal ./ (signal + norm);
                plotH(1).YData = nanmean(data, [2 3]);
                plotH(2).YData = nanmean(signal, [2 3]);
                plotH(3).YData = nanmean(norm, [2 3]);
                for k = 1:n_pts
                    plotH(1+3*k).YData = data(:, obj.pixel_x(k), obj.pixel_y(k));
                    plotH(2+3*k).YData = signal(:, obj.pixel_x(k), obj.pixel_y(k));
                    plotH(3+3*k).YData = norm(:, obj.pixel_x(k), obj.pixel_y(k));
                end
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
