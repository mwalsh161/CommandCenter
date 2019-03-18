classdef Laser532_nidaq < Modules.Source & Sources.Verdi_invisible
    %LASER532 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(SetObservable,SetAccess=private)
        source_on = false;
    end
    properties(Access=private)
        listeners
        status                       % Text object reflecting running
        sliderH                      % Handle to slider
    end
    properties(SetAccess=immutable)
        ni                           % Hardware handle
    end
    
    methods(Access=protected)
        function obj = Laser532_nidaq()
            obj.loadPrefs;
            obj.ni = Drivers.NIDAQ.dev.instance('Dev1');
            try
                line = obj.ni.getLines('532 Laser','out');
            catch err
                obj.ni.view;
                rethrow(err)
            end
            obj.source_on = boolean(line.state);
            obj.listeners = addlistener(line,'state','PostSet',@obj.update);
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Laser532_nidaq();
            end
            obj = Object;
        end
    end
    methods
        function tasks = inactive(obj)
            tasks = inactive@Sources.Verdi_invisible(obj);
        end
        function delete(obj)
            delete(obj.listeners)
        end
        function on(obj)
            obj.ni.WriteDOLines('532 Laser',1)
        end
        function off(obj)
            obj.ni.WriteDOLines('532 Laser',0)
        end
        
        % Settings and Callbacks
        function update(obj,varargin)
            line = obj.ni.getLines('532 Laser','out');
            obj.source_on = boolean(line.state);
            if obj.source_on
                obj.on;
            else
                obj.off;
            end
        end
    end
end
