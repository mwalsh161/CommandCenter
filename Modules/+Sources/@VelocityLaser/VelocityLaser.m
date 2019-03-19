classdef VelocityLaser < Modules.Source & Sources.TunableLaser_invisible
    %VelocityLaser used to control all aspects of the tunable laser.
    %
    %   Loads instances of serial connection and wavemeter. Used for
    %   course and fine tuning/scanning of laser.
    %
    %   The on/off state of laser is controlled by the PulseBlaster (loaded
    %   in set.ip).  Note this state can switch to unknown if another
    %   module takes over the PulseBlaster program.
    %
    %   Power to the laser can be controlled through the serial object
    %   - obj.serial.on()/off() - however, time consuming calls!
    
    properties
        TuningTimeout = 60; % Timeout for all tune methods
    end
    properties(SetObservable,AbortSet)
        prefs = {'PBline','pb_ip','velocity_ip','wavemeter_ip','wavemeter_channel'};
        show_prefs = {'status','diode_on','PBline','pb_ip','velocity_ip','wavemeter_channel','wavemeter_ip'};
        readonly_prefs = {'status'};
    end
    properties(SetAccess=protected)
        range = 299792./[635,640]; %tunable range in THz
        Vrange = [-2.3, 2.3]; %setting the piezo percentage maps (0,100)
        resolution = 0.01; %frequency tuning resolution in THz
    end
    properties(SetObservable)
        pb_ip = 'No Server';         % IP of computer with PB and server
        PBline = 12;
        velocity_ip = 'No Server';
        wavemeter_ip = 'No Server';
        wavemeter_channel = 3;              % Pulse Blaster flag bit (indexed from 1)
        diode_on = false;         % Power state of diode (on/off); assume off everytime because we cant check easily
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
        running                      % Boolean specifying if StaticLines program running
        status
    end
    properties(Access=private)
        listeners
        path_button
    end
    properties(SetAccess=private)
        PulseBlaster %hardware handle
        serial
        wavemeter
    end
    methods(Access=protected)
        function obj = VelocityLaser()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.VelocityLaser();
            end
            obj = Object;
        end
    end
    methods
        function task = inactive(obj)
            task = '';
            if ~isempty(obj.serial)
                task = 'Turning diode power off';
                obj.serial.off;
            end
        end
        function delete(obj)
            delete(obj.listeners)
        end
        function err = connect_driver(obj,propname,drivername,varargin)
            err = [];
            if ~isempty(obj.(propname))
                delete(obj.(propname)); %remove any old connection
            end
            if ischar(varargin{1}) && strcmpi(varargin{1},'No Server') %first input is always an ip address
                obj.(propname) = [];
            else
                try
                    obj.(propname) = Drivers.(drivername).instance(varargin{:});
                catch err
                    obj.(propname) = [];
                end
            end
        end
        function set.velocity_ip(obj,val)
            err = obj.connect_driver('serial','VelocityLaser',val);
            if isempty(obj.serial) %#ok<*MCSUP>
                obj.velocity_ip = 'No Server';
                obj.diode_on = NaN;
                return
            end
            if ~isempty(err)
                rethrow(err)
            end
            obj.velocity_ip = val;
            obj.diode_on = obj.serial.getDiodeState;
        end
        function set.pb_ip(obj,val)
            err = obj.connect_driver('PulseBlaster','PulseBlaster.StaticLines',val);
            if isempty(obj.PulseBlaster)
                obj.pb_ip = 'No Server';
                return
            end
            obj.isRunning;
            if ~isempty(err)
                rethrow(err)
            end
            obj.pb_ip = val;
            obj.source_on = obj.PulseBlaster.lines(obj.PBline);
            delete(obj.listeners);
            obj.listeners = addlistener(obj.PulseBlaster,'running','PostSet',@obj.isRunning);
        end
        function set.PBline(obj,val)
            assert(round(val)==val&&val>0,'PBline must be an integer greater than 0.')
            obj.PBline = val;
            if ~isempty(obj.PulseBlaster)
                obj.source_on = obj.PulseBlaster.lines(obj.PBline);
            end
        end
        function set.wavemeter_ip(obj,val)
            err = obj.connect_driver('wavemeter','Wavemeter',val,obj.wavemeter_channel);
            if isempty(obj.wavemeter)
                obj.wavemeter_ip = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
            obj.wavemeter_ip = val;
        end
        function set.wavemeter_channel(obj,val)
            assert(round(val)==val&&val>0,'wavemeter_channel must be an integer greater than 0.')
            obj.wavemeter_channel = val;
            err = obj.connect_driver('wavemeter','Wavemeter',obj.wavemeter_ip,val);
            if ~isempty(err)
                rethrow(err)
            end
        end
        function set.diode_on(obj,val)
            if isnan(val);obj.diode_on=false;return;end %short-circuit if set to nan but keep false for settings method
            assert(~isempty(obj.serial),'No Velocity Laser connected');
            % This requires some time, so have msgbox appear
            st = dbstack;
            if ~any(strcmpi(extractfield(st,'name'),'VelocityLaser.set.velocity_ip'))
                if val
                    f = msgbox('Turning laser diode on, please wait...');
                    obj.serial.on;
                else
                    f = msgbox('Turning laser diode off, please wait...');
                    obj.serial.off;
                end
                delete(f);
            end
            obj.diode_on = val;
        end
        function on(obj)
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.PulseBlaster.lines(obj.PBline) = true;
            obj.source_on = true;
        end
        function off(obj)
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.source_on = false;
            obj.PulseBlaster.lines(obj.PBline) = false;
        end
        function val = getFrequency(obj)
            val = obj.wavemeter.getFrequency();
        end
        function isRunning(obj,varargin)
            if isempty(obj.PulseBlaster)
                obj.status = 'Not Connected';
            else
                obj.running = obj.PulseBlaster.running;
                if obj.running
                    obj.status = 'Running';
                else
                    obj.status = 'Unknown State, to update, change state.';
                end
            end
        end
        function RangeCheck(obj,val)
            %checks if value is in range
            err = [];
            if val < min(obj.range) || val > max(obj.range)
                err = sprintf('Laser wavelength must be in range [%g,%g] THz',obj.range(1),obj.range(2));
            end
            if ~isempty(err)
                error(err)
            end
        end
    end
end
