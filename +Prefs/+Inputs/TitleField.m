classdef TitleField < Prefs.Inputs.LabelControlBasic
    %TITLEFIELD provides UI for text input

    properties(Hidden)
        uistyle = 'text';
    end

    methods
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px,margin)
            % Here, widths will all be taken care of in adjust_UI
            [obj,height_px,label_width_px] = make_UI@Prefs.Inputs.LabelControlBasic(obj,pref,parent,yloc_px,width_px,margin);
            obj.ui.String = 'Select a Pref to Reference';
            obj.ui.HorizontalAlignment = 'Center';
        end
%         function adjust_UI(obj,suggested_label_width_px,margin_px)
%             obj.ui.String = 'Empty Reference';
%         end
    end

end
