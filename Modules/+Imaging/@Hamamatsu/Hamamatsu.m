classdef Hamamatsu < Modules.Imaging
    %AxioCam Control Zeiss AxioCam camera
    %   
    
    properties
        exposure = 100        % Exposure time in ms
        binning = 1         % Bin pixels
%         exposure =      Prefs.Double(NaN, 'units', 'ms', 'min', 0, 'max', inf, 'allow_nan', true, 'set', 'set_exposure');
%         gain = Prefs.Double(NaN, 'units', 'dB', 'min', 0, 'max', 480, 'allow_nan', true, 'set', 'set_gain');
        EMGain = 4
        ImRot90 
        FlipVer 
        FlipHor 
        maxROI           % Set in constructor
        CamCenterCoord = [0,0] % camera's center of coordinates (in same units as camera calibration, i.e. um)
        data_name = 'Widefield';  % For diamondbase (via ImagingManager)
        data_type = 'General';    % For diamondbase (via ImagingManager)
        prefs = {'binning','exposure','EMGain','ImRot90','FlipVer','FlipHor','CamCenterCoord'};
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
        videoTimer       % Handle to video timer object for capturing frames
    end
    
    methods(Access=private)
        function obj = Hamamatsu()
            % Initialize Java Core
            %addpath 'C:\Micro-Manager-1.4.22\';
            %addpath 'C:\Micro-Manager-1.4\';
            addpath 'C:\Program Files\Micro-Manager-1.4\';
            import mmcorej.*;
            core=CMMCore;
            %core.loadSystemConfiguration('C:\Micro-Manager-1.4.22\HamamatsuEMCCD.cfg');
            core.loadSystemConfiguration('C:\Program Files\Micro-Manager-1.4\Hamamatsu.cfg');
            obj.core = core;
            % Load preferences
            obj.core.setCircularBufferMemoryFootprint(3);  % 3 MB is enough for one full image
            obj.loadPrefs;
            obj.setFlipVer;
            obj.setFlipHor;
            res(1) = core.getImageWidth();
            res(2) = core.getImageHeight();
            obj.resolution = res;
            obj.maxROI = [-obj.resolution(1)/2 obj.resolution(1)/2;...
                -obj.resolution(2)/2 obj.resolution(2)/2]*obj.binning;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.Hamamatsu();
            end
            obj = Object;
        end
    end
    methods
        function load_core_configuration(obj,cfgpath)
            assert(isfile(cfgpath),'File not found')
            obj.core.loadSystemConfiguration(cfgpath);
            % Load preferences
            obj.core.setCircularBufferMemoryFootprint(3);  % 3 MB is enough for one full image
            obj.loadPrefs;
            obj.setFlipVer;
            obj.setFlipHor;
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
                set(obj.setFlipVer,'string',num2str(obj.FlipVer))
            end
        end
        function set.FlipHor(obj,val)
            obj.FlipHor = val;
            if ~isempty(obj.setFlipHor)
                set(obj.setFlipHor,'string',num2str(obj.FlipHor))
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

        function metric = focus(obj,ax,Managers)
            stageManager = Managers.Stages;
            stageManager.update_gui = 'off';
   %         oldBin = obj.binning;
   %         oldExp = obj.exposure;
   %         if oldBin < 3
   %             obj.exposure = oldExp*(oldBin/3)^2;
   %             obj.binning = 3;
   %         end
            try
                metric = obj.ContrastFocus(Managers);
            catch err
                stageManager.update_gui = 'on';
                rethrow(err)
            end
   %         if oldBin < 3
   %             obj.exposure = oldExp;
   %             obj.binning = oldBin;
   %         end
            stageManager.update_gui = 'on';
        end
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
        function snap(obj,hImage)
            % This function calls snapImage and applies to hImage.
            im = obj.snapImage;
            set(hImage,'cdata',im)
        end
        function startVideo(obj,hImage)
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
        function settings(obj,panelH)
            spacing = 1.5;
            num_lines = 4;
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
        function ImRot90Callback(obj,hObj,eventdata)
            val = str2double((get(hObj,'string')));
            obj.ImRot90 = val;
            warning('Only works with full ROI.')
        end
        function FlipHorCallback(obj,hObj,~)
            if (get(hObj,'Value') == get(hObj,'Max'))
                obj.FlipHor = 1;
            else
                obj.FlipHor = 0;
            end
        end
        function FlipVerCallback(obj,hObj,~)
            if (get(hObj,'Value') == get(hObj,'Max'))
                obj.FlipVer = 1;
            else
                obj.FlipVer = 0;
            end
        end
        
    end
end

