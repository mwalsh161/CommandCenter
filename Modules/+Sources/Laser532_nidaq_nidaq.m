classdef Laser532_nidaq_nidaq < Modules.Source
    %Laser532_nidaq_PB Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetAccess=immutable)
        ni                           % Hardware handle
    end
    
    methods(Access=protected)
        function obj = Laser532_nidaq_nidaq()
            obj.loadPrefs;
            obj.ni = Drivers.NIDAQ.dev.instance('Dev1');
            try
                line = obj.ni.getLines('532 Laser','out');
            catch err
                obj.ni.view;
                rethrow(err)
            end
            obj.armed = boolean(line.state);
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Laser532_nidaq_nidaq();
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            delete(obj.listeners)
        end
        function val = set_source_on(obj, val, ~)
            obj.ni.WriteDOLines('532 Laser AOM', val)
        end
        function val = set_armed(obj, val, ~)
            obj.ni.WriteDOLines('532 Laser', val)
        end
    end
end
