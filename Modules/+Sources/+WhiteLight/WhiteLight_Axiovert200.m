classdef WhiteLight_Axiovert200 < Modules.Source
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
        ZeissDriver                           % Hardware handle
    end
    
    methods(Access=protected)
        function obj = WhiteLight_Axiovert200()
            obj.loadPrefs;
            obj.ZeissDriver = Drivers.Zeiss_Axiovert200.instance();
%             try
%                 line = obj.ni.getLines('LED','out');
%             catch err
%                 obj.ni.view;
%                 rethrow(err)
%             end
            obj.source_on = boolean(obj.ZeissDriver.HaloLampState);
            obj.listeners = addlistener(obj.ZeissDriver,'HaloLampState','PostSet',@obj.update);
            obj.listeners(2) = addlistener(obj.ZeissDriver,'HaloLampIntensity','PostSet',@obj.update);
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.WhiteLight.WhiteLight_Axiovert200();
            end
            obj = Object;
        end
    end
    methods
        function delete(obj)
            delete(obj.listeners)
        end
        function set.intensity(obj,val)
            obj.intensity = val;
            if obj.source_on %#ok<*MCSUP>
                obj.ZeissDriver.HaloLampIntensity = val;
            end
        end
        function on(obj)
            obj.ZeissDriver.HaloLampState = 1;
        end
        function off(obj)
            obj.ZeissDriver.HaloLampState = 0;
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
            obj.source_on = boolean(obj.ZeissDriver.HaloLampState);
        end
    end
end

