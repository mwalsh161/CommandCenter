classdef BooleanField < Prefs.Inputs.LabelControlBasic
    %BOOLEANFIELD provides checkbox UI for boolean input

    properties(Hidden)
        uistyle = 'checkbox';
    end
    
    methods
        function set_value(obj,val)
            obj.ui.Value = logical(val);
        end
        function val = get_value(obj)
            val = logical(obj.ui.Value);
        end
    end

end