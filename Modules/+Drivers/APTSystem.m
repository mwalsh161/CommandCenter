classdef (Sealed) APTSystem < Drivers.APT & Modules.Driver
    % APTSystem A subclass to handle MG17 APT systems
    %   These include: USB_STEPPER_DRIVE, USB_PIEZO_DRIVE, USB_NANOTRAK
    %   The purpose of this module is to discover devices

    properties(Constant,Hidden)
        %hardcoded values from the APT library
        USB_STEPPER_DRIVE = 6;
        USB_PIEZO_DRIVE = 7;
        USB_NANOTRAK = 8;
        dev_types = {'USB_STEPPER_DRIVE','USB_PIEZO_DRIVE','USB_NANOTRAK'};
    end
    
    methods (Static)
        function obj = instance()
            mlock;
            persistent Object
            if ~isempty(Object)&&isobject(Object) && isvalid(Object)
                obj = Object;
                return
            end
            obj = Drivers.APTSystem();
            Object = obj;
        end
    end    
    methods(Access=private)
        % Constructor should only be called by instance()
        function obj = APTSystem()
            obj.initialize('MG17SYSTEM.MG17SystemCtrl.1','System Control');
        end
    end

    methods
        % Get devices
        function devices = getDevices(obj)
            devices = struct;
            for j = 1:length(obj.dev_types)
                dev_type_n = obj.(obj.dev_types{j});
                [~,num] = obj.LibraryFunction('GetNumHWUnits',dev_type_n,0);
                devices.(obj.dev_types{j}) = zeros(1,num,'uint64');
                for i = 1:num
                    [~,SN] = obj.LibraryFunction('GetHWSerialNum',dev_type_n,i-1,0);
                    devices.(obj.dev_types{j})(i) = SN;
                end
            end
        end
    end
end
