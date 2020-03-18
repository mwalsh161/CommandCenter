classdef ArduinoServo < Modules.Driver
    %ARDUINOSERVO Connects with a hwserver Arduino and uses one pin to control a servo.
    %
    % Call with the 1) IP of the host computer (singleton based on ip), and 2) the (integer) pin.
    
    properties (Constant)
        hwname = 'Arduino';
    end
    properties (SetAccess=immutable)
        connection
        pin
    end
    properties (GetObservable, SetObservable)
        angle = Prefs.Double(NaN, 'min', 0, 'max', 180, 'set', 'set_angle', 'allow_nan', true);
    end
    methods(Static)
        function obj = instance(ip, pin)
            mlock;
            pin = round(pin);
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.ArduinoServo.empty(1,0);
            end
            [~,resolvedIP] = resolvehost(ip);
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(resolvedIP, {Objects(i).singleton_id, pin})
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.ArduinoServo(ip, pin);
            obj.singleton_id = {resolvedIP, pin};
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = ArduinoServo(ip, pin)
            obj.connection = hwserver(ip);
            try % Init laser
                obj.com('?')
            catch err
                error(err.message);
            end
            obj.pin = pin;
        end
        function response = com(obj,funcname,varargin) %keep this
            if obj.debug
                fprintf('--> %s %s',funcname,jsonencode(varargin));
            end
            response = obj.connection.com(obj.hwname,funcname,varargin{:});
            if obj.debug
                fprintf('  <-- %s',jsonencode(response));
            end
        end
    end
    methods
        function delete(obj)
            delete(obj.connection)
        end
        function val = set_angle(obj,val,~)
            obj.com(['s ' num2str(obj.pin) ' ' num2str(obj.val)]);
        end
        function lock(obj)
            obj.com(['l ' num2str(obj.pin)]);
        end
        function unlock(obj)
            obj.com('u');
        end
    end
end
