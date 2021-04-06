classdef ButtonField < Prefs.Inputs.LabelControlBasic
    %BUTTONFIELD provides a pushbutton for the user to click. See Prefs.Button for an example.

    properties(Hidden)
        uistyle = 'pushbutton';
    end

    methods
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px,margin)
            % Here, widths will all be taken care of in adjust_UI
            [obj,height_px,label_width_px] = make_UI@Prefs.Inputs.LabelControlBasic(obj,pref,parent,yloc_px,width_px);
            obj.ui.String = pref.value;
        end
        function set_value(~,~)
            % Do nothing.
        end
        function val = get_value(~)
            val = false;
        end
    end
end