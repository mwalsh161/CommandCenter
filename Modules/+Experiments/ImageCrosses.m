classdef ImageCrosses < Modules.Experiment
    %INITIALCHARACTERIZATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        data
        wl_exposure = 4;        % ms
        gl_exposure = 2000;     % ms
        chipSize = [3000 3000];
        prefs = {'wl_exposure','gl_exposure'};
    end
    properties(SetAccess=private)
        SmartSample = [];
    end
    properties(Access=private)
        abort_request = false;  % Request flag for abort
        pause_request = false;
        wl   % White light handle
        gl   % Green light handle
    end
    
    methods(Access=private)
        function obj = ImageCrosses()
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
                Object = Experiments.ImageCrosses();
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
            statusWin = statusH.Parent.Parent;
            button = findall(statusWin,'tag','AbortButton');
            newButton = add_button(button,'Pause');
            newButton.Callback = @obj.pause;
            if managers.Imaging.active_module.continuous
                managers.Imaging.stopVideo;
            end
            obj.abort_request = false;   % Reset abort flag
            % Initialize SmartSample
            set(statusH,'string','Initializing SmartSample.'); drawnow nocallbacks;
            sample = Base.SmartSample(obj.chipSize,obj.wl,obj.gl,managers,...
                'accuracy',1,...
                'whiteLightImProperties', {'binning',1,'exposure',obj.wl_exposure},...
                'greenLightImProperties', {'binning',1,'exposure',obj.gl_exposure},...
                'maxJog', obj.chipSize(1)*sqrt(2));
            obj.SmartSample = sample; % Useful for debugging!
            
            % Initialize Plots
            sample.drawSample(ax);
            hold(ax,'on')
            set(statusH,'string','Initializing Plots.'); drawnow nocallbacks;
            currentPos = sample.samplePositions(end,1:2);
            loc_handle = plot(ax,currentPos(1),currentPos(2),'b+');

            % Read where we want to visit
            path = 'X:\Experiments\AutomationSetup\Experiments\EG250';
            fname = 'Data2016_09_01_14_27_59_0.50_used.txt';
            fid = fopen(fullfile(path,fname));
            used = fscanf(fid,'%i');
            fclose(fid);
            fname = 'Data2016_09_01_14_27_59.txt';
            fid = fopen(fullfile(path,fname),'r','n','UTF-8');
            temp=textscan(fid,'%f %f %s %f %f','Delimiter',' ');
            fclose(fid);
            to_visit = [temp{1} temp{2}]/1e3;
            to_visit = to_visit(used,:);
            type = temp{3};
            type = type(used);
            I = ismember(type,'cross');
            to_visit = to_visit(I,:);
            temp = [];
            num_total = size(to_visit,1);
            plot(ax,to_visit(:,1),to_visit(:,2),'m.');
            title(ax,sprintf('%i crosses',size(num_total,1)));
            
            % Initialize Objects
            set(statusH,'string','Initializing Objects.'); drawnow nocallbacks;
            PosErrors = struct('err',{},'wl',{});        % Index of location of negative numbers in "map" will map to these errors
            mov = getframe(ax);
            mov = struct('cdata',mov.cdata*0,'colormap',cell(1,num_total));
            times = NaN(num_total,1);
            images = struct('image',{},'stagePos',{},'stage',{},'ROI',{},'ModuleInfo',{});
            obj.data = [];
            
            
            abort_err = [];
            i = 0;
            try % Catch the abort and populate data then rethrow error
            while ~isempty(to_visit);
                i = i + 1;
                assert(~obj.abort_request,'User aborted.')
                % Update user about timing
                t_start = tic;
                num_done = i;
                if sum(~isnan(times)) < 1
                    msg = sprintf('%0.2f%% complete.',100*num_done/num_total);
                else
                    t = (num_total-num_done)*nanmean(times);
                    hrs = floor(t/3600);
                    minutes = round((t - hrs*3600)/60);
                    h_plural = 's'; m_plural = 's';
                    if hrs == 1
                        h_plural = '';
                    end
                    if minutes == 1
                        m_plural = '';
                    end
                    msg = sprintf('%0.2f%% complete\nApproximate time left:\n   %i hour%s and %i minute%s.',100*num_done/num_total,hrs,h_plural,minutes,m_plural);
                end
                set(statusH,'string',msg); drawnow nocallbacks;

                % Attempt to execute move
                set(statusH,'string',sprintf('%s\nGetting current sample position.',msg)); drawnow nocallbacks;
                err = [];  % Check if empty for NV localization
                
                % Get closest position to us
                [~,d] = knnsearch(currentPos,to_visit,'k',1);
                [~,I] = min(d);
                nextPos = to_visit(I,:);
                to_visit(I,:) = [];
                try
                    set(statusH,'string',sprintf('%s\nGetting current sample position.',msg)); drawnow nocallbacks;
                    [currentPos,stagePos,readInfo] = sample.getPosition('enhanced',true); % Takes image
                    set(statusH,'string',sprintf('%s\nSetting new position.',msg)); drawnow nocallbacks;
                    % Set position
                    currentPos = sample.setPosition(nextPos,loc_handle,[currentPos 0],stagePos,readInfo); % Takes at least 1 images and 1 focus
                    set(statusH,'string',msg); drawnow nocallbacks;
                    currentPos = currentPos(1:2);  % Remove z (always 0)
                    set(loc_handle,'xdata',currentPos(1),'ydata',currentPos(2));
                    plot(ax,currentPos(1),currentPos(2),'g.','markersize',7,'HitTest','off');
                    drawnow nocallbacks;
                catch err
                    if strcmp(err.message,'Destination out of stage range.')
                        im = []; % Not an image problem...
                    else
                        im = sample.lastImage;
                    end
                    % We can guess our currentPos is probably pretty close to the nextPos
                    currentPos = nextPos;  % not sure about this!!!!
                    set(statusH,'string',msg); drawnow nocallbacks;
                    % Return to closest known position (that is not current position)
                    plot(ax,currentPos(1),currentPos(2),'r.','markersize',7,'HitTest','off');
                    [closestStagePos,currentPos] = sample.closestKnownPosition(currentPos,'sample');
                    set(statusH,'string',sprintf('%s\nReturing to closest known position.',msg));
                    managers.Stages.move(closestStagePos);
                    set(loc_handle,'xdata',currentPos(1),'ydata',currentPos(2));
                    drawnow;  % Allow callbacks for abort button
                    % Log error
                    err_struct.err = err;
                    err_struct.wl = im;
                    PosErrors(end+1) = err_struct;
                    obj.logger.log(sprintf('Position: %0.2f, %0.2f: %s',nextPos(1),nextPos(2),err.message));
                    err_struct = []; im = [];  % Clean some memory
                    if ~mod(length(PosErrors),10)
                        obj.notify(sprintf('RoMi has had %i positioning errors!',length(PosErrors)))
                    end
                    managers.Stages.waitUntilStopped;
                    set(statusH,'string',msg);
                end
                uistack(loc_handle,'top'); drawnow nocallbacks;
                mov(i) = getframe(ax);
                % Take fluoscent image
                images(end+1) = sample.acquire('green');
                % Update time estimate
                times(i) = toc(t_start);
                if obj.pause_request;keyboard();obj.pause_request=false;end
            end
            catch abort_err
            end
            obj.wl.off;
            obj.gl.off;
            % Move variables around and clean up
            Navigation.mov = mov; mov = [];
            Navigation.errors = PosErrors; PosErrors = [];
            Navigation.times = times;
            obj.data.Navigation = Navigation; Navigation = [];
            obj.data.images = images;
            % Save smart sample stuff too
            obj.data.SmartSample = object2struct(obj.SmartSample,{'lastImage','LightState'});
            checkoutlaser(0,getpref('CommandCenter','secret_key_path'))
            if ~isempty(abort_err)
                rethrow(abort_err)  % Prevent autosave
            end
            obj.notify('Done!')
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
        
        function settings(obj,panelH,~)
            spacing = 1.5;
            num_lines = 2;
            line = 1;
            uicontrol(panelH,'style','text','string','White Exp (ms):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.wl_exposure),...
                'units','characters','callback',@obj.exposureCallback,'tag','wl_exposure',...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 2;
            uicontrol(panelH,'style','text','string','Green Exp (ms):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.gl_exposure),...
                'units','characters','callback',@obj.exposureCallback,'tag','gl_exposure',...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            
        end
        function exposureCallback(obj,hObject,~)
            val = str2double(hObject.String);
            assert(~isnan(val),'Must be a number.')
            obj.(hObject.Tag) = val;
        end
    end
    
end

