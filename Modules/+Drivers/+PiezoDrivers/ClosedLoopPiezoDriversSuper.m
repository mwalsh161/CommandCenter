classdef ClosedLoopPiezoDriversSuper < Drivers.PiezoDrivers.OpenLoopPiezoDriversSuper
    %this superclass is meant to provide methods for closed loop piezo
    %controllers.
    
    %a closed loop piezo is one that gets active feedback on the piezo's
    %position so that it can move to an absolute position in x,y and z
    
    properties(Abstract,SetAccess=immutable)
        positionLimit      % maximum available position (in microns) ex: 20
    end
    
    methods
        %% set methods
        function setLoopMode(obj,channel,val)
            %this method should set the mode of the Piezo either 'Open' or
            %'Closed for the channel number give by channel
            
            error('Not Implemented')
        end
        
        function setPosX(obj,val)
            %this method sets the absolute position of the piezo in X
            %val should be a double
            %should check to make sure that the piezo is in loop mode closed
            
            error('Not Implemented')
        end
        
        function setPosY(obj,val)
            %this method sets the absolute position of the piezo in Y
            %val should be a double
            %should check to make sure that the piezo is in loop mode closed
            
            error('Not Implemented')
        end
        
        function setPosZ(obj,val)
            %this method sets the absolute position of the piezo in Z
            %val should be a double
            %should check to make sure that the piezo is in loop mode closed
            
            error('Not Implemented')
        end
        
        %% get methods
        
        function LoopMode = getLoopMode(obj,channel)
            %this method should get the mode of the Piezo either 'Open' or
            %'Closed' for the channel number give by channel
            
            error('Not Implemented')
        end
        
        function posX = getPosX(obj)
            %this method should return the position of the X channel
            %should be a double
            
            error('Not Implemented')
        end
        
        function posY = getPosY(obj)
            %this method should return the position of the Y channel
            %should be a double
            
            error('Not Implemented')
        end
        
        function posZ = getPosZ(obj)
            %this method should return the position of the Z channel
            %should be a double
            
            error('Not Implemented')
        end
        
        %% general methods
        function zero(obj)
           %should return the piezo to zero on all channel 
           
           error('Not Implemented')
        end
        
        function move(obj,x,y,z)
            % subclass of open loop superclass move command.
            % method should check loop mode and either set voltages or
            % microns.
            % Move to x,y,z in microns (if any are empty, ignore that axis)
            
            error('Not Implemented')
        end
        
        function step(obj,dx,dy,dz)
            % subclass of open loop superclass move command.
            % method should check loop mode and either set voltages or
            % microns.
            %this should change the microns of the piezo by an amount the
            %amounts of dx, dy and dz
            
            error('Not Implemented')
        end
        
        function reset(obj)
           %reset should set all channels to open and zero out the piezo. 
        end
        
    end
end