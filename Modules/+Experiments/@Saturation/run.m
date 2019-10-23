function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    obj.abort_request = false;
    status.String = 'Experiment started';
    ctr = Drivers.Counter.instance(obj.APD_line, obj.APD_Sync_line); % Instantiate APD counter
    drawnow;

    % Edit this to include meta data for this experimental run (saved in obj.GetData)
    obj.meta.prefs = obj.prefs2struct;
    obj.meta.position = managers.Stages.position; % Save current stage position (x,y,z);
    obj.meta.angles = obj.angle_list; %Angles corresponding to each spectrum

    % Check that rot is not empty and valid
    assert(~isempty(obj.rot) && isvalid(obj.rot),'Motor SN must be a valid number; motor handle may have been deleted. Check motor serial number/APT Config')

    % Setup graphics
    y = NaN(1,n);
    hold(ax,'on');
    plotH(1) = plot(obj.angle_list, y,'color', 'k','parent',ax);
    current_freqH = plot(ax,NaN,NaN,'--r');
    ylabel(ax,'Counts (cps)');
    xlabel(ax,'Angle (\deg)');
    yyaxis(ax, 'left');

    try
        % Home rotation mount
        if ~obj.rot.Homed
            status.String = 'Homing motor'; drawnow;
            
            obj.rot.home();
            pause4Move(obj, obj.motor_home_time);
        end
        
        % Sweep through polarisation and get spectra
        Nangles = length(obj.angle_list);
        obj.data.intensity = nan(1,Nangles)
        for i = 1:Nangles
            theta = obj.angle_list(i);
            status.String = sprintf( 'Navigating to %g (%i/%i)', theta, ...
                i, Nangles); drawnow;
            obj.rot.move(theta);
            pause4Move(obj, obj.motor_move_time);
            status.String = sprintf( 'Measuring at %g (%i/%i)', theta, ...
                i, Nangles); drawnow;
            
            % Measure count rate
            obj.data.intensity(i) = ctr.singleShot(obj.exposure, 1)

            plotH(1).YData = obj.data.intensity;
            drawnow; assert(~obj.abort_request,'User aborted');
        end
        
        %Get meta data from spectrum experiment
        obj.meta.spec_meta = tempDat_nonvolatile;
        obj.meta.diamondbase = tempDat.diamondbase;



    catch err
    end
    % CLEAN UP CODE %
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end

% Wait until motor stops moving, or timeout
function pause4Move(obj,maxTime)
    t = tic;
    while (obj.rot.Moving || ~obj.rot.Homed) && (toc(t) < maxTime)
        drawnow
        if toc(t) > maxTime
            error('Motor timed out while moving')
        end
    end
end
