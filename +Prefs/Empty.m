classdef Empty < Prefs.Numeric
    %EMPTY Placeholder for when an empty pref is needed. **Should only be used in backend.**

    properties (Hidden)
        default = NaN;
        ui = Prefs.Inputs.TitleField;
    end
    properties (Hidden)
        min = NaN;
        max = NaN;
    end

    methods
        function obj = Empty(varargin)
            obj.default = NaN;

            if numel(varargin) == 2
                obj.name = varargin{1};
                obj.unit = 'pixels';
                obj.min = 1;
                obj.max = varargin{2};
            else
                obj.name = 'None';
                obj.unit = 'none';
            end

            obj.readonly = true;
            obj.display_only = true;
            obj.auto_generated = false;
            obj.custom_validate = [];
            obj.custom_clean = [];
            obj.set = [];
        end
        function tf = isnumeric(~)      % We want this one to have min/max while not being numeric.
            tf = false;
        end
        function tf = isempty(~)
            tf = true;
        end
        
        function val = read(~)
            val = NaN;
        end
        function tf = writ(~,~)
            tf = false;
        end
    end
end
