classdef BSC203 < Modules.Stage
    %MAX302 Control the motors of this stage.
    %   Uses 3 instances of APTMotor for x,y,z.
    %
    %   All values are in microns. It is good practice to home after
    %   construction.
    %
    %   Home is -2,-2,-2
    
    properties
        prefs = {'availMotors','x_motor','y_motor','z_motor', 'factor'};
    end
    
    properties(GetObservable, SetObservable, AbortSet)
        availMotors = Prefs.MultipleChoice('', 'choices', Drivers.Kinesis.KinesisBSC203.getAvailMotors, 'allow_empty', true, 'set', 'set_controller');
        x_motor = Prefs.MultipleChoice(1,'choices',{1,2,3},'allow_empty',true,'set','set_x_motor','help_text','Which channel in the controller controls the x direction motor','readonly',true); % Show only for now; need to fix driver to be able to change properly
        y_motor = Prefs.MultipleChoice(2,'choices',{1,2,3},'allow_empty',true,'set','set_y_motor','help_text','Which channel in the controller controls the y direction motor','readonly',true);
        z_motor = Prefs.MultipleChoice(3,'choices',{1,2,3},'allow_empty',true,'set','set_z_motor','help_text','Which channel in the controller controls the z direction motor','readonly',true);
        factor = Prefs.Double(0.5, 'help_text', 'The factor between the actual distance moved and the distance read from Kinesis')
    end
    properties(SetAccess=private,SetObservable,AbortSet)
        % Default here will only matter if motors aren't set
        Homed = false;
        Moving = false;              % Track this to update position
    end
    properties(SetAccess=private)
        position
        motors;
        motor_channels = [1 2 3];
    end
    
    properties (Constant)
        % Currently used as placeholders to avoid the error as Abstract properties
        xRange = [-2 2] * 1000;
        yRange = [-2 2] * 1000;
        zRange = [-2 2] * 1000;
    end
    
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Stages.BSC203();
            end
            obj = Object;
        end
        
    end
    methods(Access=private)
        function obj = BSC203()
            obj.loadPrefs;
        end
        
        function val = set_motor_generic(obj, channelNo, motor_index)
            % Generic function that checks to make sure that no other motor
            % is using this channel before setting motor connection
            
            not_motor_index = [1 2 3];
            not_motor_index = not_motor_index(not_motor_index ~= motor_index);
            
            if isempty(channelNo)
                obj.motor_channels(motor_index) = NaN;
                obj.motors.disconnect;
                delete(obj.motors);
            elseif channelNo ~= obj.motor_channels(motor_index) % Need to check to prevent initialising motor multiple times at startup
                if any(obj.motor_channels(not_motor_index) == channelNo) % Check that not equal to an existing channel
                    error(strcat('Channel ', num2str(channelNo), ' was already used for other motors.'))
                else
                    if ~isempty(obj.motors) && isobject(obj.motors) && isvalid(obj.motors) && obj.motors.isconnected
                        obj.motors.disconnect;
                        delete(obj.motors);
                    end
                    
                    obj.motor_channels(motor_index) = channelNo;
                end
            end
            
            obj.set_controller(obj.availMotors);
            
            val = channelNo;
        end
    end
    % Callback functions for BSC203 Motor
    methods(Access=?KinesisBSC203)
        function homedCallback(obj,varargin)
            if ~isempty(obj.motors) && isobject(obj.motors) && isvalid(obj.motors)
                obj.Homed = obj.motors.Homed;
            else
                obj.Homed = false;
            end
        end
        function movingCallback(obj,varargin)
            if ~isempty(obj.motors) && isobject(obj.motors) && isvalid(obj.motors)
                obj.Moving = obj.motors.isMoving;
            else
                obj.Moving = false;
            end           
        end
    end
    methods
        function delete(obj)
            if isobject(obj.motors)
                obj.motors.disconnect;
                delete(obj.motors);
            end
        end
        function pos = get.position(obj)
            % this function reads the current motor position           
            pos = [NaN NaN NaN];
            if ~isempty(obj.motors) && isobject(obj.motors) && isvalid(obj.motors)
                n = 1;
                for channelNo = obj.motor_channels
                    positions = obj.motors.positions;
                    pos = positions;
                    if isnan(channelNo)
                        pos(n) = NaN;
                    else
                        pos(n) = positions(channelNo);
                    n = n + 1;
                    end
                end
            end
        end
        function move(obj,x,y,z)
            % Method to move the motor to a given position [x, y, z]
            pos = obj.position; % reads the current position

            new_pos = [x,y,z]; 

            for i = 1:length(new_pos)
                % Check whether the input target position for a certain axis is empty,
                if isempty(new_pos(i)) || new_pos(i)==pos(i) || isnan(new_pos(i))
                    new_pos(i) = pos(i);    % if empty, set the target position to the original position of that axis
                end
            end
            
            if ~isempty(obj.motors)&&isobject(obj.motors) && isvalid(obj.motors)
                obj.motors.moveto(new_pos) % move to the new position 
            end
        end

        function enable(obj)
            %Method to enable motors drive
            if ~isempty(obj.motors)&&isobject(obj.motors) && isvalid(obj.motors)
                obj.motors.enable();
            end
            drawnow; % Flush callback queue
        end
        function disable(obj)
            %Method to disable motors drive
            if ~isempty(obj.motors)&&isobject(obj.motors) && isvalid(obj.motors)
                obj.motors.disable();
            end
            drawnow; % Flush callback queue
        end
        function home(obj)
            %Method to home/zero the motors
            if ~isempty(obj.motors)&&isobject(obj.motors) && isvalid(obj.motors)
                obj.motors.home()
            end
            drawnow; % Flush callback queue
        end
        function abort(obj,varargin)
            %Method to try and stop the motors
            if ~isempty(obj.motors)&&isobject(obj.motors) && isvalid(obj.motors)
                obj.motors.stop(varargin{:});
            end
            drawnow; % Flush callback queue
        end
        
        function val = set_x_motor(obj, channelNo, ~)
            % Use generic function with appropriate index to check to make sure that no other motor is using this channel before setting x motor
            val = obj.set_motor_generic(channelNo, 1);
        end

        function val = set_y_motor(obj, channelNo, ~)
            % check to make sure that no other motor is using this channel before setting y motor
            val = obj.set_motor_generic(channelNo, 2);
        end

        function val = set_z_motor(obj, channelNo, ~)
            % check to make sure that no other motor is using this channel before setting z motor
            val = obj.set_motor_generic(channelNo, 3);
        end
        
        function val = set_controller(obj, SerialNo, ~)
            if ~isempty(SerialNo)
                % take val, and instantiate the driver for the BSC203
                val = SerialNo;
                obj.motors = Drivers.Kinesis.KinesisBSC203.instance(SerialNo, [0 8], SerialNo, obj.motor_channels, obj.factor);
                % Listeners will follow lifecycle of their motor
                addlistener(obj.motors,'isMoving','PostSet',@obj.movingCallback);
                addlistener(obj.motors,'Homed','PostSet',@obj.homedCallback);
                % Intialize values
                obj.homedCallback;
                obj.movingCallback;
            else
                if ~isempty(obj.motors) && isobject(obj.motors) && isvalid(obj.motors) && obj.motors.isconnected
                    obj.motors.disconnect;
                    delete(obj.motors);
                end
                val = [];
            end
        end
    end
end

