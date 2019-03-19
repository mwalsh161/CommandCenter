function run(obj,statusH,managers,ax)
% Add pause button, and link to pause callback (pauses at end of main while-loop)
statusWin = statusH.Parent.Parent;
button = findall(statusWin,'tag','AbortButton');
newButton = add_button(button,'Pause');
newButton.Callback = @obj.pause;

obj.rl.serial.PiezoPercent = 50;
panel = ax.Parent;
delete(ax)
ax(1) = subplot(1,2,1,'parent',panel);
ax(2) = subplot(1,2,2,'parent',panel);
obj.abort_request = false;
obj.pause_request = false;
lines = {obj.mirror1,obj.mirror2};
msg = {};
run_err = [];
checkoutlaser(1,getpref('CommandCenter','secret_key_path'))
try % Try/catch for entire experiment
for i = 1:numel(lines) %this all makes sure I have the necessary nidaq lines
    try
        lines{i} = obj.nidaq.getLines(lines{i},'out');
    catch err
        msg{end+1} = err.message;
    end
end
if ~isempty(msg)
    obj.nidaq.view;
    error('Add lines below, and load again.\n%s',strjoin(msg,'\n'))
end

if obj.newImage || isempty(managers.Imaging.current_image) || isempty(obj.scan)
    obj.PathSet(1,0); %set path to free space APD
    obj.gl.on; %green laser on
    obj.scan = [];
    obj.scan(end+1).image = managers.Imaging.snap; %take image snapshot
    [NVlocs, im_filt, NVPixelBounds] = NV_Finder(obj.scan(end).image,obj.NVsize); %returns array of NV locations
    NVlocs = NVlocs(randperm(size(NVlocs,1)),:);  %Randomize NV order
    for i = 1:size(NVlocs,1)
        obj.scan(end).NV(i) = emitter;
        obj.scan(end).NV(i).loc = NVlocs(i,:);
    end
else
    %now we're using previous scan - rebuild local variables
    [~, im_filt, NVPixelBounds] = NV_Finder(obj.scan(end).image,obj.NVsize); %returns array of NV locations
    NVlocs = reshape([obj.scan(end).NV.loc],2,[]);
    NVlocs = NVlocs';
end

imagesc(obj.scan(end).image.ROI(1,:),obj.scan(end).image.ROI(2,:),im_filt,'parent',ax(1));
set(ax(1),'ydir','normal');
colormap(ax(1),'gray');
axis(ax(1),'image');
hold(ax(1),'on');
title(ax(1),sprintf('%0.2f pixels < NV size < %0.2f pixels',NVPixelBounds(1),NVPixelBounds(2)))
xlabel(ax(1),sprintf('%i NVs located.',size(NVlocs,1)));
statusH.String = sprintf('%i NVs located.',size(NVlocs,1));
NVqueue = 1:size(NVlocs,1); %queue stores indices of NVs in obj.scan.NV
currentPos = managers.Stages.position;
NVstates = repmat([1 .5 0],length(NVlocs),1); %initializes all NVs as unexamined (orange)
NVscatH = scatter(NVlocs(:,1),NVlocs(:,2),[],NVstates,'+','parent',ax(1));
currentNV = plot(currentPos(1),currentPos(2),' b+','parent',ax(1),'tag','CurrentPos');

% Prepare mov struct (allow (end+1) notation)
obj.mov.dt = 0;
obj.mov.frame = getframe(managers.handles.figure1,getpixelposition(managers.handles.panel_exp,true)); tic;

%% Spectrum Loop
obj.rl.serial.off; %turn red laser driver off
obj.PathSet(0,0); %move to spectrometer path
obj.WinSpec.setExposure('sec');
obj.gl.on;
errCount = 0;
for i=NVqueue
    try
        NV = obj.scan(end).NV(i); %copying the pointer to that class instance
        if isfield(NV.spec,'spectrum')
            NVqueue = obj.NVstatus(i,NVqueue,NVscatH);
            continue
        end
        managers.Stages.move([NVlocs(i,:),currentPos(3)]) %move to NV location
        set(currentNV,'Xdata',NVlocs(i,1),'Ydata',NVlocs(i,2));
        msg = sprintf('Taking spectrum on NV %i',i);
        obj.logger.log(msg)
        statusH.String = msg;
        
        NV.spec.spectrum = obj.WinSpec.start(@(t)set(statusH,'string',sprintf('%s\nElapsed Time: %0.2f',msg,t)));
        assert(~obj.abort_request,'User aborted');  % Needed here because it will abort WinSpec.start and ret nothing
        NV.spec.specloc = SpecPeak(NV.spec.spectrum,636,639); %find NV peak
        plot(NV.spec.spectrum.x,NV.spec.spectrum.y,'b','parent',ax(2),'LineWidth',2);
        xlabel(ax(2),'Wavelength (nm)');
        ylabel(ax(2),'Intensity (a.u.)');
        set(ax(2),'Xlim',[635,639]);
        if ~isempty(NV.spec.specloc)
            hold(ax(2),'on');
            for loc = NV.spec.specloc
                plot(loc*[1,1],get(ax(2),'Ylim'),'k--','parent',ax(2));
            end
            hold(ax(2),'off');
        end
        getframe(managers.handles.figure1,getpixelposition(managers.handles.panel_exp,true));
        if obj.pause_request;keyboard();obj.pause_request=false;end
        obj.mov.dt(end+1) = toc;
        obj.mov.frame(end+1) = getframe(managers.handles.figure1,getpixelposition(managers.handles.panel_exp,true)); tic;
        errCount = 0; %reset error counter
    catch err
        if strcmp(err.message,'User aborted')
            rethrow(err)
        end
        NV.err = err;
        errCount = errCount + 1; %increment eror counter
        if errCount >= 10
            ten_err.message = sprintf('10th error: %s',err.message);
            ten_err.stack = err.stack;
            error(ten_err)
        end
    end
    NVqueue = obj.NVstatus(i,NVqueue,NVscatH);  % This is a problem now that it can alter queue in this loop
end

%% Survey Scan Loop

obj.rl.serial.on;
%calibrate spectrometer readings to wavemeter
try
    oldwarn = lastwarn;
    lastwarn('');
    spec2wave = obj.spec2wave;
    newwarn = lastwarn;
    lastwarn(oldwarn);
    if ~strcmpi(newwarn,'') && regexpi(newwarn,'Spectrometer has not been calibrated with wavemeter in \d* hours.')
        choice = questdlg(newwarn, ...
            'Spectrometer-Wavemeter Calibration Warning', ...
            'Yes','No','No');
        if strcmpi(choice,'Yes')
            obj.spec2wave = obj.SpecWaveCalibrate([636,639],10); %perform calibration
            spec2wave = obj.spec2wave;
        end
    end
catch spec2wave_err
    if strcmpi(spec2wave_err.message,'No spec2wave calibration available')
        warnstring = sprintf('Spectrometer has not been calibrated with wavemeter. Calibrate now?');
        choice = questdlg(warnstring, ...
            'Spectrometer-Wavemeter Calibration Warning', ...
            'Yes','No','No');
        if strcmpi(choice,'Yes')
            obj.spec2wave = obj.SpecWaveCalibrate([636,639],10); %perform calibration
            spec2wave = obj.spec2wave;
        else
            rethrow(spec2wave_err)
        end
    else
        rethrow(spec2wave_err)
    end
end
uiwait(msgbox('Switch resonant laser power to survey scan power.','Waiting','modal'));
i = 1;
while i<=length(NVqueue)
    try
        NVindex = NVqueue(i);
        NV = obj.scan(end).NV(NVindex); %copying the pointer to that class instance
        
        %check for completion
        if length(NV.survey) == length(NV.spec.specloc)
            if isempty(NV.region)
                obj.surveyRegion(NV); %generate regions
            end
            NVqueue = obj.NVstatus(NVindex,NVqueue,NVscatH);
            i = i+1;
            continue
        end
        
        managers.Stages.move([NVlocs(NVindex,:),currentPos(3)]) %move to NV location
        set(currentNV,'Xdata',NVlocs(NVindex,1),'Ydata',NVlocs(NVindex,2));
        
        for j = 1:length(NV.spec.specloc)
            msg = sprintf('Moving laser to NV %i, peak %i/%i at %0.2f THz',NVindex,j,length(NV.spec.specloc),spec2wave(NV.spec.specloc(j)));
            statusH.String = msg;
            obj.logger.log(msg)
            drawnow;
            assert(~obj.abort_request,'User aborted');
            
            obj.rl.off;
            obj.PathSet(0,0);
            try
                obj.rl.LaserMove(spec2wave(NV.spec.specloc(j))); %move laser to NV
            catch move_err
                if ~strcmp(move_err.message,'Laser wavelength must be in range [635 640].')
                    rethrow(move_err)
                end
                obj.logger.log(sprintf('Could not move laser; skipping peak %i on NV %i',j,NVindex));
                continue
            end
            
            statusH.String = sprintf('Survey slow scan %i/%i on \n NV %i in progress.',j,length(NV.spec.specloc),NVindex);
            drawnow;
            obj.PathSet(1,0); %set path to free space APD
            
            averages = 1e4; %starting number of averages
            points = 301; %starting number of points
            
            NV.survey(end+1) = obj.SurveyScan(averages,points,ax(2));
            NV.survey(end).ScanFit = SlowScanFit(NV.survey(end),obj.SNRThresh);
            if ~isempty(NV.survey(end).ScanFit.fit)
                hold(ax(2),'on');
                plot(ax(2),NV.survey(end).percents,NV.survey(end).ScanFit.fit(NV.survey(end).freqs),'linewidth',2);
                hold(ax(2),'off');
                drawnow;
            end
            obj.mov.dt(end+1) = toc;
            obj.mov.frame(end+1) = getframe(managers.handles.figure1,getpixelposition(managers.handles.panel_exp,true)); tic;
            if obj.pause_request;keyboard();obj.pause_request=false;end
        end
        obj.surveyRegion(NV); %generate regions
        errCount = 0;
    catch err
        if strcmp(err.message,'User aborted')
            rethrow(err)
        end
        NV.err = err;
        errCount = errCount + 1;
        if errCount >= 10
            ten_err.message = sprintf('10th error: %s',err.message);
            ten_err.stack = err.stack;
            error(ten_err)
        end
    end
    NVqueue = obj.NVstatus(NVindex,NVqueue,NVscatH);
    if length(NVqueue) >= i && NVindex == NVqueue(i) %if NV is still on queue
        i = i+1; %move on to next NV
    end
end

%% Regional Scan Loop
% Switch to low red power
uiwait(msgbox('Switch resonant laser power to low power.','Waiting','modal'));
while ~isempty(NVqueue) % Changes scan averages
    NVindex = NVqueue(1);
    obj.logger.log(sprintf('Starting loop for NV %i',NVindex));
    NV = obj.scan(end).NV(NVindex); %copying the pointer to that class instance
    managers.Stages.move([NVlocs(NVindex,:),currentPos(3)]) %move to NV location
    set(currentNV,'Xdata',NVlocs(NVindex,1),'Ydata',NVlocs(NVindex,2));
    
    assert(~obj.abort_request,'User aborted');
    
    %loop through regions
    for j = 1:length(NV.region)
        try
            if NV.region(j).done
                continue
            end
            
            msg = sprintf('Moving laser to NV %i, region %i at %0.2f THz',NVindex,j,mean(NV.region(j).span));
            statusH.String = msg;
            obj.logger.log(msg)
            drawnow;
            assert(~obj.abort_request,'User aborted');
            
            obj.setPIDstatus(false);
            obj.rl.LaserMove(mean(NV.region(j).span)); %move laser to NV
            statusH.String = sprintf('Slow scan %i on \n region %i of \n NV %i in progress.',length(NV.region(j).slow)+1,j,NVindex);
            drawnow;
            obj.PathSet(1,0); %set path to free space APD
            ScanRange = NV.region(j).span;
            points = round(diff(ScanRange)/obj.ScanResolution);
            if isempty(NV.region(j).slow)
                averages = 1e5;
                NV.region(j).slow = obj.SlowScan(averages,points,ScanRange,ax(2));
            else
                averages = round(min(NV.region(j).slow(end).averages*max(2*(obj.SNRThresh/min(NV.region(j).slow(end).ScanFit.snrs))^2,5),obj.maxAverages));
                NV.region(j).slow(end+1) = obj.SlowScan(averages,points,ScanRange,ax(2));
            end
            NV.region(j).slow(end).ScanFit = SlowScanFit(NV.region(j).slow(end),obj.SNRThresh);
            if ~isempty(NV.region(j).slow(end).ScanFit.fit)
                hold(ax(2),'on');
                plot(ax(2),NV.region(j).slow(end).freqs,NV.region(j).slow(end).ScanFit.fit(NV.region(j).slow(end).freqs),'linewidth',2);
                hold(ax(2),'off');
                drawnow;
            end
            obj.mov.dt(end+1) = toc;
            obj.mov.frame(end+1) = getframe(managers.handles.figure1,getpixelposition(managers.handles.panel_exp,true)); tic;
            if obj.pause_request;keyboard();obj.pause_request=false;end
            errCount = 0;
        catch reg_err
            if strcmp(reg_err.message,'User aborted')
                rethrow(reg_err)
            end
            NV.region(j).err = reg_err;
            errCount = errCount + 1;
            if errCount >= 10
                ten_err.message = sprintf('10th error: %s',reg_err.message);
                ten_err.stack = reg_err.stack;
                error(ten_err)
            end
        end
    end
    NVqueue = obj.NVstatus(NVindex,NVqueue,NVscatH);
end
catch run_err
end
toc;  % Stop timer on the last tic call
checkoutlaser(0,getpref('CommandCenter','secret_key_path'))
if ~isempty(run_err)
    keyboard();  % Allow user to checkout local variables before eyrroring
    rethrow(run_err)
end
end
