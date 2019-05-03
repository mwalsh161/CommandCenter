classdef Laser532_PB < Modules.Source & Sources.Verdi_invisible
    %LASER532 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetObservable)
        PBline = 1;               % Pulse Blaster flag bit (indexed from 1)
        ip = 'No Server';         % ip of host computer (with PB)
        readonly_prefs = {'running'};
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
        running = false;          % Boolean specifying if StaticLines program running
    end
    properties(Access=private)
        listeners
    end
    properties(SetAccess=private)
        PulseBlaster                 % Hardware handle
    end
    methods(Access=protected)
        function obj = Laser532_PB()
            obj.prefs = [{'PBline','ip'} obj.prefs];
            obj.show_prefs = [{'running','PBline','ip'} obj.show_prefs];
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
        function arm(obj)
            arm@Sources.Verdi_invisible(obj);
        end
        function delete(obj)
            delete(obj.listeners)
        end
        function set.ip(obj,val) %this loads the pulseblaster driver
            if strcmp('No Server',val)
                obj.PulseBlaster = [];
                delete(obj.listeners)
                obj.source_on = 0;
                obj.ip = val;
                return
            end
            err = [];
            try
                obj.PulseBlaster = Drivers.PulseBlaster.StaticLines.instance(val); %#ok<*MCSUP>
                obj.source_on = obj.PulseBlaster.lines(obj.PBline);
                delete(obj.listeners)
                obj.listeners = addlistener(obj.PulseBlaster,'running','PostSet',@obj.isRunning);
                obj.ip = val;
                obj.isRunning;
            catch err
                obj.PulseBlaster = [];
                delete(obj.listeners)
                obj.source_on = 0;
                obj.ip = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function on(obj)
            on@Sources.Verdi_invisible(obj);
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.PulseBlaster.lines(obj.PBline) = true;
            obj.source_on = true;
        end
        function off(obj)
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.source_on = false;
            obj.PulseBlaster.lines(obj.PBline) = false;
        end
        
        function isRunning(obj,varargin)
            obj.running = obj.PulseBlaster.running;
        end
    end
end