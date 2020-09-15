classdef QRNavigation < handle % Modules.Driver
    %
    
    properties(SetObservable,GetObservable)
        sample =        Prefs.File('filter_spec', '*.mat', ...
                                                'help', 'Information regarding ');
        new_sample =    Prefs.Boolean('set', 'set_new_sample', ...
                                                'help', 'Information regarding ');
        
        coarse_x =  Prefs.Pointer();
        coarse_y =  Prefs.Pointer();
        coarse_z =  Prefs.Pointer();
        
        fine_x =    Prefs.Pointer();
        fine_y =    Prefs.Pointer();
        fine_z =    Prefs.Pointer();
        
        image_main =    Prefs.ModuleInstance('inherits', {'Modules.Imaging'}, 'set', 'set_main_image', ...
                                                'help', 'Main image used for QR navigation. This is often a simple CCD such as a compact ThorCam.');
        QR_ang_main =   Prefs.Double(0, 'unit', 'deg', ...
                                                'help', '(Counter-clockwise) rotation of the QR code in the main image.');
                                            
        image_aux =     Prefs.ModuleInstance('inherits', {'Modules.Imaging'}, 'set', 'set_aux_image', ...
                                                'help', ['Auxilary image. For instance, this could be a higher performace camera with a smaller field of view:' ... 
                                                        'an image that we want to know the position of, but is for whatever reason insufficient for movement.' ... 
                                                        ' In the future, this should be generalized to any number of auxilary images.']);
        QR_ang_aux =    Prefs.Double(0, 'unit', 'deg', ...
                                                'help', '(Counter-clockwise) rotation of the QR code in the auxilary image.');
        
        QR_len =    Prefs.Double(6.25,  'unit', 'um', 'min', 0, 'readonly', true, ...
                                                'help', 'Length of the arms of the QR code. This is the distance between the centers of the large holes');
        QR_rad =    Prefs.Double(.3,    'unit', 'um', 'min', 0, 'readonly', true, ...
                                                'help', 'Radius of the three large holes that are used for positioning.');
        QR_gap =    Prefs.Double(40,    'unit', 'um', 'min', 0, 'readonly', true, ...
                                                'help', 'Standard spacing between QR codes.');
        
        
    end
    
    methods(Static)
        function obj = instance(id)
            mlock;
            persistent Objects
            
            if isempty(Objects)
                Objects = Drivers.QRNavigation.empty(1,0);
            end
            
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(id, Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            
            obj = Drivers.QRNavigation(id);
            obj.singleton_id = id;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = QRNavigation(id)
            % Nothing
        end
    end
    methods
        function delete(obj)
            
        end
        
        function calibrateXY()
            
        end
        function calibrateZ()
            
        end
        function calibrateImage()
            
        end
        
        function [X, Y] = getPosition()
            
        end
        
        function moveRelative(dX, dY)
            
        end
        function moveGlobal(X, Y)
            
        end
    end
end