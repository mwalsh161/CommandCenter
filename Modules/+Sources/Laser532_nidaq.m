classdef Laser532_nidaq < Modules.Source
    %LASER532 Summary of this class goes here
    %   Detailed explanation goes here

    methods(Access=protected)
        function obj = Laser532_nidaq()
         
        end
    end
    methods(Static)
        function obj = instance()
            warning('Sources.Laser532_nidaq no longer exists. It has been moved to Sources.Green_532Laser.Laser532_nidaq. Please change Sources.Laser532_nidaq to Sources.Green_532Laser.Laser532_nidaq.')
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
