classdef MetaStageManager < Base.Manager
    % METASTAGEMANAGER
        
    properties
        keyboard = false;
        joystick = false;
        
        scrollpanel = [];
        joyserver = [];
        joystatus = [];
        joytcpip = [];
        
        X = [];
        Y = [];
        Z = [];
    end
        
    properties
        fps = 5;
        
        keys_xp = {'rightarrow', 'd'};
        keys_xm = {'leftarrow', 'a'};
        keys_yp = {'uparrow', 'w'};
        keys_ym = {'downarrow', 's'};
        keys_zp = {'equal', 'add', 'e', 'pageup'};
        keys_zm = {'hyphen', 'subtract', 'underscore', 'q', 'pagedown'};
    end
    
    methods
        function obj = MetaStageManager(handles)
            scrollpanel = handles.panelMetaStage;
            
            base = scrollpanel.content;
            panels = scrollpanel.content.Children;
            panel = [];
            for i = 1:numel(panels)
                if strcmp(panels(i).Tag,'default')
                    panel = panels(i);
                end
            end
            if isempty(panel)
                error('Could not find default panel.')
            end
            
            h = 20;
            p = 2;         % Padding.
            m = Base.Manager.settings_horizontal_margin_px;        % Margin.
            
            panel.Units = 'pixels';
            base.Units = 'pixels';
%             H = 10*(h+p);
%             panel.Position(4) = H;
%             panel.Position(4) = H;
            
            w = panel.Position(3) - 2*m;
            
            B = (w+p)/6;
            b = B-p;
            
            H = 2*B+3*p+h;
            
            base.Position(2) = base.Position(2) - (w/2 - base.Position(4));
            base.Position(4) = H;
            
            panel.Position(2) = 0; %panel.Position(2) - (w/2 - panel.Position(4));
            panel.Position(4) = H;
            pos = panel.Position;
            
            dropdown =  uicontrol(panel, 'Style', 'popupmenu', 'String', {''}, 'Value', 1,  'Position', [m,         H-h-p, w,   h]);
%             gear =      uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x2699),     'Position', [w+m-h-p,   H-h-p, h,       h]);
            
            x = m + 2*B;
            y = H-h-2*p-2*B;
            
            obj = obj@Base.Manager(Modules.MetaStage.modules_package, handles, handles.panelMetaStage, dropdown);
            
            obj.scrollpanel = scrollpanel;
            
            mx =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x25C0), 'Callback', @(~,~)obj.step(-1,1,1), 'Tooltip', 'Left (-x)', 'Position', [x     y   b b]);
            my =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x25BC), 'Callback', @(~,~)obj.step(-1,2,1), 'Tooltip', 'Down (-y)', 'Position', [x+B   y   b b]);
            py =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x25B2), 'Callback', @(~,~)obj.step(+1,2,1), 'Tooltip', 'Up (+y)',   'Position', [x+B   y+B b b]);
            px =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x25BA), 'Callback', @(~,~)obj.step(+1,1,1), 'Tooltip', 'Right (+x)','Position', [x+2*B y   b b]);
            
            mz =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x2297), 'Callback', @(~,~)obj.step(-1,3,1), 'Tooltip', 'In (-z)',   'Position', [x+3*B y   b b], 'FontSize', 15);
            pz =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x2299), 'Callback', @(~,~)obj.step(+1,3,1), 'Tooltip', 'Out (+z)',  'Position', [x+3*B y+B b b], 'FontSize', 15);
            
            mult =  uicontrol(panel, 'Style', 'text',       'String', '',           'ForegroundColor', 'red',           'Tooltip', 'Speed Multiplier (Shift == *5, ctrl == *1/5)', 'Position', [x+2*B y+B b b]);
            
            x = m;
            y = y;
            
            h = (2*B)/4;
            h2 = h-p;
            
            key =   uicontrol(panel, 'Style', 'checkbox', 'String', 'Keyboard', 'Callback', @obj.keyboard_Callback, 'Tooltip', 'Whether to use the keyboard arrow keys for user input.', 'Position', [x y+3*h 2*b h2]);
            joy =   uicontrol(panel, 'Style', 'checkbox', 'String', 'Joystick', 'Callback', @obj.joystick_Callback, 'Tooltip', 'Whether to use a joystick for user input.', 'Position', [x y+2*h 2*b h2]);
            obj.joyserver = uicontrol(panel, 'Style', 'edit', 'String', 'No Server', 'Enable', 'off', 'Callback', @obj.joyserver_Callback, 'Tooltip', 'Whether to use a joystick for user input.', 'Position', [x y+h 2*b h2]);
            obj.joystatus = uicontrol(panel, 'Style', 'edit', 'String', 'No Server', 'Enable', 'off', 'Tooltip', 'Whether to use a joystick for user input.', 'Position', [x y 2*b h2]);
            
            
            panel.Units = 'characters';
            base.Units = 'characters';
            
%             obj.prefs = [obj.prefs {'update_gui','line_colors','face_colors','thickness','line_transparency'...
%                  'face_transparency','timeout','hideStageTimeoutError','update_period'}];
%             obj.loadPrefs;
%             obj.blockOnLoad = handles.menu_stage;
%             % Visualize
%             set(handles.stage_visualize,'callback',@obj.show)
%             % Textboxes
%             set([handles.stage_setx,handles.stage_sety,handles.stage_setz],...
%                 'callback',@obj.set_num)
%             % Stage Rel
%             set(handles.stage_rel,'callback',@obj.stage_rel)
%             % Stage Move - set in active_stage_moving_update
%             obj.active_stage_moving_update;
%             % Stage Home
%             set(handles.stage_home,'callback',@obj.home)
%             % Single direction jogs
%             set(handles.stage_posX,'callback',@(~,~)obj.single_jog(1,1))
%             set(handles.stage_negX,'callback',@(~,~)obj.single_jog(-1,1))
%             set(handles.stage_posY,'callback',@(~,~)obj.single_jog(1,2))
%             set(handles.stage_negY,'callback',@(~,~)obj.single_jog(-1,2))
%             set(handles.stage_posZ,'callback',@(~,~)obj.single_jog(1,3))
%             set(handles.stage_negZ,'callback',@(~,~)obj.single_jog(-1,3))
%             obj.update_gui = 'on'; % set.update_gui will create listener
        end
        
        % Return string representation of modules
        function strs = get_modules_str(obj,~)
            strs = {};
            for i = 1:numel(obj.modules)
                strs{i} = obj.modules{i}.singleton_id;
            end
        end
%         function disable(obj)
%             if obj.disabled > 0
%                 obj.disabled = obj.disabled + 1;
%                 return
%             end
%             obj.disabled = true;
%         end
%         function enable(obj)
%             if obj.disabled > 1
%                 obj.disabled = obj.disabled - 1;
%                 return
%             end
%             obj.disabled = false;
%         end
    end
    methods(Access=protected)
        function active_module_changed(obj, varargin)
            obj.active_module
            obj.X = obj.active_module.get_meta_pref('X');
            obj.Y = obj.active_module.get_meta_pref('Y');
            obj.Z = obj.active_module.get_meta_pref('Z');
        end
    end
    methods
        % Navigation
        function step(obj, magnitude, direction, isKeyboard)
            if nargin < 4
                isKeyboard = false;
            end
            
            pref = [];
            step = 0;
            switch direction
                case {1, 'x', 'X'}
                    pref = obj.active_module.get_meta_pref('X');
                    if isKeyboard
                        step = obj.active_module.key_step_x;
                    else
                        step = obj.active_module.joy_step_x;
                    end
                case {2, 'y', 'Y'}
                    pref = obj.active_module.get_meta_pref('Y');
                    if isKeyboard
                        step = obj.active_module.key_step_y;
                    else
                        step = obj.active_module.joy_step_y;
                    end
                case {3, 'z', 'Z'}
                    pref = obj.active_module.get_meta_pref('Z');
                    if isKeyboard
                        step = obj.active_module.key_step_z;
                    else
                        step = obj.active_module.joy_step_z;
                    end
            end
            
            if ~step
                warning('Step set to zero. No change expected.');
            end
            
            if ~isempty(pref)
                val = pref.get_ui_value();
                if isempty(val)
                    pref.writ(pref.read() + step*magnitude);        % This can cause issues.
                else
                    pref.writ(str2double(val) + step*magnitude);
                end
            end
        end
        
        % Input callbacks
        function set.keyboard(obj, val)
            obj.keyboard = val;
            
            if val
                obj.handles.figure1.KeyPressFcn = @obj.KeyPressFcn;
            else
                obj.handles.figure1.KeyPressFcn = '';
            end
%             obj.handles.figure1.KeyReleaseFcn
            
            obj.colorBorder();
        end
        function keyboard_Callback(obj, src, ~)
            if length(obj.modules) >= 1
                obj.keyboard = src.Value;
            else
                obj.keyboard = false;
                src.Value = 0;
            end
        end
        function KeyPressFcn(obj, ~, event)     % Interprets messages sent by the keyboard. Set as the main figure's KeyPressFcn when enabled.
            % First, decide whether it is appropriate to accept keyboard input in this context.
            focus = gco;

            if isprop(focus, 'Style')
                % Inappropriate contexts include, e.g. edit boxes, etc.
                proceed = (~strcmpi(focus.Style, 'edit') && ~strcmpi(focus.Style, 'choose')) || ~strcmpi(focus.Enable, 'on');    % Don't continue if we are currently changing the value of a edit uicontrol...
            else
                proceed = true;
            end

            if proceed                                  % If it is appropriate, then proceed.
                multiplier = 1;
                if ismember(event.Modifier, 'shift')    % The shift key speeds all movement by a factor of 10.
                    multiplier = multiplier*10;
                end
                if ismember(event.Modifier, 'alt')      % The alt key slows all movement by a factor of 10.
                    multiplier = multiplier/10;
                end

                switch event.Key                        % Now figure out which way we should move...
                    case obj.keys_xp    % +X
                        obj.step(+multiplier, 1, 1);
                    case obj.keys_xm    % -X
                        obj.step(-multiplier, 1, 1);
                    case obj.keys_yp    % +Y
                        obj.step(+multiplier, 2, 1);
                    case obj.keys_ym    % -Y
                        obj.step(-multiplier, 2, 1);
                    case obj.keys_zp    % +Z
                        obj.step(+multiplier, 3, 1);
                    case obj.keys_zm    % -Z
                        obj.step(-multiplier, 3, 1);
                end
            end
        end
        
        function set.joystick(obj, val)
            obj.joystick = val;
            obj.colorBorder();
            choices = {'off', 'on'};
            obj.joyserver.Enable = choices{val+1};
        end
        function joystick_Callback(obj, src, ~)
            if length(obj.modules) >= 1
                if verLessThan('matlab','9.9')
                    errordlg(['Joystick requires MATLAB >= R2020b. You have R' version('-release') '.'], 'Joystick Versioning')
                    obj.joystick = false;
                    src.Value = false;
                else
                    obj.joystick = src.Value;
                end
            else
                obj.joystick = false;
                src.Value = 0;
            end
        end
        function joyserver_Callback(obj, src, ~)
            if length(obj.modules) > 1
                obj.initializeJoystick(src.String);
            end
        end
        function initializeJoystick(obj, address)
            
%             splt = split(address, ':');
%             switch length(splt)
%                 case 1
%                     address = splt{1};
%                     port = 4000;
%                 case 2
%                     
%                 otherwise
%                     
%             end
            
            [obj.joytcpip, hello] = connectSmart(address);
            
            if isempty(obj.joytcpip)
                obj.joyserver.String = 'No Server';
                obj.joystatus.String = hello;
            else
                obj.joystick = true;
                obj.joyserver.String = address;
                obj.joystatus.String = hello;
            end

            function callbackFcn(t, ~)
                str = t.readline();

                if strcmp(str, "FIN")
                    t.flush();
                    clear t;
                    disp('Closed connection.')
                else
                    reply = jsondecode(str);
                    directions = fields(reply);
                    
                    for ii = 1:length(directions)
                        ignore = false;
                        switch directions{ii}
                            case {'xy', 'xy2', 'left', 'right'}
                                ignore = true;
                        end
                        
                        if ~ignore
                            obj.step(reply.(directions{ii}), directions{ii}(2));
                        end
                        
                        moduleplus = 0;
                        switch directions{ii}
                            case 'left'
                                moduleplus = -1;
                            case 'right'
                                moduleplus = 1;
                        end
                        
                        if moduleplus
                            obj.setActiveModule(mod(get(obj.popupHandle, 'value') - 1 + moduleplus, length(obj.modules)) + 1);
                        end
                    end
                end
            end
            function [t, hello] = connectSmart(host)
                disp('Trying to connect')
                [t, hello] = connect(host);

                if strcmp(hello, 'No Server') && strcmp(host, 'localhost')
                    disp('Starting server')
                    system('python startjoystick.py');
                    
                    pause(.5)

                    [t, hello] = connect(host);
                end
            end
            function [t, hello] = connect(host)
                try
                    t = tcpclient(host, 4001);
                    
                    t

                    hello = t.readline();
                    
                    hello

                    if isempty(hello) || strcmp(hello, 'No Joystick')
                        t.flush();
                        clear t;
                        t = [];

                        if isempty(hello)
                            hello = 'No Server';
                        end
                    else
                        configureCallback(t, "terminator", @callbackFcn)
                    end
                catch err
                    warning(err.message)
                    t = [];
                    hello = 'No Server';
                end
            end
        end
        
        function colorBorder(obj)
            if obj.keyboard && obj.joystick
                obj.scrollpanel.base.HighlightColor = [.8 0 .8];    % Purple
            elseif obj.keyboard
                obj.scrollpanel.base.HighlightColor = [0 0 1];      % Blue
            elseif obj.joystick
                obj.scrollpanel.base.HighlightColor = [1 0 0];      % Red
            else
                obj.scrollpanel.base.HighlightColor = 'w';
            end
        end
        
        % Header Menu functions
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
            uimenu(parent_menu, 'separator', 'on', 'label', 'New MetaStage',...
                'callback', @obj.new_callback);
        end
        function new_callback(obj, ~, ~)
            obj.new()
        end
        function new(obj, name)
            if nargin < 2
                name = '';
                while ~isvarname(name)
                    result = inputdlg('Enter a name for this new MetaStage. This needs to be a valid variable name.', 'New MetaStage Name');
                    name = result{1};
                end
            end
            
            obj.modules{end+1} = Modules.MetaStage.instance(name);
        end
        
        % Callbacks for GUI button press
%         function set_num(obj,hObject,varargin)
%             str = get(hObject,'String');
%             val = str2num(str); %#ok<ST2NM> uses eval, meaning allows equations; str2num('3+2') works
%             if isempty(val)
%                 obj.error('Value must be a number!')
%                 set(hObject,'String','NaN')
%             end
%         end
%         function stage_rel(obj,hObject,varargin)
%             handles = obj.handles;
%             movingCTL = [handles.stage_posX handles.stage_negX...
%                 handles.stage_posY handles.stage_negY...
%                 handles.stage_posZ handles.stage_negZ];
%             if get(hObject,'Value')
%                 set(movingCTL,'enable','on');
%             else
%                 set(movingCTL,'enable','off');
%             end
%         end
%         function moveCallback(obj,varargin)
%             x = str2double(get(obj.handles.stage_setx,'string'));
%             y = str2double(get(obj.handles.stage_sety,'string'));
%             z = str2double(get(obj.handles.stage_setz,'string'));
%             if get(obj.handles.stage_rel,'Value')
%                 obj.jog([x y z])
%             else
%                 obj.move([x y z])
%             end
%         end
%         function single_jog(obj,mult,index,varargin)
%             handles = obj.handles;
%             x = str2double(get(handles.stage_setx,'string'));
%             y = str2double(get(handles.stage_sety,'string'));
%             z = str2double(get(handles.stage_setz,'string'));
%             instr = [x y z];
%             delta = [0 0 0];
%             delta(index) = mult*instr(index);
%             obj.jog(delta)
%         end
    end
end
