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

    % Initial positions
    x = NaN(4,3);
    x(1,:) = [sqrt(8/9) 0 -1/3];
    x(2,:) = [-sqrt(2/9) sqrt(2/3) -1/3];
    x(3,:) = [-sqrt(2/9) -sqrt(2/3) -1/3];
    x(4,:) = [0 0 1];
    x(:,1) = x(:,1) * obj.initial_x_length;
    x(:,2) = x(:,2) * obj.initial_y_length;
    x(:,3) = x(:,3) * obj.initial_z_length;
    x = x + obj.Stage.position;

    % Switch on all necessary sources
    switch obj.Type
        case 'ODMR'
            obj.SignalGenerator.on;
            obj.Laser.on;
        case 'Fluorescence'
            obj.Laser.on;
        otherwise
            error("%s type of spot finding not implemented", obj.Type)
    end

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

    ax_std = subplot(2,2,4,'parent',panel); % Standard deviation of x, y & z positions
    hold(ax_std,'on')
    plotH(3) = semilogy(ax_std, 0, std(x(:,1)), 'r');
    plotH(4) = semilogy(ax_std, 0, std(x(:,2)), 'g');
    plotH(5) = semilogy(ax_std, 0, std(x(:,3)), 'b');
    hold(ax_std,'on')
    ylabel(ax_std, 'Std of position')
    xlabel(ax_std, 'Step')
    legend(ax_std,{'x','y','z'})
    set(ax_std, 'YScale', 'log')

    try
        % Loop while max number of iterations not exceeded & difference between successive measurements is sufficiently large compared to successive measurements
        for i = 1:obj.max_iterations
            drawnow; assert(~obj.abort_request,'User aborted.');
            
            % Take Nelder-Mead step
            [x, f] = obj.NelderMead_step(f, x, @(z) obj.find_cost(z,ctr), obj.alpha, obj.gamma, obj.rho, obj.sigma);
            
            % Re-measure best point to avoid outliers
            f(1) = obj.find_cost(x(1,:), ctr);
            
            % Update data
            obj.data.x_history = [obj.data.x_history; x];
            obj.data.cost_history = [obj.data.cost_history f];
            ter = std(f); % termination criterion;

            % Update plot
            plotH(1).XData = obj.data.x_history(:,1);
            plotH(1).YData = obj.data.x_history(:,2);
            plotH(1).ZData = obj.data.x_history(:,3);
            
            plotH(2).XData = [plotH(2).XData i*ones(1,4)];
            plotH(2).YData = obj.data.cost_history;
            
            plotH(3).XData = [plotH(3).XData i];
            plotH(3).YData = [plotH(3).YData std(x(:,1))];

            plotH(4).XData = [plotH(4).XData i];
            plotH(4).YData = [plotH(4).YData std(x(:,2))];

            plotH(5).XData = [plotH(5).XData i];
            plotH(5).YData = [plotH(5).YData std(x(:,3))];
            
            if std(x(:,1)) < obj.tolerance && std(x(:,2)) < obj.tolerance && std(x(:,3)) < obj.tolerance
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
    else
        % If successful, alert and move to centroid
        msgbox(sprintf("Spot finder converged successfully with convergence criterion %0.5f & position uncertainty (%0.3f, %0.3f, %0.3f)", ter, std(x(:,1)), std(x(:,2)), std(x(:,3))))
        
        x = mean(x,1);
        obj.Stage.move( x(1), x(2), x(3) );
    end
end