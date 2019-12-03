classdef Cobalt532_PB < Modules.Source
    %Cobalt532_PB Turns power on/off and controls the pulseblaster to
    %open/close the AOM shutter
    
    properties(SetObservable,GetObservable)
        PB_line = Prefs.Integer(1,'min',1,'help_text','Pulse Blaster flag bit (indexed from 1)');
        host = Prefs.String('No Server','set','set_host','help_text','hostname of hwserver computer with PB');
        running = Prefs.Boolean(false,'readonly',true,'help_text','Boolean specifying if StaticLines program running');
        prefs = {'PB_line','host'};
        show_prefs = {'running','PB_line','host'};
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
    end
    properties(Access=private)
        listeners
    end
    properties(SetAccess=private)
        PulseBlaster                 % Hardware handle
    end
    methods(Access=protected)
        function obj = Cobalt532_PB()
            obj.loadPrefs; % note that this calls set.host
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Cobalt532_PB();
            end
            obj = Object;
        end
    end
    methods
        function arm(obj)
            % Will add control in future
        end
        function delete(obj)
            delete(obj.listeners)
        end
        function val = set_host(obj,val,~) %this loads the pulseblaster driver
            if strcmp('No Server',val)
                obj.PulseBlaster = [];
                delete(obj.listeners)
                obj.source_on = false;
                return
            end
            err = [];
            try
                obj.PulseBlaster = Drivers.PulseBlaster.StaticLines.instance(val); %#ok<*MCSUP>
                obj.source_on = obj.PulseBlaster.lines(obj.PB_line);
                delete(obj.listeners)
                obj.listeners = addlistener(obj.PulseBlaster,'running','PostSet',@obj.isRunning);
                obj.isRunning;
            catch err
                obj.PulseBlaster = [];
                delete(obj.listeners)
                obj.source_on = false;
                val = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function on(obj)
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.PulseBlaster.lines(obj.PB_line) = true;
            obj.source_on = true;
        end
        function off(obj)
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.source_on = false;
            obj.PulseBlaster.lines(obj.PB_line) = false;
        end
        
        function isRunning(obj,varargin)
            obj.running = obj.PulseBlaster.running;
        end
    end
end