classdef foo < matlab.mixin.Heterogeneous
    properties
        x = 1
        y = 2
    end
    
    methods (Static)
        function c = getclass()
            c = mfilename('class')
        end
    end
    
    methods
        function obj = foo()
            
        end
    end
end