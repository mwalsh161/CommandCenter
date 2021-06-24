classdef SweepEditor < handle
    % SweepEditor is a UI to help the user make a sweep. Syntax:
    %
    %   Base.SweepEditor()              % Make a blank sweep for the user to populate.
    %   Base.SweepEditor(sweep)         % Where sweep is a Base.Sweep. Fills the GUI with the settings in sweep.

    properties (Constant, Hidden)
        pheaders =      {'#',       'Parent',  'Pref',     'Unit',     'Min',      'Max',      'X1',       'Step',     'X2',       'N',         'Pair',    'ZigZag',   'Sweep',     'OMin',     'Guess',    'OMax'};
        peditable =     [false,     false,     false,      false,      false,      false,      true,       true,       true,       true,        true,       true,       false,      true,       true,       true]; 
        pwidths =       {20,        160,       160,        40,         40,         40,         40,         40,         40,         40,          40,         50,         80,         0,          0,          0,};
        pwidthsopt =    {20,        160,       160,        40,         40,         40,         0,           0,          0,          0,          0,          0,       	0,          40,         40,         40,};
        pformat =       {'char',    'char',    'char',     'char',     'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'numeric',   'numeric',  'numeric',  'char',    'numeric',  'numeric',  'numeric'};
        
        mheaders =  {'#',       'Parent',       'Measurement', 'Size',    'Unit',     'Exposure'};
        meditable = [false,     false,         false,       false,      false,      true];
        mwidths =   {20,        160,           160,         60,         40,         0};
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
        
        gui;                        % Struct contain upper bar uicontrols.

        pmenu;                      % uicontextmenu for Prefs
        mmenu;                      % uicontextmenu for Measurements
    end

    properties (Access=private)
        pselected;                  % Which Pref row is selected? Populated via axes hidden behind table that knows the right click location.
        mselected;                  % Which Measurement row is selected?

        maxelements;                % Max number of rows that can be displayed. Scrollbars break our right click interception. Maybe there's a way around this.
    end

    methods     % Setup
		function obj = SweepEditor(varargin)
            obj.pdata = centerCharsPrefs(obj.makePrefRow([]));
            obj.mdata = centerCharsMeasurements(obj.makeMeasurementRow([]));

            padding = 30;

            w = obj.totalWidth(true) + obj.totalWidth(false);
            h = 600;
            if ismac
                rh = 17;
            else
                rh = 18;
            end
            obj.maxelements = floor(h/rh)-1;
            h = obj.maxelements*rh;

            obj.f = figure( 'NumberTitle', 'off', 'name', 'SweepEditor', 'MenuBar', 'None',...
                            'Toolbar', 'None', 'Resize', 'off', 'Visible', 'off'); %, 'KeyPressFcn', '', 'CloseRequestFcn', '');

            obj.f.Position(3) = w;
            obj.f.Position(4) = h + padding;
            
            movegui(obj.f, 'center');
            
            % uicontrols
            dp = 115;
            p = [10, h + 6, dp-5, 17];
            
            obj.gui.create              = uicontrol('String', 'Generate Sweep',...
                                                    'Tooltip', '',...
                                                    'Style', 'pushbutton',...
                                                    'Units', 'pixels',...
                                                    'Callback', @obj.generate_Callback,...
                                                    'Position', p + [0 -1 0 2]*4);    p(1) = p(1) + dp;
            
                                                
            obj.gui.timePointText       = uicontrol('String', 'Single Dwell (sec):',...
                                                    'Tooltip', 'User-generated anticipated time for all of the measurements at each point.',...
                                                    'Style', 'text',...
                                                    'HorizontalAlignment', 'right',...
                                                    'Units', 'pixels',...
                                                    'Position', p);    p(1) = p(1) + dp;
            obj.gui.timePoint           = uicontrol('String', '1',...
                                                    'Style', 'edit',... 'Enable', 'inactive',...
                                                    'Units', 'pixels',...
                                                    'Callback', @obj.setSingleTime_Callback,...
                                                    'Position', p .* [1 1 .7 1]);    p(1) = p(1) + dp*.7;
                                                
            obj.gui.numPointsText       = uicontrol('String', 'Number of Points:',...
                                                    'Tooltip', 'Number of points in the sweep.',...
                                                    'Style', 'text',...
                                                    'HorizontalAlignment', 'right',...
                                                    'Units', 'pixels',...
                                                    'Position', p);    p(1) = p(1) + dp;
            obj.gui.numPoints           = uicontrol('String', '1',...
                                                    'Tooltip', 'Number of points in the sweep.',...
                                                    'Style', 'edit',...
                                                    'Enable', 'off',...
                                                    'Units', 'pixels',...
                                                    'Position',  p .* [1 1 .7 1]);    p(1) = p(1) + dp*.7;
                                                
            obj.gui.timeTotalText       = uicontrol('String', 'Total Time:',...
                                                    'Tooltip', 'Expected total time for the sweep of measurements (DD:HH:MM:SS).',...
                                                    'Style', 'text',...
                                                    'HorizontalAlignment', 'right',...
                                                    'Units', 'pixels',...
                                                    'Position',  p .* [1 1 .7 1]);    p(1) = p(1) + dp*.7;
            obj.gui.timeTotal           = uicontrol('String', '1:00',...
                                                    'Tooltip', 'Expected total time for the sweep of measurements (DD:HH:MM:SS).',...
                                                    'Style', 'edit',...
                                                    'Enable', 'inactive',...
                                                    'Units', 'pixels',...
                                                    'Position',  p .* [1 1 .7 1]);    p(1) = p(1) + dp*.75;
                                                
                                                
            obj.gui.continuous          = uicontrol('String', 'Continuous',...
                                                    'Tooltip', ['Whether to continue repeating the measurement(s)' newline,...
                                                                'continuously after the sweep is finished. Data is' newline,...
                                                                'circshifted. Behaves like a Counter if Time is the only axis.'],...
                                                    'Style', 'checkbox',...
                                                    'Units', 'pixels',...
                                                    'Enable', 'off',...
                                                    'Callback', @obj.setContinuous_Callback,...
                                                    'Position', p);    p(1) = p(1) + dp*.8;
            obj.gui.optimize            = uicontrol('String', 'Optimize',...
                                                    'Tooltip', ['(NotImplemented) Instead of scanning across every point' newline,...
                                                                'in an N-dimensional grid, Optimize uses fminsearch() (Nelder-Mead) to' newline,...
                                                                'find the *maximum* of the *first measurement* over the' newline,...
                                                                'N-dimensional space'],...
                                                    'Style', 'checkbox',...
                                                    'Units', 'pixels',...
                                                    'Enable', 'on',...
                                                    'Callback', @obj.setOptimize_Callback,...
                                                    'Position', p);    p(1) = p(1) + dp*.8;
            obj.gui.returnToInitial     = uicontrol('String', 'Return to Initial',...
                                                    'Tooltip', ['(NotImplemented) Returns the N-dimensional space to its'  newline,...
                                                                'initial state after the sweep is finished. Incompatible' newline,...
                                                                'with Optimize and Optimize Afterward'],...
                                                    'Style', 'checkbox',...
                                                    'Value', false,...
                                                    'Units', 'pixels',...
                                                    'Enable', 'off',...
                                                    'Position', p);    p(1) = p(1) + dp;
            obj.gui.optimizeAfterSweep  = uicontrol('String', 'Optimize Afterward',...
                                                    'Tooltip', ['Unlike Optimize, Optimize Afterward sweeps'  newline,...
                                                                'over the full  space, analyzes the data to find the'  newline,...
                                                                '*maximum* of the *first measurement*, and goes to', newline,...
                                                                'that maximum. NotImplemented for N > 1.'],...
                                                    'Style', 'checkbox',...
                                                    'Units', 'pixels',...
                                                    'Enable', 'off',...
                                                    'Position', p .* [1 1 1.1 1]); p(1) = p(1) + dp*1.1;
            obj.gui.minimizeAfterSweep  = uicontrol('String', 'Optimize Minimum',...
                                                    'Tooltip', 'Makes Optimize Afterward minimize rather than maximize.',...
                                                    'Style', 'checkbox',...
                                                    'Units', 'pixels',...
                                                    'Enable', 'off',...
                                                    'Position', p .* [1 1 1.1 1]);    % p(1) = p(1) + dp*1.1;
            
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

            xlim(apt, [0, ptPosition(3)]);
            ylim(apt, [0, ptPosition(4)/rh] - 3*(~ismac)/rh);
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
            
            obj.f.Visible = 'on';
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

            uimenu(obj.mmenu, 'Label', '<html>Time [ave] (<font face="Courier" color="green">.time</font>)', 'Separator', 'on', 'Callback', @(s,e)(obj.setRow(Prefs.Time, false)));
            
            mr = Base.MeasurementRegister.instance();
            mr.getMenu(obj.mmenu, @(x)(obj.setRow(x, false)));
            
            obj.mmenu.Children(end-4).Separator = 'on';
        end
    end
    
    methods     % Sweep
        function generate_Callback(obj, ~, ~)
            s = obj.generate();
            assignin('base', 's', s);
            Base.SweepViewer(s, []);
        end
        function sweep = generate(obj)
            scans = {};
            
            for ii = 1:length(obj.prefs)
                scans{ii} = linspace(obj.pdata{ii, 7}, obj.pdata{ii, 9}, obj.pdata{ii, 10}); %#ok<AGROW>
            end
            
            
            flags = struct( 'isContinuous',             obj.gui.continuous.Value,...
                            'isOptimize',               obj.gui.optimize.Value,...
                            'shouldOptimizeAfter',      obj.gui.optimizeAfterSweep.Value*(1-2*obj.gui.minimizeAfterSweep.Value),...
                            'shouldReturnToInitial',    obj.gui.returnToInitial.Value,...
                            'shouldSetInitialOnReset',  false);
            
            sweep = Base.Sweep(obj.measurements, obj.prefs(end:-1:1), scans(end:-1:1), flags, str2double(obj.gui.timePoint.String));
        end
    end
    
    methods     % Tables
        function update(obj)
            obj.setRowNumbers(true)
            obj.setRowNumbers(false)
            
            % Checks for optimize
            if obj.gui.optimize.Value
                obj.gui.numPoints.Enable = 'on';
                
                obj.gui.numPointsText.String = 'Number of Iterations:';
                obj.gui.numPointsText.TooltipString = 'Max number of iterations (MaxIter) for fminsearch().';
                
                obj.pt.ColumnWidth = obj.pwidthsopt;
            else
                obj.gui.numPoints.Enable = 'off';
                
                obj.gui.numPointsText.String = 'Number of Points:';
                obj.gui.numPointsText.TooltipString = 'Number of points in the sweep.';
                
                obj.gui.numPoints.String = obj.numPoints();
                
                obj.pt.ColumnWidth = obj.pwidths;
            end
            
            obj.gui.timeTotal.String = datestrCustom(str2double(obj.gui.numPoints.String) * str2double(obj.gui.timePoint.String));
            
            % Checks for continuous. Renames time unit to "ago" for scans ago if continuous.
            if numel(obj.prefs) > 0
                if isa(obj.prefs{1}, 'Prefs.Time') && ~obj.gui.optimize.Value
                    obj.gui.continuous.Enable = 'on';
                else
                    obj.gui.continuous.Enable = 'off';
                    obj.gui.continuous.Value = false;
                end
                
                if obj.gui.continuous.Value
                    obj.prefs{1}.unit = 'ago';
                    obj.pdata{1, 4} = 'ago';
                elseif isa(obj.prefs{1}, 'Prefs.Time')
                    obj.prefs{1}.unit = 'ave';
                    obj.pdata{1, 4} = 'ave';
                end
                
                for ii = 2:length(obj.prefs)
                    if isa(obj.prefs{ii}, 'Prefs.Time')
                        obj.prefs{ii}.unit = 'ave';
                        obj.pdata{ii, 4} = 'ave';
                    end
                end
            else
                obj.gui.continuous.Enable = 'off';
                obj.gui.continuous.Value = false;
            end
            
            % Checks for optimize afterward. Currently blocks for N > 1 prefs.
            if numel(obj.prefs) == 1 && ~isa(obj.prefs{1}, 'Prefs.Time')
                obj.gui.optimizeAfterSweep.Enable = 'on';
                obj.gui.minimizeAfterSweep.Enable = 'on';
            else
                obj.gui.optimizeAfterSweep.Enable = 'off';
                obj.gui.optimizeAfterSweep.Value = false;
                obj.gui.minimizeAfterSweep.Enable = 'off';
                obj.gui.minimizeAfterSweep.Value = false;
            end
            
            obj.pt.Data = obj.pdata;
            obj.mt.Data = obj.mdata;
        end
        
        function setRowNumbers(obj, isPrefs)
            if isPrefs
                mask = obj.getPrefsMask(); %1:obj.numRows(true);
                for ii = 1:length(mask)
                    if obj.gui.optimize.Value
                        obj.pdata{ii,1} = formatNumber(mask(ii), -1);
                    else
                        obj.pdata{ii,1} = formatNumber(mask(ii), max(mask));
                    end
                end
                obj.pdata{end,1} = formatNumber('+');
            else
                mask = obj.getMeasurementMask();
                for ii = 1:length(mask)
                    obj.mdata{ii,1} = formatNumber(mask(ii));
                end
                obj.mdata{end,1} = formatNumber('+');
                
            end
            
            function color = getColor(ii, gradient)
                if ischar(ii)
                    color = 'blue';
                else
                    if gradient == 0
                        if mod(ii, 2)
                            color = 'green';
                        else
                            color = 'purple';
                        end
                    else
                        % hot cold gradient to imply which prefs are being scanned the most.
                        color = sprintf('rgb(%i,0,%i)', 0 + floor(255*ii/gradient), 255 - floor(255*ii/gradient));
                    end
                end
            end
            function str = formatNumber(ii, gradient)
                if nargin < 2
                    gradient = 0;
                end
                
                if isnan(ii)
                    str = '';
                else
                    num = num2str(ii);
                    
                    if gradient < 0 && isnumeric(ii)
                        optnum = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
                        num = optnum(ii);
                    end
                    
                    str = sprintf('<html><tr align=center><td width=%d><font color=%s><b>%s', Base.SweepEditor.pwidths{1}, getColor(ii, gradient), num);
                end
            end
        end
        
        % ROW FUNCTIONS %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%%
        function setRow(obj, instrument, isPrefs)
            if isPrefs
                if ~isa(instrument, 'Prefs.Time')   % Time can be added as many times as desired.
                    for ii = 1:length(obj.prefs)
                        if obj.pselected ~= ii
                            if isequal(instrument, obj.prefs{ii})
                                helpdlg(sprintf('Cannot add duplicate pref: %s.%s.', instrument.parent.encodeReadable(), instrument.property_name))
                                return;
                            end
                        end
                    end
                end
                
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
                    obj.measurements{end+1} = instrument;
                else
                    obj.measurements{obj.mselected} = instrument;
                end
                obj.mdataGenerate();
            end
            
            obj.update();
        end
        function mdataGenerate(obj)
            mdata_ = centerCharsMeasurements(obj.makeMeasurementRow([]));
            
            jj = 1;
            
            for ii = 1:length(obj.measurements)
                instrument = obj.measurements{ii};
                cm = centerCharsMeasurements(obj.makeMeasurementRow(instrument));
                
                mdata_(jj:(jj+size(cm, 1)-1), :) = cm;
                jj = jj + size(cm, 1);
            end
            
            mdata_(end+1, :) = centerCharsMeasurements(obj.makeMeasurementRow([]));
            
            obj.mdata = mdata_;
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
%                     mask = obj.getMeasurementMask();
%                     mask2 = obj.getMeasurementMask() == mask(obj.mselected);
                    mask2 = obj.getMeasurementMask() == obj.mselected;
                    obj.mdata(mask2, :) = [];
                    obj.measurements(obj.mselected) = [];
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
                helpdlg('Swapping measurements currently disabled due to implementation complexity.');
%                 mask1 = obj.getMeasurementMask() == r1;
%                 mask2 = obj.getMeasurementMask() == r2;
%                 
%                 tmp = obj.mdata(mask1, :);
% %                 obj.mdata(mask1, :) = [];
%                 
%                 obj.mdata(mask1, :) = obj.mdata(r2, :);
%                 obj.mdata(mask2, :) = tmp;
%                 
%                 tmp = obj.measurements{r1};
%                 obj.measurements{r1} = obj.measurements{r2};
%                 obj.measurements{r2} = tmp;
            end

            obj.update;
        end
        
        function d = makePrefRow(~, p)          % Make a uitable row for a pref.
            if isempty(p)
                d = {'<html><font color=blue><b>+', '', '<font color="gray"><i>Right Click to Add Prefs', '', [], [], [], [], [], [], [], [], [], [], [] , [] };
            else
                str = p.name;

                if isempty(str)
                    str = strrep(p.property_name, '_', ' ');
                end
                
                N = 11;
                m = p.min;
                M = p.max;
                
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
                
                x = p.read();

                d = {'<html><font color=red><b>',     ['<i>' p.parent.encodeReadable(true)], formatMainName(str, p.property_name), p.unit, p.min, p.max, m, dx, M, N, false, false, makeSweepStr(m, M, dx), p.min, x, p.max };
            end
        end
        function d = makeMeasurementRow(~, m)   % Make a uitable row for a measurement
            if isempty(m)
%                 mheaders =  {'#',                 'Parent', 'Subdata', 'Size', 'Unit', 'Integration'};
                d = {'<html><font color=blue><b>+', '', '<font color="gray"><i>Right Click to Add Measurements', '', '', 0 };
            else
                subdata = m.subdata;
                sizes = m.getSizes;
                units = m.getUnits;
                names = m.getNames;
                
                d = [];
                
                if ismember('Base.Pref', superclasses(m))
                    parent = m.parent.encodeReadable(true);
                else
                    parent = m.encodeReadable(true);
                end
                
                for ii = 1:length(subdata)
                    sd = subdata{ii};
                    d = [d ; {'<html><font color=red><b>',   ['<i>' parent], formatMainName(names.(sd), sd), ['[' num2str(sizes.(sd)) ']'], units.(sd), 0 }]; %#ok<AGROW>
                end
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
            Ns = cell2mat(obj.pdata(1:obj.numRows(true), 10));
            Ns = Ns(~cell2mat(obj.pdata(1:obj.numRows(true), 11)));
            N = prod(Ns);
        end
        
        % CALLBACKS %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%% %%%%%
        function setSingleTime_Callback(obj, ~, ~)
            try
                x = eval(obj.gui.timePoint.String);  % Not great...
                assert(isnumeric(x));
                assert(~isnan(x));
                assert(numel(x) == 1);
                obj.gui.timePoint.String = x;
            catch
                obj.gui.timePoint.String = 1;
            end
            obj.update();
        end
        function setContinuous_Callback(obj, ~, ~)
            if obj.gui.continuous.Value && obj.numRows(true) >= 2
            	obj.pdata{2, 11} = false;    
            end
            
            obj.update();
        end
        function setOptimize_Callback(obj, ~, ~)
            if obj.gui.optimize.Value
                obj.gui.numPoints.String = 100;
            end
            obj.update();
        end
        
        function good = edit_Callback(obj, src, evt)
            isPrefs = src.UserData.UserData;

            good = true;
            
            if isPrefs
%                 obj.pheaders{evt.Indices(2)}
                ind = evt.Indices;
                
                r = ind(1);
                
                if r > obj.numRows(isPrefs)    % We are in the + row.
%                     obj.pdata{r, ind(2)} = evt.PreviousData;
                    obj.update();
                    return;
                end
                
                m = obj.pdata{r, 5};
                M = obj.pdata{r, 6};
                
                p = obj.prefs{r};
                isInteger = isPrefInteger(p);
                isBoolean = isPrefBoolean(p);
                
                if strcmp(obj.pheaders{evt.Indices(2)}, 'Pair') % 11
                    if r > 1 + obj.gui.continuous.Value
                        obj.pdata{r, 11} = evt.NewData;
                        
                        if evt.NewData
                            N = obj.pdata{r-1, 10};
                        else
                            N = obj.pdata{r, 10};
                        end
                            
                        x = r;
                        
                        % Scan up and down the column setting N data to be the same as the parent.
                        while x <= obj.numRows(isPrefs) && obj.pdata{x, 11} && x >= r
                            srcFake.UserData.UserData = true;
                            
                            evtFake.Indices         = [x, 10];  % N
                            evtFake.PreviousData    = obj.pdata{x, 10};
                            evtFake.EditData        = N;
                            evtFake.NewData         = N;
                            evtFake.EventName       = 'CellEditNoUpdate';
                            
                            good = obj.edit_Callback(srcFake, evtFake);
                            
                            x = x - 1 + 2*good;
                        end
                    end
                end
                
                ndata = evt.NewData;
                
                if isnan(ndata) && ischar(evt.EditData)
                    ndata = str2num(evt.EditData); %#ok<ST2NM>
                end
                
                if isempty(ndata)
                    ndata = NaN;
                end
                
                if isa(p, 'Prefs.Time')     % Time should always be of the form X1, Step, X2, N = 1, 1, M, M
                    switch obj.pheaders{evt.Indices(2)}
                        case {'X1', 'Step'}   % 7, 8
                            good = false;
                        case {'X2', 'N'}    % 9, 10
                            obj.pdata{r, 7}  = 1;
                            obj.pdata{r, 8}  = 1;
                            obj.pdata{r, 9} = ndata;
                            obj.pdata{r, 10} = ndata;
                    end
                else
                    switch obj.pheaders{evt.Indices(2)}
                        case 'X1'       % 7
                            X0 = min(M, max(m, ndata));
                            if isInteger, X0 = round(X0); end
                            if isBoolean, X0 = logical(X0); end
                            obj.pdata{r, 7} = X0;

                            obj.updateStep(r);
                        case 'Step'     % 8
                            Step = ndata;

                            if obj.pdata{r, 8} > 0 && Step > 0 || obj.pdata{r, 8} < 0 && Step < 0
                                obj.pdata{r, 8} = Step;

                                N = floor((obj.pdata{r, 9} - obj.pdata{r, 7} + Step) / Step);
                                N = max(2, N);
                                obj.pdata{r, 10} = N;
                            else
                                good = false;
                            end
                        case 'X2'       % 9
                            X1 = max(m, min(M, ndata));
                            if isInteger, X1 = round(X1); end
                            if isBoolean, X1 = logical(X1); end
                            obj.pdata{r, 9} = X1;

                            obj.updateStep(r);
                        case 'N'        % 10
                            N = round(ndata);
                            if N < 2
                                good = false;
    %                             obj.pdata{r, 10} = N;
    %                             obj.pdata{r, 8} = 0;
    %                             obj.pdata{r, 9} = obj.pdata{r, 7};
                            elseif N > 0 && obj.pdata{r, 8} ~= 0
                                obj.pdata{r, 10} = N;
                                obj.pdata{r, 8} = (obj.pdata{r, 9} - obj.pdata{r, 7}) / (N - 1);
                            else
                                good = false;
                            end
                        case 'ZigZag'   % 12
                            obj.pdata{r, 12} = ndata;
                    end
                end
                
                Step = obj.pdata{r, 8};
                
                if isInteger && good
                    if abs(Step) < 1 && Step ~= 0
                        Step = Step/abs(Step);
                    else
                        Step = round(Step);
                    end
                    
                    N = (obj.pdata{r, 9} - obj.pdata{r, 7} + Step) / Step;
                    
                    if N ~= floor(N)
                        N = floor(N);
                        
                        obj.pdata{r, 8} = Step;
                        obj.pdata{r, 9} = obj.pdata{r, 7} + (N-1)*Step;
                        if isBoolean, obj.pdata{r, 9} = logical(obj.pdata{r, 9}); end
                        obj.pdata{r, 10} = N;
                    else
                        obj.pdata{r, 8} = Step;
                        obj.pdata{r, 10} = N;
                    end
                end
                
                if good
                    sweep = obj.pdata{r, 7}:obj.pdata{r, 8}:obj.pdata{r, 9};
                    
                    try
                        for s = sweep
                            obj.prefs{r}.validate(s);
                        end
                    catch err
                        warning(err.message);
                        good = false;
                    end
                end

                if ~good
                    obj.pdata = obj.pt.Data;
                    obj.pdata{r, ind(2)} = evt.PreviousData;
                else
                    obj.pdata{r, 13} = makeSweepStr(obj.pdata{r, 7}, obj.pdata{r, 9}, obj.pdata{r, 8});
                end
                
                if ~strcmp(evt.EventName, 'CellEditNoUpdate')
                    obj.update();
                end
            else    % Measurements edit; currently nothing here.
                
            end
        end
        function updateStep(obj, ind)
            N = obj.pdata{ind, 10};
            if N == 1
                N = 2;
            end
            dX = (obj.pdata{ind, 9} - obj.pdata{ind, 7}) / (N - 1);
            
            if dX ~= 0
                obj.pdata{ind, 8} = dX;
                obj.pdata{ind, 10} = N;
            end
        end
        
        function buttondown_Callback(obj, src, ~)
            cp = src.UserData.CurrentPoint(1,:);    % This value is generated by the axes that sit on top of the uitable. The y-coordinate is aligned with the rows.
            yi = floor(cp(2));

            N = size(src.Data, 1)-1;
            
            isPrefs = src.UserData.UserData;

            if yi <= N && yi > 0
                if isPrefs
                    obj.pselected = yi;
                    
                    src.UIContextMenu.Children(end).Label = ['Pref #' num2str(yi)];
                    
                    % help_text is in html and cannot be diplayed. Still keeping this around in case it is useful in the future.
%                     src.UIContextMenu.Children(end).Enable = 'on';
%                     obj.prefs{yi}
%                     src.UIContextMenu.Children(end).Callback = @(s,e)(helpdlg(obj.prefs{yi}.help_text, obj.prefs{yi}.name));
                else
                    % Measurements are indexed by Measurement, not by Meas.
                    yi = obj.getMeasurementIndex(yi);
                    obj.mselected = yi;
                    N = num(obj, false);
                    
                    src.UIContextMenu.Children(end).Label = ['Measurement #' num2str(yi)];
%                     src.UIContextMenu.Children(end).Enable = 'on';
%                     src.UIContextMenu.Children(end).Callback = @(s,e)(helpdlg());
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
            else
                if isPrefs
                    obj.pselected = 0;
                    src.UIContextMenu.Children(end).Label = 'Add Pref';
                else
                    obj.mselected = 0;
                    src.UIContextMenu.Children(end).Label = 'Add Measurement';
                end

                src.UIContextMenu.Children(end).Enable = 'off';     % Title
                src.UIContextMenu.Children(end-1).Enable = 'off';   % Up
                src.UIContextMenu.Children(end-2).Enable = 'off';   % Down
                src.UIContextMenu.Children(end-3).Enable = 'off';   % Delete
            end

            drawnow;
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
        function mask = getPrefsMask(obj)
            if obj.gui.optimize.Value
                mask = [];
                kk = 1;
                for ii = 1:length(obj.prefs)
                    if isa(obj.prefs{ii}, 'Prefs.Time')
                        mask = [mask NaN]; %#ok<AGROW>
                    else
                        mask = [mask kk]; %#ok<AGROW>
                        kk = kk + 1;
                    end
                end
            else
                mask = [];
                kk = 1;
                for ii = 1:length(obj.prefs)
                    if obj.pdata{ii, 11}    % Pair
                        kk = kk - 1;
                    end
                    mask = [mask kk]; %#ok<AGROW>
                    kk = kk + 1;
                end
            end
        end
        function mask = getMeasurementMask(obj)
            mask = [];
            obj.measurements
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
    for ii = 1:(numel(ca))
%         if ii == 1
%             ca{ii} = sprintf('<html><tr align=center><td width=%d>%s', Base.SweepEditor.pwidths{ii}, ca{ii});
% else
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
function tf = isPrefBoolean(p)
    tf = isa(p, 'Prefs.Boolean');
end
function str = datestrCustom(t)
    if t > 31*60*60*24
        str = 'Insanity';
    else
        t = ceil(t);
        str = '';
        
        for mm = [60, 60, 24, 31]
            if t > 0 || mm == 60
                str = [sprintf('%02i', mod(t, mm)) ':' str]; %#ok<AGROW>
                t = floor(t/mm);
            end
        end
        
        if str(1) == '0'
            str = str(2:end-1);
        else
            str = str(1:end-1);
        end
    end
%     elseif t > 60*60*24
%         str = datestr(t/60/60/24, 'DD:HH:MM:SS');
%     elseif t > 60*60
%         str = datestr(t/60/60/24, 'HH:MM:SS');
%     else
%         str = datestr(t/60/60/24, 'MM:SS');
%     end
end
