classdef WhiteLight_Axiovert200 < Modules.Source
    %LASER532 Summary of this class goes here
    %   Detailed explanation goes here

    methods(Access=protected)
        function obj = WhiteLight_Axiovert200()

        end
    end
    methods(Static)
        function obj = instance()
           error('Sources.WhiteLight_Axiovert200 no longer exists. It has been moved to Sources.WhiteLight.WhiteLight_Axiovert200.Please change Sources.WhiteLight_Axiovert200 to Sources.WhiteLight.WhiteLight_Axiovert200.')
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

