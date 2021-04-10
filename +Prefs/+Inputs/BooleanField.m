classdef BooleanField < Prefs.Inputs.LabelControlBasic
    %BOOLEANFIELD provides checkbox UI for boolean input

    properties(Hidden)
        uistyle = 'checkbox';
        nanuistyle = 'radiobutton';
    end
    
    methods
        function set_value(obj,val)
            if isnan(val)   % Change to circle (radiobutton) and disable
                obj.ui.Value = false;
                obj.ui.Style = obj.nanuistyle;
                obj.ui.Enable = 'off';
            else            % Change to square (checkbox) and enable if not read_only
                obj.ui.Value = logical(val);
                obj.ui.Style = obj.uistyle;
                if obj.ui.UserData  % Copy of read_only
                    obj.ui.Enable = 'off';
                else
                    obj.ui.Enable = 'on';
                end
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
