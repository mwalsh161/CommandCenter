classdef Sweep < handle
    % SWEEP is a general class for N-dimensional scanning over Base.Pref objects and measuring
    % Base.Measurement objects at each point.

    properties (SetAccess=private)   % Identity vars.
        % Axis Info
        name = {'', @(a)validateattributes(a,{'char'},{'vector'})};
        
        % Core
        axes;           % cell array                % Contains 1xN `Base.pref` classes that are being swept over.
        scans;          % cell array                % Contains 1xN numeric arrays of the points that are being swept by the axes. Numeric arrays of length 1 are treated as presettings.
        inputs;         % cell array                % Contains 1xM `Base.Data` classes that are being measured at each point.
    end
    
    properties
        sub;            % 
		index;			% integer
    end

    properties (SetObservable, SetAccess=private)   % Runtime vars.
        data;           % cell array 				% 1xM cell array (one cell per `Base.Data`) containing (N+P)-dimensional data, where P is the dimension of that `Base.Data`.
    end
    
    properties (Hidden, SetAccess=private)
        isNIDAQ;      	% boolean 					% Whether we can scan fast with NIDAQ drivers. Only works if _all_ `Base.Data`s are NIDAQ.
	end

    methods
		function obj = Sweep()
			a = Drivers.AxisTest.instance();
% 			a1 = a.x;
% 			a2 = a.y;
            a1 = a.get_meta_pref('x');
            a2 = a.get_meta_pref('y');

			obj.name = 'Test';

			I2 = Base.Data;
			I2.inputAxes = {};
			I2.inputScans = {};
% 			I2.size = [4 4];
			I2.size = [4 4];
			I2.name = 'Input Test 2';
			I2.checkAxesScans();

			I3 = Base.Data;
			I3.inputAxes = {};
			I3.inputScans = {};
			I3.size = [1 1];
			I3.name = 'Input Test 3';
			I3.checkAxesScans();

			obj.axes = {a1, a2};
			obj.scans = {linspace(0, 1, 41), linspace(3, 5, 81)};
			obj.inputs = {Base.Data, I2, I3};
            
            
            
%             a1.writ(.5)
%             a2.writ(4.5)

%             a1 = .5
%             a2 = 4.5

%             a1.value = .5;
%             a2.value = 4.5;
%             a1.writ(.5);
%             a2.writ(4.5);
            a1.writ(.5);
            a2.writ(4.5);

            obj.reset();
%             obj.snap();
            
            

% 			obj.input

			% Check scans and axes
% 			assert(length(obj.axes) == length(obj.scans))
% 
% 			for ii = 1:length(obj.axes)
% % 				assert(any((contains(superclasses(obj.axes{ii}), 'Base.Axis'))) || strcmp(class(obj.axes{ii}), 'Base.Axis'), 'Axes must be of class Base.Axis');
% % 				assert(all(obj.axes{ii}.inRange(obj.scans{ii})), ['Scans for ' obj.axes{ii}.name ' must be within ' obj.axes{ii}.nameRange '. These values were out of range: ' num2str(obj.scans{ii}(~obj.axes{ii}.inRange(obj.scans{ii})))]);
% 
% 				for jj = (ii+1):length(obj.axes)
% 					assert(~obj.axes{ii}.equals(obj.axes{jj}), ['Using ' obj.axes{ii}.name ' twice in the same scan is verboten']);
% 				end
% 			end
% 
% 			% Check inputs
% 			for ii = 1:length(obj.inputs)
% 				assert(any((contains(superclasses(obj.inputs{ii}), 'Base.Input'))) || strcmp(class(obj.inputs{ii}), 'Base.Input'));
% 			end
        end

        function L = lengths(obj)
            % Returns the length of each `Base.Pref` dimension in the scan.
%             obj.scans
			L = cellfun(@(x)(length(x)), obj.scans,'UniformOutput', true);
		end
        function d = dimension(obj)
            % Returns the total number of scan dimensions.
			d = length(obj.scans);
        end

        function D = inputDimensions(obj)
            D = [];
            
            for ii = 1:length(obj.inputs)
                D = [D obj.inputs{ii}.lengths()];
            end
            
% 			D = cellfun(@(x)(x.lengths()), obj.inputs, 'UniformOutput', true);
        end
        
		function reset(obj)
			obj.index = 1;

			L = obj.lengths();
			M = length(obj.inputs);
            
%             if ~iscell(obj.data) || numel(obj.data) ~= M
%                 obj.data = cell(1, M);
%             end
            
            newdata = cell(1, M);
            
			for ii = 1:M
                newdata{ii} = NaN([L, obj.inputs{ii}.size]);
% 				obj.data{ii} = NaN([L, obj.inputs{ii}.size]);
            end
            
            obj.data = newdata;
            
%             obj.data

			obj.isNIDAQ = false;
        end
        
        function [vec, ind] = currentPoint(obj)
% 			[sub{1:length(L)}] = ind2sub(L, obj.index);
%             sub = cell2mat(sub);
			A = 1:obj.dimension();
            
            ind = NaN*A;
            vec = NaN*A;

			for aa = A
                ind(aa) = obj.sub(aa);
                vec(aa) = obj.scans{aa}(obj.sub(aa));
            end
        end

		function snap(obj)  % Snap aquires data in the grid according to 
			% First, make sure that we are at the correct starting position.
			L = obj.lengths();
			M = length(obj.inputs);
			N = prod(L);
            
            if obj.index > N
                warning('Already done')
                return
            end
            
			[obj.sub{1:length(L)}] = ind2sub(L, obj.index);
            obj.sub = cell2mat(obj.sub);
			A = 1:obj.dimension();

			for aa = A
				obj.axes{aa}.writ(obj.scans{aa}(obj.sub(aa)));
            end

			% Slow aquisition
			if ~obj.isNIDAQ
				while obj.index <= N
					obj.tick();
				end
			else
				% Not Implemented.
				error()
			end
        end
        
        function tick(obj)
            % First, look for axes that need to be changed. This is done by comparing the current axis with the previous values.
            [sub2{1:length(L)}] = ind2sub(L, obj.index);
            sub2 = cell2mat(sub2);

            differences = obj.sub ~= sub2;	% Find the axes that need to change...

            for aa = A(differences)
                obj.axes{aa}.writ(obj.scans{aa}(sub2(aa)));
            end

            obj.sub = sub2;

            % Second, wait for our axes to arrive within tolerance. In most cases, this is an empty check, but it is important for things like tuning frequency or slow motion.
% 					for aa = A
% 						obj.axes{aa}.wait();
% 					end

            % Then, setup for assigning the data, and measure.
            SUB = num2cell(obj.sub);

            S.type = '()';

            for ii = 1:M
                C    = cell(1, sum(obj.inputs{ii}.size > 1));
                C(:) = {':'};

                S.subs = [SUB C];

                obj.data{ii} = subsasgn(obj.data{ii}, S, obj.inputs{ii}.snap());
            end

            % Lastly, incriment the index.
            obj.index = obj.index + 1;
        end
    end
end
