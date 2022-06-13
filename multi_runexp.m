%%

exp = Experiments.ResonanceEMCCD.instance;
datafile=[];
for i=1:10
    exp.percents = 'linspace(37,42,101)';
    managers.Experiment.run;
    
    datafile(i) = exp.data;
    
    exp.percents = 'linspace(42,37,101)';
    managers.Experiment.run;
    
    datafile(i) = exp.data;
end



%% acquire images with both cameras

scan_points = 1:500;

camera = Imaging.Thorlabs.CS235CU.instance;
cameraEMCCD = Imaging.Hamamatsu.instance;

msquared = Sources.Msquared.instance;

camera_exposure = 500;

camera.set_exposure(camera_exposure);
camera.set_gain(0);
cameraEMCCD.binning = 1;
cameraEMCCD.exposure = camera_exposure;
cameraEMCCD.EMGain = 1200;


ROI_EMCCD = cameraEMCCD.ROI;
imgSize_EMCCD = ROI_EMCCD(:,2) - ROI_EMCCD(:,1);
ROI_cam = camera.ROI;
imgSize_cam = ROI_cam(:,2) - ROI_cam(:,1) +1;
expdata = [];
expdata.images_camera = NaN(imgSize_cam(1), imgSize_cam(2), length(scan_points));
expdata.images_EMCCD = NaN(imgSize_EMCCD(1), imgSize_EMCCD(2), length(scan_points));


figure;ax = axes;
for i = 1 : length(scan_points)
    
    expdata.images_camera(:,:,i) = camera.snapImage();
    expdata.images_EMCCD(:,:,i) = cameraEMCCD.snapImage();

    imagesc(ax,expdata.images_EMCCD(:,:,i));
    title(i);
    drawnow;
end

