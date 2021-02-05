classdef umanager_invisible < Modules.Imaging
    %UMANAGER_INVISIBLE Provides interface to micromanager with basic
    %camera control.
    %
    % Subclasses should inherit this and define the Abstract properties. Anytime
    % one of these properties changes, the subclass should call the init method.
    % NOTE: the init method should also be called in the constructor; it is not
    %   called automatically here in case the subclass doesn't have the abstract
    %   properties set yet.
    %
    % The core of micromanager should be accessed through the Sealed "mmc" method
    %   varargout = obj.mmc(function_name, arg1, arg2, ...)
    %   NOTE: varargout is based on how many outputs the caller requested, not the
    %         number returned by obj.core.(function_name)
    %
    % TODO: Dynamically fetch devices capable settings

    properties(Abstract) % Used in init
        dev           % Device label for camera (from the cfg file)
        config_file;  % Config file full path or relative to classdef
    end
    properties(SetObservable,GetObservable)
        exposure = Prefs.Double('min', 0, 'unit', 'ms', 'set', 'set_exposure',...
            'help_text', 'How long each frame is integrated for.');
        binning = Prefs.Integer(1, 'min', 1, 'unit', 'px', 'set', 'set_binning',...
            'help_text', 'Hardware binning of the camera. For instance, binning = 2 ==> 2x2 superpixels. Note that not all integers will be available for your camera.');
    end

    properties
        buffer_images = 2 % Size of buffer (images): buffer_images*core.getImageBufferSize
        maxROI           % Set in constructor
        prefs = {'binning','exposure'};
        focusThresh = 0; % Threshold when focusing. This is updated everytime.
    end
    properties(SetAccess = private)
        pixelType = 'uint8'; % Set in constructor after loading config
        initialized = false;
        initializing = false; % Used to flag when init is being called
    end
    properties(SetObservable)
        resolution = [NaN NaN]; % Set in constructor and set.binning
        ROI              % Region of Interest in pixels [startX startY; stopX stopY]
        continuous = false;
    end
    properties(Hidden)
        focusPeaks;             % Stores relative pos of "significant" peaks in contrast detection
    end
    properties%(Access=private)
        core            % The Micro-Manager core utility (java); Access through mmc method
        videoTimer       % Handle to video timer object for capturing frames
    end
    methods
        function obj = umanager_invisible()
            obj.path = 'camera';
        end
    end
    methods%(Sealed,Access=protected)
        function varargout = mmc(obj,function_name,varargin)
            % Provide access to obj.core (micromanager core interface)
            assert(obj.initialized,'UMANAGER:not_initialized','"%s" has not initialized the core yet.',class(obj))
            if nargout
                varargout = cell(1,nargout);
                [varargout{:}] = obj.core.(function_name)(varargin{:});
            else
                obj.core.(function_name)(varargin{:});
            end
        end
        function init(obj)
            % Initialize Java Core.
            obj.initializing = true;
            try
                import mmcorej.*;
                obj.core = CMMCore;
            catch err
                warning(['Follow the instructions (for the correct version; this has been tested to work for 1.4) at https://micro-manager.org/wiki/Matlab_Configuration to install Micromananger for MATLAB!' 13 ...
                        '    This process asks you to append to MATLAB files such as librarypath.txt. You might not have adminstrative privledges to save these files directly; try modifying externally and move and replace as a workaround.']);
                rethrow(err);
            end
            
            % Load config file.
            config_file_full = obj.config_file;
            if ~(  (length(obj.config_file)>1 && obj.config_file(2) == ':') ||... % PC
                   (~isempty(obj.config_file) && obj.config_file(1) == '/')  )    % Unix-based
                [path,~,~] = fileparts(which(class(obj)));
                config_file_full = fullfile(path,obj.config_file);
            end
            if ~isfile(config_file_full)
                error('Could not find config file: "%s"',config_file_full);
            end
            obj.core.loadSystemConfiguration(config_file_full);
            
            % Load preferences.
            nbytes = obj.core.getBytesPerPixel;
            switch nbytes
                case 1
                    obj.pixelType = 'uint8';
                case 2
                    obj.pixelType = 'uint16';
                case 4
                    obj.pixelType = 'uint32';
                case 8
                    obj.pixelType = 'uint64';
                otherwise
                    error('Unsupported pixel data type: %i bytes/pixel',nbytes)
            end
            single_image = obj.core.getImageBufferSize/1024^2; % MB
            obj.core.setCircularBufferMemoryFootprint(single_image*obj.buffer_images);
            obj.initialized = true;

            
            obj.exposure = obj.core.getExposure();
            obj.binning = str2double(obj.core.getProperty(obj.dev,'Binning'));
            res(1) = obj.core.getImageWidth();
            res(2) = obj.core.getImageHeight();
            obj.resolution = res;
            new_ROI = [-obj.resolution(1)/2 obj.resolution(1)/2;...
                -obj.resolution(2)/2 obj.resolution(2)/2]*obj.binning;
            obj.maxROI = new_ROI;
            obj.ROI = new_ROI;
            
            measname = split(obj.dev, [" ", ":"]);
            obj.measurements = Base.Meas('size', obj.resolution, 'field', 'img', 'name', measname{1}, 'unit', 'cts');
            
            obj.initializing = false;
        end
    end
    methods
        function delete(obj)
            if obj.initialized
                if obj.core.isSequenceRunning()
                    obj.stopVideo;
                end
                obj.core.reset()  % Unloads all devices, and clears config data
                delete(obj.core)
            end
        end
        function [values,options] = get_all_properties(obj)
            % Useful method to get all available properties and their options
            % TODO: use this to dynamically build settings panel
            props = obj.mmc('getDevicePropertyNames',obj.dev);
            options = struct();
            values = struct();
            for i = 1:props.size
                prop = char(props.get(i-1));
                vals = obj.mmc('getAllowedPropertyValues',obj.dev,prop);
                nvals = vals.size();
                if nvals
                    vals_cell = cell(1,nvals);
                    for j = 1:nvals
                        vals_cell{j} = char(vals.get(j-1));
                    end
                    values.(prop) = char(obj.mmc('getProperty',obj.dev,prop));
                    options.(prop) = vals_cell;
                end
            end
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
            if obj.mmc('isSequenceRunning')
                wasRunning = true;
                obj.mmc('stopSequenceAcquisition');
            end
            if nargin > 1
                obj.binning = binning;
            end
            % Take Image
            obj.mmc('snapImage');
            if obj.exposure >= 100
                pause(obj.exposure/2000)    % Allow other parts of CC to update while camera is working.
            end
            dat = obj.mmc('getImage');
            width = obj.mmc('getImageWidth');
            height = obj.mmc('getImageHeight');
            dat = typecast(dat, obj.pixelType);
            dat = reshape(dat, [width, height]);
            im = transpose(dat);  % make column-major order for MATLAB
            if wasRunning
                obj.mmc('startContinuousSequenceAcquisition',100);
            end
        end
        function snap(obj,hImage)
            % This function calls snapImage and applies to hImage.
            im = obj.snapImage;
            set(hImage,'cdata',im)
        end
        function data = measure(obj)
            data = obj.snapImage;
        end
        function startVideo(obj,hImage)
            obj.continuous = true;
            if obj.mmc('isSequenceRunning')
                warndlg('Video already started.')
                return
            end
            obj.mmc('startContinuousSequenceAcquisition',100);
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
                if obj.mmc('isSequenceRunning')&&obj.mmc('getRemainingImageCount')>0
                    dat = obj.mmc('popNextImage');
                    width = obj.mmc('getImageWidth');
                    height = obj.mmc('getImageHeight');
                    dat = typecast(dat, obj.pixelType);
                    dat = reshape(dat, [width, height]);
                    dat = transpose(dat);  % make column-major order for MATLAB
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
            if ~obj.mmc('isSequenceRunning')
                warndlg('No video started.')
                obj.continuous = false;
                return
            end
            obj.mmc('stopSequenceAcquisition');
            stop(obj.videoTimer)
            delete(obj.videoTimer)
            obj.continuous = false;
        end

        % Set methods for prefs
        function val = set_exposure(obj,val,~)
            if val == obj.mmc('getExposure')
                return
            end
            wasRunning = false;
            if obj.mmc('isSequenceRunning')
                % Pause camera acquisition, but leave the video going
                % (just wont be frames until we resume acquisition)
                obj.mmc('stopSequenceAcquisition');
                wasRunning = true;
            end
            obj.mmc('setExposure',val)
            % Incase an invalid exposure was set, grab what core set it to
            val = obj.mmc('getExposure');
            if wasRunning
                obj.mmc('startContinuousSequenceAcquisition',100);
            end
        end
        function val = set_binning(obj,val,~)
            if val==str2double(obj.mmc('getProperty',obj.dev,'Binning'))
                return
            end
            wasRunning = false;
            if obj.mmc('isSequenceRunning')
                % Pause camera acquisition, but leave the video going
                % (just wont be frames until we resume acquisition)
                obj.mmc('stopSequenceAcquisition');
                wasRunning = true;
            end
            oldBin = obj.binning;
            obj.mmc('setProperty',obj.dev,'Binning',val)
            val = str2double(obj.mmc('getProperty',obj.dev,'Binning'));
            res(1) = obj.mmc('getImageWidth');
            res(2) = obj.mmc('getImageHeight');
            obj.resolution = res;
            % Update exposure to match
            obj.exposure = obj.exposure*(oldBin/val)^2; %#ok<*MCSUP>
            if wasRunning
                obj.mmc('startContinuousSequenceAcquisition',100);
            end
        end
        % Set/Get methods for other properties
        function set.ROI(obj,val)
            % Because this has a draggable rectangle in CommandCenter, it
            % is best to not stop and start acquisition like we do with
            % exposure and binning
            if obj.initializing
                % If we are initializing, this isn't a user setting ROI, it
                % is grabbed by the core directly
                obj.ROI = val;
                return
            end
            assert(~obj.mmc('isSequenceRunning'),'Cannot set while video running.')
            val = val/obj.binning;
            val(1,:) = val(1,:) + obj.resolution(1)/2;
            val(2,:) = val(2,:) + obj.resolution(2)/2;
            val = round([val(1,1) val(2,1) val(1,2)-val(1,1) val(2,2)-val(2,1)]);
            % Use the full ROI as bounds
            obj.mmc('clearROI');
            roi = obj.mmc('getROI');
            xstart = max(roi.x,val(1));
            ystart = max(roi.y,val(2));
            width = min(roi.width-xstart,val(3));
            height = min(roi.height-ystart,val(4));
            obj.mmc('setROI',xstart,ystart,width,height);
        end
        function val = get.ROI(obj)
            if ~obj.initialized
                val = NaN(2);
                return
            end
            val = obj.mmc('getROI');
            val = [val.x val.x+val.width; val.y val.y+val.height];
            val(1,:) = val(1,:) - obj.resolution(1)/2;
            val(2,:) = val(2,:) - obj.resolution(2)/2;
            val = val*obj.binning;
        end
    end
end
