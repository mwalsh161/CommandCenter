classdef FindNVs < Experiments.SmartSample.super_invisible & Modules.Experiment
    %INITIALCHARACTERIZATION subclasses SmartExperiment to map all NVs
    
    properties
        data;                   % struct('NVs',{},'errors',{});
        depth = 0;              % NV depth
    end
    
    methods(Access=private)
        function obj = FindNVs()
            obj.prefs = [obj.prefs,{'depth'}];
            obj.loadPrefs;
            obj.wl = Sources.WhiteLight.instance;
            obj.gl = Sources.Laser532_nidaq.instance;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.SmartSample.FindNVs();
            end
            obj = Object;
        end
    end
    methods
        function pre_run(obj,~,~,~)
            % Initialize data structures (erase last run's data)
            obj.data.NVs = struct('global',{},'frame',{},'err',{},'npoints',{},'coord_err',{});
            obj.data.errors = struct('err',{},'wl',{},'fl',{});
        end
        function todo(obj,statusH,managers,ax,currentPos)
            ax = ax(1);  % axes with sample map (sample coords)
            sample = obj.SmartSample;
            wl = sample.acquire('white');
            if obj.depth > 0
                managers.Stages.jog([0 0 obj.depth])
                managers.Stages.waitUntilStopped;
            end
            fl = sample.acquire('green');
            if obj.depth > 0
                managers.Stages.jog([0 0 -obj.depth])  % waitUntilStopped after processing
            end
            try
                f = findall(0,'name','getNVs');
                if isempty(f)
                    f = figure('name','getNVs');
                else
                    clf(f)
                end
                NVlocs = sample.getNVs('wl',wl,'fl',fl,'fig',f);
                if numel(NVlocs) == 0
                    error('No NVs detected!')
                end
                obj.data.NVs = [obj.data.NVs; NVlocs];
                title(ax,sprintf('%i NVs found',numel(obj.data.NVs)))
                drawnow;  % Allow callbacks for abort button
            catch err
                err_struct.err = err;
                err_struct.wl = wl;
                err_struct.fl = fl;
                obj.data.errors(end+1) = err_struct;
                if ~mod(length(obj.data.errors),10)
                    obj.notify(sprintf('RoMi has had %i NV errors!',length(obj.data.errors)))
                end
            end
            if obj.depth > 0
                managers.Stages.waitUntilStopped;
            end
        end
        
        function data = GetData(obj,~,~)
            % Grab SmartExperiment stuff
            data.SmartSample = object2struct(obj.SmartSample,{'lastImage','LightState'});
            data.Navigation = obj.navigation;
            data.wl_exposure = obj.wl_exposure;
            data.gl_exposure = obj.gl_exposure;
            % Add our NV stuff
            data.experiment = obj.data;
            data.depth = obj.depth;
        end
        
        function settings(obj,panelH,~)
            settings@Experiments.SmartSample.super_invisible(obj,panelH)
            controls = allchild(panelH);
            positions = reshape([controls.Position],4,[]);
            offset = max(positions(2,:));
            spacing = 1.5;
            line = 1;
            uicontrol(panelH,'style','text','string','Depth (um):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*line+offset 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.depth),...
                'units','characters','callback',@obj.depthCallback,'tag','stop',...
                'horizontalalignment','left','position',[19 spacing*line+offset 17 1.5]);
            
        end
        function depthCallback(obj,hObject,~)
            val = str2double(get(hObject,'String'));
            assert(~isnan(val),'Must be a number.')
            obj.depth = val;
        end
    end
end

