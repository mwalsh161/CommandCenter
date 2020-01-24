classdef Sweep < handle & Base.Measurement
    % SWEEP is a general class for N-dimensional scanning over Base.Pref dimensions, measuring
    % Base.Measurement objects at each point.

    properties (SetAccess=private)  % Identity vars.
        % Axis Info
        name = '';
        
        % Core
        measurements;   % cell array    % Contains 1xM `Base.Measurement` objects that are being measured at each point.
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
        controller = [];    % Base.SweepController. If this isn't empty, it will look to this for start/stop.
    end
    
    properties (SetAccess={?Base.Sweep, ?Base.SweepController})  % Index vars.
        sub;            % 
		index;			% integer
        ticking = false;
    end

    properties (SetObservable, SetAccess=private)   % Runtime vars.
        data;           % cell array 				% 1xM cell array (one cell per `Base.Measurement`) containing (N+P)-dimensional data, where P is the dimension of that `Base.Measurement`.
    end
    
    properties (SetAccess=private)
        flags = struct( 'isNIDAQ',                  false,...
                        'isPulseBlaster',           false,...
                        'isContinuous',             false,...
                        'isOptimize',               false,...
                        'shouldOptimizeAfter',      false,...
                        'shouldReturnToInitial',    true,...
                        'shouldSetInitialOnReset',  true)
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
                
%                 obj.measurements =  varargin{1};    % Not sure what to do here.
%                 
%                 obj.sdims =         obj.data.metadata.dims;
%                 obj.sscans =        obj.data.metadata.scans;
            else
                obj.measurements =  varargin{1};
                obj.sdims =         varargin{2};
                obj.sscans =        varargin{3};

                if nargin > 3
                    fn = fieldnames(varargin{4});
                    for ii = 1:length(fn)
                        obj.flags.(fn{ii}) = varargin{4}.(fn{ii});
                    end
                end
            end
            
            
			% Check measurements
            assert(numel(obj.measurements) == length(obj.measurements), '')
            assert(numel(obj.measurements) > 0, '')
            
            for ii = 1:length(obj.measurements)
                assert(isa(obj.measurements{ii}, 'Base.Measurement'), '');
            end
            
			% Check dims and scans
            assert(length(obj.sdims) == length(obj.sscans))
            for ii = 1:length(obj.sdims)
                assert(isa(obj.sdims{ii}, 'Base.Pref'), '');
                assert(obj.sdims{ii}.isnumeric, '');
                
                assert(isnumeric(obj.sscans{ii}), '')
                assert(numel(obj.sscans{ii}) == length(obj.sscans{ii}), '')
                % (NotImplemented) Check that all the values in obj.sweeps{2, ii} are in range.
                
				for jj = (ii+1):length(obj.sdims)
					assert(~isequal(obj.sdims{ii}, obj.sdims{jj}), ['Using ' obj.sdims{ii}.name ' twice in the same sweep is verboten']);
				end
            end
            
            obj.fillMeasurementProperties();
            obj.reset();
        end
        
        function fillMeasurementProperties(obj)
            sizes_ = struct();
            names_ = struct();
            units_ = struct();
            dims_  = struct();
            scans_ = struct();

            ssizes = obj.lengths();

            for ii = 1:length(obj.measurements)
                mtag = ['m' num2str(ii) '_'];
                
                sd = obj.measurements{ii}.subdata();
                
                msizes = obj.measurements{ii}.getSizes();
                mnames = obj.measurements{ii}.getNames();
                munits = obj.measurements{ii}.getUnits();
                mdims =  obj.measurements{ii}.getDims();
                mscans = obj.measurements{ii}.getScans();
                
                for jj = 1:length(sd)
                    s = msizes.(sd{jj});
                    sizes_.([mtag sd{jj}]) = [ssizes s(s > 1)];  % Append dimensions
                    names_.([mtag sd{jj}]) = mnames.(sd{jj});
                    units_.([mtag sd{jj}]) = munits.(sd{jj});
                    dims_.( [mtag sd{jj}]) = [obj.sdims     mdims.( sd{jj})];
                    scans_.([mtag sd{jj}]) = [obj.sscans    mscans.(sd{jj})];
                end
            end
            
            obj.sizes = sizes_;
            obj.names = names_;
            obj.units = units_;
            obj.dims  = dims_;
            obj.scans = scans_;
        end

        function l = length(obj)    % Returns the total number of dimensions length(sdims).
			l = length(obj.sdims);
        end
        function L = lengths(obj)   % Returns the length of each dimension in the scan.
% 			L = cellfun(@(x)(length(x)), obj.sscans, 'UniformOutput', true);
            
            l = obj.length();
            L = NaN(1, l);
            
            for ii = 1:l
                L(ii) = length(obj.sscans{ii});
            end
		end

        function l = measurementLength(obj)
            l = length(obj.measurements);
        end
        function D = measurementLengths(obj)
            D = [];
            
            for ii = 1:length(obj.measurements)
                D = [D obj.measurements{ii}.subdatas()]; %#ok<AGROW>
            end
        end
        
		function reset(obj)
			obj.index = 1;

            obj.data = obj.blank(@NaN);

			obj.flags.isNIDAQ = false;
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

            if obj.index > N
                warning('Already done')
                data = obj.data;
                return
            end
            
            obj.gotoIndex(obj.index);

            % Slow aquisition
            if ~obj.flags.isNIDAQ
                while obj.index <= N && (~isempty(obj.controller) && isvalid(obj.controller) && obj.controller.gui.toggle.Value)
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
        function tick(obj)
            L = obj.lengths();
            N = prod(L);

            if obj.index > N
                warning('Already done')
                return
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
                msd =       obj.measurements{ii}.subdata;
                d =         obj.measurements{ii}.snap(false);   % Don't pass metadata...

                for jj = 1:length(msd)
                    C    = cell(1, sum(size(d.(msd{jj}).dat) > 1));
                    C(:) = {':'};

                    S.subs = [SUB C];

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
    end
end
