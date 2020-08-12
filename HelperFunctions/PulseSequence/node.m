classdef node < handle
    %NODE Stores info on a specific node, including timing, type, 
    % relationships and channel details.
    %
    % NODE(previousNode, channel[, ...])
    %
    % Types:
    %   transition - most common. transition to begin/end pulse
    %   start - begin loop
    %   end - end loop
    %   null - no function, used as t=0 (should only have one in a sequence)
    
    properties
        previous;           % Node object before this one
        delta = 0;          % Delta in units from previous (can be numeric or symbolic function)
        dependent = {};     % Name of loop vars as inputs to function for delta, in correct order
        units = 'ns';       % Units: ns, us, ms
        % Data for given type.
        %   transition: channel object
        %   start:      loop var name
        %   end:        num iterations
        %   null:       Not used
        data;
        type = 'transition';% Either transition or start or end
    end
    properties(SetAccess={?node})
        % Only other node instances should update this when previous set
        next = node.empty(0);    % Next node(s)
    end
    properties(Hidden,SetAccess={?sequence,?node,?channel})
        % Used for convenience when compiling
        t                   % Absolute time (ns always)
    end
    properties(Hidden,Constant)
        allowedUnits = {'ns','us','ms'};
        allowedTypes = {'transition','start','end','null'};
    end
    properties(Access={?node})
        lineH               % Handle to line in plot
    end
    
    methods(Static)
       function obj = loadobj(s)
           obj = node(s.previous,s.data,...
               'units',s.units,...
               'delta',s.delta,...
               'dependent',s.dependent,...
               'type',s.type);
       end
    end
    methods
        function obj = node(previous,data,varargin)
            % Property,value pairs
            assert(numel(varargin)/2==round(numel(varargin)/2),'Missing property/value pair.')
            % Put units first
            units_pos = strcmpi('units',varargin);
            units_pos(find(units_pos)+1) = 1; % Get property too
            varargin = [varargin(units_pos) varargin(~units_pos)];
            for i = 1:numel(varargin)/2
                obj.(lower(varargin{i*2-1})) = varargin{i*2};
            end
            obj.previous = previous;
            obj.data = data;
        end
        function s = saveobj(obj)
            s.previous = obj.previous;
            s.data = obj.data;
            s.units = obj.units;
            s.delta = obj.delta;
            s.dependent = obj.dependent;
            s.type = obj.type;
            % obj.next assigned automatically and will cause double loading
            % if saved
        end
        function delete(obj)
            % Take care of maintaining tree
            if isa(obj.previous,'node')
                obj.previous.next(ismember(obj.previous.next,obj)) = [];
            end
            nexts = obj.next;
            for i = 1:numel(nexts)
                nexts(i).previous = obj.previous;
            end
        end
        function set.type(obj,val)
            val = lower(val);
            assert(ismember(val,obj.allowedTypes),...
                'Type must be one of: %s',strjoin(obj.allowedTypes,', '))
            obj.type = val;
        end
        function set.units(obj,val)
            val = lower(val);
            if strcmp(val,obj.units) % "AbortSet"
                return
            end
            after = strcmp(val,obj.allowedUnits);
            assert(sum(after)==1,'Units must be one of: %s',...
                strjoin(obj.allowedUnits,', '))
            before = strcmp(obj.units,obj.allowedUnits);
            obj.units = val;
            % Convert resolution and delta
            vals = [1e-6,1e-3,1];
            m = vals(before)/vals(after);
            obj.delta = obj.delta*m;
        end
        function set.previous(obj,p)
            % Associate set pulse unless sequence (which is start pulse)
            if isa(p,'node')
                p.next(end+1) = obj;
            end
            % Deassociate old pulse (if there was one)
            if isa(obj.previous,'node')
                obj.previous.next(ismember(obj.previous.next,obj))=[];
            end
            obj.previous = p;
        end
        
        function t = processTime(obj,n)
            % n should be cell array {var1, val1, var2, val2...}
            % Will throw error if parent doesn't have t set
            % Does not include channel delay
            obj.units = 'ns';
            obj.previous.units = 'ns';
            assert(~isempty(obj.previous.t),'Previous object has no t yet.')
            if isnumeric(obj.delta)
                delta = obj.delta;
            else  % Function of loop iteration(s)
                inputs = {};  % Prepare inputs
                for i = 1:numel(obj.dependent)
                    pos = find(strcmp(obj.dependent{i},n))+1;
                    assert(~isempty(pos),sprintf('Could not find %s as loop label.',obj.dependent{i}))
                    inputs{end+1} = n{pos};
                end
                delta = double(obj.delta(inputs{:}));
            end
            obj.t = obj.previous.t + delta;
            t = obj.t;
        end
        
        % GUI Stuff and Callbacks
        function p = plotNode(obj,ax,seq,callbacks)
            % Returns handle to vertical line
            % Uses n = 1 for all loops
            
            % Optional arg to prevent callbacks
            if nargin < 4
                callbacks = true;
            end
            
            assert(~isempty(obj.t),'Times not evaluated yet!')
            p = [];
            switch obj.type
                case 'transition'
                    y = [0 1] + obj.data.pltOffset;
                    p = plot(ax,[1 1]*obj.t,y,'color',obj.data.color,'linewidth',2,'tag',obj.data.label,'UserData',obj);
                    if ~isempty(obj.dependent)
                        x = obj.t;
                        y = obj.data.pltOffset + 1.1;
                        txt = text(x,y,sprintf('f(%s)',strjoin(obj.dependent,',')),'parent',ax);
                        txt.Position(1) = x-txt.Extent(3)/2;  % Center
                    end
                case {'start', 'end'}
                    y = get(ax,'ylim');
                    y = y + [1 -1]*0.25;
                    y = linspace(y(1),y(2),100);
                    x = (y-mean(y)).^2;
                    x = x*0.05*diff(get(ax,'xlim'))/abs((max(x)-min(x)));
                    if obj.type(1)=='s' % start
                        x = obj.t + x;
                        text(min(x),max(y),obj.data,'parent',ax)
                    else                % end
                         x = obj.t - x;
                         text(max(x),max(y),sprintf('%i',obj.data),'parent',ax)
                    end
                    p = plot(ax,x,y,'color','k','linewidth',2,'tag','loop','UserData',obj);
                case 'null'
                    y = get(ax,'ylim');
                    % Don't use p here because we don't want callbacks
                    obj.lineH = plot(ax,[0 0],y,'color','k','tag','StartNode');
                    if callbacks
                        obj.lineH.UserData = obj;  % Easier for inspector callback
                    end
            end
            if ~isempty(p) && callbacks
                obj.lineH = p;
                set(p,'ButtonDownFcn',@(n,eventdata)n.UserData.highlight(true,eventdata));
                iptSetPointerBehavior(p,@(fig,~)set(fig,'pointer','hand'))
                c = uicontextmenu(ax.Parent);
                uimenu(c,'Label','Delete Node','Callback',@(~,~)obj.clearNode(seq));
                p.UIContextMenu = c;
            end
        end
        function clearNode(obj,seq)
            delete(obj)
            seq.draw;
        end
        function highlight(obj,state,eventdata)
            if ~isvalid(obj) % This avoids a bug when a node that is highlighted is cleared
                return
            end
            if nargin<3 || eventdata.Button==1 % Left click or called manually (no eventdata)
            if ~isempty(obj.lineH)&&isobject(obj.lineH)&&isvalid(obj.lineH)
                thisP = obj.lineH;
                prevP = obj.previous.lineH;
                if state
                    if ~isempty(guidata(thisP))
                        lastObj = guidata(thisP);
                        lastObj.highlight(false);
                    end
                    c = get(prevP,'color')+0.6; c(c>1)=1;
                    set(prevP,'color',c,'linewidth',4)
                    c = get(thisP,'color')+0.6; c(c>1)=1;
                    set(thisP,'color',c,'linewidth',4)
                    guidata(thisP,obj)
                    set(thisP,'ButtonDownFcn',@(n,eventdata)n.UserData.highlight(false,eventdata));
                    if nargin > 2   % Only do on click
                        inspector(obj)
                    end
                else
                    if strcmp(obj.type,'transition')
                        c = obj.data.color;
                    else
                        c = 'k';
                    end
                    set(thisP,'color',c,'linewidth',2);
                    if strcmp(obj.previous.type,'transition')
                        c = obj.previous.data.color;
                    else
                        c = 'k';
                    end
                    set(prevP,'color',c,'linewidth',2);
                    set(thisP,'ButtonDownFcn',@(n,eventdata)n.UserData.highlight(true,eventdata));
                    guidata(thisP,[])
                    if nargin > 2  % Only close if callback (user deselected it then)
                        try
                            close('inspector')
                        end
                    end
                end
               drawnow;
            end
            end
        end
    end
    
end
