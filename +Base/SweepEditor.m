classdef SweepEditor < handle
    % SweepEditor is a UI to help the user make a sweep.

    properties (Constant)
        pheaders =  {'#',       'Parent',  'Pref',     'Units',    'Min',      'Max',      'X0',       'dX',       'X1',       'N',        'Sweep'};
        peditable = [false,     false,     false,      false,      false,      false,      true,       true,       true,       true,       true];
        pwidths =   {20,        150,       150,        40,         40,         40,         40,         40,         40,         40,         150};
        pformat =   {'char',    'char',    'char',     'char',     'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'numeric',  'char'};
        
        mheaders =  {'#',       'Measurement', 'Units',    'Integration'};
        meditable = [false,     false,         false,      true];
        mwidths =   {20,        150,           150,        100};
        mformat =   {'char',    'char',        'char',     'numeric'};
    end

    properties
        pt;
        mt;
    end
    
    methods
		function obj = SweepEditor()
            
            dp = [ centerChars(obj.makePrefRow(0)) ; centerChars(obj.makePrefRow(0)) ; centerChars(obj.makePrefRow([])) ];
            dm = [ centerChars(obj.makeMeasurementRow(0)) ; centerChars(obj.makeMeasurementRow([])) ];
            
            
            size(dp, 2)
            
            for ii = 1:size(dp, 1)-1
                dp{ii,1} = [dp{ii,1} num2str(ii)];
            end
            for ii = 1:size(dm, 1)-1
                dm{ii,1} = [dm{ii,1} num2str(ii)];
            end
            
            padding = 50;
            
            w = obj.totalWidth(true) + obj.totalWidth(false) + padding;
            h = 300;
            
            
            
            f = figure( 'NumberTitle', 'off', 'name', 'SweepEditor', 'MenuBar', 'None',...
                        'Toolbar', 'None', 'Resize', 'off'); %, 'Visible', 'off', 'KeyPressFcn', '', 'CloseRequestFcn', '');
            
            f.Position(3) = w;
            f.Position(4) = h + padding;
            
            menu = uicontextmenu(f);
            fish = uimenu(menu, 'label', 'fish', 'Callback', @obj.rightclick_Callback);
            uimenu(fish, 'label', 'fish', 'Callback', @obj.rightclick_Callback);
            uimenu(menu, 'label', 'dish', 'Callback', @obj.rightclick_Callback);
            uimenu(menu, 'label', 'swish', 'Callback', @obj.rightclick_Callback);
            
            obj.pt =    uitable('Data', dp,...
                                'ColumnEditable',   obj.peditable, ...
                                'ColumnName',       obj.processHeaders(true),...
                                'ColumnFormat',     obj.pformat, ...
                                'ColumnWidth',      obj.pwidths, ...
                                'RowName',          [],...
                                'Units', 'pixels', 'Position', [0, 0, obj.totalWidth(true), h],...
                                'CellSelectionCallback', @obj.selection_Callback,...
                                'UIContextMenu', menu);
            
            obj.mt =    uitable('Data', dm,...
                                'ColumnEditable',   obj.meditable, ...
                                'ColumnName',       obj.processHeaders(false),...
                                'ColumnFormat',     obj.mformat, ...
                                'ColumnWidth',      obj.mwidths, ...
                                'RowName',          [],...
                                'Units', 'pixels', 'Position', [obj.totalWidth(true)+padding, 0, obj.totalWidth(false), h],...
                                'CellSelectionCallback', @obj.selection_Callback,...
                                'UIContextMenu', menu);
                   
%          	obj.setRowNames(true, 2)
                            
            % Display the uitable and get its underlying Java object handle
%             [mtable,hcontainer] = uitable('v0', gcf, magic(3), {'A', 'B', 'C'});   % discard the 'v0' in R2007b and earlier
%             methods(obj.mt)

%             jtable = obj.mt.Table;   % or: get(mtable,'table');
            % We want to use sorter, not data model...
            % Unfortunately, UitablePeer expects DefaultTableModel not TableSorter so we need a modified UitablePeer class
            % But UitablePeer is a Matlab class, so use a modified TableSorter & attach it to the Model
%             if ~isempty(which('TableSorter'))
%                 % Add TableSorter as TableModel listener
%                 sorter = TableSorter(jtable.getModel());
%                 jtable.setModel(sorter);
%                 sorter.setTableHeader(jtable.getTableHeader());
%                 % Set the header tooltip (with sorting instructions)
%                 jtable.getTableHeader.setToolTipText('<html>&nbsp;<b>Click</b> to sort up; <b>Shift-click</b> to sort down<br />&nbsp;...</html>');
%             else
%                 % Set the header tooltip (no sorting instructions...)
%                 jtable.getTableHeader.setToolTipText('<html>&nbsp;<b>Click</b> to select entire column<br />&nbsp;<b>Ctrl-click</b> (or <b>Shift-click</b>) to select multiple columns&nbsp;</html>');
%             end
                                
                                
%             addStyle(measurements, uistyle('FontColor', .5*[1 1 1], 'FontWeight', 'italics'), 'column', 2);
        end
        function sweep = generate(obj)
            
        end
        function d = makePrefRow(obj, p)  % Make a uitable row
            if isempty(p)
                d = {'<html><font color=blue><b>+',   '<i>...', '<b>...', '', [], [], [],    [],    [],   [],  '' };
            else
                d = {'<html><font color=red><b>',      '<i>Drivers.NIDAQ', '<b>Piezo Z (ao3)', 'V', 0, 10, 0,    .1,    1,   11,  '0:.1:1' };
            end
        end
        function d = makeMeasurementRow(obj, m)  % Make a uitable row
            if isempty(m)
                d = {'<html><font color=blue><b>+',   '<i>...', '<b>...', 0 };
            else
                d = {'<html><font color=red><b>',      '<i>Drivers.NIDAQ', '<b>APD1 (ctr0)', 0 };
            end
        end
%         function rn = rowNames(obj, N)
%             rn = num2cell(1:(N+1));
%             rn{end} = '+';
%         end
%         function rn = rowNamesHTML(obj, N)
%             rn = {};
%             
%             for ii = 1:N
%                 rn{end+1} = ['<html><font color=red><b>' num2str(ii)];
%             end
%             
%             rn{end+1} = '<html><font color=purple><b>+';
%         end
        function setRowNames(obj, isPrefs, N)
            if isPrefs
                t = obj.pt;
            else
                t = obj.mt;
            end
            
            pause(1)
            
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
%             selected_cells = event.Indices
            properties(src)
            properties(evt)
            
            src.Position
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