classdef KinesisBSC203 < Drivers.Kinesis.Kinesis_invisible & Modules.Driver

properties(Constant, Hidden)
    GENERICMOTORDLL='Thorlabs.MotionControl.GenericMotorCLI.dll';
    GENERICMOTORCLASSNAME='Thorlabs.MotionControl.GenericMotorCLI.GenericMotorCLI';
    STEPPERMOTORDLL='Thorlabs.MotionControl.Benchtop.StepperMotorCLI.dll';
    STEPPERMOTORCLASSNAME='Thorlabs.MotionControl.Benchtop.StepperMotorCLI.BenchtopStepperMotor';
end

properties(SetAccess = private)
    isconnected = false;         % Flag set if device connected
    serialnumbers;               % Device serial numbers
    controllername;              % Controller Name
    controllerdescription        % Controller Description
    stagename;                   % Stage Name
    acceleration;                % Acceleration
    maxvelocity;                 % Maximum velocity limit
    minvelocity;                 % Minimum velocity limit
    positions;                   % Motor position (1 * 3 array)

    Homed;
    IsMoving;
end

properties(Constant)
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
    function obj = KinesisBSC203(serialNum, name)  % Instantiate the KinesisBSC203 motor object
        KinesisBSC203.loaddlls; % Load DLLs if not already loaded
        KinesisBSC203.connect(serialNum); % Connect device
    end
end

methods
    function obj = instance(serialNum,name)
        mlock;
        if nargin < 3
            name = serialNum;
        end
        persistent Objects
        if isempty(Objects)
            Objects = Drivers.Kinesis.KinesisBSC203.empty(1,0);
        end
        for i = 1:length(Objects)
            if isvalid(Objects(i)) && isequal(serialNum,Objects(i).singleton_id)
                obj = Objects(i);
                return
            end
        end
        obj = Drivers.Kinesis.KinesisBSC203(serialNum,name);
        obj.singleton_id = serialNum;
        Objects(end+1) = obj;
    end
    
    
    % 
    function connect(obj, serialNo) % serialNo := str
        obj.GetDevices; % Call this to build device list if not already done

        if ~exist(obj.deviceNET)    % Checking if a .NET BenchtopStepperMotor instance is already created
            if str2double(serialNo(1:2)) == double(Thorlabs.MotionControl.Benchtop.StepperMotorCLI.BenchtopStepperMotor.DevicePrefix70) % Checking whether ther serial number corresponds to a BenchtopStepperMotor
                obj.deviceNET = Thorlabs.MotionControl.Benchtop.StepperMotorCLI.BenchtopStepperMotor.CreateBenchtopStepperMotor(serialNo);  % Create an instance of .NET BenchtopStepperMotor
            else    % Serial number prefix does not belong to Benchtop Stepper Motor
                error('Serial Number is not Benchtop Stepper Motor.')
            end
        end 

        for i = 1:3
            obj.channelsNET{i} = obj.deviceNET.GetChannel(i);   % Get channel objects of the device
            obj.channelsNET{i}.ClearDeviceExceptions(); % Clear device exceptions via .NET interface
        end

        if ~obj.isconnected()   % Connect and initialize device if not connected                                 
            obj.deviceNET.Connect(serialNo);    % Connect to device via .NET interface
            obj.initialize(serialNo)    % Initialize the device
        else    % Device already connected
            error('Device is already connected')
        end
        obj.updatestatus   % Update status variables from device
    end

    function initialize(obj, serialNo) % Initialize all three channels of the device, serialNo := str
        for i = 1:3
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
                settingsLoadOption = Kinesis_invisible.GetSettingsLoadOption(serialNo, deviceID);
                obj.motorSettingsNET{i} = obj.channelsNET{i}.GetMotorConfiguration(serialNo, settingsLoadOption);

                % Initialize current motor settings
                obj.currentDeviceSettingsNET{i}=obj.channelsNET{i}.MotorDeviceSettings;
                obj.deviceInfoNET{i} = obj.channelsNET{i}.GetDeviceInfo();  % Get deviceInfo via .NET interface
            catch
                error(['Unable to initialize channel ', num2str(i)]);
            end
        end
        
    end

    function updatestatus(obj)
        obj.isconnected = obj.deviceNET.IsConnected();  % connection status            
        for i = 1:3
            obj.serialnumbers{i}=char(obj.channelsNET{i}.DeviceID); % update serial number
            obj.controllername{i}=char(obj.deviceInfoNET{i}.Name);  % update controleller name
            obj.controllerdescription{i}=char(obj.deviceInfoNET{i}.Description);    % update controller description
            obj.stagename{i}=char(obj.motorSettingsNET{i}.DeviceSettingsName);  % update stagename                
            velocityparams{i}=obj.channelsNET{i}.GetVelocityParams();   % update velocity parameter
            obj.acceleration{i}=System.Decimal.ToDouble(velocityparams{i}.Acceleration);    % update acceleration parameter
            obj.maxvelocity{i}=System.Decimal.ToDouble(velocityparams{i}.MaxVelocity);  % update max velocit parameter
            obj.minvelocity{i}=System.Decimal.ToDouble(velocityparams{i}.MinVelocity);  % update Min velocity parameter
            obj.position(i) = System.Decimal.ToDouble(obj.channelsNET{i}.Position); % motor positions

            
        end
    end

    function disconnect(obj) 
        obj.isconnected = obj.deviceNET.IsConnected();    % Read connection status
        if obj.isconnected  % Disconnect device if connected
            try
                for i = 1:3
                    obj.channelsNET{i}.StopPolling();   % Stop polling device via .NET interface
                    obj.channelsNET{i}.DisableDevice(); % Disable device via .NET interface
                end
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
        for i = 1:3
            workDone=obj.channelsNET{i}.InitializeWaitHandler();     % Initialise Waithandler for timeout
            obj.channelsNET{i}.Home(workDone);                       % Home device via .NET interface
            obj.channelsNET{i}.Wait(obj.TIMEOUTMOVE);                % Wait for move to finish                      
        end
        obj.updatestatus; % Update status variables from device
    end

    function tf = checkMove(obj, target_pos)
        %   Check to make sure target_pos is ok to execute
        %   Error if it is outside limits
        %   Error if the channel needs to be homed
        %   Otherwise returns true
        tf = true;
        for i = 1 : 3
            assert(~obj.channelsNET{i}.NeedsHoming,'Motor %f is not homed!', )
            assert(target_pos(i) <= max(obj.Travel) && target_pos >= min(obj.Travel),...
                'Attempted to move motor %f to %f, but it is limited to %f, %f', i, target_pos, min(obj.Travel), max(obj.Travel))
        end
    end

    function moveto(obj, target_pos)
        tf = obj.checkMove(target_pos);
        if tf
            for i = 1:3
                try
                    workDone=obj.channelsNET{i}.InitializeWaitHandler(); % Initialise Waithandler for timeout
                    obj.channelsNET{i}.MoveTo(target_pos(i), workDone);       % Move device to position via .NET interface
                    obj.channelsNET{i}.Wait(obj.TIMEOUTMOVE);              % Wait for move to finish
                catch
                    error(['Unable to Move channel ',obj.serialnumber{i},' to ',num2str(target_pos(i))]);
                end
            end
        else
            error('Target position is not valid')
        end
        obj.updatestatus
    end  

    function step(obj, distance)

    end

    function pos = GetPosition(obj)
        pos = [0 0 0];
        for i = 1:3
            pos(i) = System.Decimal.ToDouble(obj.channelsNET{i}.Position);
        end
    end

end

methods (Static)
    function loaddlls() % Load DLLs (Load all relevant dlls in case the GetDevices function was not called)
        if ~exist(KinesisBSC203.DEVICEMANAGERCLASSNAME,'class')
            try % Load DeviceManagerCLI dll if not already loaded
                NET.addAssembly([KinesisBSC203.MOTORPATHDEFAULT,KinesisBSC203.DEVICEMANAGERDLL]); 
            catch
                error('Unable to load .NET assemblies')
            end
        end
        if ~exist(KinesisBSC203.GENERICMOTORCLASSNAME,'class')
            try % Load in DLLs if not already loaded
                NET.addAssembly([KinesisBSC203.MOTORPATHDEFAULT,KinesisBSC203.GENERICMOTORDLL]);
                NET.addAssembly([KinesisBSC203.MOTORPATHDEFAULT,KinesisBSC203.STEPPERMOTORDLL]);
            catch   % DLLs did not load
                error('Unable to load .NET assemblies')
            end
    end
end