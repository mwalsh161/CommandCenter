classdef SnapShots < Modules.Experiment
    %TESTQR Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
%        exposure_sweep = [0.1 0.2 0.3 0.4 0.5 0.75 1 1.5 2 2.5 3 3.5 4 4.5 5];  % s
%        nphotos = 20;
        exposure_sweep = [1 1];  % s
        nphotos = 5;
        data
    end
    properties(Access=private)
        abort_request = false;  % Request flag for abort
        wl   % White light handle
        gl   % Green light handle
    end
    
    methods(Access=private)
        function obj = SnapShots()
            obj.wl = Sources.WhiteLight.instance;
            obj.gl = Sources.Laser532.instance;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.SnapShots();
            end
            obj = Object;
        end
    end
    methods
        function run(obj,statusH,managers,ax)
            camera = managers.Imaging.active_module;
            res = camera.resolution;
            obj.data = NaN(res(2),res(1),obj.nphotos,numel(obj.exposure_sweep));
            obj.abort_request = false;   % Reset abort flag
            c = 1;
            camera.binning = 1;  % Set for whole experiment
            for exp = obj.exposure_sweep*1000
%                camera.exposure = 90;  % Exposure for bin=1 with wight light
%                obj.gl.off;
%                obj.wl.on;
%                managers.Imaging.autofocus; % Will change bin to 3 then back (updating exposure too)
%                obj.wl.off;
%                obj.gl.on;
%                camera.exposure = exp; % Change to experiment exposure (should be bin=1 still)
                for j = 1:obj.nphotos
                    
                    camera.exposure = 90;  % Exposure for bin=1 with wight light
                    obj.gl.off;
                    obj.wl.on;
                    managers.Imaging.autofocus; % Will change bin to 3 then back (updating exposure too)
                    obj.wl.off;
                    obj.gl.on;
                    camera.exposure = exp; % Change to experiment exposure (should be bin=1 still)

                    set(statusH,'string',...
                        sprintf('Exposure(ms): %0.2f\nN: %i',exp,j));
                    drawnow;
                    if obj.abort_request
                        return
                    end
                    im = camera.snapImage;
                    obj.data(:,:,j,c) = im;
                end
                c = c + 1;
            end
            obj.gl.off;
        end
        
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data.im = obj.data;
                data.exp = obj.exposure_sweep;
            else
                data = [];
            end
        end
        
        function settings(obj,panelH,~)
            
        end
    end
    
end

