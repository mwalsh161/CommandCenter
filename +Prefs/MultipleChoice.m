classdef MultipleChoice < Base.pref
    %MULTIPLECHOICE Select among a set of options
    
    properties
        value = [];
        choices = {};
    end
    
    methods
        function set.value(obj,val)
            error('Not implemented')
        end
    end
    
end