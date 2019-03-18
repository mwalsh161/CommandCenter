classdef MWswitch_PB < Modules.Source
    %MWswitch_PB Summary of this class goes here
    %   Detailed explanation goes here
    % This is to turn the MW switch on and off using PB static lines.
    
    properties
        PBline = 4;                  % Pulse Blaster flag bit (indexed from 1)
        ip = 'No Server';         % ip of host computer (with PB)
        prefs = {'PBline','ip'};
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
        PulseBlaster                 % Hardware handle
    end
    
    methods(Access=protected)
        function obj = MWswitch_PB()
       %     obj.PulseBlaster = Drivers.PulseBlaster.StaticLines.instance(obj.ip);  This is accomplished in loadPrefs (set.ip)
            obj.loadPrefs;
            obj.source_on = obj.PulseBlaster.lines(obj.PBline);
            obj.listeners = addlistener(obj.PulseBlaster,'running','PostSet',@obj.isRunning);
            
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
            obj.PulseBlaster.lines(obj.PBline) = true;
            obj.source_on = true;
        end
        function off(obj)
            obj.source_on = false;
            obj.PulseBlaster.lines(obj.PBline) = false;
        end
        
        % Settings and Callbacks
        function settings(obj,panelH)
            spacing = 1.5;
            num_lines = 3;
            line = 1;
            obj.status = uicontrol(panelH,'style','text','string','Unknown State, to update, change state.','horizontalalignment','center',...
                'units','characters','position',[0 spacing*(num_lines-line) 46 1.25]);
            obj.isRunning;
            line = 2;
            uicontrol(panelH,'style','text','string','PulseBlaster Line (indexed from 1):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 35 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.PBline),...
                'units','characters','callback',@obj.PBlineCallback,...
                'horizontalalignment','left','position',[36 spacing*(num_lines-line) 10 1.5]);
            line = 3;
            uicontrol(panelH,'style','text','string','PulseBlaster Host IP:','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 25 1.25]);
            uicontrol(panelH,'style','edit','string',obj.ip,...
                'units','characters','callback',@obj.ipCallback,...
                'horizontalalignment','left','position',[26 spacing*(num_lines-line) 20 1.5]);
        end
        function PBlineCallback(obj,src,varargin)
            val = str2double(get(src,'string'));
            assert(round(val)==val&&val>0,'Number must be an integer greater than 0.')
            obj.PBline = val;
        end
        function ipCallback(obj,src,varargin)
            obj.ip = get(src,'string');
        end
        function isRunning(obj,varargin)
            obj.running = obj.PulseBlaster.running;
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
