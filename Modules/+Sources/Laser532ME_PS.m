classdef Laser532ME_PS < Modules.Source & Sources.MEdge_invisible
    % Laser532ME Source is the Millenia Edge laser (532 nm) where its  
    % on and off states are triggered by a Swabian Pulse Streamer
    % Summary of this class goes here
    % Detailed explanation goes here
    
    properties(SetObservable)
        PBline = 1;               % Pulse Streamer flag bit (indexed from 1)
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
            uwavePS = Sources.MWswitch_PS.instance();
            cwavePS = Sources.CWave.instance();
            
            assert(~isempty(obj.PulseStreamerMaster),'No IP set for PulseStreamer!')
            obj.source_on = true;
            if cwavePS.source_on == true && uwavePS.source_on == true
                output = [obj.PBline, uwavePS.PBline, cwavePS.PBline];
            elseif cwavePS.source_on == false && uwavePS.source_on == true
                output = [obj.PBline, uwavePS.PBline];
            elseif cwavePS.source_on == true && uwavePS.source_on == false
                output = [obj.PBline, cwavePS.PBline];
            elseif cwavePS.source_on == false && uwavePS.source_on == false
                output = [obj.PBline];
            end
            state = PulseStreamer.OutputState(output,0,0);
            obj.PulseStreamerMaster.PS.constant(state);  
        end
        function off(obj)
            uwavePS = Sources.MWswitch_PS.instance();
            cwavePS = Sources.CWave.instance();
            assert(~isempty(obj.PulseStreamerMaster),'No IP set for PulseStreamer!')
            obj.source_on = false;
            if cwavePS.source_on == true && uwavePS.source_on == true
                output = [uwavePS.PBline, cwavePS.PBline];
            elseif cwavePS.source_on == false && uwavePS.source_on == true
                output = [uwavePS.PBline];
            elseif cwavePS.source_on == true && uwavePS.source_on == false
                output = [cwavePS.PBline];
            elseif cwavePS.source_on == false && uwavePS.source_on == false
                output = [];
            end
            output = [obj.PBline];
            state = PulseStreamer.OutputState(output,0,0);
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