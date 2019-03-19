classdef Laser532_PB < Modules.Source
    %LASER532 Summary of this class goes here
    %   Detailed explanation goes here

    methods(Access=protected)
        function obj = Laser532_PB()
        end
    end
    methods(Static)
        function obj = instance()
            error('Sources.Laser532_PB no longer exists. It has been moved to Sources.Green_532Laser.Laser532_PB.Please change Sources.Laser532_PB to Sources.Green_532Laser.Laser532_PB.')
        end
    end
    methods
        function delete(obj)
            delete(obj.listeners)
        end

        function set.ip(obj,val) %this loads the pulseblaster driver
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
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.PulseBlaster.lines(obj.PBline) = true;
            obj.source_on = true;
        end
        function off(obj)
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.source_on = false;
            obj.PulseBlaster.lines(obj.PBline) = false;
        end
        
        % Settings and Callbacks
        function settings(obj,panelH)
         
        end
        
    end
end