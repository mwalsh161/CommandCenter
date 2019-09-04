classdef DropDownField < Prefs.Inputs.LabelControlBasic

    properties(Hidden)
        uistyle = 'popupmenu';
    end

    methods
        function labeltext = get_label(~,pref)
            if ~isempty(pref.units)
                labeltext = sprintf('%s (%s)',pref.name,pref.units);
            else
                labeltext = pref.name;
            end
        end
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px)
            [obj,height_px,label_width_px] = make_UI@Prefs.Inputs.LabelControlBasic(obj,pref,parent,yloc_px,width_px);
            obj.ui.String = pref.choices_strings;
        end
        function set_value(obj,val)
            % val can either be the STRING/CHAR value or the index into
            % obj.ui.String
            I = val;
            if ~isnumeric(val)
                mask = strcmp(obj.ui.String,val);
                assert(any(mask),...
                    sprintf('Unable to find "%s" in available options (%s)',...
                    val, strjoin(obj.ui.String,', ') ))
                I = find(mask);
            end
            obj.ui.Value = I;
        end
        function [val,I] = get_value(obj)
            val = obj.ui.String{obj.ui.Value};
            I = obj.ui.Value;
        end
    end

end