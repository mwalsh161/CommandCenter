classdef DBManager < Base.Manager
    %DBMANAGER Responsible for handling save callbacks
    %   The methods here prepare a data struct with a few default fields
    %   before passing to a Modules.Database instance:
    %       data.origin: The module whose data is being saved
    %       data.saved_by: The soon-to-be executing Module.Database instance
    %       data.saved_at: MATLAB datetime object
    %       [data|image]: data (Modules.Experiment) or image
    %          (Modules.Imaging) from origin module
    %   It is also worth noting that the notes from CC are passed as an
    %   argument to the Module.Database rather than a data field.
    
    properties
        use_git_info = true;
    end
    properties(SetAccess=private,Hidden)
        last_save_success = false; % Only true if they all succeed
    end

    methods
        function tasks = inactive(obj)
            set(obj.handles.notes,'String','');  % Erase notes field
            tasks = inactive@Base.Manager(obj);
            tasks = [{'Resetting notes field'} tasks];
        end
        function obj = DBManager(handles)
            obj = obj@Base.Manager(Modules.Database.modules_package,handles,handles.panelSave,handles.saving_select);
            obj.prefs = [obj.prefs, {'use_git_info'}];
            obj.loadPrefs;
            obj.blockOnLoad = handles.menu_saving;
            set(handles.image_save,'ClickedCallback',@(hObj,eventdata)obj.imSave(false,hObj,eventdata))
            set(handles.experiment_save,'Callback',@(hObj,eventdata)obj.expSave(false,hObj,eventdata))
            set(handles.experiment_load,'Callback',@(hObj,eventdata)obj.expLoad(hObj,eventdata))
            addlistener(obj.handles.Managers.Experiment,'experiment_finished',@(hObj,eventdata)obj.expSave(true,hObj,eventdata));
            addlistener(obj.handles.Managers.Imaging,'image_taken',@(hObj,eventdata)obj.imSave(true,hObj,eventdata));
        end
        
        function enable(obj)
            default = findall(obj.panelHandle.content,'tag','default');
            % Restore frozen state
            children = allchild(default);
            children(end+1) = obj.handles.image_save;
            for i = 1:numel(children)
                set(children(i),'enable',obj.frozen_state{i})
            end
            drawnow;
        end
        function disable(obj)
            default = findall(obj.panelHandle.content,'tag','default');
            children = allchild(default);
            children(end+1) = obj.handles.image_save;
            obj.frozen_state = get(children,'enable');
            if ~iscell(obj.frozen_state)
                % Takes care of only having a single child
                obj.frozen_state = {obj.frozen_state};
            end
            set(children,'enable','off')
            drawnow;
        end
        
        function Save(obj,type,data,auto,ax,module)
            obj.last_save_success = true;
            if ~isempty(obj.modules)
                % If is necessary! Otherwise always inactive when new mod added.
                obj.disable;
                notes = strjoin(cellstr(obj.handles.notes.String),newline);
                saved_datetime = datetime; % So it will be same for all
                target_module = class(module);
                for i = 1:numel(obj.modules)
                    active_DBmodule = obj.modules{i};
                    if auto==active_DBmodule.autosave
                        try
                            DBclass_str = class(active_DBmodule);
                            data.origin = target_module; % The module whose data is being saved
                            data.saved_by = DBclass_str;   % Module.Database
                            data.saved_at = saved_datetime;
                            try % If using git, append all the info of this version
                                gitPath = mfilename('fullpath');
                                gitPath = fileparts(gitPath); gitPath = fileparts(gitPath); gitPath = fileparts(gitPath);
                                data.GitInfo = getGitInfo(gitPath);
                                data.GitInfo.status = strip(git(sprintf('--git-dir="%s"',fullfile(gitPath,'.git')),sprintf('--work-tree="%s"',gitPath),'status'));
                                data.GitInfo.diff = strip(git(sprintf('--git-dir="%s"',fullfile(gitPath,'.git')),sprintf('--work-tree="%s"',gitPath),'diff'));
                            catch
                                warning('Git inspection failed!')
                            end
                            try % Get info on current cpu as possible incase on local git branch
                               [~,out] = system('whoami'); out = strip(out);
                               data.HostInfo.whoami = out;  % /HOST/username
                               [~,out] = system('ipconfig'); out = strip(out);
                               data.HostInfo.ipconfig = out; % contains mac and IP address
                            catch
                                warning('Computer info inspection failed!')
                            end
                            obj.sandboxed_function({active_DBmodule,type},data,ax,module,notes);
                            obj.log('%s to <a href="matlab: opentoline(%s,1)">%s</a>',type,which(DBclass_str),DBclass_str)
                        catch err
                            obj.error('Some saves failed. Should never get here!! Seek help at commandcenter-dev.slack.com\n%s',err.message)
                        end
                    end
                end
                if ~obj.last_sandboxed_fn_eval_success
                    obj.last_save_success = false;
                end
                obj.enable;
            elseif ~auto % Manual save clicked
                obj.error('No save modules loaded.')
            end
        end
        
        % Callbacks
        function imSave(obj,auto,ImagingManager,eventdata)
            [~,fig] = gcbo; % Note, this could be a popped-out image
            if isempty(fig) % Called by code
                SmartImage = ImagingManager.current_image;
                if isempty(SmartImage)
                    obj.error('No image to save yet!')
                    return
                end
            else
                imH = findall(fig,'tag','SmartImage');
                if isempty(imH)
                    obj.error('No image to save yet!')
                    return
                end
                SmartImage = imH.UserData;
            end
            ax = SmartImage.Parent;
            data = SmartImage.info;
            obj.Save('SaveIm',data,auto,ax,obj.handles.Managers.Imaging.active_module)
        end
        function expSave(obj,auto,varargin)
            h = msgbox(sprintf('Fetching data from %s.',class(obj.handles.Managers.Experiment.active_module)),'DBManager','help','modal');
            h.KeyPressFcn='';  % Prevent esc from closing window
            % Remove the OKButton
            delete(findall(h,'tag','OKButton')); drawnow;
            temp = obj.handles.Managers.Experiment.sandboxed_function({obj.handles.Managers.Experiment.active_module,'GetData'},...
                                            obj.handles.Managers.Stages,obj.handles.Managers.Imaging);
            delete(h);
            if isempty(temp)
                obj.error(sprintf('No data returned by %s',class(obj.handles.Managers.Experiment.active_module)));
                return
            end
            ax = obj.handles.axExp;
            data.data = temp;
            obj.Save('SaveExp',data,auto,ax,obj.handles.Managers.Experiment.active_module)
        end
        function expLoad(obj,varargin)
            assert(~isempty(obj.active_module),'No module loaded.')
            assert(~isempty(obj.handles.Managers.Experiment.active_module),'No experiment module loaded.')
            err = [];
            h = msgbox('Loading data.','DBManager','help','modal');
            h.KeyPressFcn='';  % Prevent esc from closing window
            delete(findall(h,'tag','OKButton')); drawnow;
            try
                data = obj.sandboxed_function({obj.active_module,'LoadExp'});
                if obj.last_sandboxed_fn_eval_success
                    obj.handles.Managers.Experiment.sandboxed_function({obj.handles.Managers.Experiment.active_module,'LoadData'},data);
                end
            catch err
            end
            delete(h);
            if ~isempty(err)
                rethrow(err)
            end
        end
    end
end

