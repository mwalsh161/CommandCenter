classdef SuperK < Modules.Source
    %superK used to control all aspects of the superK laser.
    %
    %   The on/off state of laser is controlled by the PulseBlaster (loaded
    %   in set.ip).  Note this state can switch to unknown if another
    %   module takes over the PulseBlaster program.
    %
    %   Power to the laser can be controlled through the serial object
    %   - obj.serial.on()/off() - however, time consuming calls!
    
    properties
        ip = 'No Server';         % IP of computer with and server
        prefs = {'ip'};
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
        running                      % Boolean specifying if StaticLines program running
    end
    properties(SetAccess=private,Hidden)
        status                       % Text object reflecting running
        path_button
        serial
    end
    methods(Access=protected)
        function obj = SuperK()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.SuperK();
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            delete(obj.serial)
        end
        function set.ip(obj,val)
            err = [];
            if strcmp(obj.ip,'No Server')
                obj.ip = val;
                return
            end
            try
                delete(obj.serial)
                obj.serial = Drivers.SuperK.instance(val);
                obj.ip = val;   
            catch err
                obj.ip = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function on(obj)
            obj.serial.on();
            obj.source_on = true;
        end
        function off(obj)
            obj.serial.off();
            obj.source_on = false;
        end

        function arm(obj)
            % nothing needs to be done since SuperK just needs on/off methods=
        end
        
    end
end