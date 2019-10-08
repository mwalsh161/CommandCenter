classdef Laser532ME_PS < Modules.Source & Sources.MEdge_invisible
    % Laser532ME Source is the Millenia Edge laser (532 nm) where its  
    % on and off states are triggered by a Swabian Pulse Streamer
    % Summary of this class goes here
    % Detailed explanation goes here
    
    properties(SetObservable)
        PSline = 1;               % Pulse Streamer flag bit (indexed from 1)
        ip = 'No Server';         % ip of host computer (with PB)
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
        running = false;          % Boolean specifying if StaticLines program running
    end
    properties(Access=private)
        listeners
    end
    properties(SetAccess=private)
        PulseStreamerMaster                 % Hardware handle
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
            obj.PulseStreamerMaster.delete();
        end
        function set.ip(obj,val) %this loads the PulseStreamerMaster driver
            if strcmp('No Server',val)
                obj.PulseStreamerMaster = [];
                delete(obj.listeners)
                obj.source_on = 0;
                obj.ip = val;
                return
            end
            err = [];
            try
                obj.PulseStreamerMaster = Drivers.PulseStreamerMaster.PulseStreamerMaster.instance(val); %#ok<*MCSUP>
                obj.off();
                delete(obj.listeners)
                obj.listeners = addlistener(obj.PulseStreamerMaster,'running','PostSet',@obj.isRunning);
                obj.ip = val;
                obj.isRunning;
            catch err
                obj.PulseStreamerMaster = [];
                delete(obj.listeners)
                obj.source_on = 0;
                obj.ip = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function on(obj)
            assert(~isempty(obj.PulseStreamerMaster),'No IP set for PulseStreamer!')
            state = PulseStreamer.OutputState([obj.PSline],0,0);
            obj.PulseStreamerMaster.PS.constant(state);
            obj.source_on = true;
        end
        function off(obj)
            assert(~isempty(obj.PulseStreamerMaster),'No IP set for PulseStreamer!')
            obj.source_on = false;
            state = PulseStreamer.OutputState.ZERO;
            obj.PulseStreamerMaster.PS.constant(state);
        end
        
        function isRunning(obj,varargin)
            obj.running = obj.source_on; 
            % Constant method currently has no flags to indicate successful 
            % triggering of digital channel into constant high state. 
            % Swabain is working on updating constant to return said flag.
            % In interim source_on property flags whether puslestreamer digital
            % channel is in high state.
        end
        

    

    end
end