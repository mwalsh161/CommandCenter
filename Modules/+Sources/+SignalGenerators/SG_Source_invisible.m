classdef SG_Source_invisible < Modules.Source 
    %SuperClass for serial sources
  
    properties (GetObservable, SetObservable)
        frequency =     Prefs.Double(1e9/Sources.SignalGenerators.SG_Source_invisible.freqUnit2Hz, 'units', Sources.SignalGenerators.SG_Source_invisible.freqUnit, 'set', 'set_frequency');
        power =         Prefs.Double(-30, 'units', 'dBm', 'set', 'set_power');
        
        PB_host =       Prefs.String(Sources.SignalGenerators.SG_Source_invisible.noserver, 'set', 'set_PB_host', 'help', 'IP/hostname of computer with PB server');
        PB_line =       Prefs.Integer(1, 'min', 1, 'allow_nan', false, 'set', 'set_PB_line', 'help', 'Indexed from 1');
    end
    
    properties (Constant, Hidden)
        noserver = 'No Server';
        freqUnit = 'MHz';
        freqUnit2Hz = 1e6;
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
            if ~isempty(obj.serial) % Could be empty if error constructing
                obj.serial.delete;
            end
        end
        
        function init(obj)
            obj.loadPrefs;
            
            obj.frequency = obj.get_frequency();
            obj.power =     obj.get_power();
        end
        
        function val = set_source_on(obj, val, ~)
            if obj.PB_enabled()     % If there is a PulseBlaster connected, then use on/off for this.
                obj.pb.line(obj.PB_line) = val;
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
            
            % Below is disabled because source_on calls obj.armed, which would break things.
%             if ~obj.PB_enabled()
%                 obj.source_on = val;
%             end
        end
        function arm(obj)
            obj.armed = true;
        end
        function blackout(obj)
            obj.armed = false;
        end
        
        function val = set_PB_host(obj,val,~)
            err = [];
            
            try
                obj.pb = Drivers.PulseBlaster.instance(val);
            catch err
                
            end
            
            if isempty(obj.pb)
                obj.PB_host = obj.noserver;
                if ~isempty(err)
                    rethrow(err)
                end
                return
            end
            if ~isempty(err)
                rethrow(err)
            end
            
            obj.source_on = obj.pb.lines(obj.PB_line).state;
        end
        function val = set_PB_line(obj,val,~)
            if ~isempty(obj.pb)
                obj.source_on = obj.pb.lines(val).state;
            end
        end
        function tf = PB_enabled(obj)
            switch obj.PB_host
                case obj.noserver
                    tf = false;
                otherwise
                    tf = true;
            end
        end
    end
end
