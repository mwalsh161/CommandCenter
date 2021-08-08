classdef Kinesis_invisible < handle

    properties(Constant, Hidden)
        MOTORPATHDEFAULT='C:\Program Files\Thorlabs\Kinesis\';
        DEVICEMANAGERDLL='Thorlabs.MotionControl.DeviceManagerCLI.dll';
        DEVICEMANAGERCLASSNAME='Thorlabs.MotionControl.DeviceManagerCLI.DeviceManagerCLI';

        TPOLLING=250;            % Default polling time
        TIMEOUTSETTINGS=7000;    % Default timeout time for settings change
        TIMEOUTMOVE=100000;      % Default time out time for motor move
    end

    methods(Abstract)

        loaddlls() % Load dlls

        connect(obj, serialNum) % Connect devices with a specified serial number

        disconnect(obj) % add comments

    end

    methods
        function obj = Kinesis_invisible()
            Drivers.Kinesis.Kinesis_invisible.loadDeviceManagerdll();
        end
    end

    methods(Static)
        function loadDeviceManagerdll() % Load DeviceManagerCLI dll
            if ~exist(Drivers.Kinesis.Kinesis_invisible.DEVICEMANAGERCLASSNAME,'class')
                try
                    NET.addAssembly([Drivers.Kinesis.Kinesis_invisible.MOTORPATHDEFAULT,Drivers.Kinesis.Kinesis_invisible.DEVICEMANAGERDLL]); 
                catch
                    error('Unable to load .NET assemblies')
                end
            end
        end

        function serialNumbers = GetDevices()  % Returns a cell array of serial numbers of connected devices   
            Drivers.Kinesis.Kinesis_invisible.loadDeviceManagerdll(); % Load DeviceMnagerCLI dll if not already loaded

            Thorlabs.MotionControl.DeviceManagerCLI.DeviceManagerCLI.BuildDeviceList();  % Build device list
            serialNumbersNet = Thorlabs.MotionControl.DeviceManagerCLI.DeviceManagerCLI.GetDeviceList(); % Get device list
            serialNumbers=cell(ToArray(serialNumbersNet)); % Convert serial numbers to cell array
        end

        function settingsLoadOption = GetSettingsLoadOption(serialNo, deviceID)
            Drivers.Kinesis.Kinesis_invisible.loadDeviceManagerdll(); % Load DeviceMnagerCLI dll if not already loaded

            deviceConfigMag = Thorlabs.MotionControl.DeviceManagerCLI.DeviceConfigurationManager;
            deviceConfigMagInstance = deviceConfigMag.Instance();
            deviceConfigMagInstance.CreateDeviceConfiguration(serialNo, uint32(str2double(serialNo(1:2))), true);
            deviceConfig = deviceConfigMag.Instance().GetDeviceConfiguration(deviceID);
            settingsLoadOption = deviceConfig.ApplicationSettingsLoadOption;
        end
    end
end