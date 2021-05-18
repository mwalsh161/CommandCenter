classdef SourcesManager < Base.Manager

    properties(Access=private)
        source_listener         % Listener for source.source_on
    end

    methods
        function obj = SourcesManager(handles)
            obj = obj@Base.Manager(Modules.Source.modules_package,handles,handles.panelSource,handles.sources_select);
            obj.loadPrefs;
            obj.blockOnLoad = handles.menu_sources;
        end

        % Callback to turn laser on
        function turn_on(obj,varargin)
            % Always call arm method, and if success call on method
            % Developer is responsible for ensuring arm doesn't slow down on call
            obj.sandboxed_function({obj.active_module,'arm'});
            if ~obj.last_sandboxed_fn_eval_success
                % Sandbox will issue UI error dialog
                return
            end
            obj.sandboxed_function({obj.active_module,'on'});
            obj.state_toggle;
            obj.log('%s turned on.',class(obj.active_module))
        end
        % Callback to turn laser off
        function turn_off(obj,varargin)
            obj.sandboxed_function({obj.active_module,'off'});
            obj.state_toggle;
            obj.log('%s turned off.',class(obj.active_module))
        end

        % Callback for active_module.source_on
        function state_toggle(obj,varargin)
            if obj.active_module.source_on == true
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
                dropdown.h = h;                                 % Handle to dropdown.
                dropdown.i = i;                                 % Index of this dropdown element.
                obj.modules{i}.CC_dropdown = dropdown;

                h.String{i} = '';                               % Initialize with empty strings.
            end
            
            for i = 1:numel(obj.modules)
                obj.modules{i}.updateCommandCenter(0, 0);       % Update empty strings to be correct.
            end

            drawnow expose;
        end
    end

end
