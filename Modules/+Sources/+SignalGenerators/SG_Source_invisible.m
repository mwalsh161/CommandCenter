classdef SG_Source_invisible < Modules.Source 
    % SG_SOURCE_INVISIBLE SuperClass for serial signal generators.
  
    properties (GetObservable, SetObservable)
        frequency =     Prefs.Double(1e9/Sources.SignalGenerators.SG_Source_invisible.freqUnit2Hz, ... % Default of 1 GHz is immeditely overwritten by hardware.
                                    'units', Sources.SignalGenerators.SG_Source_invisible.freqUnit, ...
                                    'set', 'set_frequency', ...
                                    'help', 'The frquency tone that the signal generator is set at');
        power =         Prefs.Double(-30, 'units', 'dBm', 'set', 'set_power', ...
                                    'help', ['The power that the signal generator outputs. dBm stands ' ...
                                            'for "dB mW", i.e. 30 dBm == 1 W.']);
        
        PB_host =       Prefs.String(Sources.SignalGenerators.SG_Source_invisible.noserver, 'set', 'set_PB_host', ...
                                    'help', 'IP/hostname of computer with PB server');
        PB_line =       Prefs.Integer(1, 'min', 1, 'allow_nan', false, 'set', 'set_PB_line', ...
                                    'help', 'Indexed from 1');
                                
%         reset_serial =  Prefs.Button('string', 'Reset', 'set', 'set_reset_serial', ...
%                                     'help', 'Push this to kill the current comport (serial, gpib, ...) and be able to reset it upon restart. Future: make this less terrible.')
    end
    
    properties (Constant, Hidden)
        noserver = 'No Server';
        freqUnit = 'MHz';
        freqUnit2Hz = 1e6;  % Convertsion between the frequency unit (this case MHz) and Hz.
    end
    
    properties
        serial;
        pb;
    end
   
    methods
        function obj = SG_Source_invisible()
        end
    end
    
    methods
        function val = set_frequency(obj, val, ~)
            obj.serial.setFreqCW(val * obj.freqUnit2Hz);
            val = obj.get_frequency();  % This probably doubles the response time. Remove? Or make asyncronous?
        end
        function val = get_frequency(obj)
            val = obj.serial.getFreqCW / obj.freqUnit2Hz;
        end
        function val = set_power(obj, val, ~)
            obj.serial.setPowerCW(val);
            val = obj.get_power();      % This probably doubles the response time. Remove? Or make asyncronous?
        end
        function val = get_power(obj)
            val = obj.serial.getPowerCW;
        end
    end
    
    methods
        function delete(obj)
            delete(obj.serial)
            delete(obj.pb)
        end
        
        function init(obj)  % Called by signal generators after instantiation to load prefs and current hardware freq/power.
            obj.loadPrefs;
            
            obj.frequency = obj.get_frequency();
            obj.power =     obj.get_power();
        end
        
        function val = set_source_on(obj, val, ~)
            if obj.PB_enabled()     % If there is a PulseBlaster connected, then use on/off for this.
                obj.pb.lines(obj.PB_line).state = val;
            else                    % Otherwise, turn toggle arm (the source's RF on/off)
                obj.armed = val;    % This is normally dangerous, but because set_armed doesn't reference source_on, it's okay.
            end
        end
        function val = set_armed(obj, val, ~)
            if val
                obj.serial.on;
            else
                obj.serial.off;
            end
            
            % Below is disabled because source_on can call obj.armed, thus, set_armed cannot reference 
            %    source_on because it would be in mid-pref-double switch. Keeping around in hopes that
            %    behavior will be possible in the future.
%             if ~obj.PB_enabled()
%                 obj.source_on = val;
%             end
        end
        
        function val = set_PB_host(obj,val,~)
            switch val
                case {'', obj.noserver}     % Allow the user to remove the current PB.
                    delete(obj.pb);
                    obj.pb = [];
                    val = obj.noserver;
                    obj.source_on = obj.armed;
                    return
                otherwise
                    % Proceed.
            end
            
            obj.pb = Drivers.PulseBlaster.instance(val);    % This will error if val is an invalid server.
            obj.source_on = obj.pb.lines(obj.PB_line).state;
        end
        function val = set_PB_line(obj,val,~)
            if ~isempty(obj.pb)
                obj.source_on = obj.pb.lines(val).state;
            end
        end
        function tf = PB_enabled(obj)
            switch obj.PB_host
                case {'', obj.noserver} % Empty should not be possible though.
                    tf = false;
                otherwise
                    tf = true;
            end
        end
        
        function set_reset_serial(obj, ~, ~)
            obj.serial.comObjectInfo = [];
            obj.serial.savePrefs();
            delete(obj);    % Suicide.
        end
    end
end
