classdef snap3D < Modules.Experiment
    %3DSNAP takes multiple snapshots as height is swept.
    %   Step through Z (positive Z is into sample)
    %   Does not automatically start at 0!
    
    properties
        zsweep = '0';       % Matlab Expression Sweep points (relative, um)
        greenExp = 1000;    % ms, for bin=1
        whiteExp = 10;      % ms, for bin=1
        data
        prefs = {'zsweep','greenExp','whiteExp'};
    end
    properties(Access=private)
        abort_request = false;  % Request flag for abort
        wl   % White light handle
        gl   % Green light handle
    end
    
    methods(Access=private)
        function obj = snap3D()
            obj.wl = Sources.WhiteLight.instance;
            obj.gl = Sources.Laser532_nidaq.instance;
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.snap3D();
            end
            obj = Object;
        end
    end
    methods
        function run(obj,statusH,managers,ax)
            camera = managers.Imaging.active_module;
            camera.binning = 1;
            res = camera.resolution;
            sweep = eval(obj.zsweep);
            if size(sweep,1)>1
                sweep = sweep';
            end
            sweepDelta = diff([0 sweep]);
            obj.data = NaN(res(2),res(1),1,numel(sweepDelta)*2);
            obj.abort_request = false;   % Reset abort flag
            obj.wl.arm;
            obj.gl.arm;
            for i = 1:numel(sweepDelta)
                set(statusH,'string',...
                    sprintf('Position %i/%i',i,numel(sweepDelta)));
                drawnow;
                if obj.abort_request
                    return
                end
                managers.Stages.jog([0,0,sweepDelta(i)]);
                managers.Stages.waitUntilStopped;
                obj.wl.off;
                obj.gl.on;
                pause(0.01)
                camera.exposure = obj.greenExp;
                im = camera.snapImage;
                obj.data(:,:,1,i*2-1) = im;
                imagesc(im,'Parent',ax);
                title(ax,sprintf('Z: %0.1f (Green)',sweep(i)))
                axis(ax,'image');
                drawnow;
                if obj.abort_request
                    return
                end
                camera.exposure = obj.whiteExp;
                obj.gl.off;
                obj.wl.on;
                pause(0.01)
                im = camera.snapImage;
                obj.data(:,:,1,i*2) = im;
                imagesc(im,'Parent',ax);
                title(ax,sprintf('Z: %0.1f (White)',sweep(i)))
                axis(ax,'image');
                drawnow;
            end
            managers.Stages.jog([0,0,-sweep(end)]);
            obj.gl.off;
            obj.wl.off;
            managers.Stages.waitUntilStopped;
        end
        
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data.im = obj.data;
                data.z = eval(obj.zsweep);
            else
                data = [];
            end
        end
        
        function settings(obj,panelH)
            spacing = 1.5;
            num_lines = 3;
            line = 1;
            uicontrol(panelH,'style','text','string','Green Exposure (ms):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.greenExp),'tag','greenExp',...
                'units','characters','callback',@obj.setExp,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 2;
            uicontrol(panelH,'style','text','string','White Exposure (ms):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.whiteExp),'tag','whiteExp',...
                'units','characters','callback',@obj.setExp,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 3;
            uicontrol(panelH,'style','text','string','Z Sweep (matlab code):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',obj.zsweep,...
                'units','characters','callback',@obj.setZsweep,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 25 1.5]);
        end
        function setExp(obj,hObj,~)
            temp = get(hObj,'string');
            temp = str2double(temp);
            assert(~isnan(temp),'Must be a number!');
            obj.(get(hObj,'tag')) = temp;
        end
        function setZsweep(obj,hObj,~)
            sweep = eval(get(hObj,'string'));
            assert(isnumeric(sweep),'Does not evaluate to numeric array.')
            obj.zsweep = get(hObj,'string');
        end
    end
    
end

