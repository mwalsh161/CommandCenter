classdef Laser532_nidaq < Modules.Source & Sources.Verdi_invisible
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
        function tasks = inactive(obj)
            tasks = inactive@Sources.Verdi_invisible(obj);
        end
        function delete(obj)
        end
       
        function update(obj,varargin)
            line = obj.ni.getLines('532 Laser','out');
            obj.source_on = boolean(line.state);
            if obj.source_on
                obj.on;
            else
                obj.off;
            end
        end
    end
end
