classdef AxioCam < Modules.Imaging & Imaging.Camera.Micromanager_camera_invisible
    %AxioCam Control Zeiss AxioCam camera
    %   
    
    properties
      
        maxROI           % Set in constructor
        data_name = 'Widefield';  % For diamondbase (via ImagingManager)
        data_type = 'General';    % For diamondbase (via ImagingManager)
        device_path='C:\Program Files\Micro-Manager-1.4';
    end
     properties (Constant)
        dev = 'Zeiss AxioCam';  % Device label open cfg file to find this out!
        dev_filename = 'AxioCam';% cfg filename @ device_path
    end
    
    properties(SetObservable,SetAccess=private)
        mirror_up = false;
    end
    properties(SetAccess=immutable)
        ni                           % Hardware handle
    end
    
    methods(Access=private)
        function obj = AxioCam()
 
       
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.Camera.AxioCam();
            end
            obj = Object;
        end
     
    end
    methods
       
        function delete(obj)
          
        end

    end
end

