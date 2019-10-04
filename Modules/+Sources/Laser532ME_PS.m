classdef Laser532ME_PS < Modules.Source & Sources.MEdge_invisible
    % Laser532ME Source is the Millenia Edge laser (532 nm) where its  
    % on and off states are triggered by a Swabian Pulse Streamer
    % Summary of this class goes here
    % Detailed explanation goes here
    
    properties(SetObservable)
        PSline = 1;               % Pulse Streamer flag bit (indexed from 1)
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
        PulseStreamer                 % Hardware handle
    end
    methods(Access=protected)
        function obj = Laser532ME_PS()
            obj.prefs = [{'PSline','ip'} obj.prefs];
            obj.show_prefs = [{'running','PSline','ip'} obj.show_prefs];
            obj.loadPrefs; % note that this calls set.ip
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Laser532ME_PS();
            end
            obj = Object;
        end
    end
    methods
        function tasks = inactive(obj)
            tasks = inactive@Sources.MEdge_invisible(obj);
        end
        function arm(obj)
            arm@Sources.MEdge_invisible(obj);
        end
        function delete(obj)
            delete(obj.listeners)
        end
        function set.ip(obj,val) %this loads the pulsestreamer driver
            if strcmp('No Server',val)
                obj.PulseStreamer = [];
                delete(obj.listeners)
                obj.source_on = 0;
                obj.ip = val;
                return
            end
            err = [];
            try
                obj.PulseStreamer = Drivers.PulseStreamerMaster.PulseStreamerMaster.instance(val); %#ok<*MCSUP>
                obj.PulseStreamer.off();
                delete(obj.listeners)
                obj.listeners = addlistener(obj.PulseStreamer,'running','PostSet',@obj.isRunning);
                obj.ip = val;
                obj.isRunning;
            catch err
                obj.PulseStreamer = [];
                delete(obj.listeners)
                obj.source_on = 0;
                obj.ip = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function on(obj)
            assert(~isempty(obj.PulseStreamer),'No IP set for PulseStreamer!')
            obj.PulseStreamer.constant([obj.PSline],0,0)
            obj.source_on = true;
        end
        function off(obj)
            assert(~isempty(obj.PulseStreamer),'No IP set for PulseStreamer!')
            obj.source_on = false;
            obj.PulseStreamer.constant([],0,0)
        end
        
        function isRunning(obj,varargin)
            obj.running = obj.PulseStreamer.isStreaming();
        end
        

    

    end
end