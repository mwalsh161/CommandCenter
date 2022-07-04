classdef UIscrollPanel < handle
    
    properties
        base                        % Handle to base panel with Title.
        content                     % Handle to panel with content (the one that moves). There should only be panels as children, or errors will occur.
        sld                         % Handle to slider
        ResizeCallback              % ResizeCallback for content panel (called after local resize)
    end
    properties(SetAccess=private,SetObservable)
        minimized = false;          % Minimized. Used internally to know what to do when base clicked.
    end
    properties(Access=private)
        home                        % Last location of content panel.
        minimized_pos               % Last position before minimized (characters)
        scroll_listener             % Listen to scroll wheel
    end
    properties(SetAccess=immutable,Hidden)
        minimizable                 % Determine if allowed to be minimized
        concealer                   % Handle to concealer panel to preserve asthetics of base panel. Do not adjust size of this manually!
    end
    methods
        % Constructor
        function [ obj ] = UIscrollPanel( base, minimizable )
            %UISCROLLPANEL Create scroll panel out of uipanel
            %   There are three panels involved. Children of the input panel are moved
            %   to a new panel that has no boundry lines that is placed inside the
            %   original panel. There is a third panel that masks the new panel.
            %
            %   uipanel <-- uipanel_concealer <-- uipanel_content
            if nargin < 2
                minimizable = true;
            end
            obj.minimizable = minimizable;
            
%             children = allchild(base);
            children = base.Children;
            tag = get(base,'tag');
            tempBase = get(base,'units');
            set(base,'tag',[tag '_Base'],'units','characters');
            set(base,'deleteFcn',@(~,~)obj.delete)
            set(base,'sizeChangedFcn',@obj.resizeBase)
            fig = Base.getParentFigure(base);
            iptPointerManager(fig)
            if obj.minimizable
                set(base,'buttonDownFcn',@obj.clicked)
                % Configure pointer
                iptSetPointerBehavior(base,@obj.pointerHover)
            end
            obj.base = base;
            pos = get(obj.base,'position');
            
            % Make concealer (do not resize manually!)
            obj.concealer = uipanel(base,'tag',[tag '_concealer'],'BorderType','None',...
                'units','characters','position',[0 0 pos(3) pos(4)-1],'visible','off');
            iptSetPointerBehavior(obj.concealer,struct('enterFcn',@obj.pointerEnter,'exitFcn',@obj.pointerExit,'traverseFcn',''));
            
            % Make content
            obj.content = uipanel(obj.concealer,'tag',tag,'BorderType','none',...
                'units','characters','position',[0 0 pos(3) pos(4)-1],...
                'sizeChangedFcn',@obj.local_resizeCallback,'visible','off');
            obj.home = get(obj.content,'position');
            
            % Move children
            set(children,'parent',obj.content)
            
            % Add scrollbar to original uipanel
            obj.sld = uicontrol(obj.base,'Style','slider',...
                'min',-1,'max',0,'value',0,...
                'units','characters',...
                'SliderStep',[.01 .1],...
                'position',[pos(3)-3.5 0 3 pos(4)-1.5],...
                'callback',@obj.SlideCallBack,'visible','off');
            iptSetPointerBehavior(obj.sld,@(hObj,~)set(hObj,'pointer','arrow'))
            % Fix width now that we have hte slider
            obj.concealer.Position(3) = pos(3) - obj.sld.Position(3);
            obj.content.Position(3) = pos(3) - obj.sld.Position(3);
            set(base,'units',tempBase)
            obj.local_resizeCallback;
            obj.scroll_listener = addlistener(fig,'WindowScrollWheel',@obj.scroll);
            obj.scroll_listener.Enabled = false;
            set([obj.concealer, obj.content],'visible','on'); % obj.sld controled in callback
        end
        function delete(obj)
            delete(obj.scroll_listener);
        end
        function pointerEnter(obj,hObj,eventdata)
            set(hObj,'pointer','arrow')
            obj.scroll_listener.Enabled = true;
        end
        function pointerExit(obj,hObj,eventdata)
            obj.scroll_listener.Enabled = false;
        end
        function scroll(obj,hObj,eventdata)
            dir = -sign(eventdata.VerticalScrollCount);
            step = obj.sld.SliderStep(1)*(obj.sld.Max-obj.sld.Min); % Small step size
            for i = 1:abs(eventdata.VerticalScrollCount)
                obj.sld.Value = min(0,max(obj.sld.Min,obj.sld.Value + dir*step));
                obj.SlideCallBack;
            end
        end
        function pointerHover(obj,hObj,currentPoint)
            pos = getpixelposition(obj.base,true);
            if currentPoint(2) > pos(2)+pos(4)-50
                set(hObj,'pointer','hand')
            end
        end
        function clicked(obj,hObj,mouse)
            pos = getpixelposition(hObj,true);
            fig = Base.getParentFigure(hObj);
            set(fig,'units','pixels')
            mousePos = get(fig,'CurrentPoint');
            % Allow top 10 pixels
            if mousePos(2) > pos(2)+pos(4)-50
                if obj.minimized
                    obj.maximize;
                else
                    obj.minimize;
                end
            end
        end
        function maximize(obj)
            temp = get(obj.base,'units');
            set(obj.base,'units','characters');
            p = get(obj.base,'position');
            h = obj.minimized_pos(4);
            set(obj.base,'position',[p(1) p(2)-h+1.5 p(3) h]);
            set(obj.base,'units',temp)
            set(obj.concealer,'visible','on')
            drawnow;
            obj.local_resizeCallback   % Use this to show slider if need be
            obj.minimized = false;
        end
        function minimize(obj)
            set([obj.sld,obj.concealer],'visible','off')
            temp = get(obj.base,'units');
            set(obj.base,'units','characters');
            p = get(obj.base,'position');
            obj.minimized_pos = p;
            set(obj.base,'position',[p(1) p(2)+p(4)-1.5 p(3) 1.5]);
            set(obj.base,'units',temp)
            obj.minimized = true;
        end
        % Function to adjust concealer on base size changing (must change
        % concealer size to match, then update slider
        function resizeBase(obj,varargin)
            % Prepare units
            tempBase = get(obj.base,'units');
            tempConcealer = get(obj.concealer,'units');
            tempSld = get(obj.sld,'units');
            set([obj.base,obj.concealer,obj.sld],'units','characters')
            % Perform the update
            pos = get(obj.base,'position');
            set(obj.concealer,'position',[0 0 pos(3) max(0,pos(4)-1)])
            set(obj.sld,'position',[pos(3)-3.5 0 3 max(0,pos(4)-1.5)])
            % Restore previous units
            set(obj.base,'units',tempBase)
            set(obj.concealer,'units',tempConcealer)
            set(obj.sld,'units',tempSld)
            obj.local_resizeCallback;
        end
         
        % Resize function to adjust slider and content panel. ResizeCallback called after this.
        function local_resizeCallback(obj,varargin)
            % How much is hanging over??
            tempContent = get(obj.content,'units');
            tempConcealer = get(obj.concealer,'units');
            set([obj.content,obj.concealer],'units','characters');
            posContent = get(obj.content,'position');
            posConcealer = get(obj.concealer,'position');
            delta = (posContent(4)-posConcealer(4));
            set(obj.content,'position',[posContent(1) -delta posContent(3) posContent(4)]);
            drawnow;
            obj.home = get(obj.content,'position');
            if delta > 1e-5  % 1e-5 just to account for slight rounding issues, I think?
                set(obj.sld,'visible','on')
                set(obj.sld,'sliderstep',[3 6]/max(6,delta))
                set(obj.sld,'min',-delta,'value',0)
            else
                set(obj.sld,'visible','off')
            end
            set(obj.content,'units',tempContent)
            set(obj.concealer,'units',tempConcealer)
            if ~isempty(obj.ResizeCallback)
                if iscell(obj.ResizeCallback)
                    f = obj.ResizeCallback{1};
                    f(varargin{:},obj.ResizeCallback{2:end});
                else
                    obj.ResizeCallback(varargin{:})
                end
            end
        end
        % Callback for slider to move content panel.
        function SlideCallBack(obj,varargin)
            delta = get(obj.sld,'value');
            temp = get(obj.content,'sizeChangedFcn');
            set(obj.content,'sizeChangedFcn','');
            set(obj.content,'position',obj.home - [0 delta 0 0])
            set(obj.content,'sizeChangedFcn',temp);
            drawnow;
        end
        
        % Change the length by delta characters.
        %   Length is added at the bottom. Children moved up by delta.
        function addLength(obj,delta)
            children = allchild(obj.content);
            set(children,'units','characters');
            set(obj.content,'units','characters');
            ContentPos = get(obj.content,'position');
            full_size = get(obj.concealer,'position');
            if ContentPos(4)+delta < full_size(4)
                delta = full_size(4)-ContentPos(4);
            end
            for i = 1:numel(children)
                pos = get(children(i),'position');
                set(children(i),'position',pos+[0 delta 0 0]);
            end
            set(obj.content,'position',ContentPos+[0 0 0 delta]);
        end
        function addPanel(obj,newPanel,tag)
            set(newPanel,'units','characters');
            pos = get(newPanel,'position');
            posContent = get(obj.content,'position');
            panels = allchild(obj.content);
            set(panels,'units','characters')
            lengths = [];
            for i = 1:numel(panels)
                contents_pos = get(panels(i),'position');
                lengths(end+1) = contents_pos(2);
                lengths(end+1) = lengths(end) + contents_pos(4);
            end
            if isempty(lengths)
                % Top minus 1 character
                bottom = posContent(4)-1;
            else
                bottom = min(lengths);
            end
            if pos(3) > posContent(3)
                warning('newPanel is wider than content panel!')
            end
            % Add the necessary lenght, then add to the origin!
%             delta = bottom-pos(4)-0.25;
            delta = bottom-pos(4);
            if delta < 0
                obj.addLength(abs(delta))
                delta = 0;
            end
            set(newPanel,'parent',obj.content,'position',[pos(1) delta pos(3) pos(4)],...
                'tag',tag);
        end
        function removePanel(obj,panel_tag)
            panel = findall(obj.content,'tag',panel_tag);
            if isempty(panel)
                error('No panel with that tag!')
            elseif numel(panel) > 1
                error('Multiple panels with that tag!')
            end
            pos = get(panel,'position');
            delete(panel)
            obj.addLength(-pos(4))
        end
        function setMaximizedHeight(obj, height)
            obj.minimized_pos(4) = height;
        end
        function val = getMaximizedPos(obj)
            val = obj.minimized_pos;
        end
    end
end