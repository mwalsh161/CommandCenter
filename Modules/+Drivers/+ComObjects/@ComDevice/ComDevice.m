classdef ComDevice < handle
    properties(Constant,Abstract)
        %this property should describe what input arguments matlab needs to
        %establish a connection to your device. For instance for Serial
        %connections:InputArg={'comPortNum'}
        
        InputArg
    end
    methods
        function reset(obj)
            %this method should reset the com port to some known working settings.
            
            error('Not implemented');
            
        end
        
        function writeOnly(obj,string)
            %this method should take in a string and it should
            %submit the string to the device. It should not expect
            %a response.It should close the line after writing.
            
            error('Not implemented');
        end
        
        function [output] = writeRead(obj,string)
            %this method should take in a string and it should
            %submit the string to the device. It should expect
            %a response (output).It should close the line after writing.
            
            error('Not implemented');
        end
       
    end
end