classdef MWswitch_PS < Modules.Source
    %MWswitch_PS Summary of this class goes here
    %   Detailed explanation goes here
    % This is to turn the MW switch on and off using Pulse Streamer channels.
    
    properties
        PSline = 4;                  % Pulse Blaster flag bit (indexed from 1)
        ip = 'No Server';         % ip of host computer (with PB)
        prefs = {'PSline','ip'};
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
        running                      % Boolean specifying if StaticLines program running
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
       %     obj.PulseStreamerHandle = Drivers.PulseStreamer.StaticLines.instance(obj.ip);  This is accomplished in loadPrefs (set.ip)
            obj.loadPrefs;
            obj.PulseStreamerHandle.off();
            obj.listeners = addlistener(obj.PulseStreamerHandle,'running','PostSet',@obj.isRunning);
            
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.MWswitch_PB();
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            delete(obj.listeners)
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
                obj.PulseStreamerHandle.off();
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
        
        % Settings and Callbacks
        function  settings(obj,panelH,~,~)
            spacing = 1.5;
            num_lines = 3;
            line = 1;
            obj.status = uicontrol(panelH,'style','text','string','Unknown State, to update, change state.','horizontalalignment','center',...
                'units','characters','position',[0 spacing*(num_lines-line) 46 1.25]);
            obj.isRunning;
            line = 2;
            uicontrol(panelH,'style','text','string','PulseStreamer Line (indexed from 1):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 35 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.PSline),...
                'units','characters','callback',@obj.PSlineCallback,...
                'horizontalalignment','left','position',[36 spacing*(num_lines-line) 10 1.5]);
            line = 3;
            uicontrol(panelH,'style','text','string','PulseStreamer Host IP:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 25 1.25]);
            uicontrol(panelH,'style','edit','string',obj.ip,...
                'units','characters','callback',@obj.ipCallback,...
                'horizontalalignment','left','position',[26 spacing*(num_lines-line) 20 1.5]);
        end
        function PSlineCallback(obj,src,varargin)
            val = str2double(get(src,'string'));
            assert(round(val)==val&&val>=0,'Line number must be an integer greater than or equal to 0 for Pulse Streamer.')
            obj.PSline = val;
        end
        function ipCallback(obj,src,varargin)
            obj.ip = get(src,'string');
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

