classdef SpotOverTime < Modules.Experiment
    %SpotOverTime Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        data
        wl_exposure = 4;        % ms
        gl_exposure = 2000;     % ms
        depth = 0;              % NV depth
        findNVs = true;
        N = 1;
        prefs = {'wl_exposure','gl_exposure','N','depth'};
    end
    properties(Access=private)
        abort_request = false;  % Request flag for abort
        pause_request = false;
        wl   % White light handle
        gl   % Green light handle
    end
    
    methods(Access=private)
        function obj = SpotOverTime()
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
                Object = Experiments.SpotOverTime();
            end
            obj = Object;
        end
    end
    methods
        function notify(obj,varargin)
            % obj.notify(msg)
            % obj.notify(subject,msg)
            switch nargin
                case 2
                    msg = varargin{1};
                    subject = 'RoMi Notification';
                case 3
                    subject = varargin{1};
                    msg = varargin{2};
                otherwise
                    error('Wrong number of inputs.')
            end
            obj.logger.log(sprintf('%s: %s',subject,msg));
        end
        function pause(obj,~,~)
            obj.pause_request = true;
        end
        function run(obj,statusH,managers,ax)
            obj.abort_request = false;   % Reset abort flag
            ims = NaN([fliplr(managers.Imaging.active_module.resolution),obj.N]);
            dt = NaN(1,obj.N);
            err = [];
            obj.wl.arm;
            obj.gl.arm;
            try
                for i = 1:obj.N
                    tic;
                    if obj.abort_request
                        break
                    end
                    set(statusH,'string',sprintf('%0.2f%% complete',100*i/obj.N));
                    obj.gl.off;
                    managers.Imaging.active_module.exposure = obj.wl_exposure;
                    obj.wl.on;
                    managers.Imaging.autofocus;
                    obj.wl.off;
                    managers.Imaging.active_module.exposure = obj.gl_exposure;
                    obj.gl.on;
                    if obj.depth > 0
                        managers.Stages.jog([0 0 obj.depth])
                        managers.Stages.waitUntilStopped;
                    end
                    im = managers.Imaging.snap(true); % quietly
                    ims(:,:,i) = im.image;
                    if obj.depth > 0
                        managers.Stages.jog([0 0 -obj.depth])
                        managers.Stages.waitUntilStopped;
                    end
                    dt(i) = toc;
                end
            catch err
                obj.data.err = err;
            end
            obj.wl.off;
            obj.gl.off;
            managers.Imaging.active_module.exposure = obj.wl_exposure;
            obj.data.images = ims;
            obj.data.dt = dt;
            obj.data.depth = obj.depth;
            obj.data.wl_exposure = obj.wl_exposure;
            obj.data.gl_exposure = obj.gl_exposure;
            if ~isempty(err)
                rethrow(err)
            end
        end
        function abort(obj)
            obj.abort_request = true;
        end
        
        function data = GetData(obj,~,~)
            if ~isempty(obj.data)
                data = obj.data;
            else
                data = [];
            end
        end
        
        function settings(obj,panelH)
            spacing = 1.5;
            num_lines = 4;
            line = 1;
            uicontrol(panelH,'style','text','string','Depth (um):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.depth),...
                'units','characters','callback',@obj.depthCallback,'tag','stop',...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 17 1.5]);
            line = 2;
            uicontrol(panelH,'style','text','string','Repetitions:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.N),...
                'units','characters','callback',@obj.Ncallback,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 17 1.5]);
            line = 3;
            uicontrol(panelH,'style','text','string','White Exp (ms):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.wl_exposure),...
                'units','characters','callback',@obj.exposureCallback,'tag','wl_exposure',...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 4;
            uicontrol(panelH,'style','text','string','Green Exp (ms):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.gl_exposure),...
                'units','characters','callback',@obj.exposureCallback,'tag','gl_exposure',...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            
        end
        function Ncallback(obj,hObject,~)
            val = str2double(get(hObject,'String'));
            assert(~isnan(val),'Must be a number.')
            obj.N = round(val);
        end
        function depthCallback(obj,hObject,~)
            val = str2double(get(hObject,'String'));
            assert(~isnan(val),'Must be a number.')
            obj.depth = val;
        end
        function exposureCallback(obj,hObject,~)
            val = str2double(hObject.String);
            assert(~isnan(val),'Must be a number.')
            obj.(hObject.Tag) = val;
        end
    end
    
end

