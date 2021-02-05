classdef MicroManagerVideomode < Imaging.MicroManager
    %MicroManagerVideomode Extends MicroManager with the option to avoid excessive calls to `core.getImage()` and
    %`core.startContinuousSequenceAcquisition`, which appear to cause memory leaks on some hardware. This mode keeps continuous acquisition always on.
    
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
    methods
        function obj = MicroManagerVideomode()
            obj.path = 'camera';
        end
    end
    
    methods
        function delete(obj)
            if obj.initialized
                if obj.core.isSequenceRunning()
                    obj.stopVideo();
                end
                obj.core.reset();   % Unloads all devices, and clears config data
                delete(obj.core);
            end
        end

        function metric = focus(obj,ax,Managers)
            
        end
        function startVideomode(obj)
            obj.core.startContinuousSequenceAcquisition(100);
            obj.continuous = true;
            
        end
        function stopVideomode(obj)
            obj.core.stopSequenceAcquisition();
            obj.continuous = false;
        end
        function im = snapImage(obj) %, delaygrab)
            if ~obj.continuous
                obj.startVideomode();
            end
            
%             if nargin < 2
%                 delaygrab = false;
%             end
%             if delaygrab
%                 pause(obj.exposure/1000);
%             end

            timeout = 1.5 * obj.exposure / 1000 + 1;
            
            t = tic;

            while obj.core.getRemainingImageCount() == 0 && timeout < toc(t)
                pause(.01);
            end
            
            im = [];
            
            width = obj.core.getImageWidth();
            height = obj.core.getImageHeight();
            
            while isempty(im)
                try
                    im = transpose(reshape(typecast(obj.core.popNextImage(), obj.pixelType), [width, height])); % Reshape and retype image.
                catch
                    if ~startswith(err.message, 'Java exception occurred')
                        obj.stopVideo();
                        rethrow(err)
                    end
                end
            end
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
                if obj.continuous
                    warndlg('No video started.')
                end
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
