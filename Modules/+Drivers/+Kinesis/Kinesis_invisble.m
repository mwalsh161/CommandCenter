classdef Kinesis_invisible

methods(abstract)

    loaddlls(obj)
    
end

methods
    connect(obj,serialNum)
    
    disconnect(obj)
end

methods(Static)
    getDevices()
end