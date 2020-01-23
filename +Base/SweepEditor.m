classdef SweepEditor < handle
    % SweepEditor is a UI to help the user make a sweep.

    properties (Constant, Hidden)
        pheaders =      {'#',       'Parent',  'Pref',     'Unit',     'Min',      'Max',      'Pair',      'X0',       'dX',       'X1',       'N',         'Sweep'};
        peditable =     [false,     false,     false,      false,      false,      false,      false,       true,       true,       true,       true,         false]; 
        pwidths =       {25,        160,       160,        40,         40,         40,         0,           40,         40,         40,         40,          80};
        pformat =       {'char',    'char',    'char',     'char',     'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'numeric',   'numeric'};
        
%         pheadersOpt =   {'#',       'Parent',  'Pref',     'Unit',     'Min',      'Max',      'X0',       'Guess',    'X1',       'N',         'Sweep'};
%         peditableOpt =  [false,     false,     false,      false,      false,      false,      true,       true,       true,       false,       false];
%         pformatOpt =    {'char',    'char',    'char',     'char',     'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'numeric',   'numeric'};
%         pformat =   {'char',    'char',    'char',     'char',     'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'char'};

        mheaders =  {'#',       'Measurement', 'Subdata',   'Size',    'Unit',     'Time'};
        meditable = [false,     false,         false,       false,      false,      true];
        mwidths =   {25,        160,           160,         60,         40,         0};
        mformat =   {'char',    'char',        'char',      'char',     'char',     'numeric'};
    end

    properties (Access=private)
        pdata;
        mdata;
        
        prefs;
        measurements;
    end

    properties (Access=private)
        f;                          % Figure
        
        pt;                         % Prefs table
        mt;                         % Measurements table
        
        gui;

        pmenu;
        mmenu;
    end

    properties (Access=private)
        pselected
        mselected

        maxelements
    end

    methods     % Setup
		function obj = SweepEditor()
%             obj.pdata = [ centerChars(obj.makePrefRow(x)) ; centerChars(obj.makePrefRow(y)) ; centerChars(obj.makePrefRow(bool)) ; centerChars(obj.makePrefRow([])) ];
%             obj.mdata = [ centerChars(obj.makeMeasurementRow(0)) ; centerChars(obj.makeMeasurementRow(0)) ; centerChars(obj.makeMeasurementRow(0)) ; centerChars(obj.makeMeasurementRow([])) ];
            obj.pdata = centerCharsPrefs(obj.makePrefRow([]));
            obj.mdata = centerCharsMeasurements(obj.makeMeasurementRow([]));


%             size(obj.pdata, 2)

            for ii = 1:size(obj.pdata, 1)-1
                obj.pdata{ii,1} = [obj.pdata{ii,1} num2str(ii)];
            end
            for ii = 1:size(obj.mdata, 1)-1
                obj.mdata{ii,1} = [obj.mdata{ii,1} num2str(ii)];
            end

            padding = 30;

            w = obj.totalWidth(true) + obj.totalWidth(false);
            h = 600;
            rh = 17;
            obj.maxelements = floor(h/rh)-1;
            h = obj.maxelements*rh;

            obj.f = figure( 'NumberTitle', 'off', 'name', 'SweepEditor', 'MenuBar', 'None',...
                            'Toolbar', 'None', 'Resize', 'off'); %, 'Visible', 'off', 'KeyPressFcn', '', 'CloseRequestFcn', '');

            obj.f.Position(3) = w;
            obj.f.Position(4) = h + padding;
            
            % uicontrols
            dp = 115;
            p = [10, h + 6, dp-5, 17];
            
            obj.gui.create              = uicontrol('String', 'Generate Sweep',...
                                                    'Tooltip', '',...
                                                    'Style', 'pushbutton',...
                                                    'Units', 'pixels',...
                                                    'Callback', @obj.generate_Callback,...
                                                    'Position', p);    p(1) = p(1) + dp;
            obj.gui.continuous          = uicontrol('String', 'Continuous',...
                                                    'Tooltip', ['(NotImplemented) Whether to continue repeating the measurement(s)'...
                                                                'continuously after the sweep is finished. Data is'...
                                                                ' circshifted. Behaves like a Counter if Time is the only axis.'],...
                                                    'Style', 'checkbox',...
                                                    'Units', 'pixels',...
                                                    'Enable', 'on',...
                                                    'Position', p);    p(1) = p(1) + dp;
            obj.gui.optimize            = uicontrol('String', 'Optimize',...
                                                    'Tooltip', ['(NotImplemented) Instead of scanning across every point'...
                                                                ' in an N-dimensional grid, Optimize uses fminsearch() to'...
                                                                ' find the *maximum* of the *first measurement* in the N-dimensional space'],...
                                                    'Style', 'checkbox',...
                                                    'Units', 'pixels',...
                                                    'Enable', 'on',...
                                                    'Position', p);    p(1) = p(1) + dp;
            obj.gui.returnToInitial     = uicontrol('String', 'Return to Initial',...
                                                    'Tooltip', ['(NotImplemented) Returns the N-dimensional space to its initial state after the'...
                                                                ' sweep is finished. Incompatible with Optimize and Optimize Afterward'],...
                                                    'Style', 'checkbox',...
                                                    'Value', true,...
                                                    'Units', 'pixels',...
                                                    'Enable', 'on',...
                                                    'Position', p);    p(1) = p(1) + dp;
            obj.gui.optimizeAfterSweep  = uicontrol('String', 'Optimize Afterward',...
                                                    'Tooltip', ['(NotImplemented) Unlike Optimize, Optimize Afterward sweeps over the full'...
                                                                ' N-dimensional space and then finds the *maximum* of the *first measurement*.'...
                                                                ' NotImplemented for N > 1.'],...
                                                    'Style', 'checkbox',...
                                                    'Units', 'pixels',...
                                                    'Enable', 'on',...
                                                    'Position', p);    p(1) = p(1) + dp;
                                                
%             obj.gui.timePointText       = uicontrol('String', 'Measurement Time:',...
%                                                     'Tooltip', 'Anticipated time for all of the measurements.',...
%                                                     'Style', 'text',...
%                                                     'HorizontalAlignment', 'right',...
%                                                     'Units', 'pixels',...
%                                                     'Position', p);    p(1) = p(1) + dp;
%             obj.gui.timePoint           = uicontrol('String', '1:00',...
%                                                     'Tooltip', 'Anticipated time for all of the measurements.',...
%                                                     'Style', 'edit',...
%                                                     'Enable', 'inactive',...
%                                                     'Units', 'pixels',...
%                                                     'Position', p);    p(1) = p(1) + dp;
                                                
            obj.gui.numPointsText       = uicontrol('String', 'Number of Points:',...
                                                    'Tooltip', 'Number of points in the sweep.',...
                                                    'Style', 'text',...
                                                    'HorizontalAlignment', 'right',...
                                                    'Units', 'pixels',...
                                                    'Position', p);    p(1) = p(1) + dp;
            obj.gui.numPoints           = uicontrol('String', '1',...
                                                    'Tooltip', 'Number of points in the sweep.',...
                                                    'Style', 'edit',...
                                                    'Enable', 'inactive',...
                                                    'Units', 'pixels',...
                                                    'Position', p);    p(1) = p(1) + dp;
                                                
%             obj.gui.timeTotalText       = uicontrol('String', 'Total Time:',...
%                                                     'Tooltip', 'Expected total time for the sweep of measurements.',...
%                                                     'Style', 'text',...
%                                                     'HorizontalAlignment', 'right',...
%                                                     'Units', 'pixels',...
%                                                     'Position', p);    p(1) = p(1) + dp;
%             obj.gui.timeTotal           = uicontrol('String', '1:00',...
%                                                     'Tooltip', 'Expected total time for the sweep of measurements.',...
%                                                     'Style', 'edit',...
%                                                     'Enable', 'inactive',...
%                                                     'Units', 'pixels',...
%                                                     'Position', p);    p(1) = p(1) + dp;
            
            obj.makeMenus();
            
            % Pref Table
            ptPosition = [obj.totalWidth(false), 0, obj.totalWidth(true), h];
            apt = axes('Visible', 'off', 'Units', 'pixels', 'Position', ptPosition, 'UserData', true);

            obj.pt =    uitable('Data', obj.pdata,...
                                'ColumnEditable',   obj.peditable, ...
                                'ColumnName',       obj.processHeaders(true),...
                                'ColumnFormat',     {},... obj.pformat, ...
                                'ColumnWidth',      obj.pwidths, ...
                                'RowName',          [],...
                                'Units', 'pixels', 'Position', ptPosition,...
                                'CellEditCallback', @obj.edit_Callback,...
                                'UIContextMenu', obj.pmenu,...
                                'ButtonDownFcn', @obj.buttondown_Callback,...
                                'UserData', apt);

%             jScrollPane = findjobj(obj.pt);
%             jtable = jScrollPane.getViewport.getView;
%             rh = jtable.getRowHeight()

            xlim(apt, [0, ptPosition(3)]);
            ylim(apt, [0, ptPosition(4)/rh]);
            apt.YDir = 'reverse';

            % Measurement Table
            mtPosition = [0, 0, obj.totalWidth(false), h];
            amt = axes('Visible', 'off', 'Units', 'pixels', 'Position', mtPosition, 'UserData', false);
            
            obj.mt =    uitable('Data', obj.mdata,...
                                'ColumnEditable',   obj.meditable, ...
                                'ColumnName',       obj.processHeaders(false),...
                                'ColumnFormat',     {},... obj.mformat, ...
                                'ColumnWidth',      obj.mwidths, ...
                                'RowName',          [],...
                                'Units', 'pixels', 'Position', mtPosition,...
                                'CellEditCallback', @obj.edit_Callback,...
                                'UIContextMenu', obj.mmenu,...
                                'ButtonDownFcn', @obj.buttondown_Callback,...
                                'UserData', amt);

            xlim(amt, [0, mtPosition(3)]);
            ylim(amt, [0, mtPosition(4)/rh]);
            amt.YDir = 'reverse';
            
            obj.update()
        end
        function makeMenus(obj)
            % Pref Menu
            obj.pmenu = uicontextmenu(obj.f);

            uimenu(obj.pmenu, 'Label', 'Pref 0', 'Enable', 'off');
            
            uimenu(obj.pmenu, 'Label', [char(8679) ' Move Up'],     'Callback', @(s,e)obj.moveRow(-1, true));
            uimenu(obj.pmenu, 'Label', [char(8681) ' Move Down'],   'Callback', @(s,e)obj.moveRow(+1, true));
            
            uimenu(obj.pmenu, 'Label', 'Delete',                    'Callback', @(s,e)obj.deleteRow(true));

%             uimenu(obj.pmenu, 'Label', '<html>Time [ave] (<font face="Courier" color="green">.time</font>)', 'Separator', 'on',   'Callback', @(s,e)(obj.setRow(Prefs.Empty('Time', 1), true)));
            uimenu(obj.pmenu, 'Label', '<html>Time [ave] (<font face="Courier" color="green">.time</font>)', 'Separator', 'on', 'Callback', @(s,e)(obj.setRow(Prefs.Time, true)));

            pr = Base.PrefRegister.instance();
            pr.getMenu(obj.pmenu, @(x)(obj.setRow(x, true)), 'readonly', false, 'isnumeric', true);
            
            % Measurement Menu
            obj.mmenu = uicontextmenu(obj.f);

            uimenu(obj.mmenu, 'Label', 'Measurement 0', 'Enable', 'off');
            
            uimenu(obj.mmenu, 'Label', [char(8679) ' Move Up'],     'Callback', @(s,e)obj.moveRow(-1, false));
            uimenu(obj.mmenu, 'Label', [char(8681) ' Move Down'],   'Callback', @(s,e)obj.moveRow(+1, false));
            
            uimenu(obj.mmenu, 'Label', 'Delete',                    'Callback', @(s,e)obj.deleteRow(false));

            mr = Base.MeasurementRegister.instance();
            mr.getMenu(obj.mmenu, @(x)(obj.setRow(x, false)));
            
            obj.mmenu.Children(end-4).Separator = 'on';
        end
    end
    
    methods     % Sweep
        function generate_Callback(obj, ~, ~)
            assignin('base', 's', obj.generate());
        end
        function sweep = generate(obj)
            scans = {};
            
            for ii = 1:length(obj.prefs)
                scans{ii} = linspace(obj.pdata{ii, 8}, obj.pdata{ii, 10}, obj.pdata{ii, 11}); %#ok<AGROW>
            end
            
            
            flags = struct( 'isNIDAQ',                  false,...
                            'isPulseBlaster',           false,...
                            'isContinuous',             obj.gui.continuous.Value,...
                            'isOptimize',               obj.gui.optimize.Value,...
                            'shouldOptimizeAfter',      obj.gui.optimizeAfterSweep.Value,...
                            'shouldReturnToInitial',    obj.gui.returnToInitial.Value,...
                            'shouldSetInitialOnReset',  true);
            
            sweep = Base.Sweep(obj.measurements, obj.prefs, scans, flags);
        end
    end
    
    methods     % Tables
        function update(obj)
            obj.setNumbers(true)
            obj.setNumbers(false)
            
            obj.gui.numPoints.String = obj.numPoints();
%             obj.gui.timeTotal.String = obj.numPoints() * str2double(obj.gui.timePoint.String);
            
            obj.pt.Data = obj.pdata;
            obj.mt.Data = obj.mdata;
        end
        
        function setNumbers(obj, isPrefs)
            if isPrefs
                mask = 1:obj.numRows(true);
                for ii = mask
                    obj.pdata{ii,1} = ['<html><font color=red><b>' num2str(mask(ii))];
                end
                obj.pdata{end,1} = '<html><font color=blue><b>+';
            else
                mask = obj.getMeasurementMask();
                for ii = 1:length(mask)
                    obj.mdata{ii,1} = ['<html><font color=red><b>' num2str(mask(ii))];
                end
                obj.mdata{end,1} = '<html><font color=blue><b>+';
            end
            
        end
        
        % ROW FUNCTIONS %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%%
        function setRow(obj, instrument, isPrefs)
            if isPrefs
                if obj.pselected == 0
                    obj.pdata(end, :) = centerCharsPrefs(obj.makePrefRow(instrument));
                    obj.pdata{end,1} = [obj.pdata{end,1} num2str(size(obj.pdata, 1))];
                    obj.pdata(end+1, :) = centerCharsPrefs(obj.makePrefRow([]));
                    obj.prefs{end+1} = instrument;
                else
                    obj.pdata(obj.pselected, :) = centerCharsPrefs(obj.makePrefRow(instrument));
                    obj.pdata{obj.pselected,1} = [obj.pdata{obj.pselected,1} num2str(obj.pselected)];
                    obj.prefs{obj.pselected} = instrument;
                end
            else
                if obj.mselected == 0
                    instrument
                    obj.makeMeasurementRow(instrument)
                    cm = centerCharsMeasurements(obj.makeMeasurementRow(instrument))
                    
                    size(cm)
                    size(cm, 1)
                    size(cm, 2)
                    
                    obj.mdata
                    
                    obj.mdata(end:(end+size(cm, 1)-1), :) = cm;
                    
                    obj.mdata(end+1, :) = centerCharsMeasurements(obj.makeMeasurementRow([]));
                    
                    obj.measurements{end+1} = instrument;
                    
                    obj.mdata
                end
%                 if obj.mselected == 0
%                     obj.pdata(end, :) = centerChars(obj.makePrefRow(instrument));
%                     obj.pdata{end,1} = [obj.pdata{end,1} num2str(size(obj.pdata, 1))];
%                     obj.pdata(end+1, :) = centerChars(obj.makePrefRow([]));
%                 else
%                     obj.pdata(obj.pselected, :) = centerChars(obj.makePrefRow(instrument));
%                     obj.pdata{obj.pselected,1} = [obj.pdata{obj.pselected,1} num2str(obj.pselected)];
%                 end
%                 if obj.pselected == 1
%                     obj.pdata(end, :) = centerChars(obj.makePrefRow(instrument));
%                     obj.pdata{end,1} = [obj.pdata{end,1} num2str(size(obj.pdata, 1))];
%                     obj.pdata(end+1, :) = centerChars(obj.makePrefRow([]));
%                 else
%                     obj.pdata(obj.pselected, :) = centerChars(obj.makePrefRow(instrument));
%                     obj.pdata{obj.pselected,1} = [obj.pdata{obj.pselected,1} num2str(obj.pselected)];
%                 end
            end
            
            obj.update();
        end
        function moveRow(obj, direction, isPrefs)
            if isPrefs
                obj.swapRows(obj.pselected, obj.pselected+direction, isPrefs);
            else
                obj.swapRows(obj.mselected, obj.mselected+direction, isPrefs);
            end
        end
        function deleteRow(obj, isPrefs)
            if isPrefs
                if obj.pselected ~= 0
                    obj.pdata(obj.pselected, :) = [];
                    obj.prefs(obj.pselected) = [];
                end
            else
                if obj.mselected ~= 0
                    mask = obj.getMeasurementMask();
                    mask2 = obj.getMeasurementMask() == mask(obj.mselected);
                    obj.mdata(mask2, :) = [];
                    obj.mrefs{obj.mselected} = [];
                end
            end
            
            obj.update();
        end
        function swapRows(obj, r1, r2, isPrefs)
            obj.num(isPrefs)
            assert(r1 > 0 && r1 <= obj.num(isPrefs));
            assert(r2 > 0 && r2 <= obj.num(isPrefs));
            
            if isPrefs
                tmp = obj.pdata(r1, :);
                obj.pdata(r1, :) = obj.pdata(r2, :);
                obj.pdata(r2, :) = tmp;
                
                tmp = obj.prefs{r1};
                obj.prefs{r1} = obj.prefs{r2};
                obj.prefs{r2} = tmp;
            else
%                 mask1 = obj.getMeasurementMask() == r1;
%                 mask2 = obj.getMeasurementMask() == r2;
%                 
%                 tmp = obj.mdata(mask1, :);
%                 obj.mdata(mask1, :) = [];
%                 
%                 obj.mdata(mask1, :) = obj.mdata(r2, :);
%                 obj.mdata(r2, :) = tmp;
%                 
%                 tmp = obj.measurements{r1};
%                 obj.measurements{r1} = obj.measurements{r2};
%                 obj.measurements{r2} = tmp;
            end

            obj.update;
        end
        
        function d = makePrefRow(~, p)          % Make a uitable row for a pref.
            if isempty(p)
                d = {'<html><font color=blue><b>+', '<i>...', '<b>... <font face="Courier" color="gray">(...)</font>', '...', [], [], [], [], [], [], [], [] };
            else
                str = p.name;

                if isempty(str)
                    str = strrep(p.property_name, '_', ' ');
                end
                
                N = 11;
                m = p.min;
                M = p.max;
%                 dx = .1;
                
                if m == -Inf && M == Inf
                    m =  -100;
                    M =  100;
                end
                
                if m == -Inf
                    m = min(-100, M-1);
                end
                if M ==  Inf
                    M = max(100, m+1);
                end
                
                dx = (M - m)/(N-1);
                
                if isPrefInteger(p)
                    N = M - m + 1;
                    dx = 1;
                end
                
                if N == 0
                    N = 1;
                end

                d = {'<html><font color=red><b>',     ['<i>' p.parent_class], formatMainName(str, p.property_name), p.unit, p.min, p.max, false, m, dx, M, N, makeSweepStr(m, M, dx) };
%                 d = {'<html><font color=red><b>',      '<i>Drivers.NIDAQ', '<b>Piezo Z (ao3)', 'V', 0, 10, 0,    .1,    1,   11,  '0:.1:1' };
            end
        end
        function d = makeMeasurementRow(~, m)   % Make a uitable row for a measurement
            if isempty(m)
%                 mheaders =  {'#',                 'Parent', 'Subdata', 'Size', 'Unit', 'Integration'};
                d = {'<html><font color=blue><b>+', '<i>...', '<b>...', '...', '...', 0 };
            else
                subdata = m.subdata;
                sizes = m.getSizes;
                units = m.getUnits;
                names = m.getNames;
                
                d = [];
                
                for ii = 1:length(subdata)
                    sd = subdata{ii};
                    d = [d ; {'<html><font color=red><b>',   ['<i>' class(m)], formatMainName(names.(sd), sd), ['[' num2str(sizes.(sd)) ']'], units.(sd), 0 }];
                end
                
%                 d = {'<html><font color=red><b>',      '<i>Drivers.NIDAQ.cin', '<b>APD1 (<font face="Courier" color="green">.ctr0</font>)', [1 1024], 'cts/sec', 0 };
                
            end
        end
        
        % HELPER FUNCTIONS %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%%
        function N = num(obj, isPrefs)
            if isPrefs
                N = length(obj.prefs);
            else
                N = length(obj.measurements);
            end
        end
        function N = numRows(obj, isPrefs)
            if isPrefs
                N = size(obj.pdata, 1) - 1;   % Minus one for the row with "..."
            else
                N = size(obj.mdata, 1) - 1;
            end
        end
        function N = numPoints(obj)
            N = prod(cell2mat(obj.pdata(1:obj.numRows(true), 11)));
        end
        
        % CALLBACKS %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%%
        function edit_Callback(obj, src, evt)
            isPrefs = src.UserData.UserData;

            good = true;
            
            evt
            
            if isPrefs
%                 obj.pheaders{evt.Indices(2)}
                ind = evt.Indices;
                
                if ind(1) > obj.numRows(isPrefs)    % We are in the ... row.
                    obj.pdata{ind(1), ind(2)} = evt.PreviousData;
                    obj.update();
                    return;
                end
                
                m = obj.pdata{ind(1), 5};
                M = obj.pdata{ind(1), 6};
                
                p = obj.prefs{ind(1)};
                isInteger = isPrefInteger(p);
                
                if isa(p, 'Prefs.Time')
                    true
                    switch obj.pheaders{evt.Indices(2)}
                        case {'X0', 'dX'}
                            good = false;
                        case {'X1', 'N'}
                            obj.pdata{ind(1), 8}  = 1;
                            obj.pdata{ind(1), 9}  = 1;
                            obj.pdata{ind(1), 10} = evt.NewData;
                            obj.pdata{ind(1), 11} = evt.NewData;
                    end
                else
                    switch obj.pheaders{evt.Indices(2)}
                        case 'X0'   % 8
                            X0 = max(m, min(M, evt.NewData));
                            if isInteger, X0 = round(X0); end
                            obj.pdata{ind(1), 8} = X0;

                            obj.updatedX(ind(1));
                        case 'dX'   % 9
                            dX = evt.NewData;

                            if obj.pdata{ind(1), 9} > 0 && dX > 0 || obj.pdata{ind(1), 9} < 0 && dX < 0
                                obj.pdata{ind(1), 9} = dX;

                                N = floor((obj.pdata{ind(1), 10} - obj.pdata{ind(1), 8} + dX) / dX);
                                N = max(2, N);
                                obj.pdata{ind(1), 11} = N;
                            else
                                good = false;
                            end
                        case 'X1'   % 10
                            X1 = max(m, min(M, evt.NewData));
                            if isInteger, X1 = round(X1); end
                            obj.pdata{ind(1), 10} = X1;

                            obj.updatedX(ind(1));
                        case 'N'   % 11
                            N = round(evt.NewData);
                            if N < 2
                                good = false;
    %                             obj.pdata{ind(1), 11} = N;
    %                             obj.pdata{ind(1), 9} = 0;
    %                             obj.pdata{ind(1), 10} = obj.pdata{ind(1), 8};
                            elseif N > 0 && obj.pdata{ind(1), 9} ~= 0
                                obj.pdata{ind(1), 11} = N;
                                obj.pdata{ind(1), 9} = (obj.pdata{ind(1), 10} - obj.pdata{ind(1), 8}) / (N - 1);
                            else
                                good = false;
                            end
                    end
                end
                
                dX = obj.pdata{ind(1), 9};
                
                if isInteger && good
                    if abs(dX) < 1 && dX ~= 0
                        dX = dX/abs(dX);
                    else
                        dX = round(dX);
                    end
                    
                    N = (obj.pdata{ind(1), 10} - obj.pdata{ind(1), 8} + dX) / dX;
                    
                    if N ~= floor(N)
                        N = floor(N);
                        
                        obj.pdata{ind(1), 9} = dX;
                        obj.pdata{ind(1), 10} = obj.pdata{ind(1), 8} + (N-1)*dX;
                        obj.pdata{ind(1), 11} = N;
                    else
                        obj.pdata{ind(1), 9} = dX;
                        obj.pdata{ind(1), 11} = N;
                    end
                end

                if ~good
                    obj.pdata{ind(1), ind(2)} = evt.PreviousData;
                else
                    obj.pdata{ind(1), 12} = makeSweepStr(obj.pdata{ind(1), 8}, obj.pdata{ind(1), 10}, obj.pdata{ind(1), 9});
                end
                
                
                obj.update();
            else
                
            end
        end
        function updateN(obj, ind)
            
        end
        function updatedX(obj, ind)
            N = obj.pdata{ind, 11};
            if N == 1
                N = 2;
            end
            dX = (obj.pdata{ind, 10} - obj.pdata{ind, 8}) / (N - 1);
            
            {dX}
            
            if dX ~= 0
                obj.pdata{ind(1), 9} = dX;
                obj.pdata{ind(1), 11} = N;
            end
        end
        
        function buttondown_Callback(obj, src, evt)
            cp = src.UserData.CurrentPoint(1,:);
            yi = floor(cp(2));

            N = size(src.Data, 1)-1;
            
            isPrefs = src.UserData.UserData;

            if yi <= N && yi > 0
                if isPrefs
                    obj.pselected = yi;
                    src.UIContextMenu.Children(end).Label = ['Pref ' num2str(yi)];
                else
                    yi = obj.getMeasurementIndex(yi);
                    obj.mselected = yi;
                    src.UIContextMenu.Children(end).Label = ['Measurement ' num2str(yi)];
                    N = num(obj, false);
                end

                if yi ~= 1
                    src.UIContextMenu.Children(end-1).Enable = 'on';
                else
                    src.UIContextMenu.Children(end-1).Enable = 'off';
                end
                if yi ~= N
                    src.UIContextMenu.Children(end-2).Enable = 'on';
                else
                    src.UIContextMenu.Children(end-2).Enable = 'off';
                end
                
                src.UIContextMenu.Children(end-3).Enable = 'on';   % Delete
                
                if ~isPrefs
                    disp('Up/Down/Delete disabled.')
                    src.UIContextMenu.Children(end-1).Enable = 'off';   % Up
                    src.UIContextMenu.Children(end-2).Enable = 'off';   % Down
                    src.UIContextMenu.Children(end-3).Enable = 'off';   % Delete
                end
            else
                if isPrefs
                    obj.pselected = 0;
                    src.UIContextMenu.Children(end).Label = 'Add Pref';
                else
                    obj.mselected = 0;
                    src.UIContextMenu.Children(end).Label = 'Add Measurement';
                end

                src.UIContextMenu.Children(end-1).Enable = 'off';   % Up
                src.UIContextMenu.Children(end-2).Enable = 'off';   % Down
                src.UIContextMenu.Children(end-3).Enable = 'off';   % Delete
            end

            drawnow;
        end

        function xi = getXIndex(obj, x)
            if true
                widths = obj.pwidths;
            else
                widths = obj.mwidths;
            end

            xi = 0;
            total = 0;

            for ii = 1:numel(widths)
                total = total + widths{ii};
                if total > x
                    xi = ii;
                    return
                end
            end
        end
        function total = totalWidth(obj, isPrefs)
            if isPrefs
                widths = obj.pwidths;
            else
                widths = obj.mwidths;
            end

            total = 6;

            for ii = 1:numel(widths)
                total = total + widths{ii};
            end
        end
        function headers = processHeaders(obj, isPrefs)
            if isPrefs
                headers =    obj.pheaders;
                editable =  obj.peditable;
            else
                headers =    obj.mheaders;
                editable =  obj.meditable;
            end

            for ii = 1:numel(headers)
                if ~editable(ii)
                    headers{ii} = ['<html><font color=gray>' headers{ii}];
                else
                    headers{ii} = ['<html><font color=red><b>' headers{ii}];
                end
            end
        end
        function mask = getMeasurementMask(obj)
            mask = [];
            for ii = 1:length(obj.measurements)
                mask = [mask ii*ones(1, obj.measurements{ii}.getN())]; %#ok<AGROW>
            end
        end
        function mi = getMeasurementIndex(obj, yi)
            mask = obj.getMeasurementMask();
            mi = mask(yi);
        end
    end
end

function str = formatMainName(name, property_name)
    str = ['<b>' name ' (<font face="Courier" color="green">.' property_name '</font>)'];
end
function ca = centerCharsPrefs(ca)
    for ii = 1:(numel(ca)-1)
        if ischar(ca{ii})
%             ca{ii} = sprintf('<html><tr align=center><td width=%d>%s', Base.SweepEditor.pwidths{ii}, ca{ii});
            ca{ii} = sprintf('<html>%s', ca{ii});   % Base.SweepEditor.pwidths{ii}, 
        end
    end
end
function ca = centerCharsMeasurements(ca)
    for ii = 1:(numel(ca)) %(size(ca, 2)-1)
        if ischar(ca{ii})
%             ca{ii} = sprintf('<html><tr align=center><td width=%d>%s', Base.SweepEditor.mwidths{mod(ii-1, length(Base.SweepEditor.mwidths))+1}, ca{ii});
            ca{ii} = sprintf('<html>%s', ca{ii});   % Base.SweepEditor.mwidths{mod(ii-1, length(Base.SweepEditor.mwidths))+1}
        end
    end
end
function str = makeSweepStr(m, M, dx)
    if dx == 0
        str = ['[' num2str(m) ']'];
    elseif dx == 1
        str = [num2str(m) ':' num2str(M)];
    elseif dx == M - m
        str = ['[' num2str(m) ', ' num2str(M) ']'];
    else
        str = [num2str(m) ':' num2str(dx) ':' num2str(M)];
    end
end
function tf = isPrefInteger(p)
    tf = isa(p, 'Prefs.Integer') || isa(p, 'Prefs.Boolean') || isa(p, 'Prefs.MultipleChoice');
end

