classdef MetaStageManager < Base.Manager
    % METASTAGEMANAGER
        
    properties
        fps = 5;
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
            m = 20;        % Margin.
            
            panel.Units = 'pixels';
            base.Units = 'pixels';
%             H = 10*(h+p);
%             panel.Position(4) = H;
%             panel.Position(4) = H;
            
            w = panel.Position(3) - 2*m;
            
            base.Position(2) = base.Position(2) - (w/2 - base.Position(4));
            base.Position(4) = w/2;
            
            panel.Position(2) = 0; %panel.Position(2) - (w/2 - panel.Position(4));
            panel.Position(4) = w/2;
            pos = panel.Position;
            H = panel.Position(4);
            
            dropdown =  uicontrol(panel, 'Style', 'popupmenu', 'String', {''}, 'Value', 1,  'Position', [m,         H-h-p, w-h-p,   h]);
            gear =      uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x2699),     'Position', [w+m-h-p,   H-h-p, h,       h]);
            
            B = (w+p)/6;
            b = B-p;
            
            y = H-h-2*p-2*B;
            x = m + 2*B;
            
            mx =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x25C0), 'Tooltip', 'Left (-x)', 'Position', [x     y   b b]);
            my =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x25BC), 'Tooltip', 'Down (-y)', 'Position', [x+B   y   b b]);
            py =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x25B2), 'Tooltip', 'Up (+y)',   'Position', [x+B   y+B b b]);
            px =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x25BA), 'Tooltip', 'Right (+x)', 'Position', [x+2*B y   b b]);
            
            mz =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x2297), 'Tooltip', 'In (-z)', 'Position', [x+3*B y   b b], 'FontSize', 20, 'FontWeight', 'bold');
            pz =    uicontrol(panel, 'Style', 'pushbutton', 'String', char(0x2299), 'Tooltip', 'Out (+z)', 'Position', [x+3*B y+B b b], 'FontSize', 20, 'FontWeight', 'bold');
            
            x = m;
            
            key =   uicontrol(panel, 'Style', 'checkbox', 'String', 'Keyboard', 'Tooltip', 'Whether to use the keyboard arrow keys for user input.', 'Position', [x y+3*h 2*b h]);
            joy =   uicontrol(panel, 'Style', 'checkbox', 'String', 'Joystick', 'Tooltip', 'Whether to use a joystick for user input.', 'Position', [x y+2*h 2*b h]);
            
            obj = obj@Base.Manager(Modules.MetaStage.modules_package, handles, handles.panelMetaStage, dropdown);
            
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
        function delete(obj)
            % Clean up timers if necessary (not this shouldn't be necessary, but makes for debugging issues easier!)
%             delete(timerfindall('tag',mfilename))
%             delete(obj.listeners)
%             if ~isempty(obj.fig)&&isobject(obj.fig)&&isvalid(obj.fig)
%                 delete(obj.fig)
%             end
        end
%         function getAvail(obj,parent_menu)
%             % Override. Show stages in order. Edit option at bottom.
%             module_strs = obj.get_modules_str;
%             delete(allchild(parent_menu));
%             if isempty(module_strs)
%                 uimenu(parent_menu,'label','No Modules Loaded','enable','off');
%             end
%             for i = 1:numel(module_strs)
%                 module_str = module_strs{i};
%                 uimenu(parent_menu,'label',module_str,'enable','off');
%             end
%             uimenu(parent_menu,'separator','on','label','Edit',...
%                 'callback',@obj.edit);
%         end
        
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
end
