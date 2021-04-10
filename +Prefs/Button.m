classdef Button < Base.Pref
    %BUTTON for access to a "set" method that the user can activate on click. For instance, 
    %
    %    Prefs.Button('Click Me!', 'name', 'Greeting', 'set', @(~,~)(disp('Hello World')) )
    %
    % will create a UI line with 'Greeting: [ Click Me! ]' where the button is square bracketed.
    % Clicking the button will execute the set function and display 'Hello World' in the console.
    
    properties(Hidden)
        default = '';
        ui = Prefs.Inputs.ButtonField;
    end
    
    methods
        function obj = Button(varargin)
            obj = obj@Base.Pref(varargin{:});
        end
        function validate(obj,val)
            val = obj.value;
%             validateattributes(val,{'char','string'},{'scalartext'})
        end
    end
    
end
