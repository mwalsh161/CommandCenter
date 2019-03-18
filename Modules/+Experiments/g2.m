classdef g2 < Modules.Experiment
    %G2 Idles an experiment to prevent inactivity timer
    
    properties(SetObservable)
        expected_time = 0;
    end
    properties
        prefs = {'expected_time'};
    end
    properties(Access=private)
        abort_request = false;  % Request flag for abort
    end
    
    methods(Access=private)
        function obj = g2()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.g2();
            end
            obj = Object;
        end
    end
    methods
        function run(obj,statusH,managers,ax)
            obj.abort_request = false;
            t = tic;
            while toc(t) < obj.expected_time
                statusH.String = sprintf('ABORT when done!!\n%i seconds left',round(obj.expected_time-toc(t)));
                if obj.abort_request
                    return
                end
                drawnow;
            end
            managers.Experiment.abort;
        end
        
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            data = [];
        end
    end
    
end

