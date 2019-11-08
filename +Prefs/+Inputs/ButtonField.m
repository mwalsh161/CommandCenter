classdef ButtonField < Prefs.Inputs.LabelControlBasic
    %CHARFIELD provides UI for text input

    properties % Add units in
        units = gobjects(1)
        empty_string = '';
    end
    properties(Hidden)
        uistyle = 'pushbutton';
    end

    methods
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px,margin)
            % Here, widths will all be taken care of in adjust_UI
            [obj,height_px,label_width_px] = make_UI@Prefs.Inputs.LabelControlBasic(obj,pref,parent,yloc_px,width_px);
            set(obj.ui,'Tooltip',pref.value);
            if isempty(pref.value)
                set(obj.ui,'String',obj.empty_string);
            end
        end
        % function link_callback(obj,callback)
        %     obj.ui.UserData = callback;
        %     obj.ui.Callback = @obj.select_file;
        % end
        function set_value(obj,val)
            if isempty(val)
                obj.ui.String = obj.empty_string;
            else
                obj.ui.String = val;
            end
            obj.ui.UserData = val;
        end
        function val = get_value(obj)
            val = obj.ui.UserData;
        end
    end
end