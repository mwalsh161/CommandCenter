classdef Time < Prefs.Integer
    %EMPTY Placeholder for when an empty pref is needed. Should only be used in backend.

    methods
        function obj = Time(varargin)
            obj = obj@Prefs.Integer(1, 'min', 1, 'name', 'Time', 'unit', 'ave');
            
            obj.parent_class = 'The.Universe';
            obj.property_name = 'time';

            obj.readonly = true;
            obj.display_only = true;
            obj.auto_generated = false;
            obj.custom_validate = [];
            obj.custom_clean = [];
            obj.set = [];
        end
        function val = read(~)
            val = now;
        end
        function tf = writ(~, ~)
            tf = true;
        end
    end
end
