classdef Resizable < handle
    %RESIZEABLE Adds a draggable object at the bottom of a panel
    %   Needs to be used with ScrollPanels
    %   If there is a tag on the panels, it will save the last dimension
    %   and use it next time.
    
    properties
        enable = 'on';
    end
    properties(SetAccess=private)
        fig
        panel
        dragPanel
        pad = 10;
        namespace
    end
    properties(Access=private)
        home
        OldWindowButtonMotionFcn
        OldWindowButtonDownFcn
        OldWindowButtonUpFcn
        busy = false;
    end
    
    methods
        function obj = Resizable(UIScrollPanel)
            obj.fig = Base.getParentFigure(UIScrollPanel.base);
            % Configure pointer
            iptPointerManager(obj.fig)
            temp = get(UIScrollPanel.base,'units');
            set(UIScrollPanel.base,'units','pixels')
            width = UIScrollPanel.base.Position(3);
            set(UIScrollPanel.base,'units',temp)
            obj.dragPanel = uipanel(UIScrollPanel.base,'units','pixels',...
                'position',[0 0 width 5]);
            obj.panel = UIScrollPanel;
            pointerBehavior.enterFcn = @obj.enterFcn;
            pointerBehavior.exitFcn = @obj.exitFcn;
            pointerBehavior.traverseFcn = [];
            iptSetPointerBehavior(obj.dragPanel,pointerBehavior)
            addlistener(UIScrollPanel.base,'ObjectBeingDestroyed',@(~,~)obj.delete);
            addlistener(UIScrollPanel,'minimized','PostSet',@obj.minimized);
            obj.namespace = get(obj.panel.base,'tag');
%             if ~isempty(obj.namespace)
%                 temp = get(obj.panel.base,'units');
%                 set(obj.panel.base,'units','pixels')
%                 h = obj.panel.base.Position(4);
%                 set(obj.panel.base,'units',temp)
%                 
%             end
        end
        function delete(obj)
%             if ~isempty(obj.namespace)
%                 savepref(mfilename,obj.namespace,
%             end
            delete(obj.dragPanel)
        end
        function clicked(obj,varargin)
            iptPointerManager(obj.fig,'disable');
            temp = get(obj.fig,'units');
            set(obj.fig,'units','pixels')
            obj.home = get(obj.fig,'CurrentPoint');
            obj.OldWindowButtonMotionFcn = get(obj.fig,'WindowButtonMotionFcn');
            set(obj.fig,'WindowButtonMotionFcn',@obj.buttonMotionFcn)
            set(obj.fig,'units',temp)
        end
        function unclicked(obj,varargin)
            set(obj.fig,'WindowButtonMotionFcn',obj.OldWindowButtonMotionFcn)
            iptPointerManager(obj.fig,'enable');
        end
        function buttonMotionFcn(obj,varargin)
            if ~obj.busy
                obj.busy = true;
                items = [obj.fig,obj.dragPanel,obj.panel.base];
                temp = get(items,'units');
                set(items,'units','pixels')
                pos = get(obj.fig,'CurrentPoint');
                delta = pos - obj.home;
                panelPos = get(obj.panel.base,'position');
                newPos = panelPos+[0 delta(2) 0 -delta(2)];
                if newPos(4) > obj.pad*2
                    set(obj.panel.base,'position',newPos);
                    obj.home = pos;
                end
                for i = 1:numel(temp)
                    set(items(i),'units',temp{i})
                end
                obj.busy = false;
            end
        end
        function enterFcn(obj,varargin)
            set(obj.fig,'pointer','top')
            obj.OldWindowButtonDownFcn = get(obj.fig,'ButtonDownFcn');
            obj.OldWindowButtonUpFcn = get(obj.fig,'WindowButtonUpFcn');
            set(obj.fig,'WindowButtonDownFcn',@obj.clicked)
            set(obj.fig,'WindowButtonUpFcn',@obj.unclicked)
        end
        function exitFcn(obj,varargin)
            set(obj.fig,'WindowButtonDownFcn',obj.OldWindowButtonDownFcn)
            set(obj.fig,'WindowButtonUpFcn',obj.OldWindowButtonUpFcn)
        end
        function minimized(obj,~,event)
            src = event.AffectedObject;
            if src.minimized
                obj.enable = 'off';
            else
                obj.enable = 'on';
            end
        end
        function set.enable(obj,val)
            val = lower(val);
            if strcmp(val,'on')
                set(obj.dragPanel,'visible','on') %#ok<*MCSUP>
            else
                set(obj.dragPanel,'visible','off')
            end
            obj.enable = val;
        end
    end
end