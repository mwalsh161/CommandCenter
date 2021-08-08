classdef BSC203 < Modules.Stage
    %MAX302 Control the motors of this stage.
    %   Uses 3 instances of APTMotor for x,y,z.
    %
    %   All values are in microns. It is good practice to home after
    %   construction.
    %
    %   Home is -2,-2,-2
    
    properties
        prefs = {'controller','calibration','x_motor','y_motor','z_motor'};
    end
    properties(SetObservable,AbortSet)
        availMotors = @Drivers.Kinesis.KinesisBSC203.getAvailMotors
        controller = Prefs.MultipleChoice(availMotors{1}, 'choices', availMotors, 'empty_val', true);  % Motor serial number
        calibration = Prefs.DoubleArray([2 2 2],'help_text','Calibration for the motor distance to true distance');
        x_motor = Prefs.MultipleChoice(1,'choices',{1,2,3},'empty_val',true);
        y_motor = Prefs.MultipleChoice(2,'choices',{1,2,3},'empty_val',true);
        z_motor = Prefs.MultipleChoice(3,'choices',{1,2,3},'empty_val',true);
    end
    properties(SetAccess=private,SetObservable,AbortSet)
        % Default here will only matter if motors aren't set
        Homed = false;
        isMoving = false;              % Track this to update position
    end
    properties(SetAccess=private)
        position
        motors = []; 
        MotorSerialNo
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
                obj.isMoving = obj.motors.isMoving;
            else
                obj.isMoving = false;
            end           
        end
    end
    methods
        function delete(obj)
            cellfun(@delete,obj.motors);
        end
        function pos = get.position(obj)
        % this function reads the current motor position
            pos = obj.motors.positions;
        end
        function move(obj,x,y,z)
            pos = obj.position;
            new_pos = [x,y,z]; % Allow for empty inputs in for loop below
            for i = 1:length(new_pos)
                if isempty(new_pos(i)) || new_pos{i}==pos(i) || isnan(new_pos(i))
                    new_pos(i) = pos(i);
                end
            end
            if ~isempty(obj.motors)&&isobject(obj.motors) && isvalid(obj.motors)
                obj.motors.moveto(new_pos)
            end
        end

        function enable(obj)
            %Method to enable motors drive
            if ~isempty(obj.motors)&&isobject(obj.motors) && isvalid(obj.motors)
                obj.motors{i}.enable();;
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
        
        % Motor construction callbacks
        function setMotor(obj,val)
            val = str2double(val);
            assert(~isnan(val),'Motor SN must be a valid number.')
            if val == 0
                return % Short circuit
            end

            % Add new motor
            obj.motors = Drivers.Kinesis.KinesisBSC203.instance(val, [0 8]);

            % Listeners will follow lifecycle of their motor
            addlistener(obj.motors,'isMoving','PostSet',@obj.movingCallback);
            addlistener(obj.motors,'Homed','PostSet',@obj.homedCallback);
            % Intialize values
            obj.homedCallback;
            obj.movingCallback;
        end

        function set.controller(obj,val)
            % Validate that the serial number is the correct type for BSC203
            if ~isempty(val)
                if strcmp(val(1:2) == '70')
                    try
                        obj.setMotor(val); 
                        obj.MotorSerialNo = val;
                    catch err
                        obj.MotorSerialNo = 'None';
                        rethrow(err)
                    end
                else
                    error('This device is not of the correct type; serial number should start with a 70')
                end
            end
        end
    end
end

