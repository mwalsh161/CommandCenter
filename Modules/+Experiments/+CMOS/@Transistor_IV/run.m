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
    N_Vgs = max(size(obj.vgs_vals));
    N_Vds = max(size(obj.vds_vals));
    obj.data = NaN(N_Vds,N_Vgs);

    if obj.x_axis_is_Vgs
        plotH = plot(obj.vgs_vals, obj.data,'parent',ax);
        xlabel('Vgs (V)','parent',ax)
    else
        plotH = plot(obj.vds_vals, obj.data,'parent',ax);
        xlabel('Vds (V)','parent',ax)
    end
    ylabel('Id (A)','parent',ax)
    
    % Initialise power supplies to first value and turn on
    obj.Vgs_supply.Channel = obj.Vgs_channel;
    obj.Vgs_supply.changeSource_Mode('Voltage');
    obj.Vgs_supply.Current = obj.Vgs_I_limit;
    obj.Vgs_supply.Voltage = obj.vgs_vals(1);

    obj.Vds_supply.Channel = obj.Vds_channel;
    obj.Vds_supply.changeSource_Mode('Voltage');
    obj.Vds_supply.Current = obj.Vds_I_limit;
    obj.Vds_supply.Voltage = obj.vds_vals(1);

    obj.Vgs_supply.on;
    obj.Vds_supply.on;

    try

        for j = 1:N_Vgs
            for i = 1:N_Vds
                status.String = sprintf('Experiment started\nVgs %i/%i (Vgs=%.02f)',j,N_Vgs,obj.vgs_vals(j));
                drawnow; assert(~obj.abort_request,'User aborted.');

                % Change voltages
                obj.Vds_supply.Voltage = obj.vds_vals(i);
                obj.Vgs_supply.Voltage = obj.vgs_vals(j);

                % Get current
                pause(obj.settle_time/1000)
                obj.data(i,j) = obj.Vds_supply.getCurrent(true);

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
    obj.Vgs_supply.off;
    obj.Vds_supply.off;
    
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
