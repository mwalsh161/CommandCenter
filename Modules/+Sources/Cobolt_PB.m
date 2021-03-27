classdef Cobolt_PB < Modules.Source
    % Cobolt_PB controls the Cobolt via USB and fast diode modulation via pulseblaster
    
    properties(SetObservable, GetObservable)
        cobolt_host =   Prefs.String('No Server', 'set', 'set_cobolt_host', 'help', 'IP/hostname of computer with hwserver for velocity laser');
        power =         Prefs.Double(NaN, 'set', 'set_power', 'min', 0, 'unit', 'mW');
        
        diode_sn =      Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'help', 'Serial number for the diode');
        diode_age =     Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'hrs', 'help', 'Recorded on-time for the diode');
        temperature =   Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'C', 'help', 'Baseplate temperature');
        
        PB_line =       Prefs.Integer(1, 'min', 1, 'help_text', 'Pulse Blaster flag bit (indexed from 1)');
        PB_host =       Prefs.String('No Server', 'set', 'set_pb_host', 'help_text', 'hostname of hwserver computer with PB');
    end
    properties(SetAccess=private)
        serial                      % hwserver handle
        PulseBlaster                % pulseblaster handle
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
                task = 'Turned diode off';
            catch
                task = 'Attempted to turn diode off; FAILED';
            end
        end
        
        function delete(obj)
            delete(obj.serial)
        end
        
        function val = set_source_on(obj, val, ~)
            obj.PulseBlaster.lines(obj.PB_line).state = val;
        end
        function val = set_armed(obj, val, ~)   % Turn the diode on or off.
            if obj.isConnected()
                if val
                    errorIfNotOK(obj.serial.com('Cobolt', '@cobas', 0));    % No autostart
                    errorIfNotOK(obj.serial.com('Cobolt', 'em'));           % Enter Modulation Mode
                    errorIfNotOK(obj.serial.com('Cobolt', 'l1'));
                else
                    errorIfNotOK(obj.serial.com('Cobolt', 'l0'));           % Laser off
                end
            else
                val = NaN;
            end
        end
        function val = set_power(obj, val, ~)
            if obj.isConnected && ~isnan(val)
                errorIfNotOK(obj.serial.com('Cobolt', 'slmp', val));    % Set laser modulation power (mW)
            else
                val = NaN;
            end
        end
        
        function val = get_power(obj, ~)
            val = obj.serial.com('Cobolt', 'glmp?');    % Get laser modulation power (mW)
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
            tf = ~strcmp('No Server', obj.cobolt_host) && ~isempty(obj.serial) && strcmp('OK', obj.serial.com('Cobolt', '?'));
            
            if ~tf
                if strcmp('No Server', obj.cobolt_host)
                    error('Host not set!');
                end
                host = obj.cobolt_host;
                obj.set_cobolt_host(obj,'No Server');
                error(['Cobolt not found at host "' host '"!']);
            end
        end
        
        function val = set_pb_host(obj,val,~) %this loads the pulseblaster driver
            if strcmp('No Server',val)
                obj.PulseBlaster = [];
                obj.source_on = false;
                return
            end
            err = [];
            try
                obj.PulseBlaster = Drivers.PulseBlaster.instance(val); %#ok<*MCSUP>
                obj.source_on = obj.PulseBlaster.lines(obj.PB_line).state;
            catch err
                obj.PulseBlaster = [];
                obj.source_on = false;
                val = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function val = set_cobolt_host(obj,val,~) %this loads the hwserver driver
            delete(obj.serial);
            
            if strcmp('No Server', val)
                obj.serial = [];
                obj.armed = false;
                return
            end
            err = [];
            try
                obj.serial = hwserver(val); %#ok<*MCSUP>
                
                obj.temperature = obj.get_temperature();
                obj.diode_sn = obj.get_diode_sn();
                obj.diode_age = obj.get_diode_age();
                obj.power = obj.get_power();
            catch err
                obj.serial = [];
                val = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
    end
end
        
function errorIfNotOK(str)
    assert(strcmp(str, 'OK'), ['Cobolt Error: ' str]);
end
