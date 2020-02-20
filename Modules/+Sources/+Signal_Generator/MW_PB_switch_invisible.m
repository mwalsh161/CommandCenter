classdef MW_PB_switch_invisible < Sources.Signal_Generator.SG_Source_invisible
    %PB MW source class
    properties
        MW_switch
        running
        
    end
    
    properties(SetObservable)
        MW_switch_on = {'yes','no'};
        MW_switch_PB_line = 1; %pulseblaster hardware line (indexed from 1) for mw_switch
        SG_trig_PB_line = 2;   %pulseblaster hardware line (indexed from 1) for SG_trigger
        ip = 'localhost';      %ip address for the pulseblaster
    end
    
    properties(SetAccess=protected, SetObservable)
        source_pb_on=false;
    end
    
    properties(Access=private)
        listeners
        status                       % Text object reflecting running
    end
    
    methods
        function obj = MW_PB_switch_invisible()
        end
    end
    
    
    methods
        function delete(obj)
            obj.pb_off;
            delete(obj.listeners);
        end
        
        function set.ip(obj,val)
            assert(ischar(val),'ip address must be entered as a string!')
            err = [];
            try
                obj.MW_switch = Drivers.PulseBlaster.StaticLines.instance(val); %#ok<*MCSUP>
                obj.source_pb_on = obj.MW_switch.lines(obj.MW_switch_PB_line);
                delete(obj.listeners)
                obj.listeners = addlistener(obj.MW_switch,'running','PostSet',@obj.isRunning);
                obj.ip = val;
                obj.isRunning;
            catch err
                obj.MW_switch = [];
                delete(obj.listeners)
                obj.source_pb_on = 0;
                obj.ip = 'No Server';
            end
        end
       
        function set.MW_switch_on(obj,val)
            if iscell(val)
                return
            end
            
            assert(ischar(val),'MW_switch_on address must be entered as a string!')
            if strcmpi(obj.ip,'no server')
                %if no server is detected then mw switch is off.
                message = 'No server found. MW switch will be set to off. Connect a server to set MW switch to on. ';
                warndlg(message);
                obj.MW_switch_on = 'no';
                return
            end
            
            switch lower(val)
                case {'yes','on'}
                    obj.pb_on;
                    val = 'yes';
                case {'no','off'}
                    obj.pb_off;
                    val = 'no';
                otherwise
                    error('Unknown MW_switch_on state.')
            end
            obj.MW_switch_on = val;
        end
        
        function isRunning(obj,varargin)
            if isempty(obj.MW_switch)
                update = 'Not Connected';
                if ~isempty(obj.status)&&isvalid(obj.status)
                    set(obj.status,'string',update)
                end
                return
            end
            obj.running = obj.MW_switch.running;
            if ~isempty(obj.status)&&isvalid(obj.status)
                if obj.running
                    update = 'Running';
                else
                    update = 'Unknown State, to update, change state.';
                end
                set(obj.status,'string',update)
            end
        end
        
        function pb_on(obj)
            if isempty(obj.MW_switch)
                error('MW switch does not exist!')
            end
            if strcmpi(obj.MW_switch_on,'yes')
                pb_line = obj.MW_switch_PB_line;
                obj.MW_switch.lines(pb_line) = true;
                obj.source_pb_on=1;
            end
        end
        
        function pb_off(obj)
            if isempty(obj.MW_switch)
                error('MW switch does not exist!')
            end
            pb_line = obj.MW_switch_PB_line;
            obj.MW_switch.lines(pb_line) = false;
            obj.source_pb_on=0;
        end
        
        function on(obj,~)
            obj.pb_on;
            on@Sources.Signal_Generator.SG_Source_invisible(obj);
        end
        function off(obj)
            obj.pb_off
            off@Sources.Signal_Generator.SG_Source_invisible(obj);
        end
    end
end







