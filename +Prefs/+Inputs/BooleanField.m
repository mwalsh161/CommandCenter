classdef BooleanField < Prefs.Inputs.LabelControlBasic

    properties(Hidden)
        uistyle = 'checkbox';
    end
    
    methods
        function labeltext = get_label(~,pref)
            if ~isempty(pref.units)
                labeltext = sprintf('%s (%s)',pref.name,pref.units);
            else
                labeltext = pref.name;
            end
        end
        
        function set_value(obj,val)
            obj.ui.Value = logical(val);
        end
        function val = get_value(obj)
            val = logical(obj.ui.Value);
        end
    end

end