classdef KinesisBSC203 < Drivers.Kinesis.Kinesis_invisible & Modules.Driver
    
    properties
        name
        motor_channels
    end
    properties(Constant, Hidden)
        GENERICMOTORDLL='Thorlabs.MotionControl.GenericMotorCLI.dll';
        GENERICMOTORCLASSNAME='Thorlabs.MotionControl.GenericMotorCLI.GenericMotorCLI';
        STEPPERMOTORDLL='Thorlabs.MotionControl.Benchtop.StepperMotorCLI.dll';
        STEPPERMOTORCLASSNAME='Thorlabs.MotionControl.Benchtop.StepperMotorCLI.BenchtopStepperMotor';
    end

    properties(SetAccess = private, SetObservable, AbortSet)
        isconnected = false;         % Flag set if device connected
        serialnumbers;               % Device serial numbers
        controllername;              % Controller Name
        controllerdescription        % Controller Description
        stagename;                   % Stage Name
        acceleration;                % Acceleration
        maxvelocity;                 % Maximum velocity limit
        minvelocity;                 % Minimum velocity limit
        positions = [NaN, NaN, NaN];                   % Motor position (1 * 3 array)

        Homed;
        isMoving = false;

        Travel = [-2 2] * 1000;
    end

    properties(Hidden)
        deviceNET;                   % Device object within .NET
        channelsNET;                 % Channel object within .NET (1 * 3 cell)
        motorSettingsNET;            % motorSettings within .NET (1 * 3 cell)
        currentDeviceSettingsNET;    % currentDeviceSetings within .NET (1 * 3 cell)
        deviceInfoNET;               % deviceInfo within .NET (1 * 3 cell)
    end

    methods(Access=private)
        % Constructor
        function obj = KinesisBSC203(serialNo, travel, name, motor_channels)  % Instantiate the KinesisBSC203 motor object
            Drivers.Kinesis.KinesisBSC203.loaddlls; % Load DLLs if not already loaded           
            obj.connect(serialNo); % Connect device
            obj.Travel = travel;
            obj.name = name;
            obj.motor_channels = motor_channels;
        end
    end

    methods(Static)
        % Use this to create/retrieve instance associated with serialNo
        function obj = instance(serialNo, travel, name, motor_channels)
            mlock;
            if nargin < 2
                name = serialNo;
            end
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.Kinesis.KinesisBSC203.empty(1,0); % Create an empty class
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(serialNo,Objects(i).singleton_id)    % Find instance with the same singleton ID
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.Kinesis.KinesisBSC203(serialNo, travel, name, motor_channels); % Create an instance
            obj.singleton_id = serialNo;   % Define singleton ID
            Objects(end+1) = obj;   % Add the instance to the object list
        end
    end
    
    methods
        % Connect to the device with a specified serial number and initialize the device
        function connect(obj, serialNo) % serialNo := str
            obj.GetDevices;  % Call this to build device list if not already done
            if ~obj.isconnected()   % Connect and initialize device if not connected  
                obj.deviceNET = Thorlabs.MotionControl.Benchtop.StepperMotorCLI.BenchtopStepperMotor.CreateBenchtopStepperMotor(serialNo);  % Create an instance of .NET BenchtopStepperMotor
                for i = obj.motor_channels
                    if ~isnan(i)
                        obj.channelsNET{i} = obj.deviceNET.GetChannel(i);   % Get channel objects of the device
                        obj.channelsNET{i}.ClearDeviceExceptions(); % Clear device exceptions via .NET interface
                    end
                end
                                                                        
                obj.deviceNET.Connect(serialNo);    % Connect to device via .NET interface
                obj.initialize(serialNo)    % Initialize the device
            else    % Device already connected
                error('Device is already connected')
            end
            obj.updatestatus   % Update status variables from device
        end

        function initialize(obj, serialNo) % Initialize all three channels of the device, serialNo := str
            for i = obj.motor_channels
                if ~isnan(i)
                    try
                        if ~obj.channelsNET{i}.IsSettingsInitialized() 
                            obj.channelsNET{i}.WaitForSettingsInitialized(obj.TIMEOUTSETTINGS); % Initialize the ith channel
                        else
                            disp('Device Already Initialized.')
                        end
                        if ~obj.channelsNET{i}.IsSettingsInitialized() % Device not successfully initialized
                            error('Unable to initialize device')
                        end
                        obj.channelsNET{i}.StartPolling(obj.TPOLLING);  % Start polling device via .NET interface
                        obj.channelsNET{i}.EnableDevice();  % Enable device via .NET interface

                        % Initialize motor configuration
                        deviceID = obj.channelsNET{i}.DeviceID;
                        settingsLoadOption = Drivers.Kinesis.Kinesis_invisible.GetSettingsLoadOption(serialNo, deviceID);
                        obj.motorSettingsNET{i} = obj.channelsNET{i}.GetMotorConfiguration(serialNo, settingsLoadOption);

                        % Initialize current motor settings
                        obj.currentDeviceSettingsNET{i}=obj.channelsNET{i}.MotorDeviceSettings;
                        obj.deviceInfoNET{i} = obj.channelsNET{i}.GetDeviceInfo();  % Get deviceInfo via .NET interface
                    catch
                        error(['Unable to initialize channel ', num2str(i)]);
                    end
                end
            end

        end

        function updatestatus(obj)
            obj.isconnected = obj.deviceNET.IsConnected();  % connection status
            homed = true(1, 3);
            moving = false(1, 3);            
            for i = obj.motor_channels
                if ~isnan(i)
                    obj.serialnumbers{i}=char(obj.channelsNET{i}.DeviceID); % update serial number
                    obj.controllername{i}=char(obj.deviceInfoNET{i}.Name);  % update controleller name
                    obj.controllerdescription{i}=char(obj.deviceInfoNET{i}.Description);    % update controller description
                    obj.stagename{i}=char(obj.motorSettingsNET{i}.DeviceSettingsName);  % update stagename                
                    velocityparams{i}=obj.channelsNET{i}.GetVelocityParams();   % update velocity parameter
                    obj.acceleration{i}=System.Decimal.ToDouble(velocityparams{i}.Acceleration);    % update acceleration parameter
                    obj.maxvelocity{i}=System.Decimal.ToDouble(velocityparams{i}.MaxVelocity);  % update max velocit parameter
                    obj.minvelocity{i}=System.Decimal.ToDouble(velocityparams{i}.MinVelocity);  % update Min velocity parameter
                    obj.positions(i) = System.Decimal.ToDouble(obj.channelsNET{i}.Position); % motor positions
                    homed(i) = ~obj.channelsNET{i}.NeedsHoming;
                    if obj.channelsNET{i}.State == Thorlabs.MotionControl.GenericMotorCLI.MotorStates.Idle
                        moving(i) = false;
                    else
                        moving(i) = true;
                    end
                end
            end
            obj.Homed = all(homed);
            obj.isMoving = any(moving);
        end

        function disconnect(obj) 
            obj.isconnected = obj.deviceNET.IsConnected();    % Read connection status
            if obj.isconnected  % Disconnect device if connected
                for i = obj.motor_channels
                    if ~isnan(i)
                        try
                            obj.channelsNET{i}.StopPolling();   % Stop polling device via .NET interface
                            obj.channelsNET{i}.DisableDevice(); % Disable device via .NET interface
                        catch
                            error(['Unable to disconnect device',obj.serialnumbers{i}]);
                        end

                    end
                end
                try
                    obj.deviceNET.Disconnect(true)
                catch
                    error(['Unable to disconnect device',obj.serialnumbers{i}]);
                end
                obj.isconnected = obj.deviceNET.IsConnected();
            else % Cannot disconnect because device not connected
                error('Device not connected.')
            end
        end

        function home(obj)
            for i = obj.motor_channels
                if ~isnan(i)
                    workDone=obj.channelsNET{i}.InitializeWaitHandler();     % Initialise Waithandler for timeout
                    obj.channelsNET{i}.Home(workDone);                       % Home device via .NET interface
                    obj.channelsNET{i}.Wait(obj.TIMEOUTMOVE);                % Wait for move to finish     
                end                 
            end
            obj.updatestatus; % Update status variables from device
        end

        function tf = checkMove(obj, target_pos)
            %   Check to make sure target_pos is ok to execute
            %   Error if it is outside limits
            %   Error if the channel needs to be homed
            %   Otherwise returns true
            tf = true;
            for i = obj.motor_channels
                if ~isnan(i)
                    assert(~obj.channelsNET{i}.NeedsHoming,'Motor %f is not homed!', i)
                    assert(target_pos(i) <= max(obj.Travel) && target_pos(i) >= min(obj.Travel),...
                        'Attempted to move motor %f to %f, but it is limited to %f, %f', i, target_pos, min(obj.Travel), max(obj.Travel))
                end
            end
        end

        function moveto(obj, target_pos)
            %   Move to target position, target_pos := 1 * 3 array of double
            tf = obj.checkMove(target_pos);
            if tf
                n = 1;
                target_pos_channel = [NaN NaN NaN];
                for channelNo = obj.motor_channels
                    if isnan(channelNo)
                        target_pos_channel(n) = NaN;
                    else
                        target_pos_channel(n) = target_pos(channelNo);
                    n = n + 1;
                    end
                end
                for i = obj.motor_channels
                    if ~isnan(i)
                        try
                            workDone=obj.channelsNET{i}.InitializeWaitHandler(); % Initialise Waithandler for timeout
                            obj.channelsNET{i}.MoveTo(target_pos(i), workDone);       % Move device to position via .NET interface
                            obj.channelsNET{i}.Wait(obj.TIMEOUTMOVE);              % Wait for move to finish
                        catch
                            error(['Unable to Move channel ',obj.serialnumber{i},' to ',num2str(target_pos(i))]);
                        end
                    end
                end
            else
                error('Target position is out of range')
            end
            obj.updatestatus
        end  

        function step(obj, channelNo, distance)
            % Method to move the motor by a jog
            % channelNo := int, distance : double,
            if distance < 0 % Set jog direction to backwards
                motordirection=Thorlabs.MotionControl.GenericMotorCLI.MotorDirection.Backward;
            elseif distance > 0 % Set jog direction to forwards
                motordirection=Thorlabs.MotionControl.GenericMotorCLI.MotorDirection.Forward;
            else
                error('Step size cannot be zero')
            end   
            
            % Calculate the position after the step 
            step_pos = [0 0 0];
            obj.channelsNET{channelNo}.SetJogStepSize(abs(distance)) % Set the step size for jog
            step_pos(channelNo) = obj.channelsNET{channelNo}.GetJogStepSize();
            target_pos = obj.positions + step_pos;
            
            % Check whether the position after the step exceeds the travel
            tf = obj.checkMove(target_pos);
            
            if tf
                try
                    workDone = obj.channelsNET{channelNo}.InitializeWaitHandler();
                    obj.channelsNET{channelNo}.MoveJog(motordirection, workDone);   % Execute jog
                    obj.channelsNET{channelNo}.Wait(obj.TIMEOUTMOVE);
                catch 
                    error('Unable to execute jog')
                end
            else
                error('Target position is out of range')
            end
            obj.updatestatus
        end
        
        function movecont(h, channelNo, varargin)  % Set motor to move continuously
            if (nargin>2) && (varargin{1})      % if parameter given (e.g. 1) move backwards
                motordirection=Thorlabs.MotionControl.GenericMotorCLI.MotorDirection.Backward;
            else                                % if no parametr given move forwards
                motordirection=Thorlabs.MotionControl.GenericMotorCLI.MotorDirection.Forward;
            end
            h.channelsNET{channelNo}.MoveContinuous(motordirection); % Set motor into continous move via .NET interface
            obj.updatestatus;            % Update status variables from device
        end
        
        function stop(h, immediate) % Stop the motor moving (needed if set motor to continous)
            for i = obj.motor_channels
                if ~isnan(i)
                    if nargin > 1 && immediate
                        h.channelsNET{i}.StopImmediate();
                    else
                        h.channelsNET{channelNo}.Stop(h.TIMEOUTMOVE); % Stop motor movement via.NET interface
                    end
                end
            end
            obj.updatestatus            % Update status variables from device
        end

        function pos = get.positions(obj)
            pos = [NaN NaN NaN];
            for i = obj.motor_channels
                if ~isnan(i)
                    pos(i) = System.Decimal.ToDouble(obj.channelsNET{i}.Position);
                end
            end
        end

        function enable(obj)
            for i = obj.motor_channels
                if ~isnan(i)
                    obj.channelsNET{i}.EnableDevice();  % Enable device via .NET interface
                end
            end
            obj.updatestatus
        end

        function disable(obj)
            for i = obj.motor_channels
                if ~isnan(i)
                    obj.channelsNET{i}.DisableDevice();  % Enable device via .NET interface
                end
            end
            obj.updatestatus
        end

    end

    methods (Static)
        function loaddlls() % Load DLLs (Load all relevant dlls in case the GetDevices function was not called)
            if ~exist(Drivers.Kinesis.KinesisBSC203.DEVICEMANAGERCLASSNAME,'class')
                try % Load DeviceManagerCLI dll if not already loaded
                    NET.addAssembly([Drivers.Kinesis.KinesisBSC203.MOTORPATHDEFAULT,Drivers.Kinesis.KinesisBSC203.DEVICEMANAGERDLL]); 
                catch
                    error('Unable to load .NET assemblies')
                end
            end
            if ~exist(Drivers.Kinesis.KinesisBSC203.GENERICMOTORCLASSNAME,'class')
                try % Load in DLLs if not already loaded
                    NET.addAssembly([Drivers.Kinesis.KinesisBSC203.MOTORPATHDEFAULT,Drivers.Kinesis.KinesisBSC203.GENERICMOTORDLL]);
                    NET.addAssembly([Drivers.Kinesis.KinesisBSC203.MOTORPATHDEFAULT,Drivers.Kinesis.KinesisBSC203.STEPPERMOTORDLL]);
                catch   % DLLs did not load
                    error('Unable to load .NET assemblies')
                end
            end
        end

        function motorSerialNumbers = getAvailMotors()
            motorSerialNumbers = {};
            serialNumbers = Drivers.Kinesis.Kinesis_invisible.GetDevices;
            for i = 1 : length(serialNumbers)
                if strcmp(serialNumbers{i}(1:2), '70')
                    motorSerialNumbers{end + 1} = serialNumbers{i};
                end
            end
        end
    end
end
