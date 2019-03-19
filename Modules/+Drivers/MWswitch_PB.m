classdef MWswitch_PB < Modules.Driver
    %MWswitch_PB Summary of this class goes here
    %   Detailed explanation goes here
    % This is to turn the MW switch on and off using PB static lines.
    
    properties
        PBline = 4;                  % Pulse Blaster flag bit (indexed from 1)
        ip = 'localhost';         % ip of host computer (with PB)
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
                Object = Drivers.MWswitch_PB();
            end
            obj = Object;
        end
        function check_edit_values(property_name,value)
            assert(value>0,['Values set for ',property_name ' must be greater than zero!'])
            assert(mod(value,1)==0,['Values set for ',property_name, ' must be an integer!'])
        end    
        
    end
    methods
        function delete(obj)
            delete(obj.listeners)
        end
        function set.ip(obj,val)
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
        function set.PBline(obj,val)
            obj.check_edit_values('PBline',val)
            obj.PBline = val;
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
