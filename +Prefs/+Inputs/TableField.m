classdef TableField < Base.Input
    %TABLEFIELD provides interface to MATLAB uitable
    %   The property "props" is passed directuly to uitable. There will be an
    %   error if you attempt to pass some reserved properties. For example,
    %   CellEditCallback, units, tag, enable, ColumnEditable are all required
    %   for operation of this field (some of which can be controlled via pref properties).
    %   https://www.mathworks.com/help/matlab/ref/matlab.ui.control.table-properties.html
    %   Some particularly useful properties are:
    %       ColumnFormat, ColumnName, RowName
    %
    %   The size of the table is not dynamic, so while it supports the Data size
    %   changing, it may result in undesired rendering.

    properties
        label = gobjects(0);
        ui = gobjects(1);
    end
    properties % Table properties
        hide_label = false; % uitables can have column names, so allow hiding label
        ColumnFormat = {};
        props = {};
        ForceFit = false; % Forces all columns to fit in width
    end

    methods
        function tf = isvalid(obj)
            tf = isgraphics(obj.ui) && isvalid(obj.ui);
        end
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px,margin)
            % Line 1: Label
            % Line 2: uitable
            % Prepare/format values
            label_width_px = 0;
            tag = strrep(pref.name,' ','_');
            enabled = 'on';
            if pref.readonly
                enabled = 'off';
            end
            labeltext = pref.name;
            if ~isempty(pref.unit)
                labeltext = sprintf('%s [%s]', pref.name, pref.unit);
            end
            height_px = 0;
            obj.ui = uitable(parent, 'units', 'pixels',...
                        'Data', pref.value,...
                        'RowName',{}, 'ColumnName',{},...
                        'ColumnFormat', obj.ColumnFormat,...
                        'ColumnEditable', true,...
                        'tag', tag,...
                        'enable', enabled,...
                        'UserData', struct('callback',[]),...
                        obj.props{:});
            % We need to specify width here because it may impact height (scroll bar)
            indent = margin(1) + margin(1)*not(obj.hide_label);
            obj.ui.Position(1) = indent;
            obj.ui.Position(3) = width_px - indent - margin(2);
            scroll_bar_pad = 15*(obj.ui.Position(3) < obj.ui.Extent(3));
            obj.ui.Position(4) = obj.ui.Extent(4) + scroll_bar_pad;
            obj.ui.Position(2) = yloc_px + height_px;
            height_px = obj.ui.Position(4);

            if ~obj.hide_label
                obj.label = uicontrol(parent, 'style', 'text',...
                            'string', [labeltext ': '],...
                            'horizontalalignment', 'right',...
                            'units', 'pixels',...
                            'tag', [tag '_label']);
                obj.label.Position(2) = yloc_px + height_px;
                label_width_px = obj.label.Extent(3);
                height_px = height_px + obj.label.Position(4);
            end

            if ~isempty(pref.help_text)
                set(obj.label, 'Tooltip', pref.help_text);
            end
        end
        function obj = link_callback(obj,callback)
            assert(isa(callback,'function_handle'),...
                sprintf('%s only supports function handle callbacks (received %s).',...
                mfilename,class(callback)));
            obj.ui.UserData.callback = callback;
            obj.ui.CellEditCallback = @obj.CellEdit;
        end
        function obj = adjust_UI(obj, suggested_label_width, margin)
            % Position UI elements on separate lines from bottom up
            if ~isempty(obj.label)
                obj.label.Position(1) = margin(1);
                obj.label.Position(3) = suggested_label_width;
                if any(obj.label.Extent(3:4) > obj.label.Position(3:4))
                    help_text = get(obj.label, 'Tooltip');
                    set(obj.label, 'Tooltip',...
                        ['<html>' obj.label.String(1:end-2) '<br/>' help_text(7:end)]);
                end
            end
        end
        function set_value(obj,val)
            obj.ui.Data = val;
        end
        function val = get_value(obj)
            val = obj.ui.Data;
        end
    end
    methods
        function obj = set.ForceFit(obj,val)
            error('Not implemented yet')
        end
        function obj = set.props(obj,val)
            avoid = {'ColumnFormat','UserData','Parent','CellEditCallback','Units','Tag','Enable','ColumnEditable'};
            assert(iscell(val),'Property, value pairs for uitable must all be in a cell array')
            assert(all(cellfun(@ischar,val(1:2:end))),...
                'Property names for uitable must be char vectors');
            propnames = val(1:2:end);
            illegal = cellfun(@(a)any(strcmpi(a,avoid)),propnames);
            assert(~any(illegal),...
                sprintf('Illegal property specified for uitable:\n\n  %s',...
                strjoin(propnames(illegal),', ')))
            obj.props = val;
        end
    end
    methods(Static)
        function CellEdit(UI,eventdata)
            if ~isempty(eventdata.Error)
                error(eventdata.Error);
            end
            if ~isempty(UI.UserData.callback)
                UI.UserData.callback(UI,eventdata);
            end
        end
    end

end
