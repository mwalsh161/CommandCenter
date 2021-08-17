classdef BSC203 < Modules.Stage
    %MAX302 Control the motors of this stage.
    %   Uses 3 instances of APTMotor for x,y,z.
    %
    %   All values are in microns. It is good practice to home after
    %   construction.
    %
    %   Home is -2,-2,-2
    
    properties
        prefs = {'availMotors','x_motor','y_motor','z_motor'};
    end
    properties(SetObservable,AbortSet)
        availMotors = Drivers.Kinesis.KinesisBSC203.getAvailMotors;
%         calibration = [500 500 500] Prefs.DoubleArray([2 2 2],'help_text','Calibration for the motor distance to true distance');
    end
    
    properties(GetObservable, SetObservable, AbortSet)
        x_motor = Prefs.MultipleChoice(1,'choices',{1,2,3},'allow_empty',true,'set',@set_x_motor,'help_text','Which channel in the controller controls the x direction motor');
        y_motor = Prefs.MultipleChoice(2,'choices',{1,2,3},'allow_empty',true,'set',@set_y_motor,'help_text','Which channel in the controller controls the y direction motor');
        z_motor = Prefs.MultipleChoice(3,'choices',{1,2,3},'allow_empty',true,'set',@set_z_motor,'help_text','Which channel in the controller controls the z direction motor');
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
                delete(obj.motors);
            end
        end
        function pos = get.position(obj)
            % this function reads the current motor position
            pos = [NaN NaN NaN];
            n = 1
            for channelNo = obj.motor_channels
                positions = obj.motors.positions;
                if isnan(channelNo)
                    pos(n) = NaN;
                else
                    pos(n) = positions(channelNo)
                n = n + 1;
            end
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

        function set.availMotors(obj,val)
            % Validate that the serial number is the correct type for BSC203
            if ~isempty(val)
                if strcmp(val(1:2), '70')
                    try
                        obj.set_controller(val); 
                    catch err
                        rethrow(err)
                    end
                else
                    error('This device is not of the correct type; serial number should start with a 70')
                end
            end
        end
        
        function val = set_x_motor(obj, channelNo, ~)
            % check to make sure that no other motor is using this channel before setting x motor
            if ~isnan(obj.motor_channels(1)) && obj.motor_channels(1) ~= channelNo
                error(strcat('Channel ', num2str(channelNo), ' was already used for other motors.'))
            else
                val = channelNo;

                if isnumeric(channelNo)
                    obj.motor_channels(1) = channelNo;

                elseif strcmp(channelNo, '<None>')
                    obj.motor_channels(1) = NaN;
                else
                    error('x_motor assignment type was not recognised.')
                end
            end
            obj.set_controller
        end

        function val = set_y_motor(obj, channelNo, ~)
            % check to make sure that no other motor is using this channel before setting y motor
            if ~isnan(obj.motor_channels(2)) && obj.motor_channels(2) ~= channelNo
                error(strcat('Channel ', num2str(channelNo), ' was already used for other motors.'))
            else
                val = channelNo;

                if isnumeric(channelNo)
                    obj.motor_channels(2) = channelNo;

                elseif strcmp(channelNo, '<None>')
                    obj.motor_channels(2) = NaN;
                else
                    error('x_motor assignment type was not recognised.')
                end
            end
            obj.set_controller
        end

        function val = set_z_motor(obj, channelNo, ~)
            % check to make sure that no other motor is using this channel before setting z motor
            if ~isnan(obj.motor_channels(3)) && obj.motor_channels(3) ~= channelNo
                error(strcat('Channel ', num2str(channelNo), ' was already used for other motors.'))
            else
                val = channelNo;

                if isnumeric(channelNo)
                    obj.motor_channels(3) = channelNo;

                elseif strcmp(channelNo, '<None>')
                    obj.motor_channels(3) = NaN;
                else
                    error('x_motor assignment type was not recognised.')
                end
            end
            obj.set_controller
        end
        
        function set_controller(obj, SerialNo)
            % take val, and instantiate the driver for the BSC203

            obj.motors = Drivers.Kinesis.KinesisBSC203.instance(SerialNo, [0 8], SerialNo, obj.motor_channels);
            % Listeners will follow lifecycle of their motor
            addlistener(obj.motors,'isMoving','PostSet',@obj.movingCallback);
            addlistener(obj.motors,'Homed','PostSet',@obj.homedCallback);
            % Intialize values
            obj.homedCallback;
            obj.movingCallback;
        end
    end
end

