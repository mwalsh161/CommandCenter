classdef seqCommand < handle
    properties 
        command={};
        %appended_value = {};
        
    end
    
    
    
    methods
        
        function obj = seqCommand()
            obj.command(:) = [];
        end
            
        function append(obj,appended_value)
            obj.command{end+1} = appended_value;
        end 
        
        function delete(obj)
           %fprintf("I'm a sequence command and that's ok. I'm about to be deleted.\n")
        end
        
        function element = end_array(obj)
           element =  obj.command{end};
        end
        
    end
    
end 
