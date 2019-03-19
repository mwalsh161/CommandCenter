classdef OpenLoopPiezoDriversSuper < Modules.Driver
    %this superclass is meant to provide methods for open loop piezo
    %controllers.
    
    %an open loop piezo is where the piezo does not have active feedback on
    %its motion. Thus while it can set output voltages it does not know
    %what the voltages correspond to in absolute position. Crucially, open
    %loop piezos cannot move and return to their previous positions
    %perfectly.
    
    properties(Abstract,SetAccess=immutable)
        voltLim      % Voltage limits of device
    end
    
    methods
        %% Get methods
        function val = getVX(obj)
            %this method should return the voltage of the X channel
            %should be a double
            
            error('Not Implemented')
        end
        
        function val = getVY(obj)
            %this method should return the voltage of the Y channel
            %should be a double
            
            error('Not Implemented')
        end
        
        function val = getVZ(obj)
            %this method should return the voltage of the Z channel
            %should be a double
            
            error('Not Implemented')
        end
        
        %% Set methods
        
        function setVX(obj,val)
            % Set voltage on x axis
            % val should be numeric and should be less than voltLim
            
            error('Not Implemented')
        end
        
        function setVY(obj,val)
            % Set voltage on y axis and should be less than voltLim
            
            error('Not Implemented')
        end
        
        function setVZ(obj,val)
            % Set voltage on z axis and should be less than voltLim
            
            error('Not Implemented')
        end
        
        function setVAll(obj,val)
            % Set all voltages. Voltages should be less than voltLim. val
            % should be a 3 element vector with each element corresponding
            % to each of the devices channels.
            
            error('Not Implemented')
        end
        
        function move(obj,x,y,z)
            % Move to x,y,z in V (if any are empty, ignore that axis)
            
            error('Not Implemented')
        end
        
        function step(obj,dx,dy,dz)
           %this should change the voltage of the piezo by an amount the
           %amounts of dx, dy and dz
           
           error('Not Implemented')
        end
    end
end