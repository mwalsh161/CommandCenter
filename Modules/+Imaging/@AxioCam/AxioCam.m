classdef AxioCam < Modules.Imaging
    %AxioCam Control Zeiss AxioCam camera
    %   
    
    properties
        exposure         % Exposure time in ms
        binning          % Bin pixels
        maxROI           % Set in constructor
        data_name = 'Widefield';  % For diamondbase (via ImagingManager)
        data_type = 'General';    % For diamondbase (via ImagingManager)
        prefs = {'binning','exposure'};
        focusThresh = 0; % Threshold when focusing. This is updated everytime.
    end
    properties(Hidden)
        core            % The Micro-Manager core utility (java)
        dev = 'Zeiss AxioCam';  % Device label (from the cfg file)
        focusPeaks;             % Stores relative pos of "significant" peaks in contrast detection
    end
    properties(SetObservable)
        resolution = [NaN NaN]; % Set in constructor and set.binning
        ROI              % Region of Interest in pixels [startX startY; stopX stopY]
        continuous = false;
    end
    properties(Access=private)
        setBinning       % Handle to GUI settings object for binning
        setExposure      % Handle to GUI settings object for Exposure
        videoTimer       % Handle to video timer object for capturing frames
        listeners
%         flipper_toggle   % Handle to GUI settings object for flipping mirror
%         mirrorStatus                       % Text object reflecting Widefield/Confocal mirror status
    end
    properties(SetObservable,SetAccess=private)
        mirror_up = false;
    end
    properties(SetAccess=immutable)
        ni                           % Hardware handle
    end
    
    methods(Access=private)
        function obj = AxioCam()
            % Initialize Java Core
            addpath 'c:/program files/Micro-Manager-1.4';
            import mmcorej.*;
            core=CMMCore;
            core.loadSystemConfiguration('C:\Program Files\Micro-Manager-1.4\AxioCam.cfg');
            obj.core = core;
            % Load preferences
            obj.core.setCircularBufferMemoryFootprint(3);  % 3 MB is enough for one full image
            obj.exposure = core.getExposure();
            obj.binning = str2double(core.getProperty(obj.dev,'Binning'));
            obj.loadPrefs;
            res(1) = core.getImageWidth();
            res(2) = core.getImageHeight();
            obj.resolution = res;
            obj.maxROI = [-obj.resolution(1)/2 obj.resolution(1)/2;...
                -obj.resolution(2)/2 obj.resolution(2)/2]*obj.binning;
            
            % get DAQ handles to control Widefield/Confocal mirror
            obj.ni = Drivers.NIDAQ.dev.instance('Dev1');
            try
                line = obj.ni.getLines('WidefieldMirror','out');
            catch err
                obj.ni.view;
                rethrow(err)
            end
            obj.mirror_up = boolean(line.state);
            obj.listeners = addlistener(line,'state','PostSet',@obj.mirrorUpdate);
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.AxioCam();
            end
            obj = Object;
        end
    end
    methods
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
                % Case of no change
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
            oldBin = obj.binning;
            obj.core.setProperty(obj.dev,'Binning',val)
            obj.binning = str2double(obj.core.getProperty(obj.dev,'Binning'));
            res(1) = obj.core.getImageWidth();
            res(2) = obj.core.getImageHeight();
            obj.resolution = res;
            if ~isempty(obj.setBinning)
                set(obj.setBinning,'string',num2str(obj.binning))
            end
            % Update exposure to match
            obj.exposure = obj.exposure*(oldBin/obj.binning)^2; %#ok<*MCSUP>
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
            val(1,:) = val(1,:) + obj.resolution(1)/2;
            val(2,:) = val(2,:) + obj.resolution(2)/2;
            val = round([val(1,1) val(2,1) val(1,2)-val(1,1) val(2,2)-val(2,1)]);
            % Use the full ROI as bounds
            obj.core.clearROI();
            roi = obj.core.getROI();
            xstart = max(roi.x,val(1));
            ystart = max(roi.y,val(1));
            width = min(roi.width-xstart,val(3));
            height = min(roi.height-ystart,val(4));
            obj.core.setROI(xstart,ystart,width,height);
        end
        function val = get.ROI(obj)
            val = obj.core.getROI();
            val = [val.x val.x+val.width; val.y val.y+val.height];
            val(1,:) = val(1,:) - obj.resolution(1)/2;
            val(2,:) = val(2,:) - obj.resolution(2)/2;
            val = val*obj.binning;
        end
        function delete(obj)
            if obj.core.isSequenceRunning()
                obj.stopVideo;
            end
            obj.core.reset()  % Unloads all devices, and clears config data
            delete(obj.core)
            delete(obj.listeners)
        end

        function metric = focus(obj,ax,Managers)
            stageManager = Managers.Stages;
            stageManager.update_gui = 'off';
            oldBin = obj.binning;
            if oldBin < 3
                obj.binning = 3;
            end
            try
                metric = obj.ContrastFocus(Managers);
                thresh = metric/2;
                if obj.focusThresh==0
                    obj.focusThresh = thresh;
                else
                    obj.focusThresh = 0.6*obj.focusThresh+0.5*thresh;
                end
            catch err
                stageManager.update_gui = 'on';
                rethrow(err)
            end
            if oldBin < 3
                obj.binning = oldBin;
            end
            stageManager.update_gui = 'on';
        end
        function im = snapImage(obj,binning)
            % This function returns the image (unlike snap)

            % Update state
            wasRunning = false;
            if obj.core.isSequenceRunning()
                wasRunning = true;
                obj.core.stopSequenceAcquisition();
            end
            if nargin > 1
                obj.binning = binning;
            end
            % Take Image
            obj.core.snapImage();
            dat = obj.core.getImage();
            width = obj.core.getImageWidth();
            height = obj.core.getImageHeight();
            dat = typecast(dat, 'uint16');
            dat = reshape(dat, [width, height]);
            im = flipud(transpose(dat));  % Fix Y inversion
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
            % Adjusts to binning of 3. Can modify after video begins.
            obj.continuous = true;
            obj.binning = 3;
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
            try % Ignore java error of empty circular buffer
                if obj.core.isSequenceRunning()&&obj.core.getRemainingImageCount()>0
                    dat = obj.core.popNextImage();
                    width = obj.core.getImageWidth();
                    height = obj.core.getImageHeight();
                    dat = typecast(dat, 'uint16');
                    dat = reshape(dat, [width, height]);
                    dat = flipud(dat');  % Fix Y inversion
                    set(hImage,'cdata',dat);
                end
                drawnow limitrate nocallbacks;
            catch err
                if ~startswith(err.message,'Java exception occurred')
                    obj.stopVideo;
                    rethrow(err)
                end
            end
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
        function  settings(obj,panelH,~,~)
            spacing = 1.5;
            num_lines = 2;
            line = 1;
            uicontrol(panelH,'style','text','string','Exposure (ms):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            obj.setExposure = uicontrol(panelH,'style','edit','string',num2str(obj.exposure),...
                'units','characters','callback',@obj.exposureCallback,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 2;
            uicontrol(panelH,'style','text','string','Binning:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            obj.setBinning = uicontrol(panelH,'style','edit','string',num2str(obj.binning),...
                'units','characters','callback',@obj.binningCallback,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
        end
        function exposureCallback(obj,hObj,eventdata)
            val = str2double((get(hObj,'string')));
            obj.exposure = val;
        end
        function binningCallback(obj,hObj,eventdata)
            val = str2double((get(hObj,'string')));
            obj.binning = val;
        end
        
        function mirrorUp(obj)
%             obj.ni.WriteDOLines('WidefieldMirror',0)
            obj.ni.WriteDOLines('WidefieldMirror',1)
        end
        function mirrorDown(obj)
%             obj.ni.WriteDOLines('WidefieldMirror',1)
            obj.ni.WriteDOLines('WidefieldMirror',0)
        end
        function mirrorUpdate(obj,varargin)
            line = obj.ni.getLines('WidefieldMirror','out');
            obj.mirror_up = boolean(line.state);
            if obj.mirror_up
                obj.mirrorUp;
            else
                obj.mirrorDown;
            end
        end
    end
end

