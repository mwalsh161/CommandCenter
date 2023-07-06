classdef Hamamatsu < Modules.Imaging
    %AxioCam Control Zeiss AxioCam camera
    %   
    
    properties(SetObservable, GetObservable)
        exposure = 100        % Exposure time in ms
        binning = 1         % Bin pixels
%         exposure =      Prefs.Double(NaN, 'units', 'ms', 'min', 0, 'max', inf, 'allow_nan', true, 'set', 'set_exposure');
%         gain = Prefs.Double(NaN, 'units', 'dB', 'min', 0, 'max', 480, 'allow_nan', true, 'set', 'set_gain');
        EMGain = 4
        ImRot90 = 0;
        FlipVer = false;
        FlipHor = false;
        maxROI           % Set in constructor
        CamCenterCoord = [0,0] % camera's center of coordinates (in same units as camera calibration, i.e. um)
        data_name = 'Widefield';  % For diamondbase (via ImagingManager)
        data_type = 'General';    % For diamondbase (via ImagingManager)
        matchTemplate = Prefs.Boolean(true);
        contrast = Prefs.Double(NaN, 'readonly', true, 'help', 'Difference square contrast. Larger contrast indicates being better focused.');
        offset = Prefs.Integer(5, 'min', 1, 'max', 10, 'help', 'Move image `offset` pixels then calculate the contrast.')
        maxMovement = Prefs.Double(50, 'min', 10, 'max', 100, 'help', 'Maximum possible movement of both template position and image center position. Single movement larger than this value will be filtered out.')
        showFiltered = Prefs.Boolean(false);
        prefs = {'binning','exposure','EMGain','ImRot90','FlipVer','FlipHor','CamCenterCoord', 'contrast', 'offset', 'matchTemplate'};
    end
    properties(Hidden)
        core            % The Micro-Manager core utility (java)
        dev = 'HamamatsuHam_DCAM';  % Device label (from the cfg file)
    end
    properties(SetObservable)
        resolution = [NaN NaN]; % Set in constructor and set.binning
        ROI              % Region of Interest in pixels [startX startY; stopX stopY]
        continuous = false;
    end
    properties(Access=private)
        setBinning       % Handle to GUI settings object for binning
        setExposure      % Handle to GUI settings object for Exposure
        setEMGain
        setImRot90
        setFlipHor
        setFlipVer
        setCamCenterCoordX
        setCamCenterCoordY
        contrastUI
        setOffset
        videoTimer       % Handle to video timer object for capturing frames
        hImage          % Handle to the smartimage in ImagingManager. Use snap or startVideo to initialize
        template = [];
        snapTemplateUI;
        setMatchTemplateUI;
        frameCnt = 0;           % Frame num counter for updating pattern detection (in video mode). 
        prevTemplatePos = []; % 2*2 matrix to store the coordinates of two rounds.
        templatePos;            % Imaging Coordinates
        prevCenterPos = [];
        centerPos;              % Normal Coordinates
        setMaxMovementUI;
        setShowFilteredUI;
        prevContrast;
        templateCorners;
    end
    
    methods(Access=private)
        function obj = Hamamatsu()
            % Initialize Java Core
            addpath 'C:\Program Files\Micro-Manager-1.4\';
            import mmcorej.*;
            core=CMMCore;
            core.loadSystemConfiguration('C:\Program Files\Micro-Manager-1.4\Hamamatsu.cfg');
            obj.core = core;
            % Load preferences
            obj.core.setCircularBufferMemoryFootprint(3);  % 3 MB is enough for one full image
            obj.loadPrefs;
            res(1) = core.getImageWidth();
            res(2) = core.getImageHeight();
            obj.resolution = res;
            obj.maxROI = [-obj.resolution(1)/2 obj.resolution(1)/2;...
                -obj.resolution(2)/2 obj.resolution(2)/2]*obj.binning;
            frameCnt = 0;
        end
    end
    methods(Static)
        obj = instance()
    end
    methods
        function metric = focus(obj,ax,managers) %#ok<INUSD>
            ms = managers.MetaStage.active_module;

            Z = ms.get_meta_pref('Z');
            anc = Drivers.Attocube.ANC350.instance('18.25.25.37');
            Zline = anc.lines(3);
            if isempty(Z.reference) || ~strcmp(replace(Z.reference.name, ' ', '_'), 'steps_moved') || ~isequal(Z.reference.parent.line, 3)
                Z.set_reference(Zline.get_meta_pref('steps_moved'));
            end


            Target = ms.get_meta_pref('Target');
            emccd = Imaging.Hamamatsu.instance;
            if isempty(Target.reference) || ~strcmp(Target.reference.name, 'contrast')
                Target.set_reference(emccd.get_meta_pref('contrast'));
            end

            try
                obj.stopVideo;
            catch err
                warning(err);
            end
            managers.MetaStage.optimize('Z', true);
            metric = Target.read;
        end
        function load_core_configuration(obj,cfgpath)
            assert(isfile(cfgpath),'File not found')
            obj.core.loadSystemConfiguration(cfgpath);
            % Load preferences
            obj.core.setCircularBufferMemoryFootprint(3);  % 3 MB is enough for one full image
            res(1) = obj.core.getImageWidth();
            res(2) = obj.core.getImageHeight();
            obj.resolution = res;
            obj.maxROI = [-obj.resolution(1)/2 obj.resolution(1)/2;...
                -obj.resolution(2)/2 obj.resolution(2)/2]*obj.binning;
        end
        function load_external_trigger(obj,cfgpath)
            obj.load_core_configuration(cfgpath)
            configdata = obj.core.getConfigData('triggered','external-positive');
            obj.core.setSystemState(configdata);
        end
        function start_triggered_acquisition(obj,maxframes,interval_ms,stoponoverflow)
            obj.core.initializeCircularBuffer();
            obj.core.startSequenceAcquisition(maxframes,interval_ms,stoponoverflow);
        end
        function dat = popNextImage(obj)
            dat = obj.core.popNextImage();
            width = obj.core.getImageWidth();
            height = obj.core.getImageHeight();
            dat = typecast(dat, 'uint16');
            dat = reshape(dat, [width, height]);
            im = flipud(transpose(dat));  % Fix Y inversion
            if obj.ImRot90 > 0
                dat = rot90(dat,obj.ImRot90);
            end
            if obj.FlipVer
                dat = flipud(dat);
            end
            if obj.FlipHor
                dat = fliplr(dat);
            end
        end
        function stop_triggered_acquisition(obj)
            obj.core.stopSequenceAcquisition()
        end
        function set.CamCenterCoord(obj,val)
            obj.CamCenterCoord = val;
        end

        function set.ImRot90(obj,val)
            obj.ImRot90 = val;
            if ~isempty(obj.setImRot90)
                set(obj.setImRot90,'string',num2str(obj.ImRot90))
            end
        end
        function set.FlipVer(obj,val)
            obj.FlipVer = val;
            if ~isempty(obj.setFlipVer)
                set(obj.setFlipVer,'value',logical(obj.FlipVer))
            end
        end
        function set.FlipHor(obj,val)
            obj.FlipHor = val;
            if ~isempty(obj.setFlipHor)
                set(obj.setFlipHor,'value',logical(obj.FlipHor))
            end
        end
        function set.EMGain(obj,val)
            if val == obj.core.getProperty('HamamatsuHam_DCAM', 'EMGain')
                obj.EMGain = val;
                return
            end
            wasRunning = false;
            if obj.core.isSequenceRunning()
                % Pause camera acquisition, but leave the video going
                % (just wont be frames until we resume acquisition)
                obj.core.stopSequenceAcquisition();
                wasRunning = true;
            end
            obj.core.setProperty('HamamatsuHam_DCAM', 'EMGain',num2str(val))
            % Incase an invalid exposure was set, grab what core set it to
            obj.EMGain = str2double(obj.core.getProperty('HamamatsuHam_DCAM', 'EMGain'));
            if ~isempty(obj.setEMGain)
                set(obj.setEMGain,'string',num2str(obj.EMGain))
            end
            if wasRunning
                obj.core.startContinuousSequenceAcquisition(100);
            end
        end
        function set.exposure(obj,val)
            if val == obj.core.getExposure()
                obj.exposure = val;
                return
            end
            wasRunning = false;
            if obj.core.isSequenceRunning()
                % Pause camera acquisition, but leave the video going
                % (just wont be frames until we resume acquisition)
                obj.core.stopSequenceAcquisition();
                wasRunning = true;
            end
            obj.core.setExposure(val)
            % Incase an invalid exposure was set, grab what core set it to
            obj.exposure = obj.core.getExposure();
            if ~isempty(obj.setExposure)
                set(obj.setExposure,'string',num2str(obj.exposure))
            end
            if wasRunning
                obj.core.startContinuousSequenceAcquisition(100);
            end
        end
        function set.binning(obj,val)
            if val==str2double(obj.core.getProperty(obj.dev,'Binning'))
                obj.binning = val;
                return
            end
            wasRunning = false;
            if obj.core.isSequenceRunning()
                % Pause camera acquisition, but leave the video going
                % (just wont be frames until we resume acquisition)
                obj.core.stopSequenceAcquisition();
                wasRunning = true;
            end
            val = sprintf('%ix%i',val,val);   % e.g. 1x1
            obj.core.setProperty(obj.dev,'Binning',val)
            bin = char(obj.core.getProperty(obj.dev,'Binning'));
            bin = strsplit(bin,'x');
            obj.binning = str2double(bin{1});
            res(1) = obj.core.getImageWidth();
            res(2) = obj.core.getImageHeight();
            obj.resolution = res;
            if ~isempty(obj.setBinning)
                set(obj.setBinning,'string',num2str(obj.binning))
            end
            if wasRunning
                obj.core.startContinuousSequenceAcquisition(100);
            end
        end
        function set.ROI(obj,val)
            % Because this has a draggable rectangle in CommandCenter, it
            % is best to not stop and start acquisition like we do with
            % exposure and binning
            assert(~obj.core.isSequenceRunning(),'Cannot set while video running.')
            val = val/obj.binning;
            val(2,:) = fliplr(val(2,:))*-1;
            val(1,:) = val(1,:) + obj.resolution(1)/2;
            val(2,:) = val(2,:) + obj.resolution(2)/2;
            val = round([val(1,1) val(2,1) val(1,2)-val(1,1) val(2,2)-val(2,1)]);
            % Use the full ROI as bounds
            obj.core.clearROI();
            roi = obj.core.getROI();
            xstart = max(roi.x,val(1));
            ystart = max(roi.y,val(2));
            width = min(roi.width-xstart,val(3));
            height = min(roi.height-ystart,val(4));
            obj.core.setROI(xstart,ystart,width,height);
        end
        function val = get.ROI(obj)
            val = obj.core.getROI();
            val = [val.x val.x+val.width; val.y val.y+val.height];
            val(1,:) = val(1,:) - obj.resolution(1)/2;
            val(2,:) = val(2,:) - obj.resolution(2)/2;
            val(2,:) = fliplr(val(2,:))*-1;
            val = val*obj.binning;
            val = val*obj.calibration;
            val = val + obj.CamCenterCoord.'*ones(1,2);
            val = val/obj.calibration;
        end
        function delete(obj)
            if obj.core.isSequenceRunning()
                obj.stopVideo;
            end
            obj.core.reset()  % Unloads all devices, and clears config data
            delete(obj.core)
        end

        % function metric = focus(obj,ax,Managers)
%             stageManager = Managers.Stages;
%             stageManager.update_gui = 'off';
%    %         oldBin = obj.binning;
%    %         oldExp = obj.exposure;
%    %         if oldBin < 3
%    %             obj.exposure = oldExp*(oldBin/3)^2;
%    %             obj.binning = 3;
%    %         end
%             try
%                 metric = obj.ContrastFocus(Managers);
%             catch err
%                 stageManager.update_gui = 'on';
%                 rethrow(err)
%             end
%    %         if oldBin < 3
%    %             obj.exposure = oldExp;
%    %             obj.binning = oldBin;
%    %         end
%             stageManager.update_gui = 'on';
        % end
        function dat = snapImage(obj,binning,exposure)
            % This function returns the image (unlike snap)
            % Default is to use bin of 1. Exposure is configured based on
            % bin size before executing this function.  Settings are
            % restored after function completes.  This can be overridden
            % using the optional inputs.
            oldBin = obj.binning;
            oldExp = obj.exposure;
            % Parse inputs
            switch nargin
                case 1  % No optional inputs
                    newBin = 1;
                    newExp = oldExp*(oldBin^2);
                case 2  % Binning specified
                    newBin = binning;
                    newExp = oldExp*(oldBin/newBin)^2;
                case 3  % Binning and exposure specified
                    newBin = binning;
                    newExp = exposure;
            end
            % Update state
            wasRunning = false;
            if obj.core.isSequenceRunning()
                wasRunning = true;
                obj.core.stopSequenceAcquisition();
            end
            obj.binning = newBin;
            obj.exposure = newExp;
            % Take Image
            obj.core.snapImage();
            dat = obj.core.getImage();
            width = obj.core.getImageWidth();
            height = obj.core.getImageHeight();
            dat = typecast(dat, 'uint16');
            dat = reshape(dat, [width, height]);
            im = flipud(transpose(dat));  % Fix Y inversion
            if obj.ImRot90 > 0
                dat = rot90(dat,obj.ImRot90);
            end
            if obj.FlipVer
                dat = flipud(dat);
            end
            if obj.FlipHor
                dat = fliplr(dat);
            end
            % Restore last state
            obj.exposure = oldExp;
            obj.binning = oldBin;
            if wasRunning
                obj.core.startContinuousSequenceAcquisition(100);
            end
        end
        function startSnapping(obj)
            if obj.core.isSequenceRunning
                obj.core.stopSequenceAcquisition;
            end
            while(obj.core.getRemainingImageCount > 0)
                obj.core.popNextImage;
            end
            obj.core.startContinuousSequenceAcquisition(100);
        end
        function dat = fetchSnapping(obj)
            while(obj.core.getRemainingImageCount == 0)
                pause(0.01);
            end
            dat = obj.core.popNextImage;
            width = obj.core.getImageWidth();
            height = obj.core.getImageHeight();
            obj.core.stopSequenceAcquisition;
            dat = typecast(dat, 'uint16');
            dat = reshape(dat, [width, height]);
            if obj.ImRot90 > 0
                dat = rot90(dat,obj.ImRot90);
            end
            if obj.FlipVer
                dat = flipud(dat);
            end
            if obj.FlipHor
                dat = fliplr(dat);
            end
        end

        function snap(obj,hImage)
            % This function calls snapImage and applies to hImage.
            if ~exist('hImage', 'var')
                if isempty(obj.hImage)
                    error('Please click `snap` in image panel to initialize obj.hImage');
                end
                hImage = obj.hImage;
            else
                obj.hImage = hImage;
            end
            im = obj.snapImage;
            if obj.matchTemplate
                im = obj.updateMatching(flipud(im'));
            end
            set(hImage,'cdata',im);
            obj.updateContrast(im);
        end
        function startVideo(obj,hImage)
            if ~exist('hImage', 'var')
                if isempty(obj.hImage)
                    error('Please click `snap` in image panel to initialize obj.hImage');
                end
                hImage = obj.hImage;
            else
                obj.hImage = hImage;
            end
            obj.continuous = true;
            if obj.core.isSequenceRunning()
                warndlg('Video already started.')
                return
            end
            obj.core.startContinuousSequenceAcquisition(100);
            obj.videoTimer = timer('tag','Video Timer',...
                                   'ExecutionMode','FixedSpacing',...
                                   'BusyMode','drop',...
                                   'Period',0.01,...
                                   'TimerFcn',{@obj.grabFrame,hImage});
            start(obj.videoTimer)
        end
        function grabFrame(obj,~,~,hImage)
            % Timer Callback for frame acquisition
            if obj.core.isSequenceRunning()&&obj.core.getRemainingImageCount()>0
                dat = obj.core.popNextImage();
                width = obj.core.getImageWidth();
                height = obj.core.getImageHeight();
                dat = typecast(dat, 'uint16');
                dat = reshape(dat, [width, height]);
                dat = flipud(dat');  % Fix Y inversion
                if obj.ImRot90 > 0
                    dat = rot90(dat,obj.ImRot90);
                end
                if obj.FlipVer
                    dat = flipud(dat);
                end
                if obj.FlipHor
                    dat = fliplr(dat);
                end
                obj.updateContrast(dat);
                if obj.matchTemplate 
                    if obj.contrast > 0.7*obj.prevContrast
                        % To prevent position shift caused by stage shifting
                        dat = obj.updateMatching(dat);
                    elseif obj.showFiltered
                        dat = frame_detection(dat);
                    end
                end
                set(hImage,'cdata',dat);
            end
            drawnow;
        end
        function stopVideo(obj)
            if ~obj.core.isSequenceRunning()
                warndlg('No video started.')
                obj.continuous = false;
                return
            end
            obj.core.stopSequenceAcquisition();
            stop(obj.videoTimer)
            delete(obj.videoTimer)
            obj.continuous = false;
        end
        
        % Settings and Callbacks
        function settings(obj,panelH, ~, ~)
            spacing = 1.5;
            num_lines = 7;
            line = 1;
            xwidth1 = 14;
            xwidth2 = 10;
            xwidth3 = 12;
            xwidth4 = 10;
            uicontrol(panelH,'style','text','string','Exposure (ms):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) xwidth1 1.25]);
            obj.setExposure = uicontrol(panelH,'style','edit','string',num2str(obj.exposure),...
                'units','characters','callback',@obj.exposureCallback,...
                'horizontalalignment','left','position',[xwidth1+1 spacing*(num_lines-line) xwidth2 1.5]);
            
            uicontrol(panelH,'style','text','string','Im. rot 90','horizontalalignment','right',...
                'units','characters','position',[xwidth1+xwidth2+1 spacing*(num_lines-line) xwidth3 1.25]);
            obj.setImRot90 = uicontrol(panelH,'style','edit','string',num2str(obj.ImRot90),...
                'units','characters','callback',@obj.ImRot90Callback,...
                'horizontalalignment','left','position',[xwidth1+xwidth2+xwidth3+1 spacing*(num_lines-line) xwidth4 1.5]);
         
            
%             uicontrol(panelH,'style','edit','string',num2str(obj.ImRot90),...
%                 'units','characters','callback',@obj.setImRot90,...
%                 'horizontalalignment','left','position',[43 spacing*(num_lines-line) 10 1.5]);

            line = 2;
            uicontrol(panelH,'style','text','string','Binning:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) xwidth1 1.25]);
            obj.setBinning = uicontrol(panelH,'style','edit','string',num2str(obj.binning),...
                'units','characters','callback',@obj.binningCallback,...
                'horizontalalignment','left','position',[xwidth1+1 spacing*(num_lines-line) xwidth2 1.5]);
            
            uicontrol(panelH,'style','text','string','Flip Hor.','horizontalalignment','right',...
                'units','characters','position',[xwidth1+xwidth2+1 spacing*(num_lines-line) xwidth3 1.25]);
            obj.setFlipHor = uicontrol(panelH,'style','checkbox','value',obj.FlipHor,...
                'units','characters','position',[xwidth1+xwidth2+xwidth3+1 spacing*(num_lines-line) xwidth4 1.5],...
                'tag','Flip Hor.','callback',@obj.FlipHorCallback);
            
            line = 3;
            uicontrol(panelH,'style','text','string','EM Gain:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) xwidth1 1.25]);
            obj.setEMGain = uicontrol(panelH,'style','edit','string',num2str(obj.EMGain),...
                'units','characters','callback',@obj.EMGainCallback,...
                'horizontalalignment','left','position',[xwidth1+1 spacing*(num_lines-line) xwidth2 1.5]);
            
            uicontrol(panelH,'style','text','string','Flip Ver.','horizontalalignment','right',...
                'units','characters','position',[xwidth1+xwidth2+1 spacing*(num_lines-line) xwidth3 1.25]);
            obj.setFlipVer = uicontrol(panelH,'style','checkbox','value',obj.FlipVer,...
                'units','characters','position',[xwidth1+xwidth2+xwidth3+1 spacing*(num_lines-line) xwidth4 1.5],...
                'tag','Flip Ver.','callback',@obj.FlipVerCallback);
            
            line = 4;
            uicontrol(panelH,'style','text','string','XCenter','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) xwidth1 1.25]);
            obj.setCamCenterCoordX = uicontrol(panelH,'style','edit','string',num2str(obj.CamCenterCoord(1)),...
                'units','characters','callback',@obj.CamCenterCoordXCallback,...
                'horizontalalignment','left','position',[xwidth1+1 spacing*(num_lines-line) xwidth2 1.5]);
            
            uicontrol(panelH,'style','text','string','YCenter','horizontalalignment','right',...
                'units','characters','position',[xwidth1+xwidth2+1 spacing*(num_lines-line) xwidth3 1.25]);
            obj.setCamCenterCoordY = uicontrol(panelH,'style','edit','string',num2str(obj.CamCenterCoord(2)),...
                'units','characters','callback',@obj.CamCenterCoordYCallback,...
                'horizontalalignment','left','position',[xwidth1+xwidth2+xwidth3+1 spacing*(num_lines-line) xwidth4 1.5]);

            line = 5;
            uicontrol(panelH,'style','text','string','contrast','horizontalalignment','right', ...
                'units','characters','position',[0 spacing*(num_lines-line) xwidth1 1.25]);
            obj.contrastUI = uicontrol(panelH,'style','edit','string',num2str(obj.contrast),...
                'units','characters','enable', 'off',...
                'horizontalalignment','left','position',[xwidth1+1 spacing*(num_lines-line) xwidth2 1.5]);
            
            uicontrol(panelH,'style','text','string','offset','horizontalalignment','right',...
                'units','characters','position',[xwidth1+xwidth2+1 spacing*(num_lines-line) xwidth3 1.25]);
            obj.setOffset = uicontrol(panelH,'style','edit','string',num2str(obj.offset),...
                'units','characters','callback',@obj.setOffsetCallback,...
                'horizontalalignment','left','position',[xwidth1+xwidth2+xwidth3+1 spacing*(num_lines-line) xwidth4 1.5]);

            line = 6;
            obj.snapTemplateUI = uicontrol(panelH,'style','pushbutton', 'string', 'Snap Template',...
                'units','characters',...
                'horizontalalignment','left','position',[3 spacing*(num_lines-line) xwidth1+3 1.5], 'Callback', @(~, ~)obj.snapTemplate);
            
            uicontrol(panelH,'style','text','string','Match Template','horizontalalignment','right',...
                'units','characters','position',[xwidth1+xwidth2 spacing*(num_lines-line) xwidth3+3 1.25]);
            obj.setMatchTemplateUI = uicontrol(panelH,'style','checkbox','value',obj.matchTemplate,...
                'units','characters','callback',@obj.setMatchTemplateCallback,...
                'horizontalalignment','left','position',[xwidth1+xwidth2+xwidth3+4 spacing*(num_lines-line) xwidth4 1.5]);

            line = 7;
            uicontrol(panelH,'style','text','string','Max Movement','horizontalalignment','right', ...
                'units','characters','position',[0 spacing*(num_lines-line) xwidth1 1.25]);
            obj.setMaxMovementUI = uicontrol(panelH,'style','edit','string',num2str(obj.maxMovement),...
                'units','characters',...
                'horizontalalignment','left','position',[xwidth1+1 spacing*(num_lines-line) xwidth2 1.5], 'callback', @obj.setMaxMovementCallback);

            uicontrol(panelH,'style','text','string','Show Filterd','horizontalalignment','right',... 
                'units','characters','position',[xwidth1+xwidth2+1 spacing*(num_lines-line) xwidth3+2 1.25]);
            obj.setShowFilteredUI = uicontrol(panelH,'style','checkbox','value',obj.showFiltered,...
                'units','characters','callback',@obj.setShowFilteredCallback,...
                'horizontalalignment','left','position',[xwidth1+xwidth2+xwidth3+4 spacing*(num_lines-line) xwidth4 1.5]);
                
        end
        function exposureCallback(obj,hObj,eventdata)
            val = str2double((get(hObj,'string')));
            obj.exposure = val;
        end
        function binningCallback(obj,hObj,eventdata)
            val = str2double((get(hObj,'string')));
            obj.binning = val;
        end
        function EMGainCallback(obj,hObj,eventdata)
            val = str2double((get(hObj,'string')));
            obj.EMGain = val;
        end
        function CamCenterCoordXCallback(obj,hObj,eventdata)
            cur = obj.CamCenterCoord;
            cur(1) = str2double((get(hObj,'string')));
            obj.CamCenterCoord = cur;
            warning('Need to reset ROI for changes to take effect.')
        end
        function CamCenterCoordYCallback(obj,hObj,eventdata)
            cur = obj.CamCenterCoord;
            cur(2) = str2double((get(hObj,'string')));
            obj.CamCenterCoord = cur;
            warning('Need to reset ROI for changes to take effect.')
        end
        function setOffsetCallback(obj, hObj, eventdata)
            val = str2num(get(hObj, 'string'));
            obj.offset = int16(val);
        end
        function setMaxMovementCallback(obj, hObj, eventdata)
            val = str2num(get(hObj, 'string'));
            obj.maxMovement = val;
        end
        function setMatchTemplateCallback(obj, hObj, eventdata)
            val = get(hObj, 'value');
            obj.matchTemplate = logical(val);
        end
        function setShowFilteredCallback(obj, hObj, eventdata)
            val = get(hObj, 'value');
            obj.showFiltered = logical(val);
        end
        function ImRot90Callback(obj,hObj,eventdata)
            val = str2double((get(hObj,'string')));
            obj.ImRot90 = val;
            warning('Only works with full ROI.')
        end
        function FlipHorCallback(obj,hObj,~)
            obj.FlipHor = get(hObj, 'Value');
        end
        function FlipVerCallback(obj,hObj,~)
            obj.FlipVer = get(hObj, 'Value');
        end
        function contrast = updateContrast(obj,frame)
            frame = double(frame);
            xmin = obj.offset+1;
            xmax = size(frame, 2)-obj.offset;
            ymin = obj.offset+1;
            ymax = size(frame, 1)-obj.offset;
            image = frame(ymin:ymax,xmin:xmax);
            imagex = frame(ymin:ymax,xmin+obj.offset:xmax+obj.offset);
            imagey = frame(ymin+obj.offset:ymax+obj.offset,xmin:xmax);
            dI = (imagex-image).^2+(imagey-image).^2;
            contrast = mean2(dI);
            obj.prevContrast = obj.contrast;
            obj.contrast = contrast;
            if ~isempty(obj.contrastUI) && isprop(obj.contrastUI, 'String')
                obj.contrastUI.String = sprintf("%.2e", contrast);
            end
        end
        function snapTemplate(obj, templateROI)
            im = flipud(transpose(obj.snapImage));

            
            obj.template = frame_detection(im, true);
            % templateROI?
            if ~exist('templateROI', 'var')
                col_has_val = any(obj.template, 1);
                row_has_val = any(obj.template, 2);
                templateROI = [find(col_has_val, 1), find(col_has_val, 1, 'last'); find(row_has_val, 1), find(row_has_val, 1, 'last')];
            end
            xmin = templateROI(1, 1);
            xmax = templateROI(1, 2);
            ymin = templateROI(2, 1);
            ymax = templateROI(2, 2);
            obj.template = obj.template(ymin:ymax, xmin:xmax);


            try close(41); catch; end
            frame_fig = figure(41);
            frame_fig.Position = [200, 200, 560, 420];
            frame_ax = axes('Parent', frame_fig);
            imH = imagesc(frame_ax, obj.template);
            colormap(frame_ax, 'bone');
            x_size = size(obj.template, 2);
            y_size = size(obj.template, 1);
            if isempty(obj.templateCorners)
                polyH = drawpolygon(frame_ax, 'Position', [1, x_size, x_size, 1; 1, 1, y_size, y_size]');
            else
                polyH = drawpolygon(frame_ax, 'Position', obj.templateCorners);
            end
            set(get(frame_ax, 'Title'), 'String', sprintf('Right click the image to confirm polygon ROI\nOnly emitters inside this region will be shown.'));
            imH.ButtonDownFcn = @obj.ROIConfirm;
            uiwait(frame_fig);
            obj.templateCorners = round(polyH.Position);
            delete(polyH);
            im = obj.drawCorners(obj.template);
            delete(imH);
            imH = imagesc(frame_ax, im);
            set(get(frame_ax, 'XLabel'), 'String', 'x');
            set(get(frame_ax, 'YLabel'), 'String', 'y');
            colormap(frame_ax, 'bone');
        end
        function im = drawCorners(obj, im, offset, val, radius)
            if ~exist('offset', 'var')
                offset = [0, 0];
            end
            if ~exist('val', 'var')
                val = 0;
            end
            if ~exist('radius', 'var')
                radius = 2;
            end
            for k = 1:4
                im(obj.templateCorners(k, 2)+offset(1)-radius:obj.templateCorners(k, 2)+radius+offset(1), obj.templateCorners(k, 1)+offset(2)-radius:obj.templateCorners(k, 1)+offset(2)+radius) = val;
            end
            obj.centerPos = round(mean(obj.templateCorners));
            im(obj.centerPos(2)+offset(1)-radius:obj.centerPos(2)+offset(1)+radius, obj.centerPos(1)+offset(2)-radius:obj.centerPos(1)+offset(2)+radius) = val;
        end
        function im = updateMatching(obj, im)
            if isempty(obj.template)
                obj.template = frame_detection(im, true);
            end
            processed_im = frame_detection(im, false);
            matchingPos = image_matching(processed_im, obj.template);
            % MatchingPos is the top right coner of the template image inserted into the target image.
            switch size(obj.prevTemplatePos, 1)
            case 0
                obj.prevTemplatePos(1, :) = matchingPos;
                obj.templatePos = matchingPos;
            case 1
                if norm(matchingPos-obj.prevTemplatePos) < obj.maxMovement
                    obj.templatePos = matchingPos;
                end
                obj.prevTemplatePos(2, :) = matchingPos;
            case 2
                if norm(matchingPos - obj.prevTemplatePos(1, :)) < obj.maxMovement && norm(matchingPos - obj.prevTemplatePos(2, :)) < obj.maxMovement 
                    obj.templatePos = matchingPos;
                end
                obj.prevTemplatePos(1, :) = obj.prevTemplatePos(2, :);
                obj.prevTemplatePos(2, :) = matchingPos;
            otherwise
                error(fprintf("size(obj.prevTemplatePos, 1) should be at most 2, but got %d.", size(obj.prevTemplatePos)));
            end



            y = obj.templatePos(1);
            x = obj.templatePos(2);
            template_y = size(obj.template, 1);
            template_x = size(obj.template, 2);

            if obj.showFiltered
                im = processed_im;
            end
            % Draw a white box directly onto the image
            im(y-template_y:y, x:x) = 65535;
            im(y-template_y:y, x-template_x:x-template_x) = 65535;
            im(y:y, x-template_x:x) = 65535;
            im(y-template_y:y-template_y, x-template_x:x) = 65535;

            im = obj.drawCorners(im, obj.templatePos-size(obj.template), 65535);

        end

        function setCorners(obj)
            try close(41); catch; end
            frame_fig = figure(41);
            frame_fig.Position = [200, 200, 560, 420];
            frame_ax = axes('Parent', frame_fig);
            wlH = imagesc(frame_ax, obj.trimmed_wl_img);
            colormap(frame_ax, 'bone');
            x_size = size(obj.trimmed_wl_img, 2);
            y_size = size(obj.trimmed_wl_img, 1);
            size(obj.trimmed_wl_img, 1);
            if isempty(obj.poly_pos)
                polyH = drawpolygon(frame_ax, 'Position', [1, x_size, x_size, 1; 1, 1, y_size, y_size]');
            else
                polyH = drawpolygon(frame_ax, 'Position', obj.poly_pos);
            end
            set(get(frame_ax, 'Title'), 'String', sprintf('Right click the image to confirm polygon ROI\nOnly emitters inside this region will be shown.'));
            wlH.ButtonDownFcn = @obj.ROIConfirm;
            uiwait(frame_fig);
        end

        function ROIConfirm(obj, hObj, event)
            if event.Button == 3
                uiresume;
                return;
            end
        end
    end
end

