classdef CharField < Base.input

    properties % Handles to all uicontrol objects
        label = gobjects(1)
        ui = gobjects(1)
        units = gobjects(1)
    end

    methods % Satisfy all abstract methods
        function tf = enabled(obj)
            tf = isgraphics(obj.ui) && isvalid(obj.ui);
        end
        % These methods are responsible for building the settings UI and setting/getting values from it
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px)
            % Here, widths will all be taken care of in adjust_UI
            tag = strrep(pref.name,' ','_');
            enabled = 'on';
            if pref.readonly
                enabled = 'off';
            end
            obj.label = uicontrol(parent, 'style', 'text',...
                        'string', [pref.name ': '],...
                        'horizontalalignment', 'right',...
                        'units', 'pixels',...
                        'tag', [tag '_label']);
            obj.label.Position(2) = yloc_px;
            label_width_px = obj.label.Extent(3);

            obj.ui = uicontrol(parent, 'style', 'edit',...
                        'horizontalalignment','left',...
                        'units', 'pixels',...
                        'tag', tag,...
                        'enable', enabled);
            obj.ui.Position(2) = yloc_px;

            if ~isempty(pref.units)
                obj.units = uicontrol(parent, 'style', 'text',...
                            'string', [' (' pref.units ')'],...
                            'units', 'pixels',...
                            'tag', [tag '_unit']);
                obj.units.Position(2) = yloc_px;
                obj.units.Position(3) = obj.units.Extent(3);
            end
            if ~isempty(pref.help_text)
                set([obj.label, obj.ui], 'ToolTip', pref.help_text);
            end
            height_px = obj.ui.Position(4);
        end
        function link_callback(obj,callback)
            obj.ui.Callback = callback;
        end
        function adjust_UI(obj,suggested_label_width_px)
            pad = obj.label.Position(1); % Use pad from left for the right as well
            obj.label.Position(3) = suggested_label_width_px;
            obj.ui.Position(1) = suggested_label_width_px + pad;
            units_space = 0;
            if isgraphics(obj.units) % units exist
                units_space = obj.units.Position(3);
                obj.units.Position(1) = obj.units.Parent.Position(3) - (units_space + pad);
            end
            obj.ui.Position(3) = obj.label.Parent.Position(3) - ...
                                (suggested_label_width_px + units_space + 2*pad);
        end
        function set_value(obj,val)
            obj.ui.String = val;
        end
        function val = get_value(obj)
            val = obj.ui.String;
        end
    end

end