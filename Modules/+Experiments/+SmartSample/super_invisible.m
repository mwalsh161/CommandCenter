classdef super_invisible < handle
    %SmartExperiment Takes care of settings for SmartSample and navigation
    %   Notice, this is not an experiment, so inherit this as well as
    %   Modules.Experiment
    %
    %   After a run is complete, SmartSample is not erased (by default) -
    %   user can overload GetData to erase it if desired.
    %   Data axes (the sample map) are assigned a click callback to make
    %   for easy navigation across sample.
    %
    %   On Init:
    %       Make sure to assign obj.wl and obj.gl (used in SmartSample init)
    %       DONT delete prefs! You can add to them in your constructor:
    %           obj.prefs = [obj.prefs,{'new_pref1','new_pref2',...}]
    %
    %  Methods that can be overloaded:
    %       function map = modifyMap(obj, map)
    %           This is called after map consturction in obj.run, but
    %           before navigations loop begins.
    %       function pre_run(obj,statusH,managers,ax)
    %           Executed after run has prepared its plots and everything.
    %           It creates 3 axes, and all obj.navitagion data should be
    %           initialized by this functions executions.
    %       function post_run(obj,statusH,managers,ax)
    %           Last thing executed in run method (turn off equipment etc).
    %           Executed even if error/abort occurs somewhere.
    %       function data = GetData(obj,stage,imager) [CC calls directly]
    %           You know the drill
    %       function todo(obj,statusH,managers,ax,currentPos)
    %           Function executed at each position on sample after
    %           autofocus (best to use custom data property)
    %           NOTE: errors on this fn are not logged. User can make
    %           custom try/catch statements in this fn.
    %               The run method will 
    %
    %   Custom Settings (note this is not protected from abuse):
    %       function settings(obj,panelH,~)
    %           settings@Experiments.SmartExperiment_invisible(obj,panelH)
    %           controls = allchild(panelH);
    %           positions = reshape([controls.Position],4,[]);
    %           offset = max(positions(2,:));
    %           spacing = 1.5;
    %           line = 1;
    
    properties
        navigation              % Navigation diagnostic data
        chipSize = [3000 3000]; % um
        wl_exposure = 4;        % ms
        gl_exposure = 2000;     % ms
        start = [0 0];          % um: lower left corner of box to search
        stop = [3000 3000];     % um: upper right corner of box to search
        todo_method = true;     % Execute todo method or not
        prefs = {'chipSize','wl_exposure','gl_exposure','start','stop','todo_method'};
    end
    properties(SetAccess=protected)
        SmartSample = [];
    end
    properties(SetAccess=protected)
        abort_request = false;  % Request flag for abort
        pause_request = false;
        wl   % White light handle
        gl   % Green light handle
    end

    methods
        % Nothing, overload if desired
        function map = modifyMap(obj,map) %#ok<*INUSL,*INUSD>
        end
        function pre_run(obj,statusH,managers,ax) 
        end
        function post_run(obj,statusH,managers,ax)
        end
        function todo(obj,statusH,managers,ax,currentPos)
            warning('Not implemented')
        end
        function data = GetData(obj,~,~)
            data = [];
        end
        
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
            source_errors = {};
            if isempty(obj.wl)
                source_errors{end+1} = 'obj.wl was never assigned!';
            end
            if isempty(obj.gl)
                source_errors{end+1} = 'obj.gl was never assigned!';
            end
            if ~isempty(source_errors)
                source_errors = strjoin(source_errors,sprintf('\n'));
                error(source_errors);
            end
            
            panel = ax.Parent;
            delete(ax);
            ax(1) = subplot(2,2,[1 3],'parent',panel,'tag','2dsamplemap');
            ax(2) = subplot(2,2,2,'parent',panel,'tag','focusmap');
            ax(3) = subplot(2,2,4,'parent',panel,'tag','focusmap_residuals');
            statusWin = statusH.Parent.Parent;
            button = findall(statusWin,'tag','AbortButton');
            newButton = add_button(button,'Pause');
            newButton.Callback = @obj.pause;
            assert(~isempty(obj.chipSize),'Must set chip size first.')
            assert(~isempty(obj.start)&&~isempty(obj.stop),'Must set start and stop.')
            if managers.Imaging.active_module.continuous
                managers.Imaging.stopVideo;
            end
            obj.abort_request = false;   % Reset abort flag
            % Initialize SmartSample
            set(statusH,'string','Initializing SmartSample.'); drawnow nocallbacks;
            if true || isempty(obj.SmartSample) || ~isa(obj.SmartSample,'Base.SmartSample')
            sample = Base.SmartSample(obj.chipSize,obj.wl,obj.gl,managers,...
                'accuracy',5,...  % Don't need to be terribly precise
                'whiteLightImProperties', {'binning',1,'exposure',obj.wl_exposure},...
                'greenLightImProperties', {'binning',1,'exposure',obj.gl_exposure},...
                'maxJog', obj.chipSize(1)*sqrt(2));
            obj.SmartSample = sample; % Useful for debugging!
            else
                sample = obj.SmartSample;
            end
            % Initialize Plots
            sample.drawSample(ax(1));
            hold(ax(1),'on')
            set(statusH,'string','Initializing Plots.'); drawnow nocallbacks;
            currentPos = sample.samplePositions(end,1:2);
            loc_handle = plot(ax(1),currentPos(1),currentPos(2),'b+');

            % Initialize Objects
            set(statusH,'string','Initializing Objects.'); drawnow nocallbacks;
            spacing = Base.QR.spacing_between;
            obj.navigation.errors = struct('err',{},'wl',{});        % Index of location of negative numbers in "map" will map to these errors
            % Convert start,stop to rows and cols. Limit to second to last
            %     QR code, to assure there are still 4 in field of view
            cols =  max(0,round(obj.start(1)/spacing)):...
                    min(obj.chipSize(1)/spacing-2,round((obj.stop(1)-1)/spacing));  % x
            rows =  max(0,round(obj.start(2)/spacing)):...
                    min(obj.chipSize(2)/spacing-2,round((obj.stop(2)-1)/spacing));  % y
            obj.navigation.map = int16(zeros(length(rows),length(cols)));  % map(y,x)
            [gridX,gridY] = meshgrid(cols,rows);
            grid = ([gridX(:) gridY(:)]+0.5);  % Sample position of center of 4 QR codes
            obj.navigation.mov = getframe(managers.handles.figure1,getpixelposition(managers.handles.panel_exp,true));
            obj.navigation.mov = struct('cdata',obj.navigation.mov.cdata*0,'colormap',cell(1,size(grid,1)));
            obj.navigation.times = NaN(size(grid,1),1);
            set(statusH,'string','Checking out laser.'); drawnow nocallbacks;
            checkoutlaser(1,getpref('CommandCenter','secret_key_path'))
            
            % Perhaps subclass wants to modify map
            obj.pre_run(statusH,managers,ax);
            obj.navigation.map = obj.modifyMap(obj.navigation.map);
            
            num_total = length(obj.navigation.map(:));
            i = 0;  % To keep track order of path
            abort_err = [];
            try % Catch the abort and populate data then rethrow error
            while sum(obj.navigation.map(:)==0)  % While there are zeros left
                assert(~obj.abort_request,'User aborted.')
                i = i + 1;
                % Update user about timing
                t_start = tic;
                num_done = sum(obj.navigation.map(:)~=0); % Count all non-zeros
                if sum(~isnan(obj.navigation.times)) < 1
                    msg = sprintf('%0.2f%% complete.',100*num_done/num_total);
                else
                    t = (num_total-num_done)*nanmean(obj.navigation.times);
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
                
                % Determine next Move
                currentGridPos = floor(currentPos/spacing)+0.5;
                closestGrids = obj.closestGrids(grid,obj.navigation.map,currentGridPos);
                nextGrid = obj.prioritizeClosest(closestGrids,currentGridPos,obj.chipSize/spacing/2);
                nextPos = nextGrid*spacing;
                index = floor(nextGrid) - [cols(1) rows(1)] + 1;  % Index into map
                % Attempt to execute move
                set(statusH,'string',sprintf('%s\nGetting current sample position.',msg)); drawnow nocallbacks;
                err = [];  % Check if empty for NV localization
                try
                    set(statusH,'string',sprintf('%s\nGetting current sample position.',msg)); drawnow nocallbacks;
                    [currentPos,stagePos,readInfo] = sample.getPosition('focus',false,'enhanced',true); % Takes image
                    set(statusH,'string',sprintf('%s\nSetting new position.',msg)); drawnow nocallbacks;
                    currentPos = sample.setPosition(nextPos,loc_handle,[currentPos 0],stagePos,readInfo,ax(2),ax(3)); % Takes at least 1 images and 1 focus
                    set(statusH,'string',msg); drawnow nocallbacks;
                    currentPos = currentPos(1:2);  % Remove z (always 0)
                    set(loc_handle,'xdata',currentPos(1),'ydata',currentPos(2));
                    plot(ax(1),currentPos(1),currentPos(2),'g.','markersize',7,'HitTest','off');
                    drawnow nocallbacks;
                    obj.navigation.map(index(2),index(1)) = i; % To get index into map
                catch err % Navigation error
                    if strcmp(err.message,'Destination out of stage range.')
                        im = []; % Not an image problem...
                    else
                        im = sample.lastImage;
                    end
                    % We can guess our currentPos is probably pretty close to the nextPos
                    currentPos = nextPos;  % not sure about this!!!!
                    set(statusH,'string',msg); drawnow nocallbacks;
                    obj.navigation.map(index(2),index(1)) = -i;
                    % Return to closest known position (that is not current position)
                    plot(ax(1),currentPos(1),currentPos(2),'r.','markersize',7,'HitTest','off');
                    [closestStagePos,currentPos] = sample.closestKnownPosition(currentPos,'sample');
                    set(statusH,'string',sprintf('%s\nReturing to closest known position.',msg));
                    managers.Stages.move(closestStagePos);
                    set(loc_handle,'xdata',currentPos(1),'ydata',currentPos(2));
                    drawnow;  % Allow callbacks for abort button
                    % Log error
                    err_struct.err = err;
                    err_struct.wl = im;
                    obj.navigation.errors(end+1) = err_struct;
                    obj.logger.log(sprintf('Position: %0.2f, %0.2f: %s',nextPos(1),nextPos(2),err.message));
                    err_struct = []; im = [];  % Clean some memory
                    if ~mod(length(obj.navigation.errors),10)
                        obj.notify(sprintf('RoMi has had %i positioning errors!',length(obj.navigation.errors)))
                    end
                    managers.Stages.waitUntilStopped;
                    set(statusH,'string',msg);
                end
                uistack(loc_handle,'top'); drawnow nocallbacks;
                obj.navigation.mov(i) = getframe(managers.handles.figure1,getpixelposition(managers.handles.panel_exp,true));
                % NV localization (retake WL image so it is closer in time)
                if isempty(err) && obj.todo_method
                    assert(~obj.abort_request,'User aborted.')
                    msg = sprintf('%s\nEvaluating todo method...',msg);
                    set(statusH,'string',msg); drawnow nocallbacks;
                    obj.todo(statusH,managers,ax,currentPos);
                end
                % Update time estimate
                obj.navigation.times(i) = toc(t_start);
                if obj.pause_request;keyboard();obj.pause_request=false;end
            end
            catch abort_err
            end
            obj.wl.off;
            obj.gl.off;

            set(ax(1),'ButtonDownFcn',@(a,b)obj.moveTo(a,b,loc_handle));
            checkoutlaser(0,getpref('CommandCenter','secret_key_path'))
            obj.post_run(statusH,managers,ax);
            if ~isempty(abort_err)
                rethrow(abort_err)  % Prevent autosave
            end
            obj.notify('Done!')
        end
        function moveTo(obj,ax,eventdata,loc_handle)
            nextPos = eventdata.IntersectionPoint(1:2);
            if eventdata.Button==1 && prod(nextPos>0) && nextPos(1) < obj.chipSize(1) && nextPos(2) < obj.chipSize(2)
                obj.SmartSample.setPositionBlind(nextPos,loc_handle)
            end
        end
        
        function abort(obj)
            obj.abort_request = true;
        end

        function settings(obj,panelH,~)
            spacing = 1.5;
            line = 1;
            % Builds bottom up
            uicontrol(panelH,'style','text','string','Stop (um,um):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*line 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.stop,'%g, %g'),...
                'units','characters','callback',@obj.boundsCallback,'tag','stop',...
                'horizontalalignment','left','position',[19 spacing*line 17 1.5]);
            line = line + 1;
            uicontrol(panelH,'style','text','string','Start (um,um):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*line 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.start,'%g, %g'),...
                'units','characters','callback',@obj.boundsCallback,'tag','start',...
                'horizontalalignment','left','position',[19 spacing*line 17 1.5]);
            line = line + 1;
            uicontrol(panelH,'style','text','string','Green Exp (ms):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*line 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.gl_exposure),...
                'units','characters','callback',@obj.exposureCallback,'tag','gl_exposure',...
                'horizontalalignment','left','position',[19 spacing*line 10 1.5]);
            line = line + 1;
            uicontrol(panelH,'style','text','string','White Exp (ms):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*line 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.wl_exposure),...
                'units','characters','callback',@obj.exposureCallback,'tag','wl_exposure',...
                'horizontalalignment','left','position',[19 spacing*line 10 1.5]);
            line = line + 1;
            uicontrol(panelH,'style','text','string','Chip Size (um):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*line 18 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.chipSize(1)),...
                'units','characters','callback',@obj.sizeCallback,...
                'horizontalalignment','left','position',[19 spacing*line 10 1.5]);
            line = line + 1;
            uicontrol(panelH,'style','checkbox','string','Execute todo','horizontalalignment','right',...
                'units','characters','position',[2 spacing*line 18 1.25],...
                'value',obj.todo_method,'callback',@obj.todo_methodCallback);
        end
        function todo_methodCallback(obj,hObj,~)
            obj.todo_method = get(hObj,'Value');
        end
        function sizeCallback(obj,hObject,~)
            val = str2double(get(hObject,'String'));
            assert(~isnan(val),'Must be a number.')
            obj.chipSize = [0 0]+val;
        end
        function exposureCallback(obj,hObject,~)
            val = str2double(hObject.String);
            assert(~isnan(val),'Must be a number.')
            obj.(hObject.Tag) = val;
        end
        function boundsCallback(obj,hObject,~)
            val = cell2mat(textscan(hObject.String,'%f,%f'));
            assert(length(val)==2,'Must be a list of two numbers delimited by a comma.')
            obj.(hObject.Tag) = val;
        end
    end
    methods (Static)
        function locs = closestGrids(grid,map,pos)
            % Returns Nx2 locs vector of nearest unvisited grid locations
            %   unvisited means map value of 0.
            %   grid should be an Nx2 vector
            %   pos should be in (col,row) format
            assert(length(pos)==2,'Position must be a 1x2 vector: (x,y)')
            opts = grid(map(:)==0,:);  % Returns grid with entries in map = 0
            I = cell2mat(knnsearch(opts,pos,'IncludeTies',true));
            locs = opts(I,:);
        end
        function loc = prioritizeClosest(locs,pos,center)
            % Returns 1x2 loc vector of prioritized location to pos.
            %   locs should be output of closestGrids
            %   pos should be in (col,row) format
            
            % Take closest firt
            I = knnsearch(locs,center,'K',1,'IncludeTies',true);
            locs = locs(I{1},:);
            if size(locs,1) == 1
                % locs==pos should only happen here as well
                loc = locs;
                return
            end
            assert(length(pos)==2,'Position must be a 1x2 vector: (x,y)')
            priority = [ 0, 1;  % up
                -1, 0;  % left
                0,-1;  % down
                1, 0]; % right
            for i = 1:size(priority,1)
                metrics = NaN(1,4);
                for j = 1:size(locs,1)
                    % Even though they are the same length, need to
                    % normalize for checking max_metric below.
                    centered = locs(j,:) - pos;
                    norm_loc = centered/norm(centered);
                    metrics(j) = dot(norm_loc,priority(i,:));
                end
                % If there is one positive, max value, we are done.
                % If there are more than one positive max values, remove
                % others and continue loop. If there are zero, keep all and
                % continue.
                max_metric = max(metrics);
                if max_metric >= sqrt(2)/2-1e4  % This nicely divides into quadrants
                    %                             (cannot be equal to, because that will
                    %                             exclude exactly 45 degree positions)
                    I_metrics = find(metrics==max_metric);
                    if length(I_metrics) == 1
                        loc = locs(I_metrics,:);
                        return
                    else % length(n_metrics) > 1
                        locs = locs(I_metrics,:);
                    end
                end
            end
            error('Bad logic lead to this error - better debug this function!')
        end
        %% Testing Walk
        function testGridWalk(cols,rows,start,bad_squares,dt,fname)
            % Pitch is just 1, not Base.QR.spacing_between
            %   So, position and grid are the same
            % cols, rows -> 1D arrays
            % start -> 1x2: (col,row)
            % bad_squares -> Nx2: (col1,row1;col2,row2,...)
            if nargin < 4
                dt = 0;
                bad_squares = NaN(0,2);
            elseif nargin < 5
                dt = 0;
            end
            obj.navigation.mov = struct('cdata',{},'colormap',{});
            bad_squares = floor(bad_squares)+0.5;
            map = zeros(length(rows),length(cols));  % map(y,x)
            [gridX,gridY] = meshgrid(cols,rows);
            grid = ([gridX(:) gridY(:)]+0.5);
            delete(findall(0,'name','testGridWalk'));
            f = figure('name','testGridWalk','units','normalized','position',[0 0 1 1]);
            ax = axes('parent',f); hold(ax,'on'); axis(ax,'image');
            Experiments.InitialCharacterization.drawMap(map,grid,ax,[]);
            i = 0;
            currentPos = start;
            while sum(map(:)==0)  % While there are zeros left
                i = i + 1;
                % Find next move
                currentGridPos = floor(currentPos)+0.5;
                closestGrids = Experiments.InitialCharacterization.closestGrids(grid,map,currentGridPos);
                nextGrid = Experiments.InitialCharacterization.prioritizeClosest(closestGrids,currentGridPos,[diff(cols([1,end])) diff(rows([1,end]))]/2);
                index = floor(nextGrid) - [cols(1) rows(1)] + 1;  % Index into map
                previousPos = currentPos;
                currentPos = nextGrid;
                map(index(2),index(1)) = i;
                for j = 1:size(bad_squares,1)
                    if isequal(nextGrid,bad_squares(j,:))
                        map(index(2),index(1)) = -i;
                        bad_squares(j,:) = [];  % Speed things up
                        visited = grid(map(:)>0,:);
                        closest = knnsearch(visited,currentPos,'K',1);
                        currentPos = visited(closest,:);
                        break
                    end
                end
                Experiments.InitialCharacterization.drawMap(map,grid,ax,previousPos);
                obj.navigation.mov(end+1) = getframe(ax);
            end
            if nargin == 6
                movie2gif(obj.navigation.mov,fname,'LoopCount',Inf,'DelayTime',dt)
            end
        end
        function drawMap(map,grid,ax,position)
            % For map:
            % 0 -> white
            % -n -> red
            % +n -> green
            % currentPos -> darker
            map = map(:);
            p = ax.UserData;
            first = false;
            if isempty(p)
                first = true;
                p = gobjects(1,size(grid,1));
            end
            for i = 1:size(grid,1)
                x = [0 1 1 0] - 1/2 + grid(i,1);
                y = [0 0 1 1] - 1/2 + grid(i,2);
                color = 'w';
                if map(i) < 0
                    color = 'r';
                elseif map(i) > 0
                    color = 'g';
                end
                if first
                    p(i) = patch(x,y,color,'parent',ax);
                    ax.UserData = p;
                else
                    set(p(i),'facecolor',color)
                end
            end
            if ~isempty(position)
                x = [0 1 1 0] - 1/2 + position(1);
                y = [0 0 1 1] - 1/2 + position(2);
                delete(findall(ax,'tag','position'));
                patch(x,y,'k','parent',ax,'facealpha',0.2,'tag','position');
            end
            drawnow;
        end
    end
    
end

