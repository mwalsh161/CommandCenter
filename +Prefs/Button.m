classdef Button < Base.Pref
    %BUTTON for access to a "set" method that the user can activate on click. For instance, 
    %
    %    Prefs.Button('name', 'Greeting', 'string', 'Click Me!', 'set', @(~,~)(disp('Hello World')) )
    %
    % will create a UI line with 'Greeting: [ Click Me! ]' where the button is square bracketed.
    % Clicking the button will execute the set function and display 'Hello World' in the console.
    
    properties(Hidden)
        default = false;    % Completely unused.
        ui = Prefs.Inputs.ButtonField;
        string = '';   % String to display on the button
    end
    
    methods
        function obj = Button(varargin)
            obj = obj@Base.Pref(varargin{:});
        end
        function val = clean(~, ~)
            val = false;
        end
    end
    
end
