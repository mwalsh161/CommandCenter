classdef BooleanField < Prefs.Inputs.LabelControlBasic
    %BOOLEANFIELD provides checkbox UI for boolean input

    properties(Hidden)
        uistyle = 'checkbox';
        nanuistyle = 'radiobutton';
    end
    
    methods
        function set_value(obj,val)
            if isnan(val)
                obj.ui.Value = false;
                obj.ui.Style = obj.nanuistyle;
                obj.ui.Enabled = false;
            else
                obj.ui.Value = logical(val);
                obj.ui.Style = obj.uistyle;
                obj.ui.Enabled = obj.ui.UserData;
            end
        end
        function val = get_value(obj)
            switch obj.ui.Style
                case obj.nanuistyle
                    val = NaN;
                case obj.uistyle
                    val = logical(obj.ui.Value);
            end
        end
    end

end