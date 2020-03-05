classdef Cobolt_PB < Modules.Source
    % Cobolt_PB controls the Cobolt via USB and fast diode modulation via pulseblaster
    
    properties(SetObservable, GetObservable)
        cobolt_ip = Prefs.String('No Server', 'set', 'set_cobolt_ip', 'help', 'IP/hostname of computer with hwserver for velocity laser');
        CW_power = Prefs.Double(35, 'set', 'set_power', 'min', 0, 'max', 35, 'unit', 'mW');
        diode_on = Prefs.Boolean(false, 'set', 'set_diode_on', 'help', 'Power state of diode (on/off)');
        
        diode_sn = Prefs.Double(NaN, 'get', 'get_diode_sn', 'allow_nan', true, 'readonly', true, 'help', 'Serial number for the diode');
        diode_age = Prefs.Double(NaN, 'get', 'get_diode_age', 'allow_nan', true, 'readonly', true, 'unit', 'hrs', 'help', 'Recorded on-time for the diode');
        temperature = Prefs.Double(NaN, 'set', 'get_temperature', 'allow_nan', true, 'readonly', true, 'unit', 'C', 'help', 'Baseplate temperature');
        
        PB_line = Prefs.Integer(1, 'min', 1, 'help_text', 'Pulse Blaster flag bit (indexed from 1)');
        PB_ip = Prefs.String('No Server', 'set', 'set_pb_ip', 'help_text', 'hostname of hwserver computer with PB');
        PB_running = Prefs.Boolean(false, 'readonly', true, 'help_text', 'Boolean specifying if StaticLines program running');
        
        prefs = {'cobolt_ip', 'PB_line', 'PB_ip', 'CW_power', 'diode_on'};
        show_prefs = {'cobolt_ip', 'PB_running','PB_line','PB_ip', 'CW_power', 'temperature', 'diode_age'};
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
    end
    properties(SetAccess=private)
        serial                      % hwserver handle
        PulseBlaster                % Hardware handle
    end
    methods(Access=protected)
        function obj = Cobolt_PB()
            obj.loadPrefs; % note that this calls set.host
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Cobolt_PB();
            end
            obj = Object;
        end
    end
    methods
        function task = inactive(obj)
            try % If PB or line is incorrect, just eat that error
                obj.off;
                obj.blackout;
                task = 'Turned PB line off';
            catch
                task = 'Attempted to turn PB line off; FAILED';
            end
        end
        
        function arm(obj)
            obj.diode_on = true;
        end
        function blackout(obj)
            obj.diode_on = false;
        end
        
        function delete(obj)
            delete(obj.listeners)
        end
        
        function set_power(obj, val, ~)
            response = obj.serial.com('Cobolt', 'slp', val);
        end
        function set_diode_on(obj, val, ~)
            if val
                response = obj.serial.com('Cobolt', '@cobas', 0);
                response = obj.serial.com('Cobolt', 'l1');
            else
                response = obj.serial.com('Cobolt', 'l0');
            end
        end
        
        function val = get_temperature(obj, ~)
            val = obj.com('rbpt?');
        end
        function val = get_diode_sn(obj, ~)
            val = obj.com('sn?');
        end
        function val = get_firmware_ver(obj, ~)
            val = obj.com('ver?');
        end
        function val = get_diode_age(obj, ~)
            val = obj.com('hrs?');
        end
        
        function val = com(obj, str, varargin)
            if obj.isConnected()
                val = obj.serial.com('Cobolt', str);
            else
                val = NaN;
            end
        end
        function tf = isConnected(obj)
            tf = strcmp('No Server', obj.cobolt_ip) && strcmp('OK', obj.serial.com('Cobolt', '?'));
            
            if ~tf
                obj.set_cobolt_ip(obj,'No Server')
            end
        end
        
        function val = set_pb_ip(obj,val,~) %this loads the pulseblaster driver
            if strcmp('No Server',val)
                obj.PulseBlaster = [];
                delete(obj.listeners)
                obj.source_on = false;
                return
            end
            err = [];
            try
                obj.PulseBlaster = Drivers.PulseBlaster.StaticLines.instance(val); %#ok<*MCSUP>
                obj.source_on = obj.PulseBlaster.lines(obj.PB_line);
                delete(obj.listeners)
                obj.listeners = addlistener(obj.PulseBlaster,'running','PostSet',@obj.isRunning);
                obj.isRunning;
            catch err
                obj.PulseBlaster = [];
                delete(obj.listeners)
                obj.source_on = false;
                val = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function val = set_cobolt_ip(obj,val,~) %this loads the hwserver driver
            if strcmp('No Server',val)
                obj.serial = [];
                obj.diode_on = false;
                return
            end
            err = [];
            try
                obj.serial = hwserver(val); %#ok<*MCSUP>
            catch err
                obj.serial = [];
                val = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        
        function on(obj)
            assert(~isempty(obj.PulseBlaster), 'No IP set!')
            obj.PulseBlaster.lines(obj.PB_line) = true;
            obj.source_on = true;
        end
        function off(obj)
            assert(~isempty(obj.PulseBlaster), 'No IP set!')
            obj.source_on = false;
            obj.PulseBlaster.lines(obj.PB_line) = false;
        end
        
        function isRunning(obj,varargin)
            obj.running = obj.PulseBlaster.running;
        end
    end
end
