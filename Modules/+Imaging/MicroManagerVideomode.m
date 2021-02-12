classdef MicroManagerVideomode < Imaging.MicroManager
    %MicroManagerVideomode Extends MicroManager with the option to avoid excessive calls to `core.getImage()` and
    %`core.startContinuousSequenceAcquisition`, which appear to cause memory leaks on some hardware. This mode keeps continuous acquisition always on.
    
    properties(GetObservable, SetObservable)
        videomode = Prefs.Boolean(false, 'set', 'set_videomode', 'help_text', 'Whether continuous acquisition mode is on and ready to snap frames.');
    end
    properties(SetAccess=private)
        timeout = Inf 
        attempts = 0;
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.MicroManagerVideomode();
            end
            obj = Object;
        end
    end
    methods(Access=private)
        function obj = MicroManagerVideomode()
            obj.path = 'camera';
        end
    end
    
    methods
        function metric = focus(obj,ax,Managers)
            
        end
        
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
            
            obj.timeout = 1.5 * obj.exposure / 1000 + 1;
        end
        
        function val = set_videomode(obj, val, pref)
            if pref.value && ~val       % Turning off
                obj.core.stopSequenceAcquisition();
            elseif val && ~pref.value   % Turning on
                obj.core.startContinuousSequenceAcquisition(100);
            end
        end
        function im = snapImage(obj) %, delaygrab)
            if obj.continuous
                obj.stopVideo();
            end
            
            if ~obj.core.isSequenceRunning()    % Faster than polling videomode.
                obj.videomode = true;
            end
            
%             if nargin < 2
%                 delaygrab = false;
%             end
%             if delaygrab
%                 pause(obj.exposure/1000);
%             end
            
            t = tic;
            
            width = obj.core.getImageWidth();
            height = obj.core.getImageHeight();

            while obj.core.getRemainingImageCount() == 0 && toc(t) < obj.timeout
                pause(.005);
            end
            
            im = [];
            
            while isempty(im) && toc(t) < obj.timeout
                try
                    im = transpose(reshape(typecast(obj.core.popNextImage(), obj.pixelType), [width, height])); % Reshape and retype image.
                catch err
                    if ~startswith(err.message, 'Java exception occurred')
                        obj.videomode = false;
                        rethrow(err)
                    end
                end
            end
            
            if obj.timeout <= toc(t) 
                str = ['Camera "' obj.dev '" failed to acquire image within the timeout of ' num2str(obj.timeout) ' seconds.'];
                if obj.attempts > 0
                    error(str);
                else
                    warning(str);

                    obj.videomode = false;
                    obj.reload = true;

                    obj.attempts = 1;
                    im = obj.snapImage();
                    obj.attempts = 0;
                end
            end
            
            if isempty(im)
                error(['Camera "' obj.dev '" failed to acquire image.']);
            end
        end
        
        function startVideo(obj,hImage)
            'start'
            if obj.videomode
                obj.videomode = false;
            end
            
            obj.continuous = true;
            if obj.core.isSequenceRunning()
%                 warndlg('Video already started.')
%                 return
            else
                obj.core.startContinuousSequenceAcquisition(100);
            end
            
            if ~isempty(obj.videoTimer)
                if isvalid(obj.videoTimer)
                    stop(obj.videoTimer)
                end
                delete(obj.videoTimer)
                obj.videoTimer = [];
            end
            
            obj.videoTimer = timer('tag', 'Video Timer',...
                                   'ExecutionMode', 'FixedSpacing',...
                                   'BusyMode', 'drop',...
                                   'Period', 0.01,...
                                   'TimerFcn', {@obj.grabFrame, hImage});
            start(obj.videoTimer)
        end
        function grabFrame(obj,~,~,hImage)
            if obj.continuous
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
        end
        function stopVideo(obj)
            'stop'
            if obj.continuous
                if ~obj.core.isSequenceRunning()
    %                 if obj.continuous
    %                     warndlg('No video started.')
    %                 end
                    obj.continuous = false;
                    return
                end

                obj.core.stopSequenceAcquisition();
                if ~isempty(obj.videoTimer)
                    if isvalid(obj.videoTimer)
                        stop(obj.videoTimer)
                    end
                    delete(obj.videoTimer)
                    obj.videoTimer = [];
                end
                obj.continuous = false;
            end
        end
    end
end
