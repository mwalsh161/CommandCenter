function run( obj,status,managers,ax )
    % Main run method (callback for CC run button)
    %obj.PreRun(status,managers,ax);
    
    obj.abort_request = false;
    status.String = 'Experiment started';
    drawnow;
    
    assert(~isempty(obj.percents),'percents is empty.');
%     assert(~isempty(obj.stop_V),'Stop is empty.');
%     assert(obj.start_V<obj.stop_V,'For now, start needs to be less that stop.');
%     assert(~isempty(obj.dwell_ms),'Dwell is empty.');
%     assert(~isempty(obj.total_time),'Total_time is empty.');
%     dwell = obj.dwell_ms*1e-3; % Convert to seconds

    obj.resLaser.on
    obj.repumpLaser.on
    obj.cameraEMCCD.binning = obj.EMCCD_binning;
    obj.cameraEMCCD.exposure = obj.EMCCD_exposure;
    obj.cameraEMCCD.EMGain = obj.EMCCD_gain;
    
    ROI_EMCCD = obj.cameraEMCCD.ROI;
    %imgSize_EMCCD = max(ROI_EMCCD) - min(ROI_EMCCD);
    imgSize_EMCCD = ROI_EMCCD(:,2) - ROI_EMCCD(:,1);
    ROI_cam = obj.camera1.ROI;
    %imgSize_cam = max(ROI_cam) - min(ROI_cam);
    imgSize_cam = ROI_cam(:,2) - ROI_cam(:,1) +1;
    obj.data.images_camera = NaN(imgSize_cam(2), imgSize_cam(1), length(obj.scan_points));
    obj.data.images_EMCCD = NaN(imgSize_EMCCD(1), imgSize_EMCCD(2), length(obj.scan_points));

    for i = 1 : length(obj.scan_points)
        drawnow('limitrate'); assert(~obj.abort_request,'User aborted.');
        % change laser wavelength
        %obj.resLaser.TunePercent(obj.scan_points(i));
        
        obj.resLaser.set_resonator_percent_limitrate(obj.scan_points(i));
        
        obj.data.images_camera(:,:,i) = obj.camera1.snapImage();
        obj.data.images_EMCCD(:,:,i) = obj.cameraEMCCD.snapImage();
        
        if obj.wavemeter_override
            obj.wavemeter.SetSwitcherSignalState(1);
            obj.data.freqMeasured(i) = obj.wavemeter.getFrequency;
        else
            obj.data.freqMeasured(i) = obj.resLaser.getFrequency;
        end
        
        imagesc(ax,obj.data.images_EMCCD(:,:,i));
        title(obj.data.freqMeasured(i));
        %imagesc(obj.ax1, obj.data.images_camera(:,:,i))
        %imagesc(obj.ax2, obj.data.images_EMCCD(:,:,i))
        
    end
end