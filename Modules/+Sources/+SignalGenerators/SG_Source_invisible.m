classdef SG_Source_invisible < Modules.Source 
    %SuperClass for serial sources
  
    properties (SetObservable)
        frequency =     Prefs.Double(3e9, 'units', 'GHz', 'set', 'set_frequency');
        power =         Prefs.Double(-30, 'units', 'dBm', 'set', 'set_power');
        
        PB_host =       Prefs.String(SG_Source_invisible.noserver, 'set', 'set_PB_host', 'help', 'IP/hostname of computer with PB server');
        PB_line =       Prefs.Integer(1, 'min', 1, 'allow_nan', false, 'set', 'set_PB_line', 'help', 'Indexed from 1');
    end
    
    properties (Constant)
        noserver = 'No Server'
    end
    
    properties
        serial
        pb
    end
   
    methods
        function obj = SG_Source_invisible()
        end
    end
    
    methods
        function val = set_frequency(obj, val, ~)
            obj.serial.setFreqCW(val);
            val = obj.serial.getFreqCW;     % This probably doubles the response time. Remove? Or make asyncronous?
        end
        function val = set_power(obj, val, ~)
            obj.serial.setPowerCW(val);
            val = obj.serial.getPowerCW;    % This probably doubles the response time. Remove? Or make asyncronous?
        end
    end
    
    methods
        function delete(obj)
            if ~isempty(obj.serial) % Could be empty if error constructing
                obj.serial.delete;
            end
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
        end
        
        function val = set_PB_host(obj,val,~)
            err = [];
            
            try
                obj.pb = Drivers.PulseBlaster.StaticLines.instance(val);
            catch err
                
            end
            
            if isempty(obj.pb)
                obj.PB_host = Sources.VelocityLaser.noserver;
                if ~isempty(err)
                    rethrow(err)
                end
                return
            end
            if ~isempty(err)
                rethrow(err)
            end
            
            obj.source_on = obj.pb.lines(obj.PB_line);
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

