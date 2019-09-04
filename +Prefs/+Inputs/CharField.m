classdef CharField < Prefs.Inputs.LabelControlBasic

    properties % Add units in
        units = gobjects(1)
    end
    properties(Hidden)
        uistyle = 'edit';
    end

    methods
        function labeltext = get_label(~,pref)
            labeltext = pref.name;
        end

        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px)
            % Here, widths will all be taken care of in adjust_UI
            [obj,height_px,label_width_px] = make_UI@Prefs.Inputs.LabelControlBasic(obj,pref,parent,yloc_px,width_px);
            tag = obj.ui.Tag;
            if ~isempty(pref.units)
                obj.units = uicontrol(parent, 'style', 'text',...
                            'string', [' (' pref.units ')'],...
                            'units', 'pixels',...
                            'tag', [tag '_unit']);
                obj.units.Position(2) = yloc_px;
                obj.units.Position(3) = obj.units.Extent(3);
            end
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
    end

end