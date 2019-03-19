classdef (Sealed) Path < Modules.Driver
    %PATH Use flip mirrors controlled by NIDAQ
    
    properties
        paths = struct('name',{},...  % Memorable name to reference optical path
                       'config',{});  % Each cell is list (NIDAQ port,state) where state is 1/0
    end
    properties(SetAccess=immutable)
        nidaq
    end
    
    events
    end
    
    methods(Access=protected)
        function obj = Path()
            obj.nidaq = Drivers.NIDAQ.instance;
        end
    end
    methods(Static)
        function singleObj = instance()
            mlock;
            persistent localObj
            if isempty(localObj) || ~isvalid(localObj)
                localObj = Drivers.Path();
            end
            singleObj = localObj;
        end
    end
    
end

