classdef uc480 < Modules.Imaging
    % Connects with old-style Thorlabs cameras.
    
    properties
        maxROI = [-1 1; -1 1];
        
        prefs = {'exposure'};
        
        cam = []
        MemId = []
    end
    properties(GetObservable, SetObservable)
        exposure =      Prefs.Double(NaN, 'units', 'ms', 'min', 0, 'max', inf, 'allow_nan', true, 'set', 'set_exposure');
%         serial_number = Prefs.String('', 'readonly', true, 'allow_empty', true);
    end
    properties(GetObservable, SetObservable)
        bitdepth = 0;
        resolution = [120 120];                 % Pixels
        ROI = [-1 1;-1 1];
        continuous = false;
    end
    methods(Access=private)
        function obj = uc480()
            % Open camera connection
            NET.addAssembly('C:\Program Files\Thorlabs\Scientific Imaging\DCx Camera Support\Develop\DotNet\uc480DotNet.dll');
            
            % Create camera object handle and open the 1st available camera
            obj.cam = uc480.Camera;
            obj.cam.Init(0);
            
            % Set display mode to bitmap (DiB) and color mode to 8-bit RGB
            obj.cam.Display.Mode.Set(uc480.Defines.DisplayMode.DiB);
            obj.cam.PixelFormat.Set(uc480.Defines.ColorMode.RGBA8Packed);
            
            % Set trigger mode to software (single image acquisition)
            obj.cam.Trigger.Set(uc480.Defines.TriggerMode.Software);
            
            % Allocate memory and take image
            [~, obj.MemId] = obj.cam.Memory.Allocate(true);
            [~, W, H, B, ~] = obj.cam.Memory.Inquire(obj.MemId);
            
%             % Grab serial number
%             info = obj.cam.GetSensorInfo()
%             obj.serial_number
            
            % Deal with CC stuff
            obj.bitdepth = B;
            obj.resolution = [double(W), double(H)];
            obj.maxROI = [1 obj.resolution(1); 1 obj.resolution(2)];
            obj.ROI = obj.maxROI;
            obj.loadPrefs;
        end
    end
    methods
        function delete(obj)
            try
                if ~isempty(obj.cam)
                    obj.cam.Exit;
                end
            end
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.Thorlabs.uc480();
            end
            obj = Object;
        end
    end
    methods
        function milliseconds = set_exposure(obj, milliseconds, ~)
            % set exposure time
            obj.cam.Timing.Exposure.Set(milliseconds) %ms
            [~, milliseconds] = obj.cam.Timing.Exposure.Get;
        end
        function set.ROI(obj,val)
            % Update ROI without going outside maxROI
            val(1,1) = max(obj.maxROI(1,1),val(1,1)); %#ok<*MCSUP>
            val(1,2) = min(obj.maxROI(1,2),val(1,2));
            val(2,1) = max(obj.maxROI(2,1),val(2,1));
            val(2,2) = min(obj.maxROI(2,2),val(2,2));
            % Now make sure no cross over
            val(1,2) = max(val(1,1),val(1,2));
            val(2,2) = max(val(2,1),val(2,2));
            obj.ROI = val;
        end
    end
    methods
        function focus(obj,ax,stageHandle) %#ok<INUSD>
            error('Thorlabs.uc480.focus() NotImplemented')
        end
        function img = snapImage(obj)
            % Acquire image
            obj.cam.Acquisition.Freeze(uc480.Defines.DeviceParameter.Wait);
            
            % Copy image from memory
            [~, tmp] = obj.cam.Memory.CopyToArray(obj.MemId);
            
            % Reshape image (make more efficient)
            img = reshape(uint8(tmp), [obj.bitdepth/8, obj.resolution(1), obj.resolution(2)]);
            img = img(1:3, 1:obj.resolution(1), 1:obj.resolution(2));
            img = permute(img, [3,2,1]);
            img = sum(img, 3);
        end
        % Required method of Modules.Imaging. The "snap button" in the UI calls this and displays the camera result on the imaging axis.
        function snap(obj, im, ~)
            im.CData = obj.snapImage();
        end
        function startVideo(obj, im)
            obj.continuous = true;
            while obj.continuous
                obj.snap(im, true);
                drawnow;
            end
        end
        function stopVideo(obj)
            obj.continuous = false;
        end
        
    end
    
end

