classdef CS235CU < Modules.Imaging
    % Connects with old-style Thorlabs cameras.
    
    properties
        maxROI = [-1 1; -1 1];
        
        prefs = {'exposure'};
        
        cam = []
        MemId = []
    end
    properties(GetObservable, SetObservable)
        exposure =      Prefs.Double(NaN, 'units', 'ms', 'min', 0, 'max', inf, 'allow_nan', true, 'set', 'set_exposure');
    end
    properties(GetObservable, SetObservable)
        bitdepth = 0;
        resolution = [120 120];                 % Pixels
        ROI = [-1 1;-1 1];
        continuous = false;
    end
    methods(Access=private)
        function obj = CS235CU()
            % Open camera connection
            try
                NET.addAssembly('C:\Program Files\Thorlabs\Scientific Imaging\Scientific Camera Support\Scientific Camera Interfaces\SDK\DotNet Toolkit\dlls\Managed_64_lib\Thorlabs.TSI.TLCamera.dll');
            catch
                error('Could not load CS235CU NET. Make sure that ThorCam is installed.')
            end
            
            % Create an Instance of ITLCameraSDK
            tlCameraSDK = Thorlabs.TSI.TLCamera.TLCameraSDK.OpenTLCameraSDK;
            % Discover connected Thorlabs scientific cameras
            serialNumbers = tlCameraSDK.DiscoverAvailableCameras;
            % Open the first camera in the list
            obj.cam = tlCameraSDK.OpenCamera(serialNumbers.Item(0), false);
            
%             % Set display mode to bitmap (DiB) and color mode to 8-bit RGB
%             obj.cam.Display.Mode.Set(uc480.Defines.DisplayMode.DiB);
%             obj.cam.PixelFormat.Set(uc480.Defines.ColorMode.RGBA8Packed);
            
            % Set trigger mode to software (single image acquisition)
            obj.cam.OperationMode = Thorlabs.TSI.TLCameraInterfaces.OperationMode.SoftwareTriggered;
            % Prepare camera for software trigger
            obj.cam.Arm;
%             % Issue software trigger
%             obj.cam.IssueSoftwareTrigger;
%             
%             % Allocate memory and take image
%             [~, obj.MemId] = obj.cam.Memory.Allocate(true);
%             [~, W, H, B, ~] = obj.cam.Memory.Inquire(obj.MemId);
%             
%             % Deal with CC stuff
%             obj.bitdepth = B;
%             obj.resolution = [double(W), double(H)];
%             obj.maxROI = [1 obj.resolution(1); 1 obj.resolution(2)];
%             obj.ROI = obj.maxROI;
%             obj.loadPrefs;
        end
    end
    methods
        function delete(obj)
            try
                if ~isempty(obj.cam)
                    obj.cam.Disarm;
                    obj.cam.Dispose;
                end
            end
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.Thorlabs.CS235CU();
            end
            obj = Object;
        end
    end
    methods
        function milliseconds = set_exposure(obj, milliseconds, ~)
            % set exposure time
            obj.cam.ExposureTime_us =  milliseconds * 1000;%us
            milliseconds = obj.cam.ExposureTime_us / 1000;
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
            imageFrame = obj.cam.GetPendingFrameOrNull;
            if ~isempty(imageFrame)
                img = imageFrame;
            end
                
%             % Acquire image
%             obj.cam.Acquisition.Freeze(uc480.Defines.DeviceParameter.Wait);
%             
%             % Copy image from memory
%             [~, tmp] = obj.cam.Memory.CopyToArray(obj.MemId);
%             
%             % Reshape image (make more efficient)
%             img = reshape(uint8(tmp), [obj.bitdepth/8, obj.resolution(1), obj.resolution(2)]);
%             img = img(1:3, 1:obj.resolution(1), 1:obj.resolution(2));
%             img = permute(img, [3,2,1]);
%             img = sum(img, 3);
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

