classdef exp_SNR_comp < Modules.Experiment
    
    properties
        exposure_time = 1000;
        max_div = 10;
        sub_images;
        data;
    end
    properties(Access=private)
        abort_request = false;  % Request flag for abort
        gl   % Green light handle
    end
    
    methods(Access=private)
        function obj = exp_SNR_comp()
            obj.gl = Sources.Laser532_nidaq.instance;
        end
    end
    methods(Static)            
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.exp_SNR_comp();
            end
            obj = Object;
        end
    end
    methods
        function run(obj,statusH,managers,ax)
            
            camera = managers.Imaging.active_module;
            obj.abort_request = false;   % Reset abort flag
            camera.binning = 1;  % Set for whole experiment
            obj.gl.on;
            
            
            
            
            for jj = 1:1:obj.max_div
                
                camera.exposure = 500;
                managers.Imaging.autofocus;                
                
                exp = obj.exposure_time/jj;
                camera.exposure = exp; % Change to experiment exposure (should be bin=1 still)

                for ii = 1:1:jj

                    set(statusH,'string',...
                        sprintf('Division: %0.2f \n n: %0.2f\n',jj,ii));
                    drawnow;
                    
                    if obj.abort_request
                        return
                    end
                    
                    im = camera.snapImage;
                    
                    obj.sub_images(:,:,jj,ii) = im;
            
                end
            end
            
            obj.data = sum(obj.sub_images,4);            

            camera.binning = 3;  % Set for whole experiment
            camera.exposure = 100;

        end
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data.im = obj.data;
                data.exp = obj.exposure_time;
                data.div = 1:1:obj.max_div;
            else
                data = [];
            end
        end
        
        function settings(obj,panelH)
            
        end
    end
    
end

