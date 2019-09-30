classdef StageManager < Base.Manager
    % STAGEMANAGER Manages stages and visualization gui.
    %
    %   stage.Moving is the only required observable property in a stage
    %   object.  This is because typically it is very convenient to have a
    %   get method for the position property. As such, this requires
    %   creating a timer object here to periodically query the position
    %   property of the stage to update.
    %
    %   There are two abort levels. Many thorlab stages support a
    %   controlled abort, where position is kept, or a more intense one
    %   where position is lost. Some stages will not differentiate - it
    %   depends entirely on the code of the custom module.
        
    properties
        update_gui = 'on';       % You can prevent it from updating GUI for timing purposes
        line_colors = {[1 0 0],[0 0 1]};     % Colors used for stages lines
        face_colors = {[1 0.7 0.7],[0.769 0.753 1]};      % Colors used for stages planes
        thickness = 2.5;      % Linewidth of boundry lines for stage
        line_transparency = 0.5; % Transparency of boundry lines (1 value for all)
        face_transparency = 0.9; % Transparency for faces (1 value for all)
        timeout = 60*5;            % Timeout in seconds for the stage to be moving at any one time.
        hideStageTimeoutError=false;      % Simply do not throw the error
        update_period = 0.2;     % The rate at which the Visualizer updates when moving (seconds)
    end
    properties(SetAccess=private) % AbortSet doesn't work well with NaN values
        % Use the newPosition event to know when to query this passively.
        % Otherwise, calls querying it will attempt to get position from
        % instruments
        position;      % Position that is updated on a timer (update_period) when stage.Moving
    end
    properties(SetAccess=private,SetObservable,AbortSet)
        moving = false;
    end
    % Figure properties
    properties(Access=private)
        pos_listener    % Listener for position update.  Allows us to delete it if we want.
        listeners       % Listeners to stage objects and this objects position
        fig             % Handle to figure
        ax              % Handle to axes
        CamOrbit        % Handle to CamOrbit
        stage_lims      % Handle to stage lines that create the limit (list for all stages)
        stage_planes    % Handle to patch for stage plane
        currentPos      % Handle to scatter point
    end
    
    events
        newPosition % Alternative to SetObservable
    end
    
    methods(Access=private)
        function close_req(obj,varargin)
            % Closes figure and cleans up axes handles
            handles = {obj.listeners obj.CamOrbit obj.fig};
            for i = 1:numel(handles)
                for j = 1:numel(handles{i})
                    if ~isempty(obj.fig)&&isobject(obj.fig)&&isvalid(obj.fig)
                        delete(handles{i}(j))
                    end
                end
            end
        end
        function stage_update(obj,varargin)
            % If stages change, then close and reopen window.
            obj.close_req;
            obj.show;
        end
        function active_stage_moving_update(obj)
            handles = obj.handles;
            % Make sure it is the correct datatype!
            if ~isempty(obj.active_module)&&obj.active_module.Moving
                set(handles.stage_move,'string','Abort')
                set(handles.stage_move,'BackgroundColor',[1 0.6 0.6])
                set(handles.stage_move,'Callback',@(~,~)obj.abort(false))
                set(handles.stage_move,'TooltipString','Controlled abort (not IMMEDIATE).')
            else
                set(handles.stage_move,'string','Move')
                set(handles.stage_move,'BackgroundColor',0.94*[1 1 1])
                set(handles.stage_move,'Callback',@obj.moveCallback)
                set(handles.stage_move,'TooltipString','Move to new position specified above.')
            end
        end
        function movingCallback(obj,prop,varargin)
            % Check to see if active stage is moving
            mov = false;
            for i = 1:numel(obj.modules)
                mov = obj.modules{i}.Moving;
                if mov
                    break
                end
            end
            obj.moving = mov;
            obj.active_stage_moving_update;
            if strcmpi(obj.update_gui,'no')
                return
            end
            stage_str = prop.DefiningClass.Name;
            stage = obj.module_byString(stage_str);
            if ~stage.Moving
                % Existing timer should handle a stage that has finished
                % moving
                return
            end
            timerH = timerfindall('name',stage_str);
            if ~isempty(timerH) && isvalid(timerH)
                % Restart timer by stopping and starting (so have to remove
                % stop function while this happens)
                set(timerH,'StopFcn','')
                stop(timerH)
                set(timerH,'StopFcn',@obj.deleteTimer)
                start(timerH)
                return
            end
            % Timer that updates local position property. Use tags to reference.
            timerH = timer('Executionmode','fixedSpacing','Period',obj.update_period,...
                'TimerFcn',@obj.updatePosCallback,'StopFcn',@obj.deleteTimer,...
                'TasksToExecute',obj.timeout/obj.update_period,...
                'name',stage_str,'tag',mfilename,'busymode','drop');
            start(timerH);
        end
        function deleteTimer(obj,timerH,varargin)
            stage_str = get(timerH,'name');
            stage = obj.module_byString(stage_str);
            if stage.Moving && ~obj.hideStageTimeoutError
                err_text = {sprintf('StageManager timeout reached. Stage %s claims to be moving still!',stage_str),...
                    'StageManager is no longer tracking this instance of the move. No fatal errors will occur, but it will be annoying to see this again.',...
                    sprintf('The timeout is set to %i. Perhaps you need to increase this value.',obj.timeout)};
                obj.error(strjoin(err_text,'\n'))
            end
            delete(timerH)
        end
        function updatePosCallback(obj,timerH,varargin)
            stage_str = get(timerH,'name');
            stage = obj.module_byString(stage_str);
            if ~stage.Moving
                stop(timerH)
            end
            obj.updatePos
        end
        function updatePos(obj,varargin)
            if isempty(obj.modules) % Short circuit
                pos = NaN(1,3);
                obj.position = pos;
                return
            end
            pos = [0 0 0];
            for i = 1:numel(obj.modules)
                cal = obj.get_cal(i); % Get calibration for i'th module
                rel_pos = obj.modules{i}.position.*cal;
                if numel(rel_pos) ~= 3
                    msg = sprintf('Stage %s position received %i of the 3 axes only',class(obj.stages{i}),numel(global_loc));
                    obj.error(msg,true);
                end
                if ~isempty(obj.ax)&&isobject(obj.ax)&&isvalid(obj.ax)
                    obj.updateAx(i,pos,rel_pos);
                end
                pos = pos + rel_pos;
            end
            obj.position = pos;
            if ~isempty(obj.ax)&&isobject(obj.ax)&&isvalid(obj.ax)
                set(obj.currentPos,'xdata',pos(1),'ydata',pos(2),'zdata',pos(3));
                set(obj.ax,'CameraTarget',pos)
            end
        end
        
        function initAx(obj)
            obj.ax = axes('parent',obj.fig);
            axis(obj.ax,'image')
            if ~isempty(obj.CamOrbit)&&isobject(obj.CamOrbit)&&isvalid(obj.CamOrbit)
                delete(obj.CamOrbit)
            end
            obj.CamOrbit = Base.CamOrbit(obj.fig,obj.ax);
            xlabel(obj.ax,'X (um)')
            ylabel(obj.ax,'Y (um)')
            zlabel(obj.ax,'Z (um)')
            hold(obj.ax,'on')
            for i = 1:numel(obj.modules)
                cal = obj.get_cal(i);
                xlim = obj.modules{i}.xRange*cal(1);
                ylim = obj.modules{i}.yRange*cal(2);
                zlim = obj.modules{i}.zRange*cal(3);
                obj.stage_lims(i) = Base.DrawBox(xlim,ylim,zlim,...
                    'linewidth',obj.thickness,...
                    'parent',obj.ax,...
                    'color',[obj.line_colors{i} obj.line_transparency]);
                x = [xlim(1) xlim(1) xlim(2) xlim(2)];
                y = [ylim(1) ylim(2) ylim(2) ylim(1)];
                obj.stage_planes(i) = patch(x,y,[0 0 0 0],'parent',obj.ax,'facecolor',obj.face_colors{i},...
                    'edgecolor','none','facealpha',obj.face_transparency);
            end
            obj.currentPos = scatter3(obj.ax,0,0,0,'markerfacecolor','k');
            view(obj.ax,3)
            obj.updatePos;
        end
        function updateAx(obj,i,parent_pos,current_pos)
            % If src is specified, must be from callback, so check that we
            % are moving, and if it seems like we aren't ask user!
            % Next boundaries (before we update global_loc, so they are centered at the parent's pos)
            cal = obj.get_cal(i);
            xlim = obj.modules{i}.xRange*cal(1);
            ylim = obj.modules{i}.yRange*cal(2);
            zlim = obj.modules{i}.zRange*cal(3);
            [x,y,z] = Base.DrawBox(xlim,ylim,zlim);
            set(obj.stage_lims(i),'xdata',x+parent_pos(1),...
                'ydata',y+parent_pos(2),...
                'zdata',z+parent_pos(3));
            % Planes - weird because x,y need to be parent, but z is current
            x = [xlim(1) xlim(1) xlim(2) xlim(2)]+parent_pos(1);
            y = [ylim(1) ylim(2) ylim(2) ylim(1)]+parent_pos(2);
            global_loc = parent_pos + current_pos;
            z = global_loc(3);
            set(obj.stage_planes(i),'xdata',x,'ydata',y,'zdata',[z z z z]);
        end
    end
    methods
        function update_GUI_pos(obj,varargin)
            % Callback for listener from constructor
            handles = obj.handles;
            global_pos = obj.position;
            set(handles.global_x,'String',sprintf('%0.2f',global_pos(1)));
            set(handles.global_y,'String',sprintf('%0.2f',global_pos(2)));
            set(handles.global_z,'String',sprintf('%0.2f',global_pos(3)));
            if ~isempty(obj.active_module)
                cal = obj.get_cal;
                pos = obj.active_module.position.*cal;
                set(handles.stage_x,'String',sprintf('%0.2f',pos(1)));
                set(handles.stage_y,'String',sprintf('%0.2f',pos(2)));
                set(handles.stage_z,'String',sprintf('%0.2f',pos(3)));
            end
        end
        function cal = get_cal(obj,mod)
            if nargin < 2
                mod = obj.active_module;
            end
            if isnumeric(mod)
                mod = obj.modules{mod};
            end
            if isnumeric(mod.calibration)&&~sum(isnan(mod.calibration))
                cal = mod.calibration;
            else
                err = sprintf('%s calibration property is not numeric (or is NaN). Please fix this. Using 1 for now',class(mod));
                obj.error(err)
                cal = 1;
            end
        end
        function pos = get.position(obj)
            d = dbstack(1);
            if ~ismember('StageManager.get.position', {d.name})
                % Force position update when not called recursively
                % NOTE: returning position and setting *in* the get method would also work
                %     but this keeps it more consistent
                obj.updatePos;
            end
            pos = obj.position;
        end
        function set.position(obj,val)
            % AbortSet doesn't treat NaN specially
            cur_pos = obj.position;
            if ~nanisequal(cur_pos,val)
                obj.position = val;
                notify(obj,'newPosition');
            end
        end
        function set.update_gui(obj,val)
            handles = obj.handles;
            if strcmpi(val,'on')
                if isempty(obj.pos_listener)||~isvalid(obj.pos_listener) %#ok<*MCSUP>
                    obj.update_GUI_pos
                    obj.pos_listener = addlistener(obj,'newPosition',@obj.update_GUI_pos);
                end
            else
                delete(obj.pos_listener)
                global_pos = NaN(1,3);
                set(handles.global_x,'String',sprintf('%0.2f',global_pos(1)));
                set(handles.global_y,'String',sprintf('%0.2f',global_pos(2)));
                set(handles.global_z,'String',sprintf('%0.2f',global_pos(3)));
                if ~isempty(obj.active_module)
                    pos = global_pos;
                    set(handles.stage_x,'String',sprintf('%0.2f',pos(1)));
                    set(handles.stage_y,'String',sprintf('%0.2f',pos(2)));
                    set(handles.stage_z,'String',sprintf('%0.2f',pos(3)));
                end
            end
        end
        function obj = StageManager(handles)
            obj = obj@Base.Manager(Modules.Stage.modules_package,handles,handles.panelStage,handles.stage_select);
            obj.prefs = [obj.prefs {'update_gui','line_colors','face_colors','thickness','line_transparency'...
                 'face_transparency','timeout','hideStageTimeoutError','update_period'}];
            obj.loadPrefs;
            obj.blockOnLoad = handles.menu_stage;
            % Visualize
            set(handles.stage_visualize,'callback',@obj.show)
            % Textboxes
            set([handles.stage_setx,handles.stage_sety,handles.stage_setz],...
                'callback',@obj.set_num)
            % Stage Rel
            set(handles.stage_rel,'callback',@obj.stage_rel)
            % Stage Move - set in active_stage_moving_update
            obj.active_stage_moving_update;
            % Stage Home
            set(handles.stage_home,'callback',@obj.home)
            % Single direction jogs
            set(handles.stage_posX,'callback',@(~,~)obj.single_jog(1,1))
            set(handles.stage_negX,'callback',@(~,~)obj.single_jog(-1,1))
            set(handles.stage_posY,'callback',@(~,~)obj.single_jog(1,2))
            set(handles.stage_negY,'callback',@(~,~)obj.single_jog(-1,2))
            set(handles.stage_posZ,'callback',@(~,~)obj.single_jog(1,3))
            set(handles.stage_negZ,'callback',@(~,~)obj.single_jog(-1,3))
            obj.update_gui = 'on'; % set.update_gui will create listener
        end
        function delete(obj)
            % Clean up timers if necessary (not this shouldn't be necessary, but makes for debugging issues easier!)
            delete(timerfindall('tag',mfilename))
            delete(obj.listeners)
            if ~isempty(obj.fig)&&isobject(obj.fig)&&isvalid(obj.fig)
                delete(obj.fig)
            end
        end
        function getAvail(obj,parent_menu)
            % Override. Show stages in order. Edit option at bottom.
            module_strs = obj.get_modules_str;
            delete(allchild(parent_menu));
            if isempty(module_strs)
                uimenu(parent_menu,'label','No Modules Loaded','enable','off');
            end
            for i = 1:numel(module_strs)
                module_str = module_strs{i};
                uimenu(parent_menu,'label',module_str,'enable','off');
            end
            uimenu(parent_menu,'separator','on','label','Edit',...
                'callback',@obj.edit);
        end
        
        function show(obj,varargin)
            if ~isempty(obj.fig)&&isobject(obj.fig)&&isvalid(obj.fig)
                figure(obj.fig)
                return
            end
            obj.fig = figure('numbertitle','off',...
                'CloseRequestFcn',@obj.close_req);
            % Pick out the tools I want, transfer, then remove the old toolbar
            h = findall(obj.fig,'type','uitoolbar');
            h = findall(h);
            tth = uitoolbar(obj.fig);
            for i = 1:numel(h)
                if ismember(h(i).Tag,{'Exploration.ZoomIn'})
                    set(h(i),'Parent',tth)
                end
            end
            set(obj.fig,'menu','none','handlevisibility','off')
            obj.listeners = addlistener(obj,'modules','PostSet',@obj.stage_update);
            obj.initAx;
        end
        function edit(obj,varargin)
            [stage_names,success] = StageManagerEdit(obj.get_modules_str);
            if success
                % Delete stages that exist
                temp = obj.modules;
                for i = 1:numel(temp)
                    delete(temp{i})
                end
                TEMPstages = obj.load_module_str(stage_names);
                % Go through and test limits and add listeners
                for i = 2:numel(TEMPstages)
                    err = {sprintf('Stange ranges for the following axes are not decreasing:\n'),...
                        sprintf('\nYou may have to go in and edit the order or fix your code.\nThis stage and those that follow will not be added.')};
                    wrongRanges = cell(1,3);
                    wrongRangesI = false(1,3);
                    cal1 = obj.get_cal(TEMPstages{i-1});
                    cal2 = obj.get_cal(TEMPstages{i});
                    if min(TEMPstages{i}.xRange*cal2(1))<min(TEMPstages{i-1}.xRange*cal1(1))...
                            || max(TEMPstages{i}.xRange*cal2(1))>max(TEMPstages{i-1}.xRange*cal1(1))
                        wrongRanges{1} = 'X'; wrongRangesI(1) = true;
                    end
                    if min(TEMPstages{i}.yRange*cal2(2))<min(TEMPstages{i-1}.yRange*cal1(2))...
                            || max(TEMPstages{i}.yRange*cal2(2))>max(TEMPstages{i-1}.yRange*cal1(2))
                        wrongRanges{2} = 'Y'; wrongRangesI(2) = true;
                    end
                    if min(TEMPstages{i}.zRange*cal2(3))<min(TEMPstages{i-1}.zRange*cal1(3))...
                            || max(TEMPstages{i}.zRange*cal2(3))>max(TEMPstages{i-1}.zRange*cal1(3))
                        wrongRanges{3} = 'Z'; wrongRangesI(3) = true;
                    end
                    wrongRanges = wrongRanges(wrongRangesI);
                    if ~isempty(wrongRanges)
                        wrongRanges = strjoin(wrongRanges',', ');
                        err = strjoin(err,wrongRanges);
                        obj.error(err)
                        for j = i:numel(TEMPstages)
                            delete(TEMPstages{j})
                        end
                        break
                    end
                end
                obj.modules = TEMPstages;
            end
        end
        function waitUntilStopped(obj)
            % Wait until the stage(s) has stopped moving
            while obj.moving
                drawnow;
            end
        end
        % Active Stage Commands
        function move(obj,new_pos)
            % Will ignore any NaN entries
            validateattributes(new_pos,{'numeric'},{'vector','numel',3});
            cal = obj.get_cal;
            new_pos = new_pos./cal;
            new_pos_cell = cell(1,3);
            for i = 1:length(new_pos)
                if ~isnan(new_pos(i))
                    new_pos_cell{i} = new_pos(i);
                end
            end
            obj.sandboxed_function({obj.active_module,'move'},new_pos_cell{:});
        end
        function jog(obj,delta)
            % Will ignore any NaN entries
            cal = obj.get_cal;
            delta = delta./cal;
            current_pos = obj.active_module.position;
            new_pos = current_pos + delta;
            new_pos_cell = cell(1,3);
            for i = 1:length(new_pos)
                if ~isnan(new_pos(i))
                    new_pos_cell{i} = new_pos(i);
                end
            end
            obj.sandboxed_function({obj.active_module,'move'},new_pos_cell{:});
        end
        
        % Active Stage Commands, but also possible callbacks
        function abort(obj,immediate,varargin)
            err = [];
            try
                obj.active_module.abort(immediate);
            catch err
                obj.error(sprintf('Following error caught in %s.abort(false):\n%s.',class(obj.active_module),err.message))
            end
            handles = obj.handles;
            set(handles.stage_move,'string','ABORT')
            set(handles.stage_move,'BackgroundColor',[1 0 0])
            set(handles.stage_move,'Callback',@(~,~)obj.abort(true))
            set(handles.stage_move,'TooltipString','IMMEDIATE abort.')
            if ~isempty(err)
                rethrow(err)
            end
        end
        function home(obj,varargin)
            button = questdlg(sprintf('Are you sure you want to home stage\n%s?',class(obj.active_module)),'StageManager Confirmation','Yes','Cancel','Yes');
            if ~strcmp(button,'Yes')
                obj.warning(sprintf('Aborted home for %s',class(obj.active_module)),false)
                return
            end
            try
                obj.active_module.home;
            catch err
                obj.error(sprintf('Following error caught in %s.home:\n%s\nTraceback in command window.',class(obj.active_module),err.message),err)
            end
            % Simply, because if there is a place someone would forget to
            % use stage.Moving, it would be here!
            obj.update_GUI_pos
        end
        
        % Callbacks for GUI button press
        function set_num(obj,hObject,varargin)
            str = get(hObject,'String');
            val = str2num(str); %#ok<ST2NM> uses eval, meaning allows equations; str2num('3+2') works
            if isempty(val)
                obj.error('Value must be a number!')
                set(hObject,'String','NaN')
            end
        end
        function stage_rel(obj,hObject,varargin)
            handles = obj.handles;
            movingCTL = [handles.stage_posX handles.stage_negX...
                handles.stage_posY handles.stage_negY...
                handles.stage_posZ handles.stage_negZ];
            if get(hObject,'Value')
                set(movingCTL,'enable','on');
            else
                set(movingCTL,'enable','off');
            end
        end
        function moveCallback(obj,varargin)
            x = str2double(get(obj.handles.stage_setx,'string'));
            y = str2double(get(obj.handles.stage_sety,'string'));
            z = str2double(get(obj.handles.stage_setz,'string'));
            if get(obj.handles.stage_rel,'Value')
                obj.jog([x y z])
            else
                obj.move([x y z])
            end
        end
        function single_jog(obj,mult,index,varargin)
            handles = obj.handles;
            x = str2double(get(handles.stage_setx,'string'));
            y = str2double(get(handles.stage_sety,'string'));
            z = str2double(get(handles.stage_setz,'string'));
            instr = [x y z];
            delta = [0 0 0];
            delta(index) = mult*instr(index);
            obj.jog(delta)
        end
    end
    methods(Access=protected)
        function modules_changed(obj,varargin)
            if isempty(obj.modules)
                set([obj.handles.stage_x,obj.handles.stage_y,obj.handles.stage_z],'String',sprintf('%0.2f',NaN));
                set([obj.handles.global_x,obj.handles.global_y,obj.handles.global_z,obj.handles.GlobalPosition],'visible','off')
                if ~isempty(obj.fig)&&isobject(obj.fig)&&isvalid(obj.fig)
                    close(obj.fig)
                end
            else
                set([obj.handles.global_x,obj.handles.global_y,obj.handles.global_z,obj.handles.GlobalPosition],'visible','on')
            end
            obj.updatePos;
            for i = 1:numel(obj.modules)
                % Don't need to track listener object, because we delete the stage here as well, which will take care of it.
                addlistener(obj.modules{i},'Moving','PostSet',@obj.movingCallback);
            end
            obj.active_stage_moving_update;
        end
        function active_module_changed(obj,varargin)
            obj.update_GUI_pos;
        end
    end
end
