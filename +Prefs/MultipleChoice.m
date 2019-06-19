classdef MultipleChoice < Base.pref
    %MULTIPLECHOICE Select among a set of options
    
    properties
        choices = {};
    end
    
    methods
        function obj = MultipleChoice(varargin)
            obj = obj.init(varargin{:});
        end
        function validate(obj,val)
            error('Not implemented')
        end
    end
    
end