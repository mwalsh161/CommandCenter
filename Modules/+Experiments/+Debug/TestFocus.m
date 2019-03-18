classdef TestFocus < Modules.Experiment
    %TESTQR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        spacing = 50;   % Spacing between points of interest
        n = 15;         % Will map out spacing*(n n) grid
        data;
    end
    properties(Access=private)
        abort_request = false;  % Request flag for abort
    end
    
    methods(Access=private)
        function obj = TestFocus()
            
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.Debug.TestFocus();
            end
            obj = Object;
        end
    end
    methods
        function run(obj,statusH,managers,ax)
            obj.abort_request = false;   % Reset abort flag
            stage = managers.Stages;
            imager = managers.Imaging;
            vid = imager.active_module.vid;
            intensities = [];
            zpos = [];
            origin = stage.position;
            p = plot(NaN,NaN,'parent',ax);
            for i = -25:0.5:25
                if obj.abort_request
                    return
                end
                stage.move(origin+[0 0 i])
                while stage.moving
                    pause(0.1)
                end
                im = getsnapshot(vid);
                val = max(im(:));
                intensities(end+1) = val;
                zpos(end+1) = i;
                set(p,'xdata',zpos,'ydata',intensities)
                drawnow;
            end
        end
        
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            data = obj.data;
        end
        
        function settings(obj,panelH)
            
        end
    end
    
end

