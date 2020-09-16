
classdef channel < handle
    %UNTITLED Summary of this class goes here
    %   Stores offset locally as a pref so that it can change over
    %   different machines.
    
    properties
        label;          % Name for channel
        color = 'b';    % Display color
        offset = [0,0];     % [delay,transition] in units (this is stored in prefs by hardware channel, so it can be per computer)
        units = 'ns';   % units
        hardware=0;     % Hardware channel number (indexed from 0)
        counter='';     % NIDAQ in-line of counter object (only if this channel is its gate)
    end
    properties(Hidden)
        % For plotting in GUI
        pltOffset       % Offset for channel
    end
    properties(Hidden,Constant)
        allowedUnits = {'ns','us','ms'};
    end
    properties(Access=private)
        parentNodeSelection  % When making a new node, this is the parent
    end
    
    methods
        function obj = channel(label,varargin)
            % Property,value pairs - make sure units is first
            assert(numel(varargin)/2==round(numel(varargin)/2),'Missing property/value pair.')
            % Put units first
            units_pos = strcmpi('units',varargin);
            units_pos(find(units_pos)+1) = 1; % Get property too
            varargin = [varargin(units_pos) varargin(~units_pos)];
            for i = 1:numel(varargin)/2
                obj.(lower(varargin{i*2-1})) = varargin{i*2};
            end
            obj.label = label;
        end
        function set.offset(obj,val)
            assert(length(val)==2,'Offsets must be [delay,transition]!')
            assert(isnumeric(val),'Offsets must be numeric!')
            setpref(strrep(class(obj),'.','_'),sprintf('hardware%i',obj.hardware),val);
        end
        function val = get.offset(obj)
%             if ispref(strrep(class(obj),'.','_'),sprintf('hardware%i',obj.hardware))
%                 val = getpref(strrep(class(obj),'.','_'),sprintf('hardware%i',obj.hardware));
%             else
%                 warning('This computer does not have a this channel initialized. Setting offset to [0,0].')
%                 setpref(strrep(class(obj),'.','_'),sprintf('hardware%i',obj.hardware),[0,0]);
                val = [0,0];
%             end
        end
        function set.units(obj,val)
            after = strcmpi(val,obj.allowedUnits);
            assert(sum(after)==1,'Units must be one of: %s',strjoin(obj.allowedUnits,', '))
            before = strcmpi(obj.units,obj.allowedUnits);
            obj.units = val;
            % Convert resolution and delta
            vals = [1e-6,1e-3,1];
            m = vals(before)/vals(after);
            obj.offset = obj.offset*m; %#ok<*MCSUP>
        end
        
        % GUI Stuff and Callbacks
        function patch(obj,ax,tend,seq,callbacks)
            if nargin < 5
                callbacks = true;
            end
            transitions = findobj(ax,'tag',obj.label); % Filter by name
            rm = false(size(transitions));
            for i = 1:length(transitions)              % Then check node channel in case two have same name
                if transitions(i).UserData.data ~= obj
                    rm(i) = true;
                end
            end
            transitions(rm) = [];
            if ~isempty(transitions)
                transitions = get(transitions,'xdata');
                if ~iscell(transitions)  % Case of one transition
                    transitions = {transitions};
                end
                transitions = cell2mat(cellfun(@(a)a(1),transitions,'UniformOutput',false));
                transitions = sort(transitions);
            else
                transitions = [];
            end
            % Prepare beginning/end
            transitions = [0; transitions; tend];
            state = 0;
            for i = 2:numel(transitions)
                start = transitions(i-1);
                stop = transitions(i);
                y = [0 0] + obj.pltOffset + state;
                x = [start stop];
                p = plot(ax,x,y,'color',obj.color,'linewidth',2); % No tag here, so updating will be the same
                state = mod(state + 1, 2);
                if callbacks
                    set(p,'ButtonDownFcn',@(~,eventdata)obj.newNode(ax,seq,eventdata))
                    c = uicontextmenu(ax.Parent);
                    uimenu(c,'Label','Edit Channel','Callback',@(~,~)seq.editChannel(obj))
                    uimenu(c,'Label','Delete Channel','Callback',@(~,~)seq.deleteChannel(obj))
                    uimenu(c,'Label','Start Loop','Callback',@(~,~)obj.beginNewLoop(ax,seq))
                    p.UIContextMenu = c;
                end
            end
        end
        
        function beginNewLoop(obj,ax,seq)
            options = findobj(ax,'type','line');
            options(cellfun(@(i)not(isempty(i)),{options.Tag})) = [];
            set(options,'ButtonDownFcn',@(hObj,event)obj.newLoopClick(hObj,event,ax,seq,[]));
            title(ax,'Select Starting Position!')
        end
        function newLoopClick(obj,hObj,event,ax,seq,temp)
            % temp should be the loop start, if second round. else empty
            if isempty(temp)
                i = 1;
            else
                i = 2;
            end
            dat = {'Place Holder',2};
            type = {'start','end'};
            obj.parentNodeSelection = [];
            t = get(ax,'CurrentPoint');
            t = t(1,1);
            options = findobj(ax,'type','line');
            options(cellfun(@isempty,{options.Tag})) = [];
            set(options,'ButtonDownFcn',@(hObj,~)obj.selectParentNode(hObj,ax));
            plot(ax,[t t],ax.YLim,'--k')
            title(ax,'Select parent node!')
            uiwait(ax.Parent)
            if ~isvalid(ax)  % Means they closed window, so just abort
                delete(temp)
                return
            end
            % Convert to ns
            if strcmpi(ax.UserData,'ms')
                t = t*1e6;
            elseif strcmpi(ax.UserData,'us')
                t = t*1e3;
            end
            delta = t - obj.parentNodeSelection.t;  % We know this will be the t used in the plot (even if something changed after plot)
            try
                temp = node(obj.parentNodeSelection,dat{i},'delta',delta,'units','ns','type',type{i});
            catch err
                delete(temp)
                rethrow(err)
            end
            if i==1
                options = findobj(ax,'type','line');
                options(cellfun(@(i)not(isempty(i)),{options.Tag})) = [];
                set(options,'ButtonDownFcn',@(hObj,event)obj.newLoopClick(hObj,event,ax,seq,temp));
                title(ax,'Select Loop End')
            else
                seq.draw; % This will also reset ButtonDownFcns
            end
        end
        function newNode(obj,ax,seq,eventdata)
            if eventdata.Button==1 % Left click
                obj.parentNodeSelection = [];
                t = get(ax,'CurrentPoint');
                t = t(1,1);
                % Convert to ns
                if strcmpi(ax.UserData,'ms')
                    t = t*1e6;
                elseif strcmpi(ax.UserData,'us')
                    t = t*1e3;
                end
                options = findobj(ax,'type','line');
                options(cellfun(@isempty,{options.Tag})) = [];
                set(options,'ButtonDownFcn',@(hObj,~)obj.selectParentNode(hObj,ax));
                title(ax,'Select parent node!')
                uiwait(ax.Parent)
                if ~isvalid(ax)  % Means they closed window, so just abort
                    return
                end
                delta = t - obj.parentNodeSelection.t;  % We know this will be the t used in the plot (even if something changed after plot)
                node(obj.parentNodeSelection,obj,'delta',delta,'units','ns');
                seq.draw; % This will also reset ButtonDownFcns
            end
        end
        function selectParentNode(obj,hObj,ax)
            title(ax,'')
            obj.parentNodeSelection = hObj.UserData;
            uiresume(ax.Parent)
        end
    end
    
end
