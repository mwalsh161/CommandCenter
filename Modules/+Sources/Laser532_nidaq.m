classdef Laser532_nidaq < Modules.Source
    %LASER532 Summary of this class goes here
    %   Detailed explanation goes here
    
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
%         function tasks = inactive(obj)
%             tasks = inactive@Sources.Verdi_invisible(obj);
%         end
        function delete(obj)
            delete(obj.listeners)
        end
        function val = set_source_on(obj, val, ~)
            obj.ni.WriteDOLines('532 Laser', val)
        end
        
        % Settings and Callbacks
        function update(obj,varargin)
            line = obj.ni.getLines('532 Laser','out');
            obj.source_on = boolean(line.state);
        end
    end
end
