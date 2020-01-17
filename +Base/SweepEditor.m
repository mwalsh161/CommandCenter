classdef SweepEditor < handle
    % SweepEditor is a UI to help the user make a sweep.

    properties (Constant, Hidden)
        pheaders =      {'#',       'Parent',  'Pref',     'Unit',     'Min',      'Max',      'X0',       'dX',       'X1',       'N',         'Sweep'};
        pheadersOpt =   {'#',       'Parent',  'Pref',     'Unit',     'Min',      'Max',      'X0',       'Guess',    'X1',       'N',         'Sweep'};
        peditable =     [false,     false,     false,      false,      false,      false,      true,       true,       true,       true,        false];
        peditableOpt =  [false,     false,     false,      false,      false,      false,      true,       true,       true,       false,       false];
        pwidths =       {25,        160,       160,        40,         40,         40,         40,         40,         40,         40,          80};
        pformat =       {'char',    'char',    'char',     'char',     'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'numeric',   'numeric'};
%         pformatOpt =    {'char',    'char',    'char',     'char',     'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'numeric',   'numeric'};
%         pformat =   {'char',    'char',    'char',     'char',     'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'char'};

        mheaders =  {'#',       'Measurement', 'Subdata',   'Size',    'Unit',     'Time'};
        meditable = [false,     false,         false,       false,      false,      true];
        mwidths =   {25,        160,           160,         50,         50,         50};
        mformat =   {'char',    'char',        'char',      'char',     'char',     'numeric'};
    end

    properties
        pdata;
        mdata;
        
        prefs;
        measurements;
    end

    properties
        f;                          % Figure
        
        pt;                         % Prefs table
        mt;                         % Measurements table
        
        gui;

        pmenu;
        mmenu;
    end

    properties
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
            dp = 110;
            p = [10, h + 6, dp, 17];
            
            obj.gui.continuous          = uicontrol('String', 'Continuous',...
                                                    'Tooltip', '',...
                                                    'Style', 'checkbox',...
                                                    'Units', 'pixels',...
                                                    'Enable', 'off',...
                                                    'Position', p);    p(1) = p(1) + dp;
            obj.gui.optimize            = uicontrol('String', 'Optimize',...
                                                    'Tooltip', '',...
                                                    'Style', 'checkbox',...
                                                    'Units', 'pixels',...
                                                    'Position', p);    p(1) = p(1) + dp;
            obj.gui.returnToInitial     = uicontrol('String', 'Return to Initial',...
                                                    'Tooltip', '',...
                                                    'Style', 'checkbox',...
                                                    'Value', true,...
                                                    'Units', 'pixels',...
                                                    'Position', p);    p(1) = p(1) + dp;
            obj.gui.optimizeAfterSweep  = uicontrol('String', 'Optimize Afterward',...
                                                    'Tooltip', '',...
                                                    'Style', 'checkbox',...
                                                    'Units', 'pixels',...
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
    
    methods     % Menus
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
                    obj.prefs{obj.pselected} = [];
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
                d = {'<html><font color=blue><b>+', '<i>...', '<b>... <font face="Courier" color="gray">(...)</font>', '...', [], [], [], [], [], [], [] };
            else
                str = p.name;

                if isempty(str)
                    str = strrep(p.property_name, '_', ' ');
                end

                d = {'<html><font color=red><b>',     ['<i>' p.parent_class], formatMainName(str, p.property_name), p.unit, p.min, p.max, p.min,    .1,    p.max,   11,  '0:.1:1' };
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
            N = prod(cell2mat(obj.pdata(1:obj.numRows(true), 10)));
        end
        
        function edit_Callback(obj, src, evt)
            isPrefs = src.UserData.UserData;
            
%             src
            evt
%             
%             src.Data{evt.Indices(1), evt.Indices(2)}

            good = true;
            
            if isPrefs
%                 obj.pheaders{evt.Indices(2)}
                ind = evt.Indices;
                m = obj.pdata{ind(1), 5};
                M = obj.pdata{ind(1), 6};
                switch obj.pheaders{evt.Indices(2)}
                    case 'X0'   % 7
                        X0 = max(m, min(M, evt.NewData));
                        X0
                        obj.pdata{ind(1), 7} = X0;
                        obj.updatedX(ind(1));
                        obj.update();
                    case 'dX'   % 8
                    case 'X1'   % 9
                        X1 = max(m, min(M, evt.NewData));
                        X1
                        obj.pdata{ind(1), 9} = X1;
                        obj.updatedX(ind(1));
                        obj.update();
                    case 'N'   % 10
                        N = round(evt.NewData);
                        if N == 1
                            obj.pdata{ind(1), 10} = N;
                            obj.pdata{ind(1), 8} = 0;
                            obj.pdata{ind(1), 9} = obj.pdata{ind(1), 7};
                        elseif N > 0 && obj.pdata{ind(1), 8} > 0
                            obj.pdata{ind(1), 10} = N;
                            obj.pdata{ind(1), 8} = (obj.pdata{ind(1), 9} - obj.pdata{ind(1), 7}) / (obj.pdata{ind(1), 10} - 1);
                        else
                            good = false;
                        end
                end
                
                if ~good
                    obj.pdata{ind(1), ind(2)} = evt.PreviousData;
                end
                
                obj.update();
            else
                
            end
%             selected_cells = evt.Indices;
        end
        function updatedX(obj, ind)
            dX = (obj.pdata{ind, 9} - obj.pdata{ind, 7}) / (obj.pdata{ind, 10} - 1);
            
            if dX ~= 0
                obj.pdata{ind(1), 8} = dX;
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
                    N = num(obj, false)
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
