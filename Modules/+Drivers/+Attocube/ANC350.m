classdef ANC350 < Modules.Driver
    properties (Access=private)
        s;
    end
    
    methods(Static)
        function obj = instance(host)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.Attocubes.ANC300.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(host, Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.Attocubes.ANC350(host);
            obj.singleton_id = host;
            Objects(end+1) = obj;
        end
    end
    methods (Access=private)
        function obj = ANC350(host)
            obj.s = hwserver(host);
        end
    end
end