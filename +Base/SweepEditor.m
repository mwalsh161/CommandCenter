classdef SweepEditor < handle
    % SweepEditor is a UI to help the user make a sweep.

    properties (Constant, Hidden)
        pheaders =  {'#',       'Parent',  'Pref',     'Units',    'Min',      'Max',      'X0',       'dX',       'X1',       'N',        'Sweep'};
        peditable = [false,     false,     false,      false,      false,      false,      true,       true,       true,       true,       true];
        pwidths =   {20,        150,       150,        40,         40,         40,         40,         40,         40,         40,         150};
        pformat =   {'char',    'char',    'char',     'char',     'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'numeric'};
%         pformat =   {'char',    'char',    'char',     'char',     'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'char'};

        mheaders =  {'#',       'Measurement', 'Subdata',   'Units',    'Time'};
        meditable = [false,     false,         false,       false,      true];
        mwidths =   {20,        150,           150,         50,        50};
        mformat =   {'char',    'char',        'char',     'char',     'numeric'};
    end

    properties
        pdata;
        mdata;
    end

    properties
        pt;
        mt;

        pmenu;
        mmenu;
    end

    properties
        pselected

        maxelements
    end

    methods
		function obj = SweepEditor()
            apt = Drivers.AxisTest.instance('Test');

            x = apt.get_meta_pref('x');
            y = apt.get_meta_pref('y');
            bool = apt.get_meta_pref('bool');

            obj.pdata = [ centerChars(obj.makePrefRow(x)) ; centerChars(obj.makePrefRow(y)) ; centerChars(obj.makePrefRow(bool)) ; centerChars(obj.makePrefRow([])) ];
            obj.mdata = [ centerChars(obj.makeMeasurementRow(0)) ; centerChars(obj.makeMeasurementRow(0)) ; centerChars(obj.makeMeasurementRow(0)) ; centerChars(obj.makeMeasurementRow([])) ];


%             size(obj.pdata, 2)

            for ii = 1:size(obj.pdata, 1)-1
                obj.pdata{ii,1} = [obj.pdata{ii,1} num2str(ii)];
            end
            for ii = 1:size(obj.mdata, 1)-1
                obj.mdata{ii,1} = [obj.mdata{ii,1} num2str(ii)];
            end

            padding = 30;

            w = obj.totalWidth(true) + obj.totalWidth(false)
            h = 400;
            rh = 17;
            obj.maxelements = floor(h/rh)-1;

            f = figure( 'NumberTitle', 'off', 'name', 'SweepEditor', 'MenuBar', 'None',...
                        'Toolbar', 'None', 'Resize', 'off'); %, 'Visible', 'off', 'KeyPressFcn', '', 'CloseRequestFcn', '');

            f.Position(3) = w;
            f.Position(4) = h + padding;

            obj.pmenu = uicontextmenu(f);
            obj.mmenu = uicontextmenu(f);

            uimenu(obj.pmenu, 'label', 'Pref 0', 'Enable', 'off');
            uimenu(obj.pmenu, 'label', [char(8679) ' Move Up'], 'Callback', @(s,e)obj.move);
            uimenu(obj.pmenu, 'label', [char(8681) ' Move Down'], 'Callback', @obj.rightclick_Callback);

            uimenu(obj.pmenu, 'label', 'Time', 'Separator', 'on', 'Callback', @(s,e)(obj.setRow(Prefs.Empty('Time', 1))));

            pr = Base.PrefRegister.instance();
            pr.getMenu(obj.pmenu, @(x)(obj.setRow(x)), 'readonly', false);

            ptPosition = [0, 0, obj.totalWidth(true), h];
            mtPosition = [obj.totalWidth(true), 0, obj.totalWidth(false), h];

            apt = axes('Visible', 'off', 'Units', 'pixels', 'Position', ptPosition);
            amt = axes('Visible', 'off', 'Units', 'pixels', 'Position', mtPosition);

            obj.pt =    uitable('Data', obj.pdata,...
                                'ColumnEditable',   obj.peditable, ...
                                'ColumnName',       obj.processHeaders(true),...
                                'ColumnFormat',     {},... obj.pformat, ...
                                'ColumnWidth',      obj.pwidths, ...
                                'RowName',          [],...
                                'Units', 'pixels', 'Position', ptPosition,...
                                'CellSelectionCallback', @obj.selection_Callback,...
                                'UIContextMenu', obj.pmenu,...
                                'ButtonDownFcn', @obj.buttondown_Callback,...
                                'UserData', apt);

%             jScrollPane = findjobj(obj.pt);
%             jtable = jScrollPane.getViewport.getView;
%             rh = jtable.getRowHeight()

            xlim(apt, [0, ptPosition(3)]);
            ylim(apt, [0, ptPosition(4)/rh]);
            apt.YDir = 'reverse';

            obj.mt =    uitable('Data', obj.mdata,...
                                'ColumnEditable',   obj.meditable, ...
                                'ColumnName',       obj.processHeaders(false),...
                                'ColumnFormat',     {},... obj.mformat, ...
                                'ColumnWidth',      obj.mwidths, ...
                                'RowName',          [],...
                                'Units', 'pixels', 'Position', mtPosition,...
                                'CellSelectionCallback', @obj.selection_Callback,...
                                'UIContextMenu', obj.mmenu,...
                                'ButtonDownFcn', @obj.buttondown_Callback,...
                                'UserData', amt);

            xlim(amt, [0, mtPosition(3)]);
            ylim(amt, [0, mtPosition(4)/rh]);
            amt.YDir = 'reverse';
        end
        function sweep = generate(obj)

        end
        function setRow(obj, pref)
            pref

            obj.update();
        end
        function update(obj)
            obj.pt.Data = obj.pdata;
            obj.mt.Data = obj.mdata;
        end
        function d = makePrefRow(obj, p)  % Make a uitable row
            if isempty(p)
                d = {'<html><font color=blue><b>+', '<i>...', '<b>... <font face="Courier" color="gray">(...)</fonnt>', '...', '...', '...', '...', '...', '...', '...', '...' };
            else
                str = p.name;

                if isempty(str)
                    str = strrep(p.property_name, '_', ' ');
                end

                d = {'<html><font color=red><b>',     ['<i>' p.parent_class], ['<b>' str ' (<font face="Courier" color="green">.' p.property_name '</font>)'], p.unit, p.min, p.max, p.min,    .1,    p.max,   11,  '0:.1:1' };
%                 d = {'<html><font color=red><b>',      '<i>Drivers.NIDAQ', '<b>Piezo Z (ao3)', 'V', 0, 10, 0,    .1,    1,   11,  '0:.1:1' };
            end
        end
        function d = makeMeasurementRow(obj, m)  % Make a uitable row
            if isempty(m)
%                 mheaders =  {'#',       'Parent', 'Subdata',   'Units',    'Integration'};
                d = {'<html><font color=blue><b>+',   '<i>...', '<b>...', '...', 0 };
            else
                d = {'<html><font color=red><b>',      '<i>Drivers.NIDAQ.cin', '<b>APD1 (<font face="Courier" color="green">.ctr0</font>)', 'cts/sec', 0 };
            end
        end
        function setRowNames(obj, isPrefs, N)
            if isPrefs
                t = obj.pt;
            else
                t = obj.mt;
            end

            t.RowName = obj.rowNamesHTML(N);

%             jscroll=findjobj(t);
%             rh = jscroll.getRowHeader
% %             methods(jscroll)
% %             properties(jscroll)
% %             rowHeaderViewport=jscroll.getComponent(6);
% %             rowHeader=rowHeaderViewport.getComponent(0);
%             h=rh.getSize
% %             properties(h)
% %             methods(h)
% %             h.getHeight
%             rh.setSize(80,h.getHeight)
        end
        function selection_Callback(obj, src, evt)
            selected_cells = evt.Indices
        end
        function rightclick_Callback(obj, src, evt)
% %             selected_cells = event.Indices
%             properties(src)
%             properties(evt)
%
%             src.Clipping
%             src.Position
%             src.Parent.Position
%             src.Parent
%             properties(src.Parent)
%             src.Parent.Parent
%
% %             properties(evt.Source)
% %             src
% %             evt.Source
%             evt.EventName
        end
        function buttondown_Callback(obj, src, evt)
            cp = src.UserData.CurrentPoint(1,:);
            yi = floor(cp(2));

            N = size(src.Data, 1);

            if yi < N && yi > 0
                obj.pselected = yi;
                src.UIContextMenu.Children(end).Label = ['Pref ' num2str(yi)];

                if yi ~= 1
                    src.UIContextMenu.Children(end-1).Enable = 'on';
                else
                    src.UIContextMenu.Children(end-1).Enable = 'off';
                end
                if yi ~= N-1
                    src.UIContextMenu.Children(end-2).Enable = 'on';
                else
                    src.UIContextMenu.Children(end-2).Enable = 'off';
                end
            else
                obj.pselected = 0;
                src.UIContextMenu.Children(end).Label = 'New Pref';

                src.UIContextMenu.Children(end-1).Enable = 'off';
                src.UIContextMenu.Children(end-2).Enable = 'off';
            end

            drawnow;
        end
        function swap(obj, r1, r2, isPrefs)
            tmp = obj.pdata{r1, :};
            obj.pdata{r1, :} = obj.pdata{r2, :};
            obj.pdata{r2, :} = tmp;

            obj.update;
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
    end
end


function ca = centerChars(ca)
    for ii = 1:(numel(ca)-1)
        if ischar(ca{ii})
            ca{ii} = sprintf('<html><tr align=center><td width=%d>%s', Base.SweepEditor.pwidths{ii}, ca{ii});
        end
    end
end
