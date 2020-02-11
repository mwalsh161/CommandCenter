classdef AndorEMCCD < Imaging.Camera.Micromanager_camera_invisible
    %AndorEMCCD Control
    %
    
    properties
        data_name = 'Widefield';  % For diamondbase (via ImagingManager)
        data_type = 'General';    % For diamondbase (via ImagingManager)
        device_path='C:\Program Files\Micro-Manager-1.4';
        CamCenterCoord = [0,0]
        offset = 100; %dc offset
    end
    
    properties (Constant)
        dev = 'Andor';  % Device label open cfg file to find this out!
        dev_filename = 'AndorEMCCD';% cfg filename @ device_path
    end
    
    methods(Access=private)
        function obj = AndorEMCCD()
            
            
        end
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Imaging.Camera.AndorEMCCD();
            end
            obj = Object;
        end
    end
    methods
     
        function delete(obj)
        end
        
       
    end
end

