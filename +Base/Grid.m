classdef mcGrid < mcSavableClass
% mcGrid 
%
% Note:
%   This class is (horrendously) intermixed with mcWaypoints. Might need refactoring.
%
% Syntax:
%    - mcGrid()     % Don't use this; use mcWaypoints instead.
%    - (Decrepetated) mcGrid(wp, indices, gridCoords)      % wp is the parent waypoint class. indices is a numeric array containing 
%
%    - grid.goto()                          % Sends all of the real axis to the point corresponding to the virtual position.
%    - grid.wait()                          % Waits for each of the real axes to reach their target positions.
%    - pos = grid.realPosition()            % Returns the real position of each real axis (in external units) corresponding to virtualPosition.
%    
% Status: Still need UI to make selecting waypoints and choosing their virtual coordinates easy...

    properties
%         config = [];                % Inherited from mcSavable class.

        % config.name               string          % Name of grid.
        % config.isFinal            boolean         % Whether the grid has been finalized (whether 
        % config.A                  double          % A (n+1) x n matrix that relates virtual positions with real positions.
        % config.axesConfigs        struct array    % Array of the configs of the real axes.

        editArray = {};             % Cell array of uicontrols (edit) that will help construct the grid.
        textArray = {};             % Cell array of uicontrols (text) that will help construct the grid.
        rangeArray = {};            % Cell array of uicontrols (edit) that define the ranges that constrain the grid.
        rangeText = {};             % Cell array of uicontrols (text) that label the ranges that constrain the grid.
        
        previewButton = [];         % Preview button for displaying the current grid.
        nameField = [];             % Text field for naming the grid. Defaults to "Best Grid"
        finalizeButton = [];        % Finalizes the grid (intended feature currently disabled.
        finalizeAxesButton = [];    % Finalizes the grid axes.

        realAxes = {};              % Cell array containing the mcAxes which make up the vectorspace that the virtual axes live in
        virtualAxes = {};           % Cell array containing the virtual mcAxes.
        virtualPosition = [];       % Numeric array containing the position of all of the virtual axes. This is neccessary 
                                    %   because each virtualmcAxis only has knowledge of its own location and needs the other 
                                    %   coordinates to actually move to the correct virtual (and corresponding real) place.
                                    
        wp = [];                    % Also store the parent mcWaypoints
    end
    
    methods
        function grid = Grid(varin)
            grid.config.name =      'Best Grid';
            grid.config.isFinal =   false;
            grid.config.matrix =    [];
            
            switch nargin
                case 0
                    return;
%                 case 1
%                     grid.config = varin;
%                     
%                 case 2
%                     wp = varin{1};
%                     indices = varin{2};         % Use only the waypoints denoted by indices.
%                     gridCoords = cell(1, length(varin{2});
%                 case 3
%                     wp = varin{1};
%                     grid.realAxes = wp.config.axes;
%                     indices = varin{2};         % Use only the waypoints denoted by indices.
%                     gridCoords = varin{3};
            
%                     grid.config.axesConfigs =   cellfun(@(x)(x.config), grid.realAxes);
            end

%             num = length(indices);
%             
%             X = zeros(num);
%             Y = zeros(wp.length(), num);
% 
%             for ii = 1:length(gridCoords)
%                 if length(gridCoords{ii}) + 1 == num
%                     X(:,ii) = [gridCoords{ii} 1];
%                     Y(:,ii) = cellfun(@(x)(x(indices(ii))), wp.config.waypoints);
%                 else
%                     error('mcGrid: N waypoints expected definining a N-1 dimensional grid...');
%                 end
%             end

%             grid.virtualAxes = cell(1, num);
%             grid.virtualPosition = ones(1, num);   % first num-1 are actual position of virtual axes, last is to account for the possible translation (non-linearity).
%                     
%             config = mcAxis.gridConfig(grid,1);
% 
%             for ii = 1:(num-1)
%                 config.index = ii;
%                 grid.virtualAxes{ii} = mcAxis(config);
%             end
            % Y = AX
            % Y*X^-1 = A
            
%             grid.config.A = Y/X;    % Where 1/X is the inverse of X.
        end
            
        function finalize(grid)
            grid.config.isFinal = true;
            
            
            dims = size(grid.editArray);
            num = dims(1);
            
            grid.virtualAxes = cell(1, num);
            grid.virtualPosition = ones(1, num);      % first num-1 are actual position of virtual axes, last is to account for the possible translation (non-linearity).
                    
            for ii = 1:(num-1)
                config = mcaGrid.gridConfig(grid, ii);
                grid.virtualAxes{ii} = mcaGrid(config);
            end
        end
        
        function tf = eq(a, b)
            tf = isequal(a.config.A, b.config.A);
        end

        function tf = goto(grid)
            gotoPos = grid.realPosition();
            tf = true;
            
            for ii = 1:length(grid.realAxes)                % First, check if all of the real axes are in range...
                if ~grid.realAxes{ii}.inRange(gotoPos(ii))
                    tf = false;
                    disp('mcGrid.goto(): Warning! Real axes position is out of range. We will not move. (Eventually make this move as close to the target point as possible.)')
                    return;
                end
            end
            
            for ii = 1:length(grid.realAxes)
                if grid.realAxes{ii}.getX() ~= gotoPos(ii)
                    grid.realAxes{ii}.goto(gotoPos(ii));    % Send each real axis to the point corresponding to the virtual position.
                end
            end
        end
        function wait(grid)
            for ii = 1:length(grid.realAxes)
                grid.realAxes{ii}.wait();                   % Wait for each axis to reach its programmed target position.
            end
        end
        function tf = open(grid)
            tf = true;
            
            for ii = 1:length(grid.realAxes)
                tf = tf && grid.realAxes{ii}.open();        % Open each axis.
            end
        end
        function tf = close(grid)
            tf = true;
            
            for ii = 1:length(grid.realAxes)
                tf = tf && grid.realAxes{ii}.close();       % Close each axis.
            end
        end

        function pos = realPosition(grid)
            pos = grid.config.A * (grid.virtualPosition');
        end
        
        function makeGridFromEdit(grid, realAxes)
            matrix = cellfun(@(x)(str2double(x.String)), grid.editArray);   % Retrieve the numbers from the uicontrol array.
            
            grid.realAxes = realAxes;
            
            num = length(grid.realAxes);
            
            X = matrix(:, num+1:end);
            X(:, end+1) = 1;
            X = X';
%             
            Y = matrix(:, 1:num)';
            
            grid.config.A = Y/X;    % Where 1/X is the inverse of X.
            
            if any(any(isnan(grid.config.A))) || any(any(isinf(grid.config.A)))
                questdlg('The rows of grid coordinates must be (mostly) linearly independent.', 'Unable to Calculate Grid', 'Got it', 'Got it');
                grid.config.A = [];
            end
        end
        
        function figureClose_Callback(grid, src, ~)
            if strcmpi(questdlg('Are you sure you want to close the grid? All child grid axes will be deleted(!)', 'Close Grid?', 'Close', 'Nope', 'Close'), 'Close')
                if isvalid(grid) && ~isempty(grid.wp) && isvalid(grid.wp)
                    grid.wp.g.XData = [];
                    grid.wp.g.YData = [];
                    grid.wp.gridCoords = [];
                    
                    for ii = 1:length(grid.virtualAxes)
                        delete(grid.virtualAxes{ii});
                    end
                end
                
                delete(src);
            end
        end
    end
end




