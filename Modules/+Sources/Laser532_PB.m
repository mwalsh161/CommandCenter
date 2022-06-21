classdef Laser532_PB < Modules.Source
    %LASER532 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        prefs = {'PB_line', 'PB_host'};
    end
    properties(GetObservable,SetObservable)
        PB_line =       Prefs.Integer(1, 'min', 1, 'help_text', 'Pulse Blaster flag bit (indexed from 1)');
        PB_host =       Prefs.String('No Server', 'set', 'set_pb_host', 'help_text', 'hostname of hwserver computer with PB');
    end
    properties(Hidden)
        PulseBlaster                 % Hardware handle
    end
    methods(Access=protected)
        function obj = Laser532_PB()
            obj.loadPrefs;
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Laser532_PB();
            end
            obj = Object;
        end
    end
    methods
        function val = set_source_on(obj, val, ~)
            obj.PulseBlaster.lines(obj.PB_line).state = val;
        end
        function val = set_pb_host(obj,val,~) %this loads the pulseblaster driver
            if strcmp('No Server',val)
                obj.PulseBlaster = [];
                obj.source_on = false;
                return
            end
            err = [];
            try
                obj.PulseBlaster = Drivers.PulseBlaster.instance(val); %#ok<*MCSUP>
                obj.PulseBlaster.lines
                obj.source_on = obj.PulseBlaster.lines(obj.PB_line).state;
            catch err
                obj.PulseBlaster = [];
                obj.source_on = false;
                val = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function tf = PB_enabled(obj)
            switch obj.PB_host
                case {'', 'No Server'} % Empty should not be possible though.
                    tf = false;
                otherwise
                    tf = true;
            end
        end
    end
end
