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
    not_loaded = {};
    if isempty(obj.Res_LaserH)
        not_loaded{end+1} = 'Res Laser not loaded.';
    end
    if isempty(obj.Repump_LaserH)
        not_loaded{end+1} = 'Repump Laser not loaded.';
    end
    if isempty(obj.MW_SourceH)
        not_loaded{end+1} = 'MW Source not loaded.';
    end
    if isempty(obj.nidaqH)
        not_loaded{end+1} = 'NIDAQ not loaded.';
    end
    if ~isempty(not_loaded)
        error('Following devices not loaded:\n  %s',strjoin(not_loaded,'\n  '));
    end
    % Prepare equipment
    status.String = sprintf('Setting laser to %0.4f THz',obj.OpticalFreq_THz); drawnow;
    obj.Res_LaserH.LaserMove(obj.OpticalFreq_THz); % couarsely move
    obj.Res_LaserH.LaserSetpoint(obj.OpticalFreq_THz); % lock
    status.String = sprintf('Setting MW source to %0.4f GHz, %0.2f dBm',obj.MWfreq_GHz,obj.MWpower_dBm); drawnow;
    obj.MW_SourceH.serial.reset;
    obj.MW_SourceH.power = obj.MWpower_dBm;
    obj.MW_SourceH.frequency = obj.MWfreq_GHz * 1e9 / obj.SignalGenerator.freqUnit2Hz;
    obj.MW_SourceH.on;
    
    status.String = 'Generating Pulse Sequence'; drawnow;
    pb = obj.Res_LaserH.PulseBlaster.HW;
    ps = obj.setup_PB_sequence;
    APDseq = APDPulseSequence(obj.nidaqH,pb,ps);
    
    f = figure('visible','off','name',mfilename);
    axtemp = axes('Parent',f);
    dataObj = plot(NaN,NaN,'parent',axtemp);
    
    res = managers.Imaging.active_module.resolution;
    X = linspace(managers.Imaging.ROI(1,1),managers.Imaging.ROI(1,2),res(1));
    Y = linspace(managers.Imaging.ROI(2,1),managers.Imaging.ROI(2,2),res(2));
    imH = imagesc(ax,X,Y,NaN(res(2),res(1)));
    colormap(ax,managers.Imaging.set_colormap);
    axis(ax,'image'); set(ax,'ydir','normal');
    
    obj.data = struct();
    obj.data.X = X;
    obj.data.Y = Y;
    obj.data.meta = obj.prefs2struct; % Grab now just in case
    status.String = 'Scanning...'; drawnow;
    try
        % EXPERIMENT CODE %
        for i = 1:length(X)
            xpoint = X(i);
            for j = 1:length(Y)
                ypoint = Y(j);
                assert(~obj.abort_request,'User aborted');
                managers.Stages.move([xpoint,ypoint,NaN]);
                managers.Stages.waitUntilStopped;
                
                APDseq.start(100);
                APDseq.stream(dataObj);
                
                obj.data.init(j,i) = squeeze(mean(dataObj.YData(1:2:end)));
                obj.data.init_var(j,i) = squeeze(var(dataObj.YData(1:2:end)));
                obj.data.signal(j,i) = squeeze(mean(dataObj.YData(2:2:end)));
                obj.data.signal_var(j,i) = squeeze(var(dataObj.YData(2:2:end)));
                
                imH.CData(j,i) = obj.data.signal(j,i);
                drawnow limitrate;
            end
        end
    catch err
    end
    delete(f);
    delete(APDseq);
    obj.MW_SourceH.off;
    if exist('err','var')
        % HANDLE ERROR CODE %
        rethrow(err)
    end
end
