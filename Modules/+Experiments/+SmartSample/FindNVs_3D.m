classdef FindNVs_3D < Experiments.SmartSample.super_invisible & Modules.Experiment
    %INITIALCHARACTERIZATION subclasses SmartExperiment to map all NVs
    
    properties
        data;                   % struct('NVs',{},'errors',{});
        depth = 0;              % NV depth
        step = 0.2;             % um to reach depth
        NVsize = 2.6;           % Pixels (bin = 3)
    end
    
    methods(Access=private)
        function obj = FindNVs_3D()
            obj.prefs = [obj.prefs,{'depth','step','NVsize'}];
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
                Object = Experiments.SmartSample.FindNVs_3D();
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
            wl = sample.acquire('white'); %#ok<*PROP>
            z = 0:obj.step:obj.depth;
            fl = struct('image',{},'stagePos',{},'stage',{},'ROI',{},'ModuleInfo',{});
            assert(length(z)>1, 'Not enough steps for a 3d image')
            for i = z
                fl(end+1) = sample.acquire('green');
                managers.Stages.jog([0 0 obj.step])
                managers.Stages.waitUntilStopped;
            end
            managers.Stages.jog([0 0 -z(end)])
            fl3d = zeros([size(fl(1).image) length(z)]);
            for i = 1:length(z)
                fl3d(:,:,i) = fl(i).image;
            end
            try
                spatial_filter = [100 980; 94 543;408 61;1056 63;1238 509;1216 980];
                spatial_filter(:,1) = spatial_filter(:,1)*460/1388;
                spatial_filter(:,2) = spatial_filter(:,2)*344/1040;
                NVsize = [8/3 8/3 1.3/obj.step];
                f = findall(0,'name','getNVs');
                if isempty(f)
                    f = figure('name','getNVs');
                else
                    clf(f)
                end
                ax1 = subplot(1,2,1,'parent',f);
                ax2 = subplot(1,2,2,'parent',f);
                [posSample,~,readInfo] = sample.getPosition('im',wl,'verbose',ax1,'enhanced',true);
                [NV,err] = NVposition3D(fl3d,NVsize,3.5,spatial_filter,ax2);
                % Convert from pixel -> um
                fl = fl(1);
                x = fl.ROI(1,:);
                y = fl.ROI(2,:);
                im = fl.image;
                conv = [diff(x)/(size(im,2)-1),diff(y)/(size(im,1)-1)]; % um/pixel
                NV(:,1) = (NV(:,1)-1)*conv(1) + x(1);
                NV(:,2) = (NV(:,2)-1)*conv(2) + y(1);
                sz = size(NV,1);
                pos(:,1:2) = transformPointsInverse(readInfo.tform,NV(:,1:2));
                pos(:,3) = NV(:,3);
                npoints = zeros(sz,1) + readInfo.npoints;
                coord_err = zeros(sz,1) + readInfo.err;
                NVlocs = struct('global',mat2cell(pos,ones(1,sz),3),...
                            'frame',mat2cell(NV,ones(1,sz),3),...
                            'err',num2cell(err),...
                            'npoints',num2cell(npoints),...
                            'coord_err',num2cell(coord_err));
                
                NVs = [NVs; NVlocs];
                title(ax,sprintf('%i NVs found',numel(NVs)))
                drawnow;  % Allow callbacks for abort button
            catch err
                err_struct.err = err;
                err_struct.wl = wl;
                err_struct.fl = fl3d;
                NVErrors(end+1) = err_struct;
                if ~mod(length(NVErrors),10)
                    obj.notify(sprintf('RoMi has had %i NV errors!',length(NVErrors)))
                end
            end
            managers.Stages.waitUntilStopped;
        end
        
        function data = GetData(obj,~,~)
            % Grab SmartExperiment stuff
            data.SmartSample = object2struct(obj.SmartSample,{'lastImage','LightState'});
            data.Navigation = obj.navigation;
            data.wl_exposure = obj.wl_exposure;
            data.gl_exposure = obj.gl_exposure;
            % Add our NV stuff
            data.experiment = obj.data;
            data.NV_size = obj.NV_size;
            data.step = obj.step;
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

