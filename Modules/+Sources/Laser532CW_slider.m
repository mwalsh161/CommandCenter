classdef Laser532CW_slider < Modules.Source
    %LASER532 Summary of this class goes here
    %   Detailed explanation goes here
 
    methods(Access=protected)
        function obj = Laser532CW_slider()
          
        end
    end
    methods(Static)
        function obj = instance()
           error('Sources.Laser532CW_slider no longer exists. It has been moved to Sources.Green_532Laser.Laser532CW_slider.Please change Sources.Laser532CW_slider to Sources.Green_532Laser.Laser532CW_slider.')
        end
    end
    methods
        function delete(obj)
        end
       
        % Settings and Callbacks
        function settings(obj,panelH)
        end
    end
end

