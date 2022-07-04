classdef WhiteLight < Modules.Source
    %WHITELIGHT Is an antiquanted Source for analog LEDs such as:
    % https://www.thorlabs.com/newgrouppage9.cfm?objectgroup_id=2616
    
    properties(SetObservable, GetObservable)
        intensity = Prefs.Double(100, 'set', 'set_intensity'); % Intenisty 0-100 (0-5 V)
    end
    properties
        prefs = {'intensity'};
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
        function val = set_intensity(obj,val, ~)
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
                err = [];
                try
                    if obj.source_on.value %#ok<*MCSUP>
                        obj.on;  % Reset to this value
                        line = obj.ni.getLine('LED',obj.ni.OutLines);
                        val = line.state*20;
                    end
                catch err
                end
                if ~isempty(err)
                    rethrow(err)
                end
            end
        end
        function val = set_source_on(obj, val, ~)
            obj.ni.WriteAOLines('LED', logical(val) * obj.intensity/20)
        end
        function val = set_armed(obj, val, ~)
            % Opt out of armed warning.
        end
        
        % Settings and Callbacks
        function  settings(obj,panelH,~,~)
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

