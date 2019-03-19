classdef SourcesManager < Base.Manager
    
    properties(Access=private)
        source_listener         % Listener for source.source_on
    end
    
    methods
        function obj = SourcesManager(handles)
            obj = obj@Base.Manager(Modules.Source.modules_package,handles,handles.panelSource,handles.sources_select);
            obj.loadPrefs;
            obj.blockOnLoad = handles.menu_sources;
            set(handles.sources_select,'ButtonDownFcn',@obj.sourcesClick);
        end
        
        % Callback to turn laser on
        function turn_on(obj,varargin)
            obj.active_module_method('on');
            obj.state_toggle;
            obj.log('%s turned on.',class(obj.active_module))
        end
        % Callback to turn laser off
        function turn_off(obj,varargin)
            obj.active_module_method('off');
            obj.state_toggle;
            obj.log('%s turned off.',class(obj.active_module))
        end
        
        % Callback for active_module.source_on
        function state_toggle(obj,varargin)
            if obj.active_module.source_on
                set(obj.handles.sources_toggle,'String','Off','Value',1)
                set(obj.handles.sources_toggle,'callback',@obj.turn_off)
            else
                set(obj.handles.sources_toggle,'String','On','Value',0)
                set(obj.handles.sources_toggle,'callback',@obj.turn_on)
            end
        end
        
    end
    methods(Access=protected)
        function active_module_changed(obj,varargin)
            if isempty(obj.active_module)
                set(obj.handles.sources_toggle,'value',0);
                set(obj.handles.sources_toggle,'enable','off');
            else
                set(obj.handles.sources_toggle,'enable','on');
                if ~isempty(obj.source_listener)&&isvalid(obj.source_listener)
                    delete(obj.source_listener)
                end
                obj.source_listener = addlistener(obj.active_module,'source_on','PostSet',@obj.state_toggle);
                obj.state_toggle;
            end
        end
        function modules_changed(obj,varargin)
            if isempty(obj.modules)
                return
            end
            h = obj.handles.sources_select;
            for i = 1:numel(obj.modules)
                mod_dropdown_struct.h = h;
                mod_dropdown_struct.i = i;
                obj.modules{i}.CC_dropdown = mod_dropdown_struct;
                % Initialize with correct color, but any update after this
                % is handled in Modules.Source
                name = strsplit(class(obj.modules{i}),'.');
                short_name = strjoin(name(2:end),'.');
                if obj.modules{i}.source_on
                    h.String{i} = sprintf('<HTML><FONT COLOR="green">%s</HTML>',short_name);
                else
                    h.String{i} = sprintf('<HTML><FONT COLOR="red">%s</HTML>',short_name);
                end
            end
        end
    end

end