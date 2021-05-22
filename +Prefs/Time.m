classdef Time < Prefs.Integer
    %TIME Placeholder for when time pref is needed. **Should only be used in backend.**

    methods
        function obj = Time(varargin)
            obj = obj@Prefs.Integer(1, 'min', 1, 'name', 'Time', 'unit', 'ave');
            
            obj.parent = Base.Zeitgeist.instance();
            obj.property_name = 'time';

            obj.readonly = true;
            obj.display_only = true;
            obj.auto_generated = false;
            obj.custom_validate = [];
            obj.custom_clean = [];
            obj.set = [];
            
            obj = obj.bind(Base.Zeitgeist.instance());
        end
        function val = read(~)
            val = now;
        end
        function tf = writ(~, ~)
            tf = true;
        end
    end
end
