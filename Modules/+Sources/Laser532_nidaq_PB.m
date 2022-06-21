classdef Laser532_nidaq_PB < Sources.Laser532_PB
    %Laser532_nidaq_PB Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=immutable)
        ni                           % Hardware handle
    end
    
    methods(Access=protected)
        function obj = Laser532_nidaq_PB()
            obj.loadPrefs;
            obj.ni = Drivers.NIDAQ.dev.instance('Dev1');
            try
                line = obj.ni.getLines('532 Laser','out');
            catch err
                obj.ni.view;
                rethrow(err)
            end
            obj.armed = boolean(line.state);
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Laser532_nidaq_PB();
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            delete(obj.listeners)
        end
        function val = set_source_on(obj, val, ~)
            if obj.PB_enabled()     % If there is a PulseBlaster connected, then use on/off for this.
                obj.PulseBlaster.lines(obj.PB_line).state = val;
            else                    % Otherwise, turn toggle arm (the source's RF on/off)
                obj.armed = val;    % This is normally dangerous, but because set_armed doesn't reference source_on, it's okay.
            end
        end
        function val = set_armed(obj, val, ~)
            obj.ni.WriteDOLines('532 Laser', val)
        end
    end
end