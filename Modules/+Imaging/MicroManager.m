classdef MicroManager < Modules.Imaging
    %MicroManager Provides an interface to micromanager with basic
    % camera control.

    properties(SetObservable,GetObservable)
        dev =           Prefs.String(...
            'help_text', 'This is the device label for the camera from the config file.');
        config_file =   Prefs.File('filter_spec', '*.cfg',...
            'help_text', 'Path to MicroManager .cfg file.');
        reload =        Prefs.Boolean(false,'set','reload_toggle',...
            'help_text', 'Toggle this to reload MicroManager.')
        exposure =      Prefs.Double('min', 0, 'unit', 'ms', 'set', 'set_exposure',...
            'help_text', 'How long each frame is integrated for.');
        binning =       Prefs.Integer(1, 'min', 1, 'unit', 'px', 'set', 'set_binning',...
            'help_text', 'Hardware binning of the camera. For instance, binning = 2 ==> 2x2 superpixels. Note that not all integers will be available for your camera.');
    end

    properties
        maxROI                  % Set in constructor
        prefs = {'dev', 'config_file', 'reload', 'binning', 'exposure'};
    end
    properties(SetAccess=private)
        initialized = false;    % Having two of these variables is quesionable.
        initializing = false;   % Used to flag when init is being called
    end
    properties(SetObservable)
        resolution = [NaN NaN]; % Set in constructor and set.binning
        ROI                     % Region of Interest in pixels [startX startY; stopX stopY]
        continuous = false;     % Tempted to get rid of this.
    end
    properties%(Access=private)
        core            % The Micro-Manager core utility (java)
        
        pixelType = 'uint8';    % Set in constructor after loading config
        buffer_images = 2       % Size of buffer (images): buffer_images*core.getImageBufferSize
        
        videoTimer              % Handle to video timer object for capturing frames
    end
    
    %
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.MicroManager();
            end
            obj = Object;
        end
    end
    methods(Access={?Imaging.MicroManagerVideomode})
        function obj = MicroManager()
            obj.path = 'camera';
            obj.loadPrefs();
        end
    end
    
    
    methods%(Sealed,Access=protected)
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
            nbytes = obj.core.getBytesPerPixel();
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
                    error('Unsupported pixel data type: %i bytes/pixel', nbytes)
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
                    obj.core.stopSequenceAcquisition();
                end
                
                obj.core.reset();   % Unloads all devices, and clears config data
                delete(obj.core);
                
                if ~isempty(obj.videoTimer)
                    if isvalid(obj.videoTimer)
                        stop(obj.videoTimer)
                    end
                    delete(obj.videoTimer)
                    obj.videoTimer = [];
                end
            end
        end
        function [values,options] = get_all_properties(obj)
            % Useful method to get all available properties and their options
            % TODO: use this to dynamically build settings panel
            props = obj.core.getDevicePropertyNames(obj.dev);
            options = struct();
            values = struct();
            for i = 1:props.size
                prop = char(props.get(i-1));
                vals = obj.core.getAllowedPropertyValues(obj.dev, prop);
                nvals = vals.size();
                if nvals
                    vals_cell = cell(1,nvals);
                    for j = 1:nvals
                        vals_cell{j} = char(vals.get(j-1));
                    end
                    values.(prop) = char(obj.core.getProperty(obj.dev, prop));
                    options.(prop) = vals_cell;
                end
            end
        end

        function metric = focus(obj,ax,Managers)
            
        end
        function im = snapImage(obj)
            % This function returns the image (unlike snap)
            % Update state
            wasRunning = obj.core.isSequenceRunning();
            if wasRunning
                obj.core.stopSequenceAcquisition();
            end
            
            % Take Image
            obj.core.snapImage();
            if obj.exposure >= 100
                pause(obj.exposure/2000)    % Allow other parts of CC to update while the camera is working.
            end
            
            width = obj.core.getImageWidth();
            height = obj.core.getImageHeight();
            im = transpose(reshape(typecast(obj.core.getImage(), obj.pixelType), [width, height])); % Reshape and retype image.
            
            if wasRunning
                obj.core.startContinuousSequenceAcquisition(100);
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
            if obj.core.isSequenceRunning()
                warndlg('Video already started.')
                return
            end
            obj.core.startContinuousSequenceAcquisition(100);
            obj.videoTimer = timer('tag', 'Video Timer',...
                                   'ExecutionMode', 'FixedSpacing',...
                                   'BusyMode', 'drop',...
                                   'Period', 0.01,...
                                   'TimerFcn', {@obj.grabFrame, hImage});
            start(obj.videoTimer)
        end
        function grabFrame(obj,~,~,hImage)
            % Timer Callback for frame acquisition
            try % Ignore java error of empty circular buffer
                if obj.core.isSequenceRunning() && obj.core.getRemainingImageCount() > 0
                    width = obj.core.getImageWidth();
                    height = obj.core.getImageHeight();
                    dat = transpose(reshape(typecast(obj.core.popNextImage(), obj.pixelType), [width, height]));
                    set(hImage,'cdata',dat);
                end
                drawnow limitrate nocallbacks;
            catch err
                if ~startswith(err.message,'Java exception occurred')
                    obj.stopVideo();
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

        % Set methods for prefs
        function val = set_exposure(obj,val,~)
            if isempty(obj.core)
                return
            end
            if val == obj.core.getExposure()
                return
            end
            
            wasRunning = obj.core.isSequenceRunning();
            if wasRunning
                % Pause camera acquisition, but leave the video going
                % (just wont be frames until we resume acquisition)
                obj.core.stopSequenceAcquisition();
            end
            
            obj.core.setExposure(val);
            % In case an invalid exposure was set, grab the current value from core
            val = obj.core.getExposure();
            
            if wasRunning
                obj.core.startContinuousSequenceAcquisition(100);
            end
        end
        function val = set_binning(obj,val,~)
            if isempty(obj.core)
                return
            end
            
            if val == str2double(obj.core.getProperty(obj.dev,'Binning'))
                return
            end
            
            wasRunning = obj.core.isSequenceRunning();
            if wasRunning
                % Pause camera acquisition, but leave the video going
                % (just wont be frames until we resume acquisition)
                obj.core.stopSequenceAcquisition();
            end
            
            oldBin = obj.binning;
            obj.core.setProperty(obj.dev,'Binning',val);
            val = str2double(obj.core.getProperty(obj.dev,'Binning'));
            obj.resolution = [obj.core.getImageWidth() obj.core.getImageHeight()];
            
            % Update exposure to match (Remove this?)
            obj.exposure = obj.exposure*(oldBin/val)^2; %#ok<*MCSUP>
            
            if wasRunning
                obj.core.startContinuousSequenceAcquisition(100);
            end
        end
        function val = reload_toggle(obj,val,~)
            % TODO: replace with a Prefs.Button
            % Pretends to be a button from a boolean pref
            if val
                val = false; % Swap back to false
                
                if ~isempty(obj.core)
                    obj.core.reset()  % Unloads all devices, and clears config data
                    delete(obj.core)
                end
                
                obj.init;
            end
%             obj.loadPrefs('-config_file','-dev');
        end
    
        % These functions should perhaps be somewhere else.
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
            
            assert(~obj.core.isSequenceRunning(), 'Cannot set while video running.')
            
            val = val/obj.binning;
            val(1,:) = val(1,:) + obj.resolution(1)/2;
            val(2,:) = val(2,:) + obj.resolution(2)/2;
            val = round([val(1,1) val(2,1) val(1,2)-val(1,1) val(2,2)-val(2,1)]);
            
            % Use the full ROI as bounds
            obj.core.clearROI();
            roi = obj.core.getROI();
            
            xstart = max(roi.x, val(1));
            ystart = max(roi.y, val(2));
            
            width =  min(roi.width -xstart, val(3));
            height = min(roi.height-ystart, val(4));
            
            obj.core.setROI(xstart,ystart,width,height);
        end
        function val = get.ROI(obj)
            if ~obj.initialized
                val = NaN(2);
                return
            end
            val = obj.core.getROI();
            val = [val.x val.x+val.width; val.y val.y+val.height];
            val(1,:) = val(1,:) - obj.resolution(1)/2;
            val(2,:) = val(2,:) - obj.resolution(2)/2;
            val = val*obj.binning;
        end
    end
end
