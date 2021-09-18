classdef CheckHSQ < Modules.Experiment
    %INITIALCHARACTERIZATION Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        data
        chipSize = [3000 3000];
        NVfile = '';
        prefs = {'chipSize'};
    end
    properties(Access=private)
        abort_request = false;  % Request flag for abort
        wl   % White light handle
        gl   % Green light handle
    end
    
    methods(Access=private)
        function obj = CheckHSQ()
            obj.loadPrefs;
            obj.wl = Sources.WhiteLight.instance;
            obj.gl = Sources.Laser532.instance;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Experiments.CheckHSQ();
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
        function run(obj,statusH,managers,ax)
            assert(~isempty(obj.NVfile),'Please select an NV file!')
            statusWin = statusH.Parent.Parent;
            if isempty(obj.chipSize)
                error('Must set chip size first.')
            end
            obj.data = struct('stagePos',{},'type',{},'err',{});
            obj.abort_request = false;   % Reset abort flag
            set(statusH,'string','Initializing SmartSample.'); drawnow;
            sample = Base.SmartSample(obj.chipSize,obj.wl,obj.gl,managers,...
                'accuracy',10,...  % Don't need to be terribly precise
                'whiteLightImProperties', {'binning',1,'exposure',45},...
                'greenLightImProperties', {'binning',1,'exposure',2000},...
                'maxJog', 40); % Make quite small to avoid problems.
            set(statusH,'string','Calculating path.'); drawnow;
            fid = fopen(obj.NVfile);
            NVs = textscan(fid,'%f,%f,%s','EndOfLine','\n');
            fclose(fid)
            NVs{3} = str2double(NVs{3});
            NVs{3}(isnan(NVs{3})) = 2.75;  % bullseye
            x = [];
            y = [];
            radii = [];
            f = [];
            for i = 20:numel(NVs{1})
                radius = NVs{3}(i);
                if radius < 0.39
                    continue
                end
                % Search 300 forward and backward for collision, and
                % only keep ones that don't collide
                start = max([i,1]);
                stop = min([i,numel(x)]);
                safe = true;
                for j = [start:i-1 i+1:stop]
                    otherRadius = str2double(NVs{3}(j));
                    if sqrt((NVs{1}(i)-NVs{1}(j))^2+(NVs{2}(i)-NVs{2}(j))^2) < otherRadius + radius
                        safe = false;
                        break
                    end
                end
                if safe
                    x(end+1) = NVs{1}(i);
                    y(end+1) = NVs{2}(i);
                    radii(end+1) = NVs{3}(i);
                end
            end
            sample.drawSample(ax);
            hold(ax,'on')
            plot(ax,x,y,'k.');
            [currentPos,~,readInfo] = sample.getPosition;  % This might be an unnecessary step
            spacing = mode([readInfo.qrInfo.spacing]);
            loc = plot(ax,currentPos(1),currentPos(2),'b+');
            nlocs = numel(x);
            failed = 0;  % Only allow 5 failures before txting
            dt = [];
            roi = managers.Imaging.ROI;
            for i = 1:nlocs
                tic;
                assert(~obj.abort_request,'User aborted.')
                if isempty(dt)
                    msg = sprintf('%0.2f complete\nCalculating time left.',100*i/nlocs);
                else
                    t = (nlocs - i)*dt;
                    hrs = floor(t/3600);
                    mint = round((t - hrs*3600)/60);
                    msg = sprintf('%0.2f complete\nApproximate time left: %i:%i',100*i/nlocs,hrs,mint);
                end
                set(statusH,'string',msg)
                % Move if not in the field of view
                if ~(abs(currentPos(1)-x(i)) < diff(roi(1,:))-10 && abs(currentPos(2)-y(i)) < diff(roi(2,:))-10)
                    msg = sprintf('%s\nSetting to: (%0.2f,%0.2f)',msg,x(i),y(i));
                    set(statusH,'string',sprintf('%s\nAttempt: %i/5',msg,failed+1));
                    drawnow;
                    try
                        currentPos = sample.setPosition([x(i),y(i)],loc);
                        set(loc,'xdata',currentPos(1),'ydata',currentPos(2))
                        drawnow;
                        failed = 0;
                    catch err
                        if strcmp(err.message,'Destination out of stage range.')
                            obj.notify('Stage Error',err.message)
                        end
                        failed = failed + 1;
                        % Move away and go to next iteration in loop
                        if failed < 5
                            step = [0 0] + spacing;
                            managers.Stages.jog([step 0]);
                            managers.Stages.waitUntilStopped;
                            continue
                        else
                            obj.notify('RoMi Error',sprintf('I am lost!\n%s',err.message))
                            statusWin.WindowStyle = 'normal';
                            input('Fix error, then enter to continue!');
                            statusWin.WindowStyle = 'modal';
                        end
                    end
                end
                assert(~obj.abort_request,'User aborted.')
                sample.focus;
                im = managers.Imaging.snap;
                currentPos = sample.getPosition('im',im,'enhanced',true);
                assert(~obj.abort_request,'User aborted.')
                % Find NVs (this step takes a long time)
                relativePos = currentPos(1:2) - [x(i) y(i)];
                assert(~logical(sum(isnan(relativePos))),'relativePos is nan.')
                %r = radii(i);
                %cropped = im.image([-r r]*2+relativePos(1),[-r r]*2+relativePos(2));
                if ~isempty(f)&&isvalid(f)
                    close(f)
                end
                f = figure; ax = axes('parent',f);
                imagesc(roi(1,:),roi(2,:),im.image,'parent',ax)
                hold(ax,'on');
                plot(relativePos(1),relativePos(2),'r+')
                statusWin.WindowStyle = 'normal';
                input('Continue?')
                statusWin.WindowStyle = 'modal';
                dt = mean([dt toc]);
            end
            obj.data.NVs = obj.data;
            obj.data.sample = struct(sample);
            set(statusH,'string','Finished.')
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
        
        function  settings(obj,panelH,~,~)
            spacing = 1.5;
            num_lines = 3;
            line = 1;
            uicontrol(panelH,'style','text','string','Chip Size (um):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.chipSize(1)),...
                'units','characters','callback',@obj.nvfile,...
                'horizontalalignment','left','position',[19 spacing*(num_lines-line) 10 1.5]);
            line = 3;
            tip = obj.NVfile;
            uicontrol(panelH,'style','PushButton','String','NV File','tooltipstring',tip,...
                'units','characters','position',[3 spacing*(num_lines-line) 20 2],...
                'callback',@obj.nvfile);
        end
        function sizeCallback(obj,hObject,~)
            val = str2double(get(hObj,'String'));
            if isnan(val)
                error('Must be a number.')
            end
            obj.chipSize = [0 0]+val;
        end
        function nvfile(obj,hObject,~)
            [fname,pathname] = uigetfile('*.txt','Select NV File',obj.NVfile);
            if ~isequal(fname,0)
                obj.NVfile = fullfile(pathname,fname);
                set(hObject,'tooltipstring',obj.NVfile)
            end
        end
    end
    
end

