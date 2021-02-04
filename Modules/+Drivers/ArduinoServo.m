classdef ArduinoServo < Modules.Driver
    %ARDUINOSERVO Connects with a hwserver Arduino and uses one pin to control a servo.
    %
    % Call with the 1) hostname of the host computer (singleton based on host), and 2) the (integer) pin.
    
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
        function obj = instance(host, pin)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.ArduinoServo.empty(1,0);
            end
            [~,resolvedIP] = resolvehost(host);
            
            singleton_id = [resolvedIP '_line' num2str(pin)];
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(singleton_id, Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.ArduinoServo(resolvedIP, pin);
            obj.singleton_id = singleton_id;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = ArduinoServo(host, pin)
            obj.connection = hwserver(host);
            obj.com('?');   % This command pings the server for an appropriate response. If something is wrong, we will catch it here.
            obj.pin = pin;
        end
        function response = com(obj,funcname,varargin) %keep this
            response = obj.connection.com(obj.hwname,funcname,varargin{:});
        end
    end
    methods
        function delete(obj)
            delete(obj.connection)
        end
        function val = set_angle(obj,val,~)     % Locks to new angle (0 -> 180 standard), then unlocks.
            obj.com(['s ' num2str(obj.pin) ' ' num2str(val)]);
        end
        function lock(obj)                      % Tells the arduino to get the servo to apply electronic feedback against any force. Without the lock, the servo can spin ~freely by hand. With the lock, this is more difficult. Only works for one pin at a time at the moment.
            obj.com(['l ' num2str(obj.pin)]);
        end
        function unlock(obj)                    % Unlocks any locked pin.
            obj.com('u');
        end
    end
end
