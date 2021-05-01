classdef Cobolt_PB < Modules.Source
    % Cobolt_PB controls the Cobolt via USB and fast diode modulation via pulseblaster

    properties(SetObservable, GetObservable)
        cobolt_host =   Prefs.String(Sources.Cobolt_PB.noserver, 'set', 'set_host', 'help', 'IP/hostname of computer with hwserver for the Cobolt laser');
        power =         Prefs.Double(NaN, 'set', 'set_power', 'min', 0, 'unit', 'mW');

        diode_sn =      Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'help', 'Serial number for the diode');
        diode_age =     Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'hrs', 'help', 'Recorded on-time for the diode');
        temperature =   Prefs.Double(NaN, 'allow_nan', true, 'readonly', true, 'unit', 'C', 'help', 'Baseplate temperature');

        PB_line =       Prefs.Integer(1, 'min', 1, 'help_text', 'Pulse Blaster flag bit (indexed from 1)');
        PB_host =       Prefs.String(Sources.Cobolt_PB.noserver, 'set', 'set_pb_host', 'help_text', 'hostname of hwserver computer with PB');
    end
    properties(SetAccess=private)
        serial                      % hwserver handle
        PulseBlaster                % pulseblaster handle
    end
    properties(Constant)
        noserver = 'No Server';
    end
    properties
        prefs =         {'cobolt_host', 'PB_line', 'PB_host', 'power'};
        show_prefs =    {'PB_host', 'PB_line', 'cobolt_host', 'power', 'diode_sn', 'diode_age', 'temperature'}; 
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
            if ~isempty(obj.PulseBlaster)
                obj.PulseBlaster.lines(obj.PB_line).state = val;
            end
        end
        function val = set_armed(obj, val, ~)   % Turn the diode on or off.
            if obj.isConnected()
                if val
                    errorIfNotOK(obj.serial.com('Cobolt', '@cobas', 0));    % No autostart
                    errorIfNotOK(obj.serial.com('Cobolt', 'em'));           % Enter Modulation Mode
                    errorIfNotOK(obj.serial.com('Cobolt', 'l1'));           % Laser on
                else
                    errorIfNotOK(obj.serial.com('Cobolt', 'l0'));           % Laser off
                end
            else
                val = NaN;
            end
        end
        
        function val = set_power(obj, val, pref)
            if obj.isConnected
                errorIfNotOK(obj.serial.com('Cobolt', 'slmp', val));    % Set laser modulation power (mW)
            elseif ~isnan(val) && isnan(pref.value)
                error('Cannot set power without a connection.');
            else
                val = NaN;
            end
        end

        function val = get_armed(obj, ~)
            val = obj.com('l?');
        end
        function val = get_power(obj, ~)
            val = obj.com('glmp?');    % Get laser modulation power (mW)
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
            tf = ~strcmp(Sources.Cobolt_PB.noserver, obj.cobolt_host);  % If we are trying to connect to a real IP....

            if tf
                tf = strcmp('OK', obj.serial.com('Cobolt', '?'));       % ...If the device is not responding affirmatively...
                
                if ~tf
                    obj.cobolt_host = Sources.Cobolt_PB.noserver;
                end
            end
        end

        function val = set_pb_host(obj,val,~) %this loads the pulseblaster driver
            try
                obj.PulseBlaster = Drivers.PulseBlaster.instance(val); %#ok<*MCSUP>
                obj.source_on = obj.PulseBlaster.lines(obj.PB_line).state;
            catch
                obj.PulseBlaster = [];
                obj.source_on = NaN;
                val = Sources.Cobolt_PB.noserver;
            end
        end
        function val = set_host(obj,val,~) %this loads the hwserver driver
            delete(obj.serial);

            try
                obj.serial = hwserver(val); %#ok<*MCSUP>

                obj.temperature = obj.get_temperature();
                obj.diode_sn = obj.get_diode_sn();
                obj.diode_age = obj.get_diode_age();
                obj.power = obj.get_power();
                obj.armed = obj.get_armed();
            catch
                obj.serial = [];
                obj.armed = NaN;
                val = Sources.Cobolt_PB.noserver;
            end
        end
    end
end

function errorIfNotOK(str)
    assert(strcmp(str, 'OK'), ['Cobolt Error: ' str]);
end
