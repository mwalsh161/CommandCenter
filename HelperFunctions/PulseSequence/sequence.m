classdef sequence < handle
    %SEQUENCE Stores handle to the transition nodes as linked list, and has
    % methods to compile and visualize the sequence.
    %
    % Sequences initial condition is 0 at time 0.
    
    properties
        name;            % Name of sequence (used when saving)
        resolution = 2;  % ns
        minDuration = 10;% Minimum duration in ns
        channelOrder = channel.empty(0);     % Channel Order for edit
        repeat = 1;      % How to handle entire sequence
    end
    properties(SetAccess=private)
        StartNode;      % Use this as initial node
        editorH;        % Handle to GUI
    end
    properties(SetAccess=private,Hidden)
        allNodes = [];  % Used for saving and loading a sequence
    end

    methods(Static)
        function obj = loadobj(obj)
            obj.allNodes = [];
        end
    end
    methods
        function obj = sequence(name)
            obj.name = name;
            obj.StartNode = node(obj,[],'type','null');
        end
        
        function set.repeat(obj,val)
            assert(round(val) == val, 'Sequence repetition must be integer.');
            if val > 2^20 && val ~= Inf
                warning('Currently cannot support more than 2^20 repeats. Truncating to maximum.')
                val = 2^20;
            end
            obj.repeat = val;
        end

        function out = walkSequenceTree(obj,todo)
            % Breadth first walk
            % todo should take a node. Return values go into cell array
            out = {};
            Q = obj.StartNode.next;  % No need to include the root
            if iscell(todo)
                f = todo{1};
                inp = todo(2:end);
            else
                f = todo;
                inp = {};
            end
            while ~isempty(Q)
                n = Q(1);
                Q(1) = [];
                Q = [Q n.next];
                out{end+1} = f(n,inp{:});
            end
        end
        
        function chansOut = getSequenceChannels(obj)
            todo = @(n)n.data;
            channels = obj.walkSequenceTree(todo);
            chansOut = channel.empty(0);
            for i = 1:numel(channels)
                if isa(channels{i},'channel')&&~ismember(channels{i},chansOut)
                    chansOut(end+1) = channels{i};
                end
            end
        end
        
        function [loops,loopsNodes] = getSequenceLoops(obj)
            loops = {};   % { name,maxIter,..}
            loopsNodes = node.empty(0,2);
            loopStack = {}; % Holds var names that haven't ended yet
            nodes = obj.walkSequenceTree(@(n)n);
            nodes = [nodes{:}];
            % Get unordered list of loop starts, so that we can order them
            loopn = {};
            for i = 1:numel(nodes)
                if strcmpi(nodes(i).type,'start')
                    loopn(end+1:end+2) = {nodes(i).data,1};
                end
            end
            % Walk through tree evaluating times at loops=1
            obj.StartNode.t = 0;     % Always should be 0
            ts = cell2mat(obj.walkSequenceTree(@(curNode)curNode.processTime(loopn)));
            [~,I] = sort(ts);
            nodes = nodes(I);  % For this method to work, needs to be in order
            % Now that it is ordered, we can pair the loops
            for i = 1:numel(nodes)
                n = nodes(i);
                switch n.type
                    case 'start'
                        % loop var name
                        loopStack{end+1} = n;
                    case 'end'
                        % num iterations
                        assert(~isempty(loopStack),'Loop end without beginning!')
                        loops(end+1:end+2) = {loopStack{end}.data,n.data};
                        loopsNodes(end+1,:) = [loopStack{end},n];
                        loopStack(end) = [];
                end
            end
            assert(isempty(loopStack),sprintf('%i loops without end.',numel(loopStack)))
        end
        
        function ts = processSequenceN(obj,varargin)
            % Breadth first walk to evaluate times at loop(s) n
            % n should be cell array {loop var1, val1, var2, val2...}

            % Prepare loop info
            loops = obj.getSequenceLoops;
            if nargin < 2
                varargin = {};
            end
            % Initialize to beginning of all loops
            n = loops;
            n(2:2:end) = {1};
            % Go through and override with any user input
            assert(numel(varargin)/2==round(numel(varargin)/2),'n must have even number of elements')
            for i = 1:numel(varargin)/2
                varName = varargin{i*2-1};
                iters = varargin{i*2};
                map = strcmp(varName,n);
                assert(sum(map)==1,sprintf('Could not find loop name "%s" in loops.',varName))
                n{find(map)+1} = iters;
            end
            % Make sure n does not exceed max loop
            for i = 1:numel(n)/2
                varName = n{i*2-1}; % Go through var names in input n
                iters = n{i*2};
                pos = find(strcmp(varName,loops))+1;
                assert(iters <= loops{pos},sprintf('Loop %s exceeds maximum iterations.',varName))
            end

            % Walk through tree evaluating times
            obj.StartNode.t = 0;     % Always should be 0
            ts = cell2mat(obj.walkSequenceTree(@(curNode)curNode.processTime(n)));
        end
        
        function f = draw(obj,ax,varargin)
            % varargin piped to PROCESSSEQUENCEN
            % If ax is supplied, callbacks = false. Leave ax empty otherwise
            callbacks = true;
            if nargin == 1
                ax = [];
            end
            if ~isempty(ax)
                if isvalid(ax)
                    callbacks = false;
                else
                    error('Supplied axes invalid or deleted.')
                end
            end
            
            % Create GUI if callbacks
            if callbacks
                if isempty(obj.editorH)
                    f = figure('name',sprintf('PulseSequence: %s',obj.name),'menubar',...
                        'none','toolbar','figure','numbertitle','off','DeleteFcn',@(~,~)obj.close);
                    toolbar = findall(f,'tag','FigureToolBar');
                    toolbar_items = allchild(toolbar);
                    keep = {'Standard.SaveFigure','Exploration.ZoomOut','Exploration.ZoomIn',...
                        'Exploration.Pan','Exploration.DataCursor'};
                    for i = 1:numel(toolbar_items)
                        if ~sum(strcmp(toolbar_items(i).Tag,keep))
                            delete(toolbar_items(i))
                        end
                    end
                    save = findall(toolbar_items,'tag','Standard.SaveFigure');
                    save.ClickedCallback = @(~,~)obj.save;
                    iptPointerManager(f);
                    ax = axes;
                    obj.editorH = f;
                    c = uicontextmenu(f);
                    uimenu(c,'Label','Add Channel','Callback',@(~,~)obj.newChannel)
                    uimenu(c,'Label','Channel Order','Callback',@(~,~)obj.editChannelOrder)
                    ax.UIContextMenu = c;
                else
                    ax = findall(obj.editorH,'type','axes');
                    cla(ax)
                end
            end
            hold(ax,'on')
            % Position channels
            channels = obj.getSequenceChannels;
            assert(numel(channels) <= numel(obj.channelOrder),'channelOrder is not complete.')
            assert(isa(channels,'channel'),'channelOrder should be of type channel.')
            channels = obj.channelOrder;
            
            for i = 1:numel(channels)
                channels(i).pltOffset = 1.5*(i-1);
            end
            if isempty(channels)
                set(ax,'ylim',[0 1],'YTick',0.5,...
                    'YTickLabel','No Channels')
            else
                set(ax,'ylim',[-0.5 1.5*i],'YTick',(0:numel(channels)-1)*1.5,...
                    'YTickLabel',{channels.label})
            end
            ts = obj.processSequenceN(varargin{:});
            maxT = max(ts)*1.1;
            minT = min([0 ts]);

            if isempty(maxT) || maxT == 0
                maxT = 1;
            end
            
            % Determine best units (default is ns)
            div = 1;
            ax.UserData = 'ns';
            xlabel(ax,sprintf('Time (ns)\nThis does not include channel delays.'))
            if maxT > 1e3
                xlabel(ax,sprintf('Time (us)\nThis does not include channel delays.'))
                ax.UserData = 'us';
                div = 1e3;
            elseif maxT > 1e6
                xlabel(ax,sprintf('Time (ms)\nThis does not include channel delays.'))
                ax.UserData = 'ms';
                div = 1e6;
            end
            set(ax,'xlim',[minT maxT]/div)
            
            % Render
            obj.StartNode.plotNode(ax,obj,callbacks);
            obj.walkSequenceTree(@(n)n.plotNode(ax,obj,callbacks));
            % Connect lines
            for i = 1:numel(channels)
                channels(i).patch(ax,maxT,obj);
            end
            % Put loops ontop
            uistack(findobj(ax,'tag','loop'),'top')
            % Fix units to be more readable (plotNode/evaluateTime is always ns
            lines = findobj(ax,'type','line');
            labels = findobj(ax,'type','text');
            for i = 1:numel(lines)
                if strcmp(lines(i).Tag,'loop') % Have to shift loop, not scale to preserve appearance
                    lines(i).XData = lines(i).XData - lines(i).XData(1) + lines(i).XData(1)/div;
                else
                    lines(i).XData = lines(i).XData/div;
                end
            end
            for i = 1:numel(labels)
                labels(i).Position(1) = labels(i).Position(1)/div;
            end
            % Highlight active
            if ~isempty(guidata(ax))
                n = guidata(ax);
                n.highlight(true)
            end
        end
        function newChannel(obj)
            temp = newChannel;
            if ~isempty(temp)
                obj.channelOrder(end+1) = temp;
                obj.draw;
            end
        end
        function editChannel(obj,chan)
            newChannel(chan);
            obj.draw;
        end
        function deleteChannel(obj,chan)
            function n = todo(n,chan)
                if n.data==chan
                    delete(n);
                end
            end
            obj.walkSequenceTree({@todo,chan});
            obj.channelOrder(obj.channelOrder==chan) = [];
            delete(chan)
            obj.draw;
        end
        function editChannelOrder(obj)
            [~,newOrder] = reorderer({obj.channelOrder.label});
            newOrder = obj.channelOrder(newOrder);
            if ~isequal(obj.channelOrder,newOrder)
                obj.channelOrder = newOrder;
                obj.draw;
            end
        end
        function close(obj)
            f = obj.editorH;
            obj.editorH = [];
            delete(f)
        end

        function save(obj,PathName,FileName)
            if nargin < 2
                [FileName,PathName] = uiputfile({'*.mat','Pulse Sequence';'*.png','Image'},'Save Sequence',obj.name);
            end
            if ~PathName
                return
            end
            [~,~,ext] = fileparts(FileName);
            assert(boolean(sum(strcmp(ext,{'.mat','.png'}))),'Only supports .mat and .png')
            if strcmp(ext,'.png')
                assert(~isempty(obj.editorH)&&isobject(obj.editorH) && isvalid(obj.editorH),'No valid figure.')
                saveas(obj.editorH,fullfile(PathName,FileName))
                return
            end
            obj.allNodes = obj.walkSequenceTree(@(n)n);
            redraw = false;
            if ~isempty(obj.editorH) && isvalid(obj.editorH)
                redraw = true;
                delete(obj.editorH);
            end
            seq = obj;  % Give a better name
            save(fullfile(PathName,FileName),'seq')
            obj.allNodes = [];
            if redraw
                obj.draw;
            end
        end
        function [seq,loc,tadd] = flattenTree(obj,tadd,start,loopStart,loopCounters,loops,nsMaster)
            % Recursive function. Call without arguments
            % Walk through tree in special way to flatten dependent loops
            % Return ordered list of structures with the time value and the
            % node
            % This requires walking through the tree the number of times of
            % any dependent loops and sorting in time
            % DO NOT edit sequence tree while this executes (no safeguards).
            if nargin < 2
                [loopCounters,loops] = obj.getSequenceLoops;
                loopCounters(2:2:end) = {1};
                nsMaster = obj.walkSequenceTree(@(n)n); % This order of nodes shouldnt change!
                nsMaster = [nsMaster{:}];
                ts = obj.processSequenceN(loopCounters{:});
                [~,I] = sort(ts);
                ns = nsMaster(I);  % Ordered list of nodes
                start = ns(1);  % Node to start with
                tadd = 0;
                loopStart = obj.StartNode;
                seq = struct('t',0,'node',obj.StartNode);
            else
                seq = struct('t',{},'node',{});
            end
            ts = obj.processSequenceN(loopCounters{:});
            [~,I] = sort(ts);
            ns = nsMaster(I);  % Ordered list of nodes
            % Find start node
            loc = find(ismember(ns,start));
            tsub = loopStart.t;
            while loc <= length(ns)
                % Get all nodes until next dependent loop
                currentNode = ns(loc);
                % getSequenceLoops already checks for loop integrity, no need to do it here
                loc = loc + 1;
                % Determine if dependent loop or not
                temp = {ns.dependent};
                temp(cellfun(@isempty,temp))=[];
                dependentVars = {};
                for i = 1:numel(temp)
                    dependentVars = [dependentVars temp{i}];
                end
                action = 'continue';  % Default to this for action and non-dependent loops
                switch currentNode.type
                    case 'start'
                        if ismember(currentNode.data,dependentVars)
                            action = currentNode.type;
                        end
                    case 'end'
                        % Find in loops, to determine starting loop node
                        row = find(currentNode==loops(:,2));
                        if ismember(loops(row,1).data,dependentVars)
                            action = currentNode.type;
                        end
                end
                % Now, do appropriate thing
                switch action
                    case 'continue'
                        seq(end+1) = struct('t',currentNode.t+tadd-tsub,'node',currentNode);
                    case 'start'
                        [subseq,loc,tadd] = obj.flattenTree(currentNode.t+tadd-tsub,ns(loc),currentNode,loopCounters,loops,nsMaster);
                        seq = [seq subseq];
                    case 'end'
                        i = find(cellfun(@(x)isequal(x,loopStart.data),loopCounters));
                        iter = loopCounters{i+1};
                        tadd = currentNode.t+tadd-tsub;
                        if iter >= currentNode.data
                            return
                        else
                            % Override next loc to return to begin of loop
                            % and increment loopCounter
                            loopCounters{i+1} = iter + 1;
                            ts = obj.processSequenceN(loopCounters{:});
                            [~,I] = sort(ts);
                            ns = nsMaster(I);  % Ordered list of nodes
                            loc = find(ismember(ns,start));
                        end
                end
            end
            
        end
        function [instructionSet,seqOut,instInfo,time] = compile(obj,overrideMinDuration, defaultLines_)
            % repeat puts a loop around the full thing. If Inf, a branch
            % statement is used instead. If more than a single command can
            % handle, nested loops will be used
            % First and last instruction create mandatory pause of at least
            % 12.5 ns between repeats
            %   The last instruction is given default of obj.minDurration
            % If overrideMinDuration, the compiler will make sure all
            %   instructions are atleast minduration, and fix and warn you
            %   if not.
            if nargin < 2
                overrideMinDuration = false;
                defaultLines_ = zeros(1,24);
            end
            if nargin < 2
                overrideMinDuration = false;
            end
            
            chans = obj.getSequenceChannels;
            
            assert(numel(defaultLines_) <= 24 && length(defaultLines_) == numel(defaultLines_), 'defaultLines_ must be a vector with length less than 24 inclusive.');
            
            defaultLines = zeros(1,24);
            defaultLines(1:numel(defaultLines_)) = defaultLines_;  % In case defaultLines_ is a column vector or has fewer elemeents
            defaultLines([chans.hardware] + 1) = 0;                % Any channel that is used should start off. Turned zero indexing into one indexing.
            defaultLines = fliplr(defaultLines);                   % Little endian.
            
            assert(numel(chans)==numel(unique([chans.hardware])),'Channels have repeated hardware lines.')
            % Add in channel offsets and apply resolution (should help reduce number of instructions)
            offsets = reshape([chans.offset],2,[]);
            maxOffset = max(offsets(1,:)); % This could probably be done better
            minOffset = min(offsets(1,:));
            seq = obj.flattenTree;  % Irons out dependent loops and organizes
            % Address any negative times
            lowestT = min([seq.t]);
            if lowestT < 0
                % Subtract lowestT from only children of StartNode, re-flatten then undo
                for i = 1:length(obj.StartNode.next)
                    obj.StartNode.next(i).delta = obj.StartNode.next(i).delta - lowestT;
                end
                seq = obj.flattenTree;
                for i = 1:length(obj.StartNode.next)
                    obj.StartNode.next(i).delta = obj.StartNode.next(i).delta + lowestT;
                end
            end
            for i = 1:numel(seq)
                switch seq(i).node.type
                    case 'transition'
                        seq(i).t = seq(i).t - seq(i).node.data.offset(1);
                    case {'start','null'} % In case there are negative offsets...
                        seq(i).t = seq(i).t - maxOffset;
                    case 'end'
                        seq(i).t = seq(i).t - minOffset;
                end
                seq(i).t = round(seq(i).t/obj.resolution)*obj.resolution;
            end
            % Reorder in case an offset changed the order
            % Should add check to see if loop start changes logical order
            [~,I] = sort([seq.t]);
            seq = seq(I);
            seqOut = seq;
            % First, go through seq and determine groups of flags, their dt
            % and most significant node type. Also check for multiple loops
            % in one flag (cannot do that).
            assert(strcmp(seq(1).node.type,'null'),'The first node in time is not the null node. This means there must be a negative delta set which orders another node before the null node!')
            instInfo = struct('flag',defaultLines,'dt',seq(2).t - seq(1).t,'msn',seq(1).node,'notes',''); % msn = most significant node
            seq(1) = [];
            while ~isempty(seq)
                notes = {};  % Use for warnings 'name:data,...'
                I = find(seq(1).t==[seq.t]);  % This is a bit slow since the list is ordered, but meh.
                active = seq(I);
                seq(I) = [];  % Pop from list
                if isempty(seq) % Last instruction should just be as short as possible
                    dt = obj.minDuration;
                else
                    dt = seq(1).t - active(1).t; % All active should have same t
                end
                active = [active.node];
                chans = [];
                types = struct('transition',node.empty(0),...
                                    'start',node.empty(0),...
                                      'end',node.empty(0)); % Tally number of each type
                for i = 1:numel(active)
                    types.(active(i).type)(end+1) = active(i);
                    if isa(active(i).data,'channel')
                        % If for somereason two of the same, then remove it
                        rmv = find(active(i).data.hardware==chans);
                        if isempty(rmv)
                            chans(end+1) = active(i).data.hardware; % hardware indexed from 0 (from the right)
                        else
                            chans(rmv) = [];
                        end
                    end
                end
                assert(isempty(types.start)||isempty(types.end),'Cannot have both start and end of loop at same time.')
                assert(length(types.start)<2&&length(types.end)<2,'Cannot have multiple starts or ends of loops at same time.')
                if ~isempty(types.end)
                    msn = types.end;
                elseif ~isempty(types.start)
                    msn = types.start;
                elseif ~isempty(types.transition)
                    msn = types.transition(1); % Doesn't matter which one we choose...
                else
                    error('No type found!!')
                end
                if dt < obj.minDuration && overrideMinDuration
                    instNum = length(instInfo); % no plus 1, because we remove the first instruction immediately after this loop
                    warning('Instruction %i of length %i ns was extended to min duration (%i ns)',instNum,dt,obj.minDuration)
                    notes{end+1} = sprintf('dt:%i',dt);
                    dt = obj.minDuration;
                end
                newflag = instInfo(end).flag;
                newflag(end-chans) = double(not(newflag(end-chans)));
                newinstInfo.flag = newflag;
                newinstInfo.dt = dt;
                newinstInfo.msn = msn;
                newinstInfo.notes = strjoin(notes,',');
                instInfo(end+1) = newinstInfo;
            end
            % The first instInfo useful only for starting flags, don't need
            % it anymore unless we want to include any 0 flags at beginning
            if instInfo(1).dt == 0
                instInfo(1) = [];
            end
            % If last instruction is END loop, append one more instruction of all off
            if strcmp(instInfo(end).msn.type,'end')
                newinstInfo.flag = zeros(1,24);
                newinstInfo.dt = obj.minDuration;
                newinstInfo.msn = node.empty(0);  % Shouldn't be used
                instInfo(end+1) = newinstInfo;
            end
            % Create instructions
            [~,loops] = obj.getSequenceLoops;
            
            instructionSet = cell(length(instInfo),1);
            % Take care of first instruction depending on repeat
            append = '';
            indent = 'Start: ';
            if obj.repeat > 1 && obj.repeat < Inf && ~strcmp(instInfo(1).msn.type,'start')
                % If the first instruction is a loop as well, we will have
                % to add the main loop at the very end by prepending
                append = sprintf(', LOOP, %i // main loop',obj.repeat);
            end
            % Take care of middle instructions
            for i = 1:length(instInfo)-1
                notes = {};
                switch instInfo(i).msn.type
                    case 'transition'
                        if i > 1  % First instruction append is set above
                            append = '';
                        end
                    case 'start'
                        row = find(instInfo(i).msn==loops(:,1));
                        nloops = loops(row,2).data;
                        append = sprintf(', LOOP, %i',nloops);
                        notes{end+1} = sprintf('loop name: %s',instInfo(i).msn.data);
                    case 'end'
                        row = find(instInfo(i).msn==loops(:,2));
                        loopName = loops(row,1).data;
                        append = ', END_LOOP';
                        notes{end+1} = sprintf('loop name: %s',loopName);
                end
                if ~isempty(instInfo(i).notes)
                    notes{end+1} = instInfo(i).notes;
                end
                % Format notes
                if isempty(notes)
                    notes = '';
                else
                    notes = sprintf('// %s',strjoin(notes,','));
                end
                instructionSet{i} = sprintf('%s0b %s, %0.2f ns%s%s',indent,num2str(instInfo(i).flag,'%i'),instInfo(i).dt,append,notes);
                indent = '       ';  % Just to align nicely with the Start
            end
            % Take care of last instruction depending on repeat
            if obj.repeat == Inf
                append = sprintf(', BRANCH, Start');
            elseif obj.repeat > 1
                append = ', END_LOOP // main loop';
            else
                append = '';
            end
            assert(length(instructionSet)>1,'Somehow ended up with only one instruction! Does not make sense.');
            if length(instructionSet)==2
                i = 1; % Because for loop above would have set this to []
            end
            instructionSet{i+1} = sprintf('%s0b %s, %0.2f ns%s',indent,num2str(instInfo(i+1).flag,'%i'),instInfo(i+1).dt,append);
            instructionSet{end+1} = sprintf('%s0x000000, 100ms',indent);
            instructionSet{end+1} = sprintf('%sSTOP',indent);
            if obj.repeat > 1 && obj.repeat < Inf && strcmp(instInfo(1).msn.type,'start')
                % If the first instruction is a loop as well, we will have
                % to add the main loop at the very end by prepending
                append = sprintf(', LOOP, %i // main loop',obj.repeat);
                instructionSet = [{sprintf('Main:  0b %s, %0.2f ns%s',num2str(zeros(1,length(instInfo(1).flag)),'%i'),obj.minDuration,append)}; instructionSet];
            end
            assert(numel(instructionSet) <= 4096,...
                sprintf('Can only handle 4096 instructions, have %i currently.',numel(instructionSet)))
            
            % Calculate expected time for this sequence to take.
            N = length(seqOut);
            times = NaN(1,N);

            for ii = 1:N    % Iterate through every node in the sequence (probably could convert to array function but meh).
                switch seqOut(ii).node.units
                    case 'ns'
                        times(ii) = seqOut(ii).t / 1e9;
                    case 'us'
                        times(ii) = seqOut(ii).t / 1e6;
                    case 'ms'
                        times(ii) = seqOut(ii).t / 1e3;
                    otherwise
                        error(['Units ' num2str(seqOut(ii).node.units) ' not recognized.'])
                end
            end

            time = (max(times) - min(times)) * obj.repeat;  % Multiply time difference between first and last instructions by the number of repeats.
        end
        
        function simulate(obj,seq,ax)
            if nargin < 2
                f = figure('name','Simulation');
                ax = axes('parent',f);
                seq = obj.flattenTree;
            elseif nargin < 3
                f = figure('name','Simulation');
                ax = axes('parent',f);
            end
            hold(ax,'on')
            tend = seq(end).t*1.1;
            set(ax,'xlim',[0 tend]);
            % seq should be an ordered (by time) struct with properties t and node
            for i = 1:numel(seq)
                n = seq(i).node;
                switch n.type
                    case 'transition'
                        y = [0 1] + n.data.pltOffset;
                        plot(ax,[1 1]*seq(i).t,y,'color',n.data.color,'linewidth',2,'tag',n.data.label);
                    case {'start', 'end'}
                        y = get(ax,'ylim');
                        y = y + [1 -1]*0.25;
                        y = linspace(y(1),y(2),100);
                        x = (y-mean(y)).^2;
                        x = x*0.05*diff(get(ax,'xlim'))/abs((max(x)-min(x)));
                        if n.type(1)=='s' % start
                            x = seq(i).t + x;
                            text(min(x),max(y),n.data,'parent',ax)
                        else              % end
                            x = seq(i).t - x;
                            text(max(x),max(y),sprintf('%i',n.data),'parent',ax)
                        end
                        plot(ax,x,y,'color','k','linewidth',2,'tag','loop');
                end
            end
            chans = obj.channelOrder;
            for i = 1:numel(chans)
                chans(i).patch(ax,tend,obj,false);
            end
        end
    end
    
end

