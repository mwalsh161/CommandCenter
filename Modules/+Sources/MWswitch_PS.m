classdef MWswitch_PS < Modules.Source
    %MWswitch_PS Summary of this class goes here
    %   Detailed explanation goes here
    % This is to turn the MW switch on and off using Pulse Streamer channels.
    
   
    properties(SetObservable)
        PBline = 4;                  % Pulse Blaster flag bit (indexed from 1)
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
%         prefs = {'PBline','ip','enabled'};
%         show_prefs = {'PBline','ip'};
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
            obj.prefs = [{'PBline','ip'} obj.prefs];
            obj.show_prefs = [{'running','PBline','ip'} obj.show_prefs];
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
           
            laser532PS = Sources.Laser532ME_PS.instance();
            cwavePS = Sources.CWave.instance();
            assert(~isempty(obj.PulseStreamerHandle),'No IP set for PulseStreamer!')
            obj.source_on = true;
            if laser532PS.source_on == true && cwavePS.source_on == true
                output = [ laser532PS.PBline, obj.PBline, cwavePS.PBline];
            elseif laser532PS.source_on == false && cwavePS.source_on == true
                output = [ obj.PBline,cwavePS.PBline];
            elseif laser532PS.source_on == true && cwavePS.source_on == false
                output = [obj.PBline, laser532PS.PBline];
            elseif laser532PS.source_on == false && cwavePS.source_on == false
                output = [obj.PBline];
            end
            state = PulseStreamer.OutputState(output,0,0);
            obj.PulseStreamerHandle.PS.constant(state);
        end
        function off(obj)
            laser532PS = Sources.Laser532ME_PS.instance();
            cwavePS = Sources.CWave.instance();
            assert(~isempty(obj.PulseStreamerHandle), 'No IP set for PulseStreamer!')
            obj.source_on = false;
            if laser532PS.source_on == true && cwavePS.source_on == true
                output = [ laser532PS.PBline, cwavePS.PBline];
            elseif laser532PS.source_on == false && cwavePS.source_on == true
                output = [ cwavePS.PBline];
            elseif laser532PS.source_on == true && cwavePS.source_on == false
                output = [laser532PS.PBline];
            elseif laser532PS.source_on == false && cwavePS.source_on == false
                output = [];
            end
            
            state = PulseStreamer.OutputState(output,0,0);
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

