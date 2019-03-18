classdef WhiteLight < Modules.Source
    %LASER532 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        intensity = 100;               % Intenisty 0-100 (0-5 V)
        prefs = {'intensity'};
    end
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
        function obj = WhiteLight()
            obj.ni = Drivers.NIDAQ.dev.instance('Dev1');
            obj.loadPrefs; % This sets intensity, so need ni instance first
            try
                line = obj.ni.getLines('LED','out');
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
                Object = Sources.WhiteLight();
            end
            obj = Object;
        end
    end
    methods
        function task = inactive(obj)
            task = '';
            if obj.source_on
                task = 'Turning off';
                obj.off;
            end
        end
        function delete(obj)
            delete(obj.listeners)
        end
        function set.intensity(obj,val)
            obj.intensity = val;
            err = [];
            try
            if obj.source_on %#ok<*MCSUP>
                obj.on;  % Reset to this value
                line = obj.ni.getLine('LED',obj.ni.OutLines);
                obj.intensity = line.state*20;
            end
            catch err
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function on(obj)
            obj.ni.WriteAOLines('LED',obj.intensity/20)
        end
        function off(obj)
            obj.ni.WriteAOLines('LED',0)
        end
        
        % Settings and Callbacks
        function settings(obj,panelH)
            spacing = 1.5;
            num_lines = 2;
            line = 1;
            obj.status = uicontrol(panelH,'style','text','string','Power',...
                'units','characters','position',[0 spacing*(num_lines-line) 35 1.25]);
            line = 2;
            obj.sliderH = uicontrol(panelH,'style','slider','min',0,'max',100,'value',max(0,obj.intensity),...
                'sliderStep',[0.01 0.1],'units','characters','callback',@obj.changePower,...
                'horizontalalignment','left','position',[0 spacing*(num_lines-line) 50 1.5]);
        end
        function changePower(obj,src,varargin)
            val = get(src,'value');
            obj.intensity = val;
        end
        function update(obj,varargin)
            line = obj.ni.getLines('LED','out');
            if isnan(line.state)
                obj.source_on = true; % Assume on if unknown
            else
                obj.source_on = boolean(line.state);
                if ~isempty(obj.sliderH)&&isvalid(obj.sliderH)&&obj.source_on
                    set(obj.sliderH,'value',line.state*20)
                end
            end
        end
    end
end

