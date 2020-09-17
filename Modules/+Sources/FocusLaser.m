classdef FocusLaser < Modules.Source
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
        function obj = FocusLaser()
            obj.loadPrefs;
            obj.ni = Drivers.NIDAQ.dev.instance('Dev1');
            try
                line = obj.ni.getLines('Focusing Laser','out');
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
                Object = Sources.FocusLaser();
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            delete(obj.listeners)
        end
        function val = set_source_on(obj, val, ~)
            obj.ni.WriteDOLines('Focusing Laser', val);
        end
        
        % Settings and Callbacks
        function  settings(obj,panelH,~,~)
            
        end
        function update(obj,varargin)
            line = obj.ni.getLines('Focusing Laser','out');
            obj.source_on = boolean(line.state);
            if obj.source_on
                obj.on;
            else
                obj.off;
            end
        end
    end
end

