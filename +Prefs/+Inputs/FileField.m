classdef FileField < Prefs.Inputs.LabelControlBasic
    %FILEFIELD displays a file on a pushbutton

    properties
        empty_string = '';
    end
    properties(Hidden)
        uistyle = 'pushbutton';
    end

    methods
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px,margin)
            % Here, widths will all be taken care of in adjust_UI
            [obj,height_px,label_width_px] = make_UI@Prefs.Inputs.LabelControlBasic(obj,pref,parent,yloc_px,width_px);
            set(obj.ui,'TooltipString',pref.value);
            if isempty(pref.value)
                set(obj.ui,'String',obj.empty_string);
            end
        end
        function set_value(obj,val)
            if isempty(val)
                obj.ui.String = obj.empty_string;
            else
                [~,name,ext] = fileparts(val);
                obj.ui.String = [name, ext];
            end
            if ~isstruct(obj.ui.UserData)
                obj.ui.UserData = struct();
            end
            obj.ui.UserData.value = val;
            obj.ui.TooltipString = val;
        end
        function val = get_value(obj)
            val = obj.ui.UserData.value;
        end
    end
end