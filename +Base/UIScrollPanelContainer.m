classdef UIScrollPanelContainer < handle
    %SCROLLPANELCONTAINER Manages vertical scroll panels
    
    properties(SetAccess=immutable)
        spacing = 5;                % Spacing between panels in pixels (from bottom of one to top of other)
        container                   % Containing panel
    end
    properties(SetAccess=private)
        children                    % Set of SplitPanels in container
    end
    properties(Access=private)
        listeners
    end
    
    methods(Access=private)
        function order_panels(obj)
            temp = get(obj.children,'units');
            set(obj.children,'units','pixels')
            metric = zeros(numel(obj.children),1);
            for i = 1:numel(obj.children)
                pos = obj.children(i).Position;
                metric(i) = pos(2);
            end
            [~,I] = sort(metric);
            obj.children = obj.children(I);
            for i = 1:numel(temp)
                set(obj.children(i),'units',temp{i})
            end
        end
    end
    methods
        function obj = UIScrollPanelContainer(panel, SplitPanels, spacing)
            % SplitPanels is an array, not cell array!
            % Spacing is in pixels
            obj.listeners =     addlistener(panel, 'ObjectBeingDestroyed',  @(~,~)obj.delete);
            obj.listeners(2) =  addlistener(panel, 'SizeChanged',           @obj.sizeChanged);
            obj.children = gobjects(0);
            for i = 1:numel(SplitPanels)
                if isprop(SplitPanels{i}, 'Type') && strcmp(SplitPanels{i}.Type, 'uipanel')
                    base = SplitPanels{i};
                else
                    base = SplitPanels{i}.base;
                end
                
%                 base.Tag
                
                assert(isequal(base.Parent, panel),'SplitPanels must be children of panel.')
                obj.listeners(end+1) = addlistener(base, 'SizeChanged',     @obj.arrange);
                obj.listeners(end+1) = addlistener(base, 'LocationChanged', @obj.arrange);
                obj.children(end+1) = base;
            end
            
            obj.container = panel;
            obj.spacing = spacing;
%             obj.order_panels;    % Order panels in increasing yposition
            obj.arrange;         % Spatially arrange panels
            obj.sizeChanged;
        end
        function delete(obj)
            delete(obj.listeners)
        end
        function listenersEnable(obj, tf)
            for ii = 1:length(obj.listeners)
                obj.listeners(ii).Enabled = tf;
            end
        end
        function arrange(obj,varargin)
            obj.listenersEnable(false);
            
            % Go through top to bottom and arrange them
            temp = get(obj.children,'units');
            set(obj.children,'units','pixels')
            
            xedge = obj.children(1).Position(1);
            width = obj.children(1).Position(3);
            edge =  obj.children(1).Position(2);
            for i = 2:numel(obj.children)
%                 obj.children(i).Tag
                top = edge - obj.spacing;
                bottom = top - obj.children(i).Position(4);
                obj.children(i).Position(1:3) = [xedge bottom width];
                edge = bottom;
            end
            
            for i = 1:numel(temp)
                set(obj.children(i),'units',temp{i})
            end
            
            obj.listenersEnable(true);
            
            drawnow
        end
        function sizeChanged(obj,varargin)
            obj.listenersEnable(false);
            
            items = [obj.children obj.container];
            temp = get(items,'units');
            set(items,'units','pixels')
            % Figure out how much space we have
            topPos = obj.children(1).Position;
            top = topPos(2)+topPos(4);
            containerPos = obj.container.Position;
            delta = containerPos(4) - top - obj.spacing*2;
            for i = 1:numel(obj.children)
                p = obj.children(i).Position(2);
                obj.children(i).Position(2) = p+delta;
            end
            for i = 1:numel(temp)
                set(items(i),'units',temp{i})
            end
            
            obj.listenersEnable(true);
            
            drawnow
        end
    end
    
end

