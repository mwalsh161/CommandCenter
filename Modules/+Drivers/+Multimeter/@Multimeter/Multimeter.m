classdef Multimeter < handle
  
     properties (Constant,Abstract)
        Number_of_channels  % how many channels does your multimeter have?
        dev_id              % what is your devices name?
     end
    
    methods
        function setVoltRange(obj)
            %this method sets the voltage range. Should be used to increase
            %the accuracy/precision of voltage measurements.
            
        end
        
        function setCurrentRange(obj)
            %this method sets the current range. Should be used to increase
            %the accuracy/precision of current measurements.
            
        end
  
        %% 

        function  voltage = measureVoltage(obj,channel)
            %this gets the voltage 
            
            %channel must be entered as a string that is an integer ex: '1'
            %output: double,  and unit should be V
            error('Not implemented');
        end
        
        function  current = measureCurrent(obj,channel)
            %this gets the current
            
            %channel must be entered as a string that is an integer ex: '1'
            %output: double, unit should be A
            error('Not implemented');
        end
        %% 
        function on(obj)
            
        end
        
        function off(obj)
            
        end
    end
end