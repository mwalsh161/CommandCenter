classdef Hamamatsu <Imaging.Camera.Micromanager_camera_invisible 
    %Hamamatsu Control Hamamatsu  camera
    %   
    
    properties
        maxROI           % Set in constructor
        data_name = 'Widefield';  % For diamondbase (via ImagingManager)
        data_type = 'General';    % For diamondbase (via ImagingManager)
        device_path='C:\Program Files\Micro-Manager-1.4';
    end
    properties (Constant)
        dev = 'HamamatsuHam_DCAM';  % Device label open cfg file to find this out!
        dev_filename = 'HamamatsuEMCCD';% cfg filename @ device_path
    end
    
    
    
    methods(Access=private)
        function obj = Hamamatsu()
            
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.Camera.Hamamatsu();
            end
            obj = Object;
        end
      
    end
    methods
      
        function delete(obj)
            
        end
       
    end
end

