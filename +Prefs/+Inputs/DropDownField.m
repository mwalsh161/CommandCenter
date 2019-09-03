classdef DropDownField < Base.input

    properties % Handles to all uicontrol objects
        label = gobjects(1)
        ui = gobjects(1)
    end

    methods % Satisfy all abstract methods
        function tf = enabled(obj)
            tf = isgraphics(obj.ui) && isvalid(obj.ui);
        end
        % These methods are responsible for building the settings UI and setting/getting values from it
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px)
            % Here, widths will all be taken care of in adjust_UI
            tag = strrep(pref.name,' ','_');
            if ~isempty(pref.units)
                nameFormatted = sprintf('%s (%s): ',pref.name,pref.units);
            else
                nameFormatted = sprintf('%s: ',pref.name);
            end
            enabled = 'on';
            if pref.readonly
                enabled = 'off';
            end
            obj.label = uicontrol(parent, 'style', 'text',...
                        'string', nameFormatted,...
                        'horizontalalignment', 'right',...
                        'units', 'pixels',...
                        'tag', [tag '_label']);
            obj.label.Position(2) = yloc_px;
            label_width_px = obj.label.Extent(3);

            obj.ui = uicontrol(parent, 'style', 'popupmenu',...
                        'String',obj.choices_strings,...
                        'horizontalalignment','left',...
                        'units', 'pixels',...
                        'tag', tag,...
                        'enable', enabled);
            obj.ui.Position(2) = yloc_px;

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
            obj.ui.Position(3) = obj.label.Parent.Position(3) - ...
                                (suggested_label_width_px + 2*pad);
        end
        function set_value(obj,val)
            mask = strcmp(obj.ui.String,val);
            assert(any(mask),...
                sprintf('Unable to find "%s" in available options (%s)',...
                val, strjoin(obj.ui.String,', ') ))
            obj.ui.Value = obj.ui.String(mask);
        end
        function val = get_value(obj)
            val = obj.ui.String{obj.ui.Value};
        end
    end

end