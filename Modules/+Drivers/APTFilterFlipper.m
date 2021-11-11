classdef (Sealed) APTFilterFlipper < Drivers.APT & Modules.Driver
    % APTFilterFlipper A subclass to handle things specific to the Filter Flipper
    %   The two possible states are 1 and 2
    %
    %	Singleton based off serial number
    
    properties
        name
    end

    methods (Static)
        % Use this to create/retrieve instance associated with serialNum
        function obj = instance(serialNum,name)
            mlock;
            if nargin < 2
                name = serialNum;
            end
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.APTFilterFlipper.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(serialNum,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.APTFilterFlipper(serialNum,name);
            obj.singleton_id = serialNum;
            Objects(end+1) = obj;
        end
    end    
    methods(Access=private)
        % Constructor should only be called by instance()
        function obj = APTFilterFlipper(serialNum,name)
            obj.initialize('MGMOTOR.MGMotorCtrl.1',serialNum)
            obj.name = name;
        end
     end

    methods
        function setState(obj,state,blocking)
            % State can be 1 or 2
            assert(state==1 || state == 2,'State must be either 1 or 2. See APT Server help for details.')
            if nargin < 3; blocking=false; end
            obj.LibraryFunction('MoveJog',0,state);
            pause(0.05);
            while blocking && obj.isMoving
                pause(0.05);
            end
        end

        % Get current state
        function state = getState(obj)
            state = ~obj.getStatus(1);
            state = state+1;
        end
        
        %Method to identify the device
        function identify(obj)
            obj.LibraryFunction('Identify');
        end
        
        %Method to enable motor drive
        function enable(obj)
            obj.LibraryFunction('EnableHWChannel',0);
        end
        
        %Method to disable motor drive (allows to turn by hand)
        %   Assume home is lost
        function disable(obj)
            obj.LibraryFunction('DisableHWChannel',0);
        end
        
        %Method to test if motor moving
        function tf = isMoving(obj)
            tf = ~obj.getStatus(2);
        end
    end
    
    methods (Access = protected)
        % Called by initialize (after APT class is constructed)
        function subInit(obj)
            obj.enable;
        end
    end
end
