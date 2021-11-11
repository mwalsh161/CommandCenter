classdef SphericalAberration < Modules.Experiment
    %TESTQR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        xNum = 15;      % Number of positions in x coordinate
        yNum = 15;       % Number of positions in y coordinate
        data;
    end
    properties(Access=private)
        abort_request = false;  % Request flag for abort
    end
    
    methods(Access=private)
        function obj = SphericalAberration()
            
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.SphericalAberration();
            end
            obj = Object;
        end
    end
    methods
        run(obj,statusH,managers,ax)
        
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            data = obj.data;
        end
        
        function  settings(obj,panelH,~,~)
            
        end
    end
    
end

