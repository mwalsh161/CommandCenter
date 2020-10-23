classdef CharField < Prefs.Inputs.LabelControlBasic
    %CHARFIELD provides UI for text input

    properties % Add units in (for displaying the units even if the main label overflows)
        unit = gobjects(1)
    end
    properties(Hidden)
        uistyle = 'edit';
    end

    methods
        function labeltext = get_label(~,pref)
            labeltext = pref.name;
        end

        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px,margin)
            % Here, widths will all be taken care of in adjust_UI
            [obj,height_px,label_width_px] = make_UI@Prefs.Inputs.LabelControlBasic(obj,pref,parent,yloc_px,width_px);
            tag = obj.ui.Tag;
            if ~isempty(pref.unit)
                obj.unit = uicontrol(parent, 'style', 'text',...
                            'string', [' [' pref.unit ']'],...
                            'units', 'pixels',...
                            'tag', [tag '_unit']);
                obj.unit.Position(2) = yloc_px;
                obj.unit.Position(3) = obj.unit.Extent(3);
            end
        end
        function adjust_UI(obj,suggested_label_width_px,margin_px)
            obj.label.Position(1) = margin_px(1);
            obj.label.Position(3) = suggested_label_width_px;
            obj.ui.Position(1) = suggested_label_width_px + margin_px(1);
            unit_space = 0;
            if isgraphics(obj.unit) % unit exist
                unit_space = obj.unit.Position(3);
                obj.unit.Position(1) = obj.unit.Parent.Position(3) - (unit_space + margin_px(2));
            end
            obj.ui.Position(3) = obj.label.Parent.Position(3) - ...
                                (suggested_label_width_px + unit_space + sum(margin_px));
            if any(obj.label.Extent(3:4) > obj.label.Position(3:4))
                help_text = get(obj.label, 'Tooltip');
                set(obj.label, 'Tooltip',...
                    ['<html>' obj.label.String(1:end-2) '<br/>' help_text(7:end)]);
            end
        end
    end

end
