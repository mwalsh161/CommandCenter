classdef SplitPanel < handle
    %SPLITPANEL Resizable panels.  One instance per divider.
    
    properties(AbortSet)
        type                    % horizontal or vertical
        min_size = 15;          % Min panel size
        units = 'pixels';       % Units for min_size and pad
        enable = 'on';          % Disable to hide divider
    end
    properties(Hidden)
        dividerH                % Handle to list of dividers
    end
    properties(SetAccess=private)
        panels                  % Handles to panels ordered by increasing start line (based on type).  See obj.order_panels
        parent_fig
        pad = 5;                % Pad for determining if click captured (units)
        busy = false;
    end
    properties(Access=private)
        home                    % Position when clicked
        OldWindowButtonMotionFcn
        OldWindowButtonDownFcn
        OldWindowButtonUpFcn
    end
    
    methods(Access=private)
        function pos = get_pos(obj,things,item)
            if nargin < 3
                item = 'position';
            end
            temp = get(things,'units');
            set(things,'units','pixels');
            pos = get(things,item);
            if length(things) == 1
                set(things,'units',temp)
            else
                for i = 1:numel(things)
                    set(things(i),'units',temp{i})
                end
            end
        end
        function order_panels(obj)
            metric = zeros(numel(obj.panels),1);
            for i = 1:numel(obj.panels)
                pos = obj.get_pos(obj.panels(i));
                if strcmp(obj.type,'horizontal')
                    metric(i) = pos(1);
                else
                    metric(i) = pos(2);
                end
            end
            [~,I] = sort(metric);
            obj.panels = obj.panels(I);
        end
        function updateDivider(obj,varargin)
            temp = get(obj.panels,'units');
            set(obj.panels,'units',obj.units)
            set(obj.dividerH,'units',obj.units)
            pos = get(obj.panels,'position');
            if strcmp(obj.type,'horizontal')
                xcenter = (pos{1}(1)+pos{1}(3)+pos{2}(1))/2;
                x = xcenter - obj.pad/2;
                y = pos{1}(2);
                width = obj.pad;
                height = pos{1}(4);
            else
                ycenter = (pos{1}(2)+pos{1}(4)+pos{2}(2))/2;
                x = pos{1}(1);
                y = ycenter - obj.pad/2;
                width = pos{1}(3);
                height = obj.pad;
            end
            set(obj.dividerH,'position',[x,y,width,height])
            pointerBehavior.enterFcn = @obj.enterFcn;
            pointerBehavior.exitFcn = @obj.exitFcn;
            pointerBehavior.traverseFcn = [];
            iptSetPointerBehavior(obj.dividerH,pointerBehavior)
            for i = 1:numel(temp)
                set(obj.panels(i),'units',temp{i})
            end
        end
    end
    methods
        function obj = SplitPanel(panel1,panel2,type)
            % Input every panel to be split (must be part of same fig)
            if nargin == 0
                obj.parent_fig = figure;
                panel1 = uipanel(obj.parent_fig,'position',[0 0 0.5 1]);
                panel2 = uipanel(obj.parent_fig,'position',[0.5 0 0.5 1]);
                type = 'horizontal';
            end
            parent1 = Base.getParentFigure(panel1);
            parent2 = Base.getParentFigure(panel1);
            assert(isequal(parent1,parent2),'Panels need to share the same figure!')
            obj.parent_fig = parent1;
            iptPointerManager(obj.parent_fig)
            obj.panels = [panel1,panel2];
            obj.order_panels;
            addlistener(parent1,'ObjectBeingDestroyed',@(~,~)obj.delete);
            obj.dividerH = uipanel(get(obj.panels(1),'parent'),'position',[0,0,1,1],...
                'tag','Divider','deleteFcn',@(~,~)obj.delete,'bordertype','none');
            addlistener(panel1,'SizeChanged',@obj.updateDivider);
            addlistener(panel1,'LocationChanged',@obj.updateDivider);
            addlistener(panel2,'SizeChanged',@obj.updateDivider);
            addlistener(panel2,'LocationChanged',@obj.updateDivider);
            obj.type = type;
        end
        
        function clicked(obj,varargin)
            'clicked'
            iptPointerManager(obj.parent_fig,'disable');
            pos = obj.get_pos(obj.parent_fig,'CurrentPoint');
            obj.home = pos;
            obj.OldWindowButtonMotionFcn = get(obj.parent_fig,'WindowButtonMotionFcn');
            if isequal(@obj.buttonMotionFcn, obj.OldWindowButtonMotionFcn)
                obj.OldWindowButtonMotionFcn = [];
            end
            set(obj.parent_fig,'WindowButtonMotionFcn',@obj.buttonMotionFcn)
            obj.busy = false;
        end
        function unclicked(obj,varargin)
            'unclocked'
%             set(obj.parent_fig,'WindowButtonMotionFcn',obj.OldWindowButtonMotionFcn)
            set(obj.parent_fig,'WindowButtonMotionFcn',[])
            iptPointerManager(obj.parent_fig,'enable')
        end
        function buttonMotionFcn(obj,varargin)
            if ~obj.busy
                obj.busy = true;
            
            'movinfg'
                
%             if isempty(obj.OldWindowButtonDownFcn) || isempty(obj.OldWindowButtonUpFcn)
%                 'test'
%                 set(obj.parent_fig,'WindowButtonMotionFcn',obj.OldWindowButtonMotionFcn)
%                 iptPointerManager(obj.parent_fig,'enable')
%             end
                
            pos = obj.get_pos(obj.parent_fig,'CurrentPoint');
            delta = pos - obj.home;
            temp = get([obj.panels,obj.dividerH],'units');
            set([obj.panels,obj.dividerH],'units','pixels')
            if strcmp(obj.type,'horizontal')
                panelPos = get(obj.panels(1),'position');
                newPos1 = panelPos + [0 0 delta(1) 0];
                panelPos = get(obj.panels(2),'position');
                newPos2 = panelPos + [delta(1) 0 -delta(1) 0];
                panelPos = get(obj.dividerH,'position');
                newPos3 = panelPos + [delta(1) 0 0 0];
                if newPos1(3) > obj.pad*2 && newPos2(3) > obj.pad*2
                    set(obj.panels(1),'position',newPos1);
                    set(obj.panels(2),'position',newPos2);
                    set(obj.dividerH,'position',newPos3);
                    obj.home = pos;
                end
            else
                panelPos = get(obj.panels(1),'position');
                newPos1 = panelPos+[0 0 0 delta(2)];
                panelPos = get(obj.panels(2),'position');
                newPos2 = panelPos+[0 delta(2) 0 -delta(2)];
                panelPos = get(obj.dividerH,'position');
                newPos3 = panelPos + [0 delta(2) 0 0];
                if newPos1(4) > obj.pad*2 && newPos2(4) > obj.pad*2
                    set(obj.panels(1),'position',newPos1);
                    set(obj.panels(2),'position',newPos2);
                    set(obj.dividerH,'position',newPos3);
                    obj.home = pos;
                end
            end
            objects = [obj.panels,obj.dividerH];
            for i = 1:numel(temp)
                set(objects(i),'units',temp{i})
            end
            obj.busy = false;
            end
        end
        function enterFcn(obj,varargin)
            'enter'
            if strcmp(obj.type,'horizontal')
                set(obj.parent_fig,'pointer','right')
            else
                set(obj.parent_fig,'pointer','top')
            end
            obj.OldWindowButtonDownFcn = get(obj.parent_fig,'ButtonDownFcn');
            obj.OldWindowButtonUpFcn = get(obj.parent_fig,'WindowButtonUpFcn');
            set(obj.parent_fig,'WindowButtonDownFcn',@obj.clicked)
            set(obj.parent_fig,'WindowButtonUpFcn',@obj.unclicked)
        end
        function exitFcn(obj,varargin)
            set(obj.parent_fig,'WindowButtonDownFcn',obj.OldWindowButtonDownFcn)
            set(obj.parent_fig,'WindowButtonUpFcn',obj.OldWindowButtonUpFcn)
            obj.OldWindowButtonDownFcn = [];
            obj.OldWindowButtonUpFcn = [];
        end
        function set.type(obj,var)
            var = lower(var);
            possible = {'horizontal','vertical'};
            assert(ismember(var,possible),'The property "type" must be either "horizontal" or "vertical"');
            obj.type = var;
            obj.order_panels;
            obj.updateDivider;
        end
        function set.enable(obj,var)
            possible = {'on','off'};
            assert(ismember(var,possible),'The property "enable" must be either "on" or "off"');
            set(obj.dividerH,'visible',var) %#ok<*MCSUP>
            obj.enable = var;
        end
    end
    
end

