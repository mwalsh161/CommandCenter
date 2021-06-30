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
    obj.meta.start_position = managers.Stages.position; % Save current stage position (x,y,z);

    ctr = Drivers.Counter.instance(obj.APD_line, obj.APD_Sync_line);
    obj.Laser.arm;
    obj.SignalGenerator.MWPower = obj.MW_Power;

    % Initial ositions
    x = NaN(4,3);
    x(end,1) = obj.Stage.position;
    x(1,:) = x(end,1) + [sqrt(8/9) 0 -1/3];
    x(2,:) = x(end,1) + [-sqrt(2/9) sqrt(2/3) -1/3];
    x(3,:) = x(end,1) + [-sqrt(2/9) -sqrt(2/3) -1/3];
    x(4,:) = x(end,1) + [0 0 1];
    x(:,1) = x(:,1) * obj.initical_x_length;
    x(:,2) = x(:,2) * obj.initical_y_length;
    x(:,3) = x(:,3) * obj.initical_z_length;


    % Initial cost
    f = NaN(1,4);
    for i = 1:size(x,1)
        f(i) = obj.find_cost(x(i,:), ctr);
    end

    % Initialise data
    obj.data.x_history = x;
    obj.data.cost_history = f;

    % Setup Graphics
    panel = ax.Parent; delete(ax);
    ax_x = subplot(2,2,[1 3],'parent',panel);
    plotH(1) = stem3(ax_x, x(:,1), x(:,2), x(:,3)); % Plot of points

    ax_f = subplot(2,2,2,'parent',panel);
    plotH(2) = scatter(ax_f, zeros(1,4), f); % Plot of cost function
    ylabel(ax_f, 'Cost function')

    yyaxis(ax_f, 'right')
    plotH(3) = plot(ax_f, 0, std(f), 'r-'); % Plot of convergence criterion
    ylabel(ax_f, 'Convergence Criterion')
    xlabel(ax_f, 'Step')

    ax_std = subplot(2,2,4,'parent',panel); % Standard deviation of x, y & z positions
    plotH(4) = plot(ax_std, 0, std(x(:,1)), 'r');
    plotH(5) = plot(ax_std, 0, std(x(:,2)), 'g');
    plotH(6) = plot(ax_std, 0, std(x(:,3)), 'b');
    ylabel(ax_std, 'Std of position')
    xlabel(ax_std, 'Step')
    legend(ax_std,{'x','y','z'})

    try
        switch obj.Type
            case 'ODMR'
                obj.SignalGenerator.on;
                obj.Laser.on;
            case 'Fluorescence'
                obj.Laser.on;
            otherwise
                error("%s type of spot finding not implemented", obj.Type)
        end

        % Loop while max number of iterations not exceeded & difference between successive measurements is sufficiently large compared to successive measurements
        for i = 1:obj.max_iterations
            % Take Nelder-Mead step
            [x, f] = obj.NelderMead_step(x, f, obj.alpha, obj.gamma, obj.rho, obj.sigma);
            
            % Update data
            obj.data.x_history = [obj.data.x_history; x];
            obj.data.f_history = [obj.data.x_history; f];
            ter = std(f); termination criterion;

            % Update plot
            plotH(1).XData = obj.data.x_history(:,1);
            plotH(1).YData = obj.data.x_history(:,2);
            plotH(1).ZData = obj.data.x_history(:,3);
            
            plotH(2).XData = [plotH(2).XData i*ones(1,4)];
            plotH(2).YData = obj.f_history;

            plotH(3).XData = [plotH(3).XData i];
            plotH(3).YData = [plotH(3).YData ter];
            
            plotH(4).XData = [plotH(4).XData i];
            plotH(4).YData = [plotH(4).YData std(x(:,1))];

            plotH(5).XData = [plotH(4).XData i];
            plotH(5).YData = [plotH(4).YData std(x(:,2))];

            plotH(6).XData = [plotH(4).XData i];
            plotH(6).YData = [plotH(4).YData std(x(:,3))];
            
            if ter > obj.tolerance
                break
            end
        end

        if i==obj.max_iterations
            warning('Max number of iterations reached before convergence')
        end

        obj.SignalGenerator.off
        obj.Laser.off
    catch err
    end
    
    % CLEAN UP CODE %
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
