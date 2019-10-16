classdef MWswitch_PS < Modules.Source
    %MWswitch_PS Summary of this class goes here
    %   Detailed explanation goes here
    % This is to turn the MW switch on and off using Pulse Streamer channels.
    
   
    properties(SetObservable)
        PSline = 4;                  % Pulse Blaster flag bit (indexed from 1)
        ip = 'No Server';         % ip of host computer (with PS)
        enabled = false;
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
        running = false;                    % Boolean specifying if StaticLines program running
    end
    properties
          prefs;
          show_prefs;
    end
    properties(Access=private)
        listeners
        status                       % Text object reflecting running
    end
    properties(SetAccess=private)
        PulseStreamerHandle                 % Hardware handle
    end
    
    methods(Access=protected)
        function obj = MWswitch_PS()
            obj.prefs = [{'PSline','ip'} obj.prefs];
            obj.show_prefs = [{'running','PSline','ip'} obj.show_prefs];
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.MWswitch_PS();
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            delete(obj.listeners)
            obj.PulseStreamerHandle.delete();
        end
        function set.ip(obj,val)
            if strcmp('No Server',val)
                obj.PulseStreamerHandle = [];
                delete(obj.listeners)
                obj.source_on = 0;
                obj.ip = val;
                return
            end
            err = [];
            try
                obj.PulseStreamerHandle = Drivers.PulseStreamerMaster.PulseStreamerMaster.instance(val); %#ok<*MCSUP>
                obj.off();
                delete(obj.listeners)
                obj.listeners = addlistener(obj.PulseStreamerHandle,'running','PostSet',@obj.isRunning);
                obj.ip = val;
                obj.isRunning;
            catch err
                obj.PulseStreamerHandle = [];
                delete(obj.listeners)
                obj.source_on = 0;
                obj.ip = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function on(obj)
            assert(~isempty(obj.PulseStreamerHandle), 'No IP set for PulseStreamer!')
            state = PulseStreamer.OutputState([obj.PSline],0,0);
            obj.PulseStreamerHandle.PS.constant(state);
            obj.source_on = true;
        end
        function off(obj)
            assert(~isempty(obj.PulseStreamerHandle), 'No IP set for PulseStreamer!')
            obj.source_on = false;
            state = PulseStreamer.OutputState([],0,0);
            obj.PulseStreamerHandle.PS.constant(state);
        end
        function arm(obj)
            obj.enabled = true;
        end
        function blackout(obj)
            obj.off()
            %possibly add code to depower switch (assuming it can be
            %powered by nidaq)
        end
        
        function isRunning(obj,varargin)
            obj.running = obj.source_on;
            if ~isempty(obj.status)&&isvalid(obj.status)
                if obj.running
                    update = 'Running';
                else
                    update = 'Unknown State, to update, change state.';
                end
                set(obj.status,'string',update)
            end
        end
    end
end

