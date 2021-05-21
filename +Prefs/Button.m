classdef Button < Prefs.Numeric
    %BUTTON for access to a "set" method that the user can activate on click. For instance, 
    %
    %    Prefs.Button('string', 'Click Me!', 'name', 'Greeting', 'set', @(~,~)(disp('Hello World')) )
    %
    % will create a UI line with 'Greeting: [ Click Me! ]' where the button is square bracketed.
    % Clicking the button will execute the set function and display 'Hello World' in the console.

    properties (Hidden)
        min = false;
        max = true;
    end
    
    properties (Hidden)
        default = true;
        string = '';
        ui = Prefs.Inputs.ButtonField;
    end
    
    methods
        function obj = Button(varargin)
            obj = obj@Prefs.Numeric(varargin{:});
        end
        function validate(obj,val)
            val = obj.value;
%             validateattributes(val,{'char','string'},{'scalartext'})
        end
    end
    
end
