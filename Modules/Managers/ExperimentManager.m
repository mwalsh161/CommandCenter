classdef ExperimentManager < Base.Manager
    
    properties(SetAccess=private)
        aborted = false;
    end
    
    events
        experiment_finished
    end
    
    methods
        function obj = ExperimentManager(handles)
            obj = obj@Base.Manager(Modules.Experiment.modules_package,handles,handles.panelExperiment);
            obj.blockOnLoad = handles.menu_experiments;
            set(handles.experiment_run,'callback',@obj.run)
        end
        
        % GUI Callbacks
        function run(obj,varargin)
            assert(~isempty(obj.active_module),'No module loaded.')
            obj.aborted = false;
            last_dumbimage = obj.handles.Managers.Imaging.dumbimage;
            obj.handles.Managers.Imaging.dumbimage = true;
            obj.log('%s starting experiment.',class(obj.active_module))
            obj.disable;
            if strcmp(get(obj.handles.panel_exp,'visible'),'off')
                CommandCenter('axes_exp_only_Callback',obj.handles.axes_exp_only,[],guidata(obj.handles.axes_exp_only))
            end
            [textH,h] = obj.abortBox(class(obj.active_module),@obj.abort);
            drawnow;
            err = [];
            try
                if ~isempty(obj.active_module.path) %if path defined, select path
                    obj.handles.Managers.Path.select_path(obj.active_module.path);
                end
                if isvalid(obj.handles.axExp)
                    cla(obj.handles.axExp,'reset')
                    subplot(1,1,1,obj.handles.axExp); % Re-center
                else % Clean up and reset axes
                    delete(allchild(obj.handles.panel_exp));  % Potential memory leak if user doesn't have delete callback to clean up listeners
                    obj.handles.axExp = axes('parent',obj.handles.panel_exp,'tag','axExp');
                end
                obj.sandboxed_function({obj.active_module,'run'},textH,obj.handles.Managers,obj.handles.axExp);
                if ~obj.aborted
                    notify(obj,'experiment_finished')
                end
            catch err
            end
            obj.handles.Managers.Imaging.dumbimage = last_dumbimage;
            obj.enable;
            delete(h);
            if ~isempty(err)
                rethrow(err)
            end
            obj.log('%s finished experiment.',class(obj.active_module))
        end
        function abort(obj,varargin)
            obj.aborted = true;
            obj.sandboxed_function({obj.active_module,'abort'});
            obj.log('%s aborted experiment.',class(obj.active_module))
        end
        
        % Save Event Callback
        function forceSave(obj,varargin)
            % Go through autosave
            obj.handles.Managers.DB.expSave(true)
        end

    end
    methods(Access=protected)
        function active_module_changed(obj,varargin)
            if ~isempty(obj.active_module)
                addlistener(obj.active_module,'save_request',@obj.forceSave);
            end
        end
    end
    methods(Static)
        function [textH,h] = abortBox(name,abort_callback)
            h = msgbox('Experiment Started',sprintf('%s running',name),'help','modal');
            h.KeyPressFcn='';  % Prevent esc from closing window
            h.CloseRequestFcn = abort_callback;
            % Repurpose the OKButton
            button = findall(h,'tag','OKButton');
            set(button,'tag','AbortButton','string','Abort',...
                'callback',abort_callback)
            textH = findall(h,'tag','MessageBox');
            addlistener(textH,'String','PostSet',@Base.Manager.resizeMsgBox);
        end
    end
end

