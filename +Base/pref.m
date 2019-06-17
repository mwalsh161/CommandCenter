classdef pref
    %PREF Abstract Class for prefs.
    %   The only required part of a pref is having a value field
    
    properties(Abstract)
        value
    end
    
    methods
        % These two functions are called when the module's property (that is a pref)
        % gets assigned/referenced; as such the intent is to set/get "value"
        % The S(1).subs is not useless, it has just been used already by the caller
        % to get to this function call in the first place.
        function obj = pref_subsasgn(obj,S,B)
            if S(1).type == '.' % Can only handle dot notation for first item in S
                S(1).subs = 'value';
            else
                error('Unknown type of call!')
            end
            obj = builtin('subsasgn',obj,S,B);
        end
        function B = pref_subsref(obj,S)
            if S(1).type == '.' % Can only handle dot notation for first item in S
                S(1).subs = 'value';
            else
                error('Unknown type of call!')
            end
            B = builtin('subsref',obj,S);
        end
    end
    
end