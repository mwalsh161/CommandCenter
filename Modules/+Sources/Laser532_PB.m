classdef Laser532_PB < Modules.Source & Sources.Verdi_invisible
    %LASER532 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetObservable)
        PB_line = 1;               % Pulse Blaster flag bit (indexed from 1)
        PB_host = 'No Server';         % ip of host computer (with PB)
    end
    properties(SetAccess=private)
        PulseBlaster                 % Hardware handle
    end
    methods(Access=protected)
        function obj = Laser532_PB()
            obj.prefs = [{'PB_line','PB_host'} obj.prefs];
            obj.show_prefs = [{'PB_line','PB_host'} obj.show_prefs];
            obj.loadPrefs; % note that this calls set.ip
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Laser532_PB();
            end
            obj = Object;
        end
    end
    methods
        function tasks = inactive(obj)
            tasks = inactive@Sources.Verdi_invisible(obj);
        end
        function set.PB_host(obj,val) %this loads the pulseblaster driver
            if strcmp('No Server',val)
                obj.PulseBlaster = [];
                obj.source_on = 0;
                obj.PB_host = val;
                return
            end
            err = [];
            try
                obj.PulseBlaster = Drivers.PulseBlaster.instance(val); %#ok<*MCSUP>
                obj.source_on = obj.PulseBlaster.lines(obj.PB_line).state;
                obj.PB_host = val;
            catch err
                obj.PulseBlaster = [];
                obj.source_on = 0;
                obj.PB_host = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function val = set_source_on(obj, val, ~)
            obj.PulseBlaster.lines(obj.PB_line).state = val;
        end
    end
end
