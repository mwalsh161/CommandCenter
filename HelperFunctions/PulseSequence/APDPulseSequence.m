classdef APDPulseSequence < handle
    %APDPULSESEQUENCE Summary of this class goes here
    %   Currently only supports one counter line
    
    properties
        ni              % NIDAQ driver
        pb              % PulseBlaster handle
        seq             % Handle to sequence object
    end
    properties(SetAccess=private)
        tasks           % Handles to nidaq tasks (can querry for available samples)
    end
    
    methods
        function obj = APDPulseSequence(ni,pb,seq)
            obj.ni = ni;
            obj.seq = seq;
            obj.pb = pb;
            % Verify chanels exist in nidaq
            chans = seq.getSequenceChannels;
            chans(cellfun(@(a)isempty(a),{chans.counter}))=[];
            lineNames = [{chans.label} {chans.counter}];
            msg = {};
            for i = 1:numel(lineNames)
                try
                    obj.ni.getLines(lineNames{i},'in');
                catch err
                    msg{end+1} = err.message;
                end
            end
            if ~isempty(msg)
                obj.ni.view;
                error('Add lines below, and load again.\n%s',strjoin(msg,'\n'))
            end
        end
        function [nsamples,i] = count_bins(obj,nodes,GateLineName,nsamples)
            % Recursive function. Call: nsamples = obj.count_bins(nodes,GateLineName);
            if nargin < 4
                nsamples = 0;
            end
            i = 1;
            while ~isempty(nodes)
                node = nodes(1).node;
                switch node.type
                    case 'transition'
                        if strcmp(node.data.label,GateLineName)
                            nsamples = nsamples + 0.5;  % We are counting every transition (rise and fall)
                        end
                    case 'start'
                        [nsamples,j] = obj.count_bins(nodes(2:end),GateLineName,nsamples);
                        i = i + j - 1;
                        nodes(1:i) = [];
                    case 'end'
                        nsamples = nsamples*node.data;  % Number of loops
                        assert(nsamples==round(nsamples),'Loop found with odd number of transitions!')
                        return
                end
                nodes(1) = [];
                i = i + 1;
            end
            % Should only reach here at end of sequence main loop
            assert(nsamples==round(nsamples),'Sequence found with odd number of transitions!')
            nsamples = nsamples*obj.seq.repeat;
        end
        function start(obj,MaxCounts,overrideMinDuration)
            % Max expected counts per gate as input
            % See sequence.compile for overrideMinDuration
            
            if nargin < 3
                overrideMinDuration = false;
            end
            % Get the gate channels
            gate_chans = obj.seq.getSequenceChannels;
            gate_chans(cellfun(@(a)isempty(a),{gate_chans.counter}))=[];

            obj.tasks = Drivers.NIDAQ.task.empty(0);
            s = obj.seq.flattenTree;
            for i = 1:numel(gate_chans)
                GateLineName = gate_chans(i).label;
                obj.tasks(end+1) = obj.ni.CreateTask([mfilename ' ' GateLineName]);
                obj.tasks(i).UserData.N = obj.count_bins(s,GateLineName);
                obj.tasks(i).UserData.raw_data = NaN(obj.tasks(i).UserData.N,1);
                obj.tasks(i).UserData.ii = 0;
                try
                    obj.tasks(i).ConfigurePulseWidthCounterIn(gate_chans(i).counter,GateLineName,obj.tasks(i).UserData.N,0,MaxCounts)
                catch err
                    for j = 1:numel(obj.tasks)
                        obj.tasks(j).Clear;
                    end
                    obj.tasks = Drivers.NIDAQ.task.empty(0);
                    rethrow(err)
                end
            end

            for i = 1:numel(obj.tasks)
                obj.tasks(i).Start;
            end
            try
                [program,s] = obj.seq.compile(overrideMinDuration);
                obj.pb.open;
                obj.pb.load(program);
                obj.pb.start;
            catch err
                for j = 1:numel(obj.tasks)
                    obj.tasks(j).Clear;
                end
                obj.tasks = Drivers.NIDAQ.task.empty(0);
                rethrow(err)
            end
        end
        function stream(obj,varargin)
            % Inputs are line objects (one for each counter)
            assert(~isempty(obj.tasks),'Nothing setup!')
            assert(numel(varargin)==numel(obj.tasks),sprintf('%i Counters. Only received %i inputs.',numel(obj.tasks),numel(varargin)))
            for i = 1:numel(varargin)
                assert(isvalid(varargin{i}),'Invalid line handle')
            end
            err = [];
            try
                while ~isempty(obj.tasks)
                    for i = 1:numel(obj.tasks)
                        if obj.tasks(i).IsTaskDone
                            clearFlag = 1;
                        else
                            clearFlag = 0;
                        end
                        SampsAvail = obj.tasks(i).AvailableSamples;
                        if SampsAvail
                            ii = obj.tasks(i).UserData.ii;
                            % Change to counts per second
                            counts = obj.tasks(i).ReadCounter(SampsAvail);
                            obj.tasks(i).UserData.raw_data(ii+1:ii+SampsAvail) = counts;
                            obj.tasks(i).UserData.ii = obj.tasks(i).UserData.ii + SampsAvail;
                            set(varargin{i},'ydata',obj.tasks(i).UserData.raw_data,...
                                'xdata',1:numel(obj.tasks(i).UserData.raw_data))
                            drawnow;
                        end
                        if clearFlag
                            obj.tasks(i).Clear
                            obj.tasks(i) = [];
                        end
                    end
                end
            catch err
            end
            for j = 1:numel(obj.tasks)
                obj.tasks(j).Clear;
            end
            obj.tasks = Drivers.NIDAQ.task.empty(0);
            if ~isempty(err)
                rethrow(err)
            end
        end
    end
end