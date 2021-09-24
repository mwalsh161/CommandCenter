function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;

    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.meta.prefs = obj.prefs2struct;
    obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);
    obj.meta.Vgs = obj.vgs_vals;
    obj.meta.Vds = obj.vds_vals;

    % Prepare plotting
    N_Vgs = max(size(obj.vgs_vals);
    N_Vds = max(size(obj.vds_vals);
    obj.data = NaN(max(size(N_Vds)),max(size(N_Vgs)));

    if obj.x_axis_is_Vgs
        plotH = plot(obj.vgs_vals, obj.data,'parent',ax)
    else
        plotH = plot(obj.vds_vals, obj.data,'parent',ax)
    end

    % Initialise power supplies to first value and turn on
    obj.Vgs_Power_Supply.Channel = obj.Vgs_channel;
    obj.Vgs_Power_Supply.changeSource_Mode = 'Voltage';
    obj.Vgs_Power_Supply.Voltage = obj.vgs_vals(1);

    obj.Vds_Power_Supply.Channel = obj.Vds_channel;
    obj.Vds_Power_Supply.changeSource_Mode = 'Voltage';
    obj.Vds_Power_Supply.Voltage = obj.vds_vals(1);

    obj.Vgs_Power_Supply.on;
    obj.Vds_Power_Supply.on;

    try

        for j = 1:N_Vgs
            for i = 1:N_Vds
                status.String = sprintf('Experiment started\nV_{gs} %i/%i, V_{gs} %i/%i, (V_{gs}=%.02f)',j,N_Vgs,obj.vds_vals(j));
                drawnow; assert(~obj.abort_request,'User aborted.');

                % Change voltages
                obj.Vds_Power_Supply.Voltage = obj.vds_vals(i);
                obj.Vgs_Power_Supply.Voltage = obj.vgs_vals(j);

                % Get current
                obj.data(i,j) = obj.Vds_Power_Supply.getCurrent(true);

                % Update plots
                if obj.x_axis_is_Vgs
                    plotH(i).YData = obj.data(i,:);
                else
                    plotH(j).YData = obj.data(:,j);
                end
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
