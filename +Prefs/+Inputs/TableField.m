classdef TableField < Base.input
    %TABLEFIELD provides interface to MATLAB uitable
    %   make_UI has an additional varargin ontop of that defined in Base.Input
    %   This is passed directuly to uitable. There will be an error if you attempt
    %   to pass some reserved properties. For example, CellEditCallback, units,
    %   tag, enable, ColumnEditable are all required for operation of this
    %   field (some of which can be controlled via pref properties).
    %   https://www.mathworks.com/help/matlab/ref/matlab.ui.control.table-properties.html
    %   Some particularly useful properties are:
    %       ColumnFormat, ColumnName, RowName

    properties
        label = gobjects(0);
        ui = gobjects(1);
    end
    properties % Table properties
        hide_label = false; % uitables can have column names, so allow hiding label
    end

    methods
        function tf = isvalid(obj)
            tf = isgraphics(obj.ui) && isvalid(obj.ui);
        end
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px,margin,varargin)
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
            if ~isempty(pref.units)
                labeltext = sprintf('%s (%s)',pref.name,pref.units);
            end
            height_px = 0;
            varargin_propnames = varargin(1:2:end);
            assert(all(cellfun(@ischar,varargin_propnames)),'Property names for uitable must be char vectors');
            avoid = {'Parent','CellEditCallback','Units','Tag','Enable','ColumnEditable'};
            illegal = cellfun(@(a)any(strcmpi(a,avoid)),varargin_propnames);
            assert(~any(illegal),...
                sprintf('Cant specify %s through the varagin input.',...
                strjoin(varargin_propnames(illegal),', ')))
            obj.ui = uitable(parent, 'units', 'pixels',...
                        'ColumnEditable', true,...
                        'tag', tag,...
                        'enable', enabled,...
                        varargin{:});
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
                set([obj.label, obj.ui], 'ToolTip', pref.help_text);
            end
        end
        function link_callback(obj,callback)
            obj.ui.CellEditCallback = callback;
        end
        function adjust_UI(obj, suggested_label_width, margin)
            % Position UI elements on separate lines from bottom up
            if ~isempty(obj.label)
                obj.label.Position(1) = margin(1);
                obj.label.Position(3) = suggested_label_width;
            end
        end
        function set_value(obj,val)
            obj.ui.Data = val;
        end
        function val = get_value(obj)
            val = obj.ui.Data;
        end
    end

end