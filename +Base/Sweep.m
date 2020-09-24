classdef Sweep < handle & Base.Measurement
    % SWEEP is a general class for N-dimensional scanning over Base.Pref dimensions, measuring
    % Base.Measurement objects at each point.

    properties (SetAccess=private)  % Identity vars.
        % Axis Info
        name = '';
        
        % Core
        measurements_;   % cell array    % Contains 1xM `Base.Measurement` objects that are being measured at each point.
        sweeps;         % cell array    % 2xN cell array with a `Base.Pref`, numeric array pair in each column. (NotImplemented) Numeric arrays of length 1 are treated as presettings.
        
        sdims;          % cell array                % Contains 1xN `Base.Pref` objects that are being swept over.
        sscans;         % cell array                % Contains 1xN numeric arrays of the points that are being swept by the axes. Numeric arrays of length 1 are treated as presettings.
    end
    
    
    
%   properties (Hidden)             % Inherited from Measurement.
%       % sizes
%       % names
%       % units
%       % dims
%       % scans
%   end

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
    
    properties (SetAccess=private)
        flags = struct( 'isContinuous',             false,...
                        'isOptimize',               false,...   % NotImplemented
                        'shouldOptimizeAfter',      false,...   % NotImplemented
                        'shouldReturnToInitial',    true,...    % NotImplemented
                        'shouldSetInitialOnReset',  true)       % NotImplemented
    end
    
    properties (SetAccess=private, Hidden)  % NIDAQ vars.
        NIDAQ = struct( 'isNIDAQ',              false,...
                        'isPrefNIDAQ',          false,...
                        'isMeasurementNIDAQ',   false,...
                        'dev',                  [],...
                        'tasks',                [],...
                        'pulseTrain',           [],...
                        'lastCount',            [],...  % integer array with size tasks
                        'dwell',                [],...  % seconds (temp variable until a better solution is written)
                        'timer',                [],...  % timer that periodically gathers data from the DAQ
                        'updateRate',           .2);    % seconds
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

%                 obj = Base.Sweep({e}, {a1, a2}, {linspace(0, 1, 41), linspace(3, 5, 81)});
                obj = Base.Sweep({a1}, {a1, a2}, {linspace(0, 1, 41), linspace(3, 5, 11)});
                
                return;
            end
            
            if numel(varargin) == 1     % (NotImplemented) If one thing was given, assume it is a data struct (i.e. output of measurement or a scan)
                obj.data = Base.Measurement.validateStructureStatic(varargin{1}, []);
                
                error('NotImplemented');
                
%                 obj.measurements_ =  varargin{1};    % Not sure what to do here.
%                 
%                 obj.sdims =         obj.data.metadata.dims;
%                 obj.sscans =        obj.data.metadata.scans;
            else
                obj.measurements_ =  varargin{1};
                obj.sdims =         varargin{2};
                obj.sscans =        varargin{3};

                if nargin > 3
                    fn = fieldnames(varargin{4});
                    for ii = 1:length(fn)
                        obj.flags.(fn{ii}) = varargin{4}.(fn{ii});
                    end
                end

                if nargin > 4
%                     obj.name = varargin{5};
                    obj.dwell = varargin{5};
                end
            end
            
            defaultname = 'Sweep';  % Fix me.
            
			% Check measurements
            assert(numel(obj.measurements_) == length(obj.measurements_), '')
            assert(numel(obj.measurements_) > 0, '')
            
            obj.NIDAQ.isMeasurementNIDAQ = false(1, numel(obj.measurements_));
            
            for ii = 1:length(obj.measurements_)
                assert(isa(obj.measurements_{ii}, 'Base.Measurement'), '');
                
                obj.NIDAQ.isMeasurementNIDAQ(ii) = isa(obj.measurements_{ii}, 'Drivers.NIDAQ.in');
            end
            
            prefList = {};
                
            obj.NIDAQ.isPrefNIDAQ = false(1, numel(obj.sdims));
            
            % Check dims and scans
            if ~obj.flags.isOptimize
                assert(iscell(obj.sdims), '.sdims must be a cell array.')
                assert(iscell(obj.sscans), '.sscans must be a cell array.')
                assert(numel(obj.sdims) == numel(obj.sscans), '.sdims must have the same length as .sdims')
                
                for ii = 1:numel(obj.sdims)
                    checkPref(obj.sdims{ii})
                    checkScan(obj.sscans{ii}, obj.sdims{ii});

                    obj.NIDAQ.isPrefNIDAQ(ii) = isNIDAQ(obj.sdims{ii});

                    for jj = (ii+1):length(obj.sdims)
                        assert(~isequal(obj.sdims{ii}, obj.sdims{jj}), ['Using ' obj.sdims{ii}.name ' twice in the same sweep is verboten']);
                    end
                end
            else
                error('NotImplemented');
            end
            
            if isempty(obj.name)
                obj.name = defaultname;
            end
            
            if all(obj.NIDAQ.isPrefNIDAQ) && all(obj.NIDAQ.isMeasurementNIDAQ) && false
                obj.NIDAQ.isNIDAQ = true;
                
                obj.NIDAQ.dev = obj.measurements_{1}.dev;
                
                obj.setupNIDAQ();
            end
            
            obj.fillMeasurementProperties();
            obj.reset();
            
            function tf = isNIDAQ(pref)
                if isa(pref, 'Prefs.Time')
                    tf = true;
                elseif isa(pref, 'Prefs.Paired')
                    tf = true;
                    
                    for ii = 1:length(pref.prefs)
                        tf = tf && isNIDAQ(pref.prefs(ii));
                    end
                else
                    tf = strcmp(pref.parent_class, 'Drivers.NIDAQ.dev');
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
        end
        
        function [vec, ind] = current(obj)
% 			[sub{1:length(L)}] = ind2sub(L, obj.index);
%             sub = cell2mat(sub);

			A = 1:obj.length();
            
            ind = NaN*A;
            vec = NaN*A;

            for aa = A
                ind(aa) = obj.sub(aa);
                vec(aa) = obj.sscans{aa}(obj.sub(aa));
            end
        end

        function gotoIndex(obj, index)
            L = obj.lengths();

            obj.sub = [];

            [obj.sub{1:length(L)}] = ind2sub(L, index);
            obj.sub = cell2mat(obj.sub);
            A = 1:obj.length();

            for aa = A
                obj.sdims{aa}.writ(obj.sscans{aa}(obj.sub(aa)));
            end
            
            obj.index = index;
        end
		function data = measure(obj)
            % First, make sure that we are at the correct starting position.
            N = prod(obj.lengths());

            if obj.index > N && ~obj.flags.isContinuous
                warning('Already done')
                data = obj.data;
                return
            end
            
            obj.gotoIndex(obj.index);

            % Slow aquisition
            if ~obj.flags.isNIDAQ
                while (obj.index <= N || obj.flags.isContinuous) && (~isempty(obj.controller) && isvalid(obj.controller) && obj.controller.gui.toggle.Value)
                    obj.controller.gui.toggle.Value
                    obj.tick();
                end
            else
                % Not Implemented.
                error()
            end

            if obj.controller.running
                obj.controller.running = false;
            end

            data = obj.data;
        end
    end
    methods (Access=private, Hidden)
        function setupNIDAQ(obj)
            error('NotImplemented');
            
            obj.NIDAQ.timer = timer('ExecutionMode', 'fixedRate', 'name', ['Sweep ' obj.name],...
                'period', obj.NIDAQ.updateRate, 'timerfcn', @obj.updateNIDAQ);
            
            obj.PulseTrainH = obj.NIDAQ.dev.CreateTask('Counter PulseTrain');
            
            f = 1/obj.NIDAQ.dwell;
%             try
                obj.NIDAQ.pulseTrain.ConfigurePulseTrainOut('CounterSync', f);  % Change this?
%             catch err
%                 rethrow(err)
%             end
            

            kk = 1;

            for ii = 1:length(obj.sdims)
                if isa(obj.sdims{ii}, 'Prefs.Paired')
                    
                else
                    obj.NIDAQ.tasks(kk) = obj.NIDAQ.dev.CreateTask([obj.name ' ' obj.sdims{ii}.name]);
                    configureTask(obj.sdims{ii}, obj.NIDAQ.tasks(kk));
                end
            end
            
%             obj.NIDAQ.task = obj.NIDAQ.dev.CreateTask(obj.name);
            
            obj.NIDAQ.task = obj.nidaq.CreateTask([obj.name ' Task']);
            
            try
                continuous = true;
                buffer = 2*f*obj.update_rate;
                obj.CounterH.ConfigureCounterIn(obj.lineIn,buffer,obj.PulseTrainH,continuous);
            catch err
                obj.reset
                rethrow(err)
            end
            
            function configureTask(pref, task)
                
            end
        end
        function measureNIDAQ(obj)
            obj.NIDAQ.pulseTrain.Start;
            obj.NIDAQ.task.Start;
            start(obj.NIDAQ.timer)
%             obj.running = true;
        end
        function resetNIDAQ(obj)
            if ~isempty(obj.timerH)
                if isvalid(obj.timerH) && strcmp(obj.timerH.Running,'on')
                    obj.stopTimer()
                end
                obj.timerH = [];
            else
                if ~isempty(obj.CounterH) && isvalid(obj.CounterH)
                    obj.CounterH.Clear;
                end
                if ~isempty(obj.PulseTrainH) && isvalid(obj.PulseTrainH)
                    obj.PulseTrainH.Clear
                end
            end
        end
        function updateNIDAQ(obj)
            % Reads Counter Task
            if ~isvalid(obj.CounterH)
                obj.stopTimer()
            end
            nsamples = obj.CounterH.AvailableSamples;
            if nsamples
                counts = mean(diff(obj.CounterH.ReadCounter(nsamples)));
                counts = counts/obj.dwell;
                obj.callback(counts,nsamples)
            end
        end
        function stopTimer(obj,varargin)
            if isvalid(obj)
                stop(obj.timerH);
                delete(obj.timerH);
                obj.timerH = [];
                obj.CounterH.Clear;
                obj.PulseTrainH.Clear;
                obj.callback = [];
                obj.running = false;
            end
        end
    end
    methods (Hidden)
        function measureSweep(obj)
            
        end
        function measureOptimize(obj)
            error('NotImplemented')
            
            options = optimset('Display', 'iter', 'PlotFcns', @optimplotfval);

            fun = @(x)100*(x(2) - x(1)^2)^2 + (1 - x(1))^2;
            x0 = [-1.2, 1];
            x = fminsearch(fun, x0, options);
        end
        function tick(obj)
            L = obj.lengths();
            N = prod(L);
            
            shouldCircshift = false;

            if obj.index > N
                if obj.flags.isContinuous
                    shouldCircshift = true;
                    obj.index = 1;
                else
                    warning('Already done')
                    return
                end
            end

            % First, look for axes that need to be changed. This is done by comparing the current axis with the previous values.
            [sub2{1:length(L)}] = ind2sub(L, obj.index);
            SUB = sub2;
            sub2 = [sub2{:}];

            differences = obj.sub ~= sub2;	% Find the axes that need to change...
            A = 1:obj.length();

            for aa = A(differences)
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
                d =         obj.measurements_{ii}.snap(false);   % Don't pass metadata...

                for jj = 1:length(msd)
                    C    = cell(1, sum(size(d.(msd{jj}).dat) > 1));
                    C(:) = {':'};

                    S.subs = [SUB C];

                    if shouldCircshift
                        obj.data.(sd{kk}).dat           = circshift(obj.data.(sd{kk}).dat,1);
                        obj.data.(sd{kk}).dat(1,:,:)    = NaN;
                    end
                    
                    obj.data.(sd{kk}).dat = subsasgn(obj.data.(sd{kk}).dat, S, d.(msd{jj}).dat);

%                     if ~isempty(d.(msd{jj}).std)
%                         obj.data.(sd{kk}).std = subsasgn(obj.data.(sd{kk}), S, d.(msd{jj}).std);
%                     end

                    kk = kk + 1;
                end
            end

            % Lastly, incriment the index.
            obj.index = obj.index + 1;

            if ~isempty(obj.controller) && isvalid(obj.controller)
                obj.controller.setIndex();
            end
        end
        
        function fillMeasurementProperties(obj)
            obj.measurements = [];
            
            digits = floor(max(length(obj.measurements_), 0)) + 1;
            
            for ii = 1:length(obj.measurements_)
%                 tag = ['m' num2str(ii) '_'];
                tag = sprintf(sprintf('m%%0%ii_', digits), ii);
                
                for jj = 1:length(obj.measurements_{ii})
                    obj.measurements = [obj.measurements obj.measurements_{ii}.measurements(jj).extendBySweep(obj, tag)];
                end
            end
        end
        
%         function fillMeasurementProperties(obj)
%             sizes_ = struct();
%             names_ = struct();
%             units_ = struct();
%             dims_  = struct();
%             scans_ = struct();
% 
%             ssizes = obj.size();
% 
%             digits = floor(max(length(obj.measurements_), 0)) + 1;
%             
%             for ii = 1:length(obj.measurements_)
% %                 mtag = ['m' num2str(ii) '_'];
%                 mtag = sprintf(sprintf('m%%0%ii_', digits), ii);
%                 
%                 sd = obj.measurements_{ii}.subdata();
%                 
%                 msizes = obj.measurements_{ii}.getSizes();
%                 mnames = obj.measurements_{ii}.getNames();
%                 munits = obj.measurements_{ii}.getUnits();
%                 mdims =  obj.measurements_{ii}.getDims();
%                 mscans = obj.measurements_{ii}.getScans();
%                 
%                 for jj = 1:length(sd)
%                     s = msizes.(sd{jj});
%                     sizes_.([mtag sd{jj}]) = [ssizes s(s > 1)];  % Append dimensions
%                     names_.([mtag sd{jj}]) = mnames.(sd{jj});
%                     units_.([mtag sd{jj}]) = munits.(sd{jj});
%                     dims_.( [mtag sd{jj}]) = [obj.sdims     mdims.( sd{jj})];
%                     scans_.([mtag sd{jj}]) = [obj.sscans    mscans.(sd{jj})];
%                 end
%             end
%             
%             obj.sizes = sizes_;
%             obj.names = names_;
%             obj.units = units_;
%             obj.dims  = dims_;
%             obj.scans = scans_;
%         end
    end
end
