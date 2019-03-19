
function run(obj,statusH,managers,ax)
%this experiment is meant to test whether your cameras
%are written correctly.
%% establish connection for your camera

obj.abort_request=false;
obj.tests = struct('name',{},'success',{},'output',{},'err',{}); %initialize structure to store test results
obj.status = ''; %empty test status

%Load signal generator
rel_path = 'Modules\+Imaging\+Camera\+Cameras_invisible'; % path relative to AutomationSetup (Git root)
[CC_root,~,~] = fileparts(which('CommandCenter')); % path to AutomationSetup (Git root)
[file,path] = uigetfile('*.m','Select Camera to Test',fullfile(CC_root,rel_path));
[~,class_name,~] = fileparts(file);
[prefix] = Base.GetClasses(path); % get the prefix
camera = [prefix, class_name];

super = superclasses(camera);
assert(ismember('Imaging.Camera.Cameras_invisible',super),...
    'Superclass of %s must be Imaging.Camera.Cameras_invisible',camera)
obj.camera = eval(sprintf('%s.instance', camera)); %instantiate driver for your cameras
%% unlock the camera from memory in case user modified it to fix an error.

munlock(camera)
%% begin testing
try
    obj.logger.visible = 'on'; %open the logger to show testing progress
    obj.logger.log(sprintf(['Now testing ',obj.camera.dev]));
    
    %Test camera reset
    
    obj.tests(end+1) = obj.run_test('test if device can reset',...
        @() obj.camera.reset,'','');
    
    %Test if camera is in Internal mode after reset
    
    obj.tests(end+1) = obj.run_test('test if in Internal mode after reset',...
        '',@()obj.camera.getTrigMode,'Internal');
    
    %Test if camera has an exposure of 30 ms after reset
    
    obj.tests(end+1) = obj.run_test('test if exposure is 30 ms after reset',...
        '',@() round(obj.camera.getExposure),30);
    
    %Test if you can set a different exposure
    
    obj.tests(end+1) = obj.run_test(['test setting exposure to ',num2str(obj.exposure),' ms.'],...
        @() obj.camera.setExposure(obj.exposure),@()round(obj.camera.getExposure),obj.exposure);
    
    %Test if camera can set trigger mode:External Exposure
    
    obj.tests(end+1) = obj.run_test('test External Exposure trigMode',...
        @()obj.camera.setTrigMode('External Exposure'),...
        @()obj.camera.getTrigMode,'External Exposure');
    
    %Test if camera can set trigger mode:Internal
    
    obj.tests(end+1) = obj.run_test('test Internal trigMode',...
        @()obj.camera.setTrigMode('Internal'),...
        @()obj.camera.getTrigMode,'Internal');
    
    
    obj.camera.reset;
    
    %Test if camera can set an EM Gain
    
    obj.tests(end+1) = obj.run_test(['test setting EMGain to ',num2str(obj.EMGain),'.'],...
        @()obj.camera.setEMGain(obj.EMGain),...
        @()obj.camera.getEMGain,obj.EMGain);
    
    %Test if EM gain can be set to 0
    
    obj.tests(end+1) = obj.run_test('test setting EMGain to 0',...
        @()obj.camera.setEMGain(0),...
        @()obj.camera.getEMGain,0);
    
    %Test if camera can set Gain
    
    obj.tests(end+1) = obj.run_test(['test setting Gain to ',num2str(obj.gain),'.'],...
        @()obj.camera.setEMGain(obj.gain),...
        @()obj.camera.getEMGain,obj.gain);
    
    %Test if camera can set Gain to 0
    
    obj.tests(end+1) = obj.run_test('test setting Gain to 0',...
        @()obj.camera.setEMGain(0),...
        @()obj.camera.getEMGain,0);
    
    %Test if you can grab an image
    
    obj.tests(end+1) = obj.run_test('test snapping an image',...
        '',...
        @()~isempty(obj.camera.snap),true);
    
    %Test if image has the right dimensions (m x n)
    
    obj.tests(end+1) = obj.run_test('test if image has right dimensions',...
        '',...
        @()length(size(obj.camera.snap)),2);
    
    
    axImage = obj.get_image_axis_handle;
    
    %Test if image has the right dimensions (m x n)
    
    obj.tests(end+1) = obj.run_test('test snapping an image',...
        '',...
        @()length(size(obj.camera.snap)),2);
    
    %Test if resolution (1) was set correctly
    
    obj.tests(end+1) = obj.run_test('test res(1)',...
        @()obj.camera.resolution(1),...
        @()size(obj.camera.snap,1),obj.camera.resolution(1));
    
    %Test if resolution (2) was set correctly
    
    obj.tests(end+1) = obj.run_test('test res(2)',...
        @()obj.camera.resolution(2),...
        @()size(obj.camera.snap,2),obj.camera.resolution(2));
    
    %Test if resolution (2) was set correctly
    
    obj.tests(end+1) = obj.run_test('test res(2)',...
        @()obj.camera.resolution(2),...
        @()size(obj.camera.snap,2),obj.camera.resolution(2));
    
    %Test if binning 1 can be set
    
    obj.tests(end+1) = obj.run_test('test setting binning 1',...
        @()obj.camera.setBinning(1),...
        @()obj.camera.getBinning,1);
    
    %Test if binning 8 can be set
    
    obj.tests(end+1) = obj.run_test('test setting binning 8',...
        @()obj.camera.setBinning(8),...
        @()obj.camera.getBinning,8);
    
    %Test if binning is set correctly when reset is called
    
    obj.tests(end+1) = obj.run_test('test binning after reset',...
        @()obj.camera.reset(2),...
        @()obj.camera.getBinning,2);
    
    %Test if resolution as binning changes is set correctly
    
    for binning_test=obj.binning_vec
        obj.tests(end+1) = obj.run_test('test resolution(1) as binning changes',...
            @()obj.camera.setBinning(binning_test),...
            @()obj.camera.resolution(1) == size(obj.camera.snap,1),true);
        
        obj.tests(end+1) = obj.run_test('test resolution(2) as binning changes',...
            @()obj.camera.setBinning(binning_test),...
            @()obj.camera.resolution(2) == size(obj.camera.snap,2),true);
    end
    
    obj.camera.reset(1);
    
    %Test if maxROI is set correctly
    
    obj.tests(end+1) = obj.run_test('test maxROI(3) ',...
        @()obj.camera.setBinning(1),...
        @()round(obj.camera.maxROI(3)),obj.camera.resolution(1));
    
    obj.tests(end+1) = obj.run_test('test maxROI(4) ',...
        @()obj.camera.setBinning(1),...
        @()round(obj.camera.maxROI(4)),obj.camera.resolution(2));
    
    %Test if camera readoutTime returns
    
    obj.tests(end+1) = obj.run_test('test if readoutTime returns ',...
        '',...
        @()isempty(obj.camera.getReadoutTime),false);
    
    %Test if camera readoutTime is a double
    
    obj.tests(end+1) = obj.run_test('test if readoutTime is a double',...
        '',...
        @()isa(obj.camera.getReadoutTime,'double'),true);
    
    %Test if camera readoutTime has the right units
    
    obj.tests(end+1) = obj.run_test('test if readoutTime has the right units',...
        '',...
        @()(obj.camera.getReadoutTime>1),true); %assume that if readoutime is greater than 1, then it is units of ms
    %% If the camera has failed the previous tests, ask the user if they would like to continue triggering
    % camera. May cause memory leaks if their is an error.
    
    if ~obj.status
        question = 'Not all tests were successful. Would you like to test triggering camera?';
        button = questdlg(question,'Query User');
        if ~strcmp(button,'Yes')
            %abort if the user didn't select yes
            obj.abort;
            errordlg('User aborted')
        end
    end
    
    %% Test if triggered set of exposure is programmed correctly
    
    sequence = setup_PB_sequence(obj);
    [program,s] = sequence.compile;
    obj.pulseblaster.open;
    obj.pulseblaster.load(program);
    obj.pulseblaster.stop;
    pauseTimeSequence = obj.camera.getExposure/1000+0.020;%convert to seconds
    
    obj.camera.reset(8);
    
    
    %Test if startSequenceAcquisition errors
    %
    obj.tests(end+1) = obj.run_test('test if startSequenceAcquisition errors',...
        @()obj.camera.startSequenceAcquisition(obj.Num_Images),...
        '','');
    
    
    for frame = 1:obj.Num_Images
        obj.pulseblaster.start;
        pause(pauseTimeSequence)
        obj.pulseblaster.stop;
        pause(obj.camera.getReadoutTime/1000)
        dat_test(:,:,frame) = obj.camera.snap(axImage); %grab an image after every trigger
    end
    
    %Test if stoptSequenceAcquisition returns images (should not)
    
    obj.tests(end+1) = obj.run_test('test stoptSequenceAcquisition',...
        '',...
        @()isempty(obj.camera.stopSequenceAcquisition(0)),true);
    
    % obj.camera.stopSequenceAcquisition(0)
    
    obj.camera.startSequenceAcquisition(obj.Num_Images)
    for frame = 1:obj.Num_Images
        obj.pulseblaster.start;
        pause(pauseTimeSequence)
        obj.pulseblaster.stop;
        pause(obj.camera.getReadoutTime/1000)
        try
            obj.camera.setBinning(2) %make sure this fails
        catch ME
            
        end
        assert(~isempty(ME),'set_binning should error out when inside a acquisition sequence')
        
        try
            obj.camera.setExposure(20)%make sure this fails
        catch ME
            
        end
        assert(~isempty(ME),'set_exposure should error out when inside a acquisition sequence')
        
        try
            obj.camera.setTrigMode('Internal')%make sure this fails
        catch ME
            
        end
        assert(~isempty(ME),'set_trig_mode should error out when inside a acquisition sequence')
    end
    
    obj.tests(end+1) = obj.run_test('test stoptSequenceAcquisition returns data matrix',...
        '',...
        @()size(obj.camera.stopSequenceAcquisition(obj.Num_Images),3),obj.Num_Images);
    
    
catch err
    obj.status = 'fail';
    obj.camera.reset(1)
    rethrow(err)
end
%If status not set to failure, all tests must have succeeded
if isempty(obj.status)
    obj.status = 'pass';
    obj.logger.log('Passed all performed tests.')
    drawnow;
else
    obj.logger.log('Failed at least one test. See report for details.')
end
end