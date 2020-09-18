classdef Button < Base.pref
    %BUTTON for access to a "set" method that the user can activate on click.
    
    properties(Hidden)
        default = false;    % Completely unused.
        ui = Prefs.Inputs.ButtonField;
        string = {'', @(a)validateattributes(a,{'char'},{'vector'})};   % String to display on the button
    end
    
    methods
        function obj = Button(varargin)
            obj = obj@Base.pref(varargin{:});
        end
        function val = clean(~, ~)
            val = false;
        end
    end
    
end