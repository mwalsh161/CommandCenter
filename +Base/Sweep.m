classdef Sweep < handle & Base.Measurement
    % SWEEP is a general class for N-dimensional scanning over Base.Pref dimensions, measuring
    % Base.Measurement objects at each point.

    properties (SetAccess=private)  % Identity vars.
        % Axis Info
        name = '';
        
        % Core
        measurements_;  % cell array    % Contains 1xM `Base.Measurement` objects that are being measured at each point.
        sdims;          % cell array                % Contains 1xN `Base.Pref` objects that are being swept over.
        sscans;         % cell array                % Contains 1xN numeric arrays of the points that are being swept by the axes. Numeric arrays of length 1 are treated as presettings.
    end

    properties
        controller = [];    % Base.SweepController. If this isn't empty, it will look to this object for start/stop.
    end
    
    properties (SetAccess={?Base.Sweep, ?Base.SweepController})  % Index vars.
        sub;                % 
		index;              % integer
        ticking = false;
        dwell = 1;          % seconds
    end

    properties (SetObservable, SetAccess=private)   % Runtime vars.
        data;           % cell array 				% 1xM cell array (one cell per `Base.Measurement`) containing (N+P)-dimensional data, where P is the dimension of that `Base.Measurement`.
    end
    
    properties (SetAccess=private)                  % Boolean flags
        flags = struct( 'isContinuous',             false,...
                        'isOptimize',               false,...   % NotImplemented
                        'shouldOptimizeAfter',      1,...
                        'shouldReturnToInitial',    true,...
                        'shouldSetInitialOnReset',  true)
    end
    
    properties
        meta = struct(  'initial',                  [])
    end
    
    properties (SetAccess=private, Hidden)          % NIDAQ vars.
        NIDAQ = struct( 'isNIDAQ',                  false,...
                        'isPrefNIDAQ',              false,...
                        'isMeasurementNIDAQ',       false,...
                        'dev',                      [],...
                        'out',                      [],...
                        'in',                       [],...
                        'pulseTrain',               [],...
                        'lastCount',                [],...  % integer array with size tasks
                        'dwell',                    [],...  % seconds (temp variable until a better solution is written)
                        'timer',                    [],...  % timer that periodically gathers data from the DAQ
                        'updateRate',               .2);    % seconds
    end

    methods
        function obj = Sweep(varargin)
            if numel(varargin) == 0     % If nothing was given, generate a test Sweep.
                a = Drivers.AxisTest.instance('fish');
                a1 = a.get_meta_pref('x');
                a2 = a.get_meta_pref('y');
                a1.writ(.5);
                a2.writ(4.5);
                e = Experiments.Spectrum.instance;

                obj = Base.Sweep({e, a1, a2}, {a1, a2}, {linspace(0, 1, 21), linspace(3, 5, 41)});
                
                return;
            end
            
            if numel(varargin) == 1     % (NotImplemented) If one thing was given, assume it is a data struct (i.e. output of measurement or a scan)
                obj.data = Base.Measurement.validateStructureStatic(varargin{1}, []);
                
                error('NotImplemented');
                
%                 obj.measurements_ =  varargin{1};    % Not sure what to do here.
%                 obj.sdims =         obj.data.metadata.dims;
%                 obj.sscans =        obj.data.metadata.scans;
            else
                obj.measurements_ = varargin{1};
                obj.sdims =         varargin{2};
                obj.sscans =        varargin{3};

                if nargin > 3
                    fn = fieldnames(varargin{4});
                    for ii = 1:length(fn)
                        obj.flags.(fn{ii}) = varargin{4}.(fn{ii});
                    end
                end

                if nargin > 4
                    obj.dwell = varargin{5};
                end

                if nargin > 5
                    obj.name = varargin{6};
                end
            end
            
			% Check measurements
            assert(iscell(obj.measurements_), 'Measurements must be a cell array.')
            assert(numel(obj.measurements_) == length(obj.measurements_), 'Measurements must be a 1xN cell array.')
            assert(numel(obj.measurements_) > 0, 'Cannot generate a sweep without measurements.')
            
            obj.NIDAQ.isMeasurementNIDAQ = false(1, numel(obj.measurements_));
            
            for ii = 1:length(obj.measurements_)
                assert(isa(obj.measurements_{ii}, 'Base.Measurement'), '');
                
                obj.NIDAQ.isMeasurementNIDAQ(ii) = isa(obj.measurements_{ii}, 'Drivers.NIDAQ.in');
            end
            
            % Check dims and scans
            obj.NIDAQ.isPrefNIDAQ = false(1, numel(obj.sdims));
            
            if ~obj.flags.isOptimize
                assert(iscell(obj.sdims), '.sdims must be a cell array.')
                assert(iscell(obj.sscans), '.sscans must be a cell array.')
                assert(numel(obj.sdims) == numel(obj.sscans), '.sdims must have the same length as .sdims')
                
                for ii = 1:numel(obj.sdims)
                    checkPref(obj.sdims{ii})
                    checkScan(obj.sscans{ii}, obj.sdims{ii});
                    obj.sscans{ii} = obj.sscans{ii}(:);

                    obj.NIDAQ.isPrefNIDAQ(ii) = isNIDAQ(obj.sdims{ii});

                    for jj = (ii+1):length(obj.sdims)
                        assert(~isequal(obj.sdims{ii}, obj.sdims{jj}), ['Using ' obj.sdims{ii}.name ' twice in the same sweep is verboten']);
                    end
                end
                
                obj.resetInitial();
            else
                error('NotImplemented');
            end
            
            if all(obj.NIDAQ.isPrefNIDAQ) && all(obj.NIDAQ.isMeasurementNIDAQ)
                obj.NIDAQ.isNIDAQ = true;
                
                obj.NIDAQ.dev = obj.measurements_{1}.dev;
                obj.NIDAQ.dwell = obj.dwell;
            end
            
            % Finish up
            obj.fillMeasurementProperties();
            obj.reset();
            
            % Set name
            if isempty(obj.name)
                obj.name = obj.autoGenerateName();
            end
            
            % Helper functions
            function tf = isNIDAQ(pref)
                if isa(pref, 'Prefs.Time')
                    tf = false;
                elseif isa(pref, 'Prefs.Paired')
                    tf = true;
                    
                    for kk = 1:length(pref.prefs)
                        tf = tf && isNIDAQ(pref.prefs(kk));
                    end
                else
                    tf = isa(pref.parent, 'Drivers.NIDAQ.dev');
                end
            end
            function checkPref(pref)
                assert(isa(pref, 'Base.Pref'), 'Each element ');
                assert(pref.isnumeric, '');
            end
            function checkScan(scan, pref)
                assert(isnumeric(scan), '')
                assert(numel(scan) == length(scan), '')
                
                for s = scan
                    pref.validate(s);
                end
            end
        end
        
        % function l = length(obj)    % Returns the total number of dimensions length(sdims).
        function l = ndims(obj)         % Returns the total number of scan dimensions length(sdims).
			l = length(obj.sdims);
        end
        % function L = lengths(obj)   % Returns the length of each scan dimension in the sweep.
        function L = size(obj)   % Returns the length of each scan dimension in the sweep.
% 			L = cellfun(@(x)(length(x)), obj.sscans, 'UniformOutput', true);
            
            l = obj.ndims();
            L = NaN(1, l);
            
            for ii = 1:l
                L(ii) = length(obj.sscans{ii});
            end
            
            L(L < 1) = [];  % Check me!
		end
        
            % function l = measurementLength(obj)
        function l = measurementLength(obj)
            l = length(obj.measurements_);
        end
            % function D = measurementLengths(obj)
        function D = measurementLengths(obj)
            D = [];
            
            for ii = 1:length(obj.measurements_)
                D = [D obj.measurements_{ii}.nmeas()]; %#ok<AGROW>
            end
        end
        function D = measurementDimensions(obj)
            D = [];
            
            for ii = 1:length(obj.measurements_)
                D = [D obj.measurements_{ii}.dimensions()]; %#ok<AGROW>
            end
        end
        
		function reset(obj)
			obj.index = 1;

            obj.data = obj.blank(@NaN);
            
            if obj.flags.shouldSetInitialOnReset
                obj.resetInitial();
            end
            
            if ~isempty(obj.controller) && isvalid(obj.controller)
                obj.controller.setIndex()
            end
        end
        function resetInitial(obj)
            for ii = 1:numel(obj.sdims)
                obj.meta.initial(ii) = obj.sdims{ii}.read();
            end
        end
        
        function [vec, ind] = current(obj)
% 			[sub{1:length(L)}] = ind2sub(L, obj.index);
%             sub = cell2mat(sub);

			A = 1:obj.ndims();
            
            ind = NaN*A;
            vec = NaN*A;

            for aa = A
                ind(aa) = obj.sub(aa);
                vec(aa) = obj.sscans{aa}(obj.sub(aa));
            end
        end

        function gotoIndex(obj, index)
            L = obj.size();

            obj.sub = [];

            [obj.sub{1:length(L)}] = ind2sub(L, index);
            obj.sub = cell2mat(obj.sub);
            A = 1:obj.ndims();

            for aa = A
                obj.sdims{aa}.writ(obj.sscans{aa}(obj.sub(aa)));
            end
            
            obj.index = index;
        end
		function data = measure(obj)
            N = prod(obj.size());
            sd = obj.subdata;
            obj.controller.gui.toggle.Value = true;

            % First, make sure that we are at the correct starting position.
            if obj.index > N && ~obj.flags.isContinuous
                warning('Already done')
                data = obj.data;
                return
            end
            
            % Go to the first/current index
            obj.gotoIndex(obj.index);

            if ~obj.NIDAQ.isNIDAQ
                % Slow aquisition.
                while (obj.index <= N || obj.flags.isContinuous) && ...                                         % While we still can take data...
                    (~isempty(obj.controller) && isvalid(obj.controller) && obj.controller.gui.toggle.Value)    % ...and while the controller wants us to take data...
                    obj.tick();
                end
            else
                % Fast aquisition.
                obj.setupNIDAQ();
                
                % Start all tasks.
                for ii = 1:length(obj.NIDAQ.out.tasks); obj.NIDAQ.out.tasks{ii}.Start; end
                for ii = 1:length(obj.NIDAQ.in.tasks);  obj.NIDAQ.in.tasks{ii}.Start;  end
                obj.NIDAQ.pulseTrain.Start;
                
                going = true;
                
                % While we are gathering samples...
                while isvalid(obj.NIDAQ.in.tasks{1}) && going
                    going = false;
                    
                    % Start all tasks.
                    for kk = 1:length(obj.NIDAQ.in.tasks)
                        samples = obj.NIDAQ.in.tasks{kk}.AvailableSamples;
                        
                        if samples
                            obj.NIDAQ.in.raw{kk}(obj.NIDAQ.in.index(kk):(obj.NIDAQ.in.index(kk) + samples - 1)) = obj.NIDAQ.in.tasks{kk}.ReadCounter(samples);
                            obj.NIDAQ.in.index(kk) = obj.NIDAQ.in.index(kk) + samples;

                            obj.data.(sd{kk}).dat = diff(obj.NIDAQ.in.raw{kk}) / obj.NIDAQ.dwell;
                        end
                        
                        going = going || (~obj.NIDAQ.in.tasks{kk}.IsTaskDone || obj.NIDAQ.in.tasks{kk}.AvailableSamples);

                        obj.index = min(obj.NIDAQ.in.index);

                        if ~isempty(obj.controller) && isvalid(obj.controller)
                            obj.controller.setIndex();
                        end
                    end
                    
                    going = going && (~isempty(obj.controller) && isvalid(obj.controller) && obj.controller.gui.toggle.Value);
                end
                
                for ii = 1:length(obj.NIDAQ.out.tasks); obj.NIDAQ.out.tasks{ii}.Clear; end
                for ii = 1:length(obj.NIDAQ.in.tasks);  obj.NIDAQ.in.tasks{ii}.Clear;  end
                obj.NIDAQ.pulseTrain.Clear;
                
                A = 1:obj.ndims();
                L = obj.size();
                N = prod(L);

                % First, look for axes that need to be changed. This is done by comparing the current axis with the previous values.
                [sub2{1:length(L)}] = ind2sub(L, min(obj.index, N));
                sub2 = [sub2{:}];

                for aa = A
                    obj.sdims{aa}.writ(obj.sscans{aa}(sub2(aa)));
                end
            end
            
            % Optimize afterward
%             obj.flags.shouldOptimizeAfter
%             length(obj.sscans)
%             obj.index
%             N
            if obj.flags.shouldOptimizeAfter && length(obj.sscans) == 1 && obj.index >= N
                % shouldOptimizeAfter is +\-1, and acts to sign() whether the data is maximized (+1) or minimized (-1).
                x0 = fitoptimize(obj.sscans{1}, obj.flags.shouldOptimizeAfter * obj.data.(sd{1}).dat);
                obj.sdims{1}.writ(obj.sscans{1}(1));
                obj.sdims{1}.writ(x0);
            elseif obj.flags.shouldReturnToInitial
                for ii = 1:obj.ndims()
                    if ~isnan(obj.meta.initial(ii))
                        obj.sdims{ii}.writ(obj.sscans{1}(1));
                        obj.sdims{ii}.writ(obj.meta.initial(ii));
                    end
                end
            end

            % Update the conroller, if applicable
            if ~isempty(obj.controller) && isvalid(obj.controller) && obj.controller.running
                obj.controller.running = false;
            end

            % Return the data
            data = obj.data;
        end
        function reset_measure(obj)
            obj.reset();
            obj.measure();
        end
    end
    methods (Access=private, Hidden)
        function setupNIDAQ(obj)
            obj.NIDAQ.dev.ClearAllTasks
%             error('NotImplemented');
            
%             obj.NIDAQ.timer = timer('ExecutionMode', 'fixedRate', 'name', ['Sweep ' obj.name],...
%                 'period', obj.NIDAQ.updateRate, 'timerfcn', @obj.updateNIDAQ);
            
            obj.NIDAQ.pulseTrain = obj.NIDAQ.dev.CreateTask([obj.name ' PulseTrain']);
            
            f = 1/obj.NIDAQ.dwell;
%             try
                obj.NIDAQ.pulseTrain.ConfigurePulseTrainOut('SweepSync', f);  % Change this?
%             catch err
%                 rethrow(err)
%             end
            
            s = obj.size();
            obj.NIDAQ.out.tasks = {};
            obj.NIDAQ.in.tasks = {};
            obj.NIDAQ.in.raw = {};
            obj.NIDAQ.in.index = [];

            kk = 1;

            for ii = 1:length(obj.sdims)
%                 if isa(obj.sdims{ii}, 'Prefs.Paired')
%                 
%                 else
                    obj.NIDAQ.out.tasks{kk} = obj.NIDAQ.dev.CreateTask([obj.name ' ' obj.sdims{ii}.name]);
                    out = obj.NIDAQ.dev.getLines(obj.sdims{ii}.name, 'out');
                    
                    sthis = s;
                    sthis(ii) = 1;
                    sweep = repmat(shiftdim(obj.sscans{ii}, ii-1), sthis);
                    
                    sweep = [sweep(:); sweep(end)];
                    
%                     obj.NIDAQ.dev.GetTaskByName('AnalogWrite')
                    
                    switch out.type
                        case 'analog'
                            obj.NIDAQ.out.tasks{kk}.ConfigureVoltageOut(out.name, sweep, obj.NIDAQ.pulseTrain)
                        case 'digital'
                            obj.NIDAQ.out.tasks{kk}.ConfigureDigitalOut(out.name, sweep, obj.NIDAQ.pulseTrain)
                    end
%                 end
                kk = kk + 1;
            end

            
            kk = 1;
            for ii = 1:length(obj.measurements_)
%                 if isa(obj.sdims{ii}, 'Prefs.Paired')
%                 
%                 else
                    obj.NIDAQ.in.tasks{kk} = obj.NIDAQ.dev.CreateTask([obj.name ' ' obj.measurements_{ii}.line]);
                    
                    obj.NIDAQ.in.tasks{kk}.ConfigureCounterIn(obj.measurements_{ii}.name, prod(s)+1, obj.NIDAQ.pulseTrain)
                    obj.NIDAQ.in.raw{kk} = NaN(prod(s)+1, 1);
                    obj.NIDAQ.in.index(kk) = 1;
%                 end
                kk = kk + 1;
            end
        end
    end
    methods (Hidden)
        function measureOptimize(obj) %#ok<MANU>
            error('NotImplemented')
            
            options = optimset('Display', 'iter', 'PlotFcns', @optimplotfval); %#ok<UNRCH>

            fun = @(x)100*(x(2) - x(1)^2)^2 + (1 - x(1))^2;
            x0 = [-1.2, 1];
            x = fminsearch(fun, x0, options);
        end
        function tick(obj)
            L = obj.size();
            N = prod(L);
            
            shouldCircshift = false;
            
%             isa(obj.sdims{end}, 'Prefs.Time')
            
            if obj.flags.isContinuous
%                 isa(obj.sdims{end}, 'Prefs.Time')
%                 M = prod(L(1:end-1));
%                 'a'
                obj.index = 1;
                if ~isempty(obj.controller) && isvalid(obj.controller)
                    obj.controller.setIndex();
                end
%                 obj.index = mod(obj.index-1, M) + 1;
%                 obj.index
%                 'b'
%                 mod(obj.index-1, M)
                if obj.index == 1
                    shouldCircshift = true;
                end
            end

            if obj.index > N
%                 if obj.flags.isContinuous
%                     shouldCircshift = true;
%                     obj.index = 1;
%                 else
%                     warning('Already done')
                    return
%                 end
            end
           

            % First, look for axes that need to be changed. This is done by comparing the current axis with the previous values.
            [sub2{1:length(L)}] = ind2sub(L, obj.index);
            SUB = sub2;
            sub2 = [sub2{:}];

            differences = obj.sub ~= sub2;	% Find the axes that need to change...
            A = 1:obj.ndims();
            needchange = A(differences);

            for aa = needchange(end:-1:1)
                obj.sdims{aa}.writ(obj.sscans{aa}(sub2(aa)));
            end

            obj.sub = sub2;

            % Second, wait for our axes to arrive within tolerance. In most cases, this is an empty check, but it is important for things like tuning frequency or slow motion.
            % 					for aa = A
            % 						obj.axes{aa}.wait();
            % 					end

            % Then, setup for assigning the data, and measure.
            S.type = '()';

            M = obj.measurementLength;

            sd = obj.subdata;
            kk = 1;

            for ii = 1:M
                msd =       obj.measurements_{ii}.subdata;
                d =         obj.measurements_{ii}.measureValidated(false);   % Don't pass metadata...

                for jj = 1:length(msd)
                    C    = cell(1, sum(size(d.(msd{jj}).dat) > 1));
                    C(:) = {':'};

                    S.subs = [SUB C];

                    if shouldCircshift
                        obj.data.(sd{kk}).dat = subsasgn(circshift(obj.data.(sd{kk}).dat, 1), S, d.(msd{jj}).dat); %, length(S.subs));
                    else
                        obj.data.(sd{kk}).dat = subsasgn(obj.data.(sd{kk}).dat, S, d.(msd{jj}).dat);
                    end
%                     if ~isempty(d.(msd{jj}).std)
%                         obj.data.(sd{kk}).std = subsasgn(obj.data.(sd{kk}), S, d.(msd{jj}).std);
%                     end

                    kk = kk + 1;
                end
            end

            % Lastly, incriment the index.
            if ~shouldCircshift
                obj.index = obj.index + 1;
                
                if ~isempty(obj.controller) && isvalid(obj.controller)
                    obj.controller.setIndex();
                end
            end
        end
        
        function fillMeasurementProperties(obj)
            obj.measurements = [];
            
            digits = ceil(log10(max(length(obj.measurements_), 0) + 1));
            
            for ii = 1:length(obj.measurements_)
                tag = sprintf(sprintf('m%%0%ii_', digits), ii);
                
                for jj = 1:obj.measurements_{ii}.getN()
                    obj.measurements = [obj.measurements obj.measurements_{ii}.measurements(jj).extendBySweep(obj, tag)];
                end
            end
        end
        
        function name = autoGenerateName(obj)
            if obj.flags.shouldOptimizeAfter
                name = [obj.measurements_{1}.measurements(1).name ' Optimization Over ' obj.sdims{1}.name];
            else
                name = 'Sweep';
                for ii = 1:obj.ndims()
                    name = [' vs ' obj.sdims{ii}.name];
                end
            end
        end
    end
end
