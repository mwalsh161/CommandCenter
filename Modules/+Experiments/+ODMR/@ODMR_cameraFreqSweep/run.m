function run(obj,statusH,managers,ax)
%% initialize some values
try
    obj.abort_request = false;
    assert(~obj.abort_request,'User aborted');
    
    message = [];
    obj.data = [];
    %% generate subplot axis 
    panel = ax.Parent;
    s1 = subplot(2,3,1,'parent',panel);
    s2 = subplot(2,3,2,'parent',panel);
    s3 = subplot(2,3,3,'parent',panel);
    s4 = subplot(2,3,4,'parent',panel);
    s5 = subplot(2,3,5,'parent',panel);
    %% determine experiment conditions
   
    dwellTime = (obj.exposure + obj.cameraReadTime)/1000; %time (ms) should be the exposure time + readoutTime (4 ms)
    
    experimentTime = obj.nImages * dwellTime;
    
    freqVector = linspace(obj.startFreq,obj.stopFreq,obj.nImages);
 
    %% Setup signal generator for frequency sweeping
    assert(~obj.abort_request,'User aborted');
    
    obj.SG.serial.reset; %clear any previous setting;
    obj.SG.MWPower = obj.RF_power;
    
    obj.SG.serial.setStepTrig('external');
    obj.SG.serial.setPointTrig('imm');
    
    obj.SG.serial.setSweepDirection('fwd');
    obj.SG.serial.setTrigPolarity('pos');
    
    obj.SG.serial.programFrequencySweep(obj.startFreq,obj.stopFreq,obj.nImages - 1,dwellTime , 'single');
    
    obj.SG.serial.executeSweep;
    obj.SG.serial.on;
    pause(5); %wait for PLL to settle
    
    %% setup pulse sequence which triggers the camera to start acquisition
    assert(~obj.abort_request,'User aborted');
    
    % Make channel
    cCamTrig = channel('camTrig','color','k','hardware',obj.Camera_PB_line - 1);
    cLaser = channel('laserTrig','color','b','hardware',obj.laser.PBline - 1);
    
    % Make sequence
    s = sequence('ODMR Frequency Sweep');
    s.channelOrder = [cCamTrig,cLaser];
    
    n_camTrig = node(s.StartNode,cCamTrig,'delta',10,'units','ms'); %send one ttl to trig camera to start acquisition
    n_camTrig = node(n_camTrig,cCamTrig,'delta',10,'units','ms');
    
    nLaser = node(s.StartNode,cLaser,'delta',0,'units','ms'); %keep laser on the whole time
    nLaser = node(s.StartNode,cLaser,'delta',10 + 2*experimentTime*1000,'units','ms'); %keep laser on the whole time
    
    s.repeat = 1;
    
    [program] = s.compile;
    
    obj.PB.open;
    obj.PB.load(program);
    obj.PB.stop;
    
    %% setup camera
    assert(~obj.abort_request,'User aborted');
    obj.camera.reset;
    obj.camera.exposure = obj.exposure;

    pxlY = obj.camera.resolution(1);
    pxlX = obj.camera.resolution(2);
  
    %determine camera offset
    
    backgroundImage = obj.camera.snap;
    meanBckCts = mean(backgroundImage(:));
    
    preAmpGain = obj.camera.getGain; %this is preamp gain
    EMGain = obj.camera.getEMGain; %this is em gain
      
    photo2A = obj.q/(obj.exposure*1e-3); %convert photoelectrons to amps
    photo2uA = photo2A*1e6; %convert amps to uA
    photo2nA = photo2A*1e9; %convert amps to nA
   
    %not calibrated yet
    meanBckCts = 0;
    preAmpGain = 1;
    EMGain = 1;
    photo2uA = 1;
    photo2nA = 1;
    
    %% run ODMR experiment
    
    %preallocate data
    
    raw_data = NaN(pxlX*pxlY,obj.nImages,10);
    runningAverageData = NaN(pxlX*pxlY,obj.nImages,obj.runningAverageIndex);
    made = 0;
    ODMRPxl1 =[];
    ODMRPxl2 = [];
    index = 0;
    
    while index < obj.nAverages
        
        assert(~obj.abort_request,'User aborted');
        index = index + 1;
        
        %prep sweep to go again on next trigger
        dat_matrix = [];
        obj.camera.startSequenceAcquisition(obj.nImages,'External Start');
        obj.SG.serial.resetSweep;
        obj.SG.serial.executeSweep;
        
        %run pulse sequence to trigger camera which then outputs ttl to SG.
        %Both the camera and sg run on their own clock. 
        
        obj.PB.stop;
        obj.PB.start;
        pause(experimentTime + 1)
        
        dat_matrix = obj.camera.stopSequenceAcquisition(obj.nImages);
        
        assert(~isempty(dat_matrix),'camera returned no images')
        
        if index < obj.stbIndex 
            continue
        end
        
        if strcmpi(obj.reset,'yes')
            raw_data = NaN(pxlX*pxlY,obj.nImages,10);
            runningAverageData = NaN(pxlX*pxlY,obj.nImages,obj.runningAverageIndex);
            made = 0;
            ODMRPxl1 =[];
            ODMRPxl2 = [];
            index = 0;
            index = 0;
            index2 = 0;
            obj.reset = 'no';
            continue
        end
        
        %data analysis
        
        image = dat_matrix(:,:,1); %get image so we can see fluorscence of experiment
        
        dat_matrixPhotoElec = (dat_matrix - meanBckCts).*preAmpGain/EMGain;
        
        dataLinear = reshape(dat_matrixPhotoElec,pxlX*pxlY,obj.nImages);
        raw_data(:,:,index) = dataLinear;
        
        index2 = mod(index-1, obj.runningAverageIndex) + 1;
        runningAverageData(:,:,index2) = dataLinear;
        
        runningAverage = nanmean(squeeze(nanmean(runningAverageData,1)),2);
        totalODMR = nanmean(squeeze(nanmean(raw_data,1)),2);
        
        %grab data for pxl1
        xPoints1 = obj.pixelX1 - obj.r : obj.pixelX1 + obj.r;
        yPoints1 = obj.pixelY1 - obj.r : obj.pixelY1 + obj.r;
        
        [xVector,yVector] = meshgrid(xPoints1,yPoints1);
        linearIndices1 = sub2ind([pxlY,pxlX],yVector,xVector);
        
        ODMRPxl1 = runningAverageData(linearIndices1,:,:);
        ODMRPxl1RunningAvg = nanmean(squeeze(nanmean(ODMRPxl1,1)),2);
        
        %grab data for pxl2
        xPoints2 = obj.pixelX2 - obj.r : obj.pixelX2 + obj.r;
        yPoints2 = obj.pixelY2 - obj.r : obj.pixelY2 + obj.r;
        
        [xVector,yVector] = meshgrid(xPoints2,yPoints2);
        linearIndices2 = sub2ind([pxlY,pxlX],yVector,xVector);
        
        ODMRPxl2 = runningAverageData(linearIndices2,:,:);
        ODMRPxl2RunningAvg = nanmean(squeeze(nanmean(ODMRPxl2,1)),2);
        
        titleString = sprintf('Total: index %0.0f',index);
        titleStringRunningAvg = sprintf('Running Avg');

        %% plot data
        
        if made == 0
            hold(s1,'off')
            imagesc(s1,image)
            hold(s1,'on')
            plot(s1,obj.pixelX1,obj.pixelY1,'r*','linewidth',obj.linewidth)
            plot(s1,obj.pixelX2,obj.pixelY2,'b*','linewidth',obj.linewidth)
            c1 = colorbar(s1,'location','westoutside');
            ylabel(c1,'counts','fontsize',obj.fontsize);
            set(c1,'fontsize',obj.fontsize)
            hold(s1,'off')
            axis(s1,'image')
            set(s1,'fontsize',obj.fontsize)
            
            plot(s2,freqVector/1e9,totalODMR.*photo2uA,'linewidth',obj.linewidth)
            xlabel(s2,'Frequency (GHz)','fontsize',obj.fontsize)
            ylabel(s2,'PhotoCurrent (uA)','fontsize',obj.fontsize)
            set(s2,'fontsize',obj.fontsize)
            title(s2,titleString,'fontsize',obj.fontsize);
            axis(s2,'tight');
            
            plot(s3,freqVector/1e9,runningAverage.*photo2uA,'linewidth',obj.linewidth)
            xlabel(s3,'Frequency (GHz)','fontsize',obj.fontsize)
            ylabel(s3,'PhotoCurrent (uA)','fontsize',obj.fontsize)
            set(s3,'fontsize',obj.fontsize)
            axis(s3,'tight');
            title(s3,titleStringRunningAvg,'fontsize',obj.fontsize)

            hold(s4,'off')
            plot(s4,freqVector/1e9,ODMRPxl1RunningAvg.*photo2nA,'r*-','linewidth',obj.linewidth)
            hold(s4,'on')
            plot(s4,freqVector/1e9,ODMRPxl2RunningAvg.*photo2nA,'b*-','linewidth',obj.linewidth)
            xlabel(s4,'Frequency (GHz)','fontsize',obj.fontsize)
            ylabel(s4,'PhotoCurrent (nA)','fontsize',obj.fontsize)
            set(s4,'fontsize',obj.fontsize)
            axis(s4,'tight');
            
            hold(s5,'off')
            plot(s5,freqVector/1e9,detrend(ODMRPxl1RunningAvg.*photo2nA),'r*-','linewidth',obj.linewidth)
            hold(s5,'on')
            plot(s5,freqVector/1e9,detrend(ODMRPxl2RunningAvg.*photo2nA),'b*-','linewidth',obj.linewidth)
            xlabel(s5,'Frequency (GHz)','fontsize',obj.fontsize)
            set(s5,'fontsize',obj.fontsize)
            axis(s5,'tight');
            set(s5,'YTick',[])
            
            made = 1;
        else
           s1.Children(3).CData = image;
           s1.Children(2).XData = obj.pixelX1;
           s1.Children(2).YData = obj.pixelY1;
           s1.Children(1).YData = obj.pixelY2;
           s1.Children(1).XData = obj.pixelX2;
           
           s2.Children.YData = totalODMR.*photo2uA;
           s2.Title.String = titleString;
           
           s3.Children.YData = runningAverage.*photo2uA;
           
           s4.Children(2).YData = ODMRPxl1RunningAvg.*photo2nA;
           s4.Children(1).YData = ODMRPxl2RunningAvg.*photo2nA;
           
           s5.Children(2).YData = detrend(ODMRPxl1RunningAvg.*photo2nA);
           s5.Children(1).YData = detrend(ODMRPxl2RunningAvg.*photo2nA);
           
        end


    end
    
catch message

end
%% cleanup
obj.SG.off;
obj.PB.stop;
obj.camera.reset;

%grab data for saving
try
    obj.data.image = image;
    obj.data.raw_data = raw_data;
    obj.data.runningAverageData = runningAverageData;
    obj.data.runningAverage = runningAverage;
    obj.data.totalODMR = totalODMR;
    obj.data.runningAverage = runningAverage;
    obj.data.freqVector = freqVector;
    
    obj.data.PXL1.xPoints = xPoints1;
    obj.data.PXL1.yPoints = yPoints1;
    obj.data.PXL1.linearIndices = linearIndices1;
    obj.data.PXL1.ODMRPxl1RunningAvg = ODMRPxl1RunningAvg;
    
    obj.data.PXL2.xPoints = xPoints2;
    obj.data.PXL2.yPoints = yPoints2;
    obj.data.PXL2.linearIndices = linearIndices2;
    obj.data.PXL2.ODMRPxl2RunningAvg = ODMRPxl2RunningAvg;
    
    obj.data.offset =  meanBckCts;
    obj.data.preAmpGain = preAmpGain;
    obj.data.EMGain = EMGain;
    obj.data.photo2nA = photo2nA;
    obj.data.photo2uA = photo2uA;
end        
%%
if ~isempty(message)
    rethrow(message)
end
end