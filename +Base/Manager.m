classdef Manager < handle
    %MANAGER Root manager class to wrap modules and manage GUI panel
    %   Makes it easier to load and change modules. Handles constructing
    %   and destroying unused ones. Given a parent uimenu, it will generate
    %   and manage the children.
    %
    %   Figure/GUI callbacks must be public methods
    %   Internal callbacks should be protected (although not necessary)
    %   
    %   Upon active_module change, the master callback calls the
    %   active_module_changed method which is reserved for children to
    %   define.
    %   Upon modules change, the master callback calls the
    %   modules_changed method which is reserved for children to
    %   define.
    %
    %   If there is an error under the default devider (custom settings)
    %   that will not be handled by this code.
    %
    %   A manager can subclass this as a "simple" manager as well in which
    %   all module related methods will error
    
    properties(Access=protected)
        no_module_str = 'No Modules Loaded';
    end
    properties(SetAccess=private)
        disabled = 0;                    % Number disabled calls. Also to prevent disabling "twice"
        namespace
        last_sandboxed_fn_eval_success = false;  % Set after each sandboxed_function eval
    end
    properties(SetAccess=protected,SetObservable,Hidden)
        modules = {};   % Cell array of modules.
    end
    properties(SetAccess=protected,SetObservable,AbortSet,Hidden)
        % Handle to active module (should be in list modules!)
        %   AbortSet only sets if value has changed. This is used because there
        %   is a lot of overhead for the GUI when this changes.
        active_module = 0;
    end
    properties(SetAccess=immutable,GetAccess=protected)
        single          % True if there can only be 1. False if no limit.
        panelHandle     % Handle to scrollPanel of UI that belongs to type.
        popupHandle     % Only if it is not single.
    end
    properties(Access=protected)
        blockOnLoad     % Handle to things to deactive on module load
        handles         % All handles to GUI
        type            % Specify type to have separate namespaces in prefs
        frozen_state    % State of panel controls before frozen (active_module is empty)
    end
    
    methods(Static)
        function getAvailModules(package,parent_menu,fun_callback,fun_in_use)
            path = fileparts(fileparts(mfilename('fullpath'))); % Root AutomationSetup/
            [prefix,module_strs,packages] = Base.GetClasses(path,'Modules',package);  % Returns name without package name
            % Alphabetic order
            packages = sortrows(packages');
            module_strs = sortrows(module_strs');
            remove = findall(parent_menu,'tag','module');
            for i = 1:length(remove)
                if remove ~= parent_menu
                    delete(remove(i));
                end
            end
            previousStuff = allchild(parent_menu); % Push these down to bottom
            if isempty(module_strs)
                uimenu(parent_menu,'label','No Modules found','enable','off','tag','module');
            end
            for i = 1:numel(packages)
                package = fullfile(['+' strrep(prefix(1:end-1),'.','/+')],['+' packages{i}]);
                h = uimenu(parent_menu,'label',packages{i},'tag','module');
                Base.Manager.getAvailModules(package,h,fun_callback,fun_in_use); % Recursively call to populate
            end
            for i = 1:numel(module_strs)
                module_str = module_strs{i};
                module_fullstr = [prefix module_str];
                checked = 'off';
                if fun_in_use([prefix module_str])
                    checked = 'on';
                end
                h = uimenu(parent_menu,'label',module_str,'checked',checked,...
                    'callback',fun_callback,'tag','module');
                h.UserData = module_fullstr;
            end
            for i = 1:length(previousStuff)
                previousStuff(i).Position = h.Position + i - 1;
            end
        end
        function resizeMsgBox(~,eventdata)
            textH = eventdata.AffectedObject;
            f = Base.getParentFigure(textH);
            f.Units = 'points';
            textH.Units = 'points';
            border = [20 20];
            tPos = textH.Extent;
            NewSize = [tPos(1)+tPos(3) tPos(2)+tPos(4)] + border;
            ind = [];
            if NewSize(1) > f.Position(3)
                ind(end+1) = 3;
            end
            if NewSize(2) > f.Position(4)
                ind(end+1) = 4;
            end
            if ~isempty(ind)  % All logic is so we only set this once
                f.Position(ind) = NewSize(ind-2);
            end
        end
    end
    methods(Access=protected)
        function savePrefs(obj)
            if isprop(obj,'prefs')
                for i = 1:numel(obj.prefs)
                    try
                        eval(sprintf('setpref(obj.namespace,''%s'',obj.%s);',obj.prefs{i},obj.prefs{i}));
                    catch err
                        warning('MANAGER:save_prefs','%s',err.message)
                    end
                end
            end
        end
        function loadPrefs(obj)
            % Load prefs
            if isprop(obj,'prefs')
                for i = 1:numel(obj.prefs)
                    if ispref(obj.namespace,obj.prefs{i})
                        pref = getpref(obj.namespace,obj.prefs{i});
                        try
                            obj.(obj.prefs{i}) = pref;
                        catch err
                            warning('MANAGER:load_prefs','Error on loadPrefs (%s): %s',obj.prefs{i},err.message)
                        end
                    end
                end
            end
        end
        function modules_temp = load_module_str(obj,class_str)
            set(obj.blockOnLoad,'enable','off')
            drawnow expose;
            errors = {};
            if ~isa(class_str,'cell')
                class_str = {class_str};
            end
            modules_temp = {};
            for i = 1:numel(class_str)
                nloaded_before = numel(getappdata(obj.handles.figure1,'ALLmodules'));
                try
                    super = superclasses(class_str{i});
                    singular_type = obj.type;
                    if obj.type(end)=='s'  % Because of how folder packages were labeled
                        singular_type = obj.type(1:end-1);
                    end
                    assert(ismember(sprintf('Modules.%s',singular_type),super),'Superclass of %s must be Modules.%s',class_str{i},singular_type)
                    modules_temp{end+1} = eval(sprintf('%s.instance',class_str{i}));
                    addlistener(modules_temp{end},'ObjectBeingDestroyed',@obj.moduleBeingDestroyed);
                    obj.log('Initialized <a href="matlab: opentoline(''%s'',1)">%s</a>',which(class_str{i}),class_str{i})
                catch err
                    % IMPORTANT - remove from tracked modules (added in
                    % Base.Module constructor before error in subclass)
                    loaded_modules = getappdata(obj.handles.figure1,'ALLmodules');
                    % All new modules must be from attempted load and at
                    % the end (keep in mind, if module cleans up on its
                    % own, this list can change by more than 1 on each
                    % loop!
                    while numel(loaded_modules) > nloaded_before
                        delete(loaded_modules{end});
                        loaded_modules = getappdata(obj.handles.figure1,'ALLmodules');
                    end
                    if mislocked(class_str{i})
                        % Lock is the first thing called in
                        % module.instance, so even if an error before gets 
                        % added to loaded_modules, will still be locked.
                        munlock(class_str{i});
                    elseif mislocked([class_str{i} '.instance'])
                        munlock([class_str{i} '.instance'])
                    end
                    errors{end+1} = sprintf('Error loading %s:\n%s',class_str{i},err.message);
                    msg = sprintf('Following error caught in <a href="matlab: opentoline(''%s'',%i)">%s (line %i)</a>:\n%s',err.stack(1).file,err.stack(1).line,err.stack(1).name,err.stack(1).line,err.message);
                    obj.log(msg,Base.Logger.ERROR) % This part of the log keeps the traceback
                end
            end
            if ~isempty(errors)
                errors = strjoin(errors,'\n\n');
                obj.error(errors)
            end
            set(obj.blockOnLoad,'enable','on')
        end
        
        % Callback when obj.modules is modified (this modifies obj.active_module)
        function master_modules_changed(obj,varargin)
            module_strs = obj.get_modules_str('simple');
            if isempty(module_strs)
                module_strs{1} = obj.no_module_str;
            end
            val = 1;
            if ~obj.single
                val = get(obj.popupHandle,'Value');
                val = min(val,numel(module_strs));
                set(obj.popupHandle,'String',module_strs,'Value',val)
            end
            if strcmp(module_strs{1},obj.no_module_str)
                obj.active_module = [];
            else
                obj.active_module = obj.modules{val};
            end
            obj.modules_changed(varargin{:});
        end
        % Callback when obj.active_module is modified (DO NOT OVERRIDE THIS)
        function master_active_module_changed(obj,varargin)
            obj.update_settings;
            if isempty(obj.active_module)
                obj.disable;
            else
                obj.enable;
            end
            obj.active_module_changed(varargin{:});
        end
        % Reserved for children if they want to do more when obj.active_module is modified.
        function active_module_changed(varargin)
        end
        % Reserved for children if they want to do more when obj.modules is modified.
        function modules_changed(varargin)
        end
        
        % Method to update settings in scrollpanel
        function update_settings(obj)
            scrollPanel = obj.panelHandle;
            % Clear all but default
            oldPanels = allchild(scrollPanel.content);
            for i = 1:numel(oldPanels)
                tag = get(oldPanels(i),'tag');
                if ~strcmp(tag,'default')
                    scrollPanel.removePanel(tag);
                end
            end
            if ~isempty(obj.active_module)
                width = get(scrollPanel.content,'position'); width = width(3);
                temp = figure('visible','off');
                settings_panel = uipanel(temp,'BorderType','None',...
                    'units','characters','position',[0 0 width 0]);
                obj.sandboxed_function({obj.active_module,'settings'},settings_panel);
                % Make sure width wasn't changed
                set(settings_panel,'units','characters')
                w = get(settings_panel,'position');
                if w(3) ~= width
                    delete(settings_panel)
                    msg = sprintf('%s modified settings panel width. This is not allowed!',class(obj.active_module));
                    obj.error(msg);
                else
                    % Adjust length of panel to fit contents.
                    contents = allchild(settings_panel);
                    set(contents,'units','characters')
                    lengths = 0;
                    for i = 1:numel(contents)
                        contents_pos = get(contents(i),'position');
                        lengths(end+1) = contents_pos(2);
                        lengths(end+1) = lengths(end) + contents_pos(4);
                    end
                    bottom = min(lengths);
                    top = max(lengths);
                    if bottom < 0
                        obj.warning('MANAGER:settings','Detected some panels with negative positions, this may cause display errors.')
                    end
                    set(settings_panel,'position',[0 0 w(3) top])
                    if ~isempty(contents)
                        divider = uipanel(temp,'units','characters','Position',[w(3)/8 top+0.1 w(3)*3/4 0.1]);
                        scrollPanel.addPanel(divider,'Divider');
                    end
                    % Adjust Callbacks
                    obj.SettingsCallbackOverride(contents)
                    scrollPanel.addPanel(settings_panel,'Settings');
                end
                delete(temp)
            end
        end
        % Redefines all uicontrol elements in contents to go through sandbox
        function SettingsCallbackOverride(obj,contents)
            control = findobj(contents,'type','uicontrol'); % Respect HandleVisibility = 'off'
            for i = 1:numel(control)
                item = control(i);
                if ~isempty(item.Callback)
                    inp = {};
                    callback = item.Callback;
                    if iscell(callback) % MATLAB docs: A cell array in which the first element is a function handle. Subsequent elements in the cell array are the arguments to pass to the callback function.
                        inp = callback(2:end);
                        callback = callback{1};
                    elseif ischar(callback) % MATLAB docs: A character vector containing a valid MATLAB expression (not recommended). MATLAB evaluates this expression in the base workspace.
                        callback = @(varargin)evalin('base',callback);
                    end
                    item.Callback = @(varargin)obj.sandboxed_function(callback,varargin{:},inp{:});
                end
            end
        end

    end
    methods
        function tasks = inactive(obj)
            % Called when inactivity timer expires
            tasks = {};
            for i = 1:length(obj.modules)
                 % If user doesn't have return arg, will be empty double: fine
                 % If user has an error in module, as usual, sandboxed_function
                 % will handle, and program execution will continue
                task = obj.sandboxed_function({obj.modules{i} ,'inactive'});
                if ~isempty(task)
                    tasks{end+1} = sprintf('%s: %s',class(obj.modules{i}),task);
                end
            end
        end
        function assert(obj,varargin)
            try
                assert(varargin{:}); % built-in assert
            catch err
                obj.error(err.message,err); % Need to also raise to command window to halt execution
            end
        end
        function error(obj,dlgMsg,varargin)
            % error(msg)            % msg is used as log and dlg
            % error(dlgMsg,logMsg)  % separate log and dlg msgs
            % error(__,errObject)   % Will rethrow(errObject)
            % error(__,throw)       % Will throw error with dlgMsg
            % error(__,__,traceback)% Traceback (in case you don't want to
            %                         throw error, but want traceback)
            logMsg = dlgMsg;
            if numel(varargin) > 0
                if isa(varargin{1},'char')
                    logMsg = varargin{1};
                end
            end
            if ~isempty(varargin) && isstruct(varargin{end})
                stack = varargin{end};
                varargin(end) = [];
            elseif ~isempty(varargin) && isa(varargin{end},'MException')
                stack = varargin{end}.stack;
            else
                stack = dbstack;
                stack(1) = []; % Remove this method
            end
            
            obj.log(logMsg,stack,Base.Logger.ERROR)
            if ~isempty(obj.handles.Managers.error_dlg) && isvalid(obj.handles.Managers.error_dlg)
                txt = findall(obj.handles.Managers.error_dlg,'type','Text');
                if ~strcmp(strjoin(txt.String,'\n'),dlgMsg)
                    txt.String(end+1:end+2) = {'---------------',dlgMsg};
                end
                figure(obj.handles.Managers.error_dlg); % Bring to front
            else
                obj.handles.Managers.error_dlg = errordlg(dlgMsg,'Error!','replace');
                txt = findall(obj.handles.Managers.error_dlg,'type','Text');
                addlistener(txt,'String','PostSet',@obj.resizeMsgBox);
            end
            if ~isempty(varargin)
                switch class(varargin{end})
                    case {'double','logical'}
                        if varargin{end}
                            error(dlgMsg)
                        end
                    case 'MException'
                        rethrow(varargin{end})
                end
            end
        end
        function warning(obj,dlgMsg,varargin)
            % error(msg)            % msg is used as log and dlg
            % error(dlgMsg,logMsg)  % separate log and dlg msgs
            % error(__,throw)       % Will throw error with dlgMsg
            logMsg = dlgMsg;
            if numel(varargin) > 0
                if isa(varargin{1},'char')
                    logMsg = varargin{1};
                end
            end
            stack = dbstack;
            stack(1) = []; % Remove this method
            obj.log(logMsg,stack,Base.Logger.WARNING)
            if ~isempty(obj.handles.Managers.warn_dlg) && isvalid(obj.handles.Managers.warn_dlg)
                txt = findall(obj.handles.Managers.warn_dlg,'type','Text');
                if ~strcmp(strjoin(txt.String,'\n'),dlgMsg)
                    txt.String{end+1:end+2} = {'---------------',dlgMsg};
                end
                figure(obj.handles.Managers.warn_dlg); % Bring to front
            else
                obj.handles.Managers.warn_dlg = warndlg(dlgMsg,'Warning!','replace');
                txt = findall(obj.handles.Managers.warn_dlg,'type','Text');
                addlistener(txt,'String','PostSet',@obj.resizeMsgBox);
            end
            if numel(varargin)>0
                switch class(varargin{end})
                    case {'double','logical'}
                        if varargin{end}
                            warning('MANAGER:warning',dlgMsg)
                        end
                end
            end
        end
        function obj = Manager(type,handles,panelHandle,popupHandle)
            obj.type = type;
            obj.handles = handles;
            obj.namespace = strrep(class(obj),'.','_');
            if nargin < 3 % "simple" manager
                obj.log('%s %s Initialized (simple)',obj.type,mfilename)
                return
            end
            if nargin < 4
                obj.single = true;
            else
                if ~isvalid(popupHandle)
                    errormsg('Received invalid popup handle!')
                    error('Received invalid popup handle!')
                end
                obj.popupHandle = popupHandle;
                obj.single = false;
            end
            if ~isvalid(panelHandle)
                errormsg('Received invalid panel handle!')
                error('Received invalid panel handle!')
            end
            obj.panelHandle = panelHandle;
            set(obj.popupHandle,'callback',@obj.module_selected)
            % Determine state of GUI objects
            obj.disable;
            obj.enable;
            obj.log('%s %s Initialized',obj.type,mfilename)
            addlistener(obj,'modules','PostSet',@obj.master_modules_changed);
            addlistener(obj,'active_module','PostSet',@obj.master_active_module_changed);
            if ispref(mfilename,type)
                class_strs = getpref(mfilename,type);
                obj.modules = obj.load_module_str(class_strs);
            else
                obj.modules = {};
            end
        end
        % Destructor
        function delete(obj)
            obj.savePrefs;
            % Save loaded
            module_strs = obj.get_modules_str;
            if isempty(module_strs)
                if ispref(mfilename,obj.type)
                    rmpref(mfilename,obj.type)
                end
            else
                setpref(mfilename,obj.type,module_strs)
            end
            modulesTemp = obj.modules;
            for i = 1:numel(modulesTemp)
                if ~isempty(modulesTemp{i})&&isobject(modulesTemp{i})&&isvalid(modulesTemp{i})
                    delete(modulesTemp{i})
                    drawnow; % Let other callbacks listening to delete event take place
                end
            end
            obj.log('%s %s Destroyed',obj.type,mfilename)
        end
        function log(obj,msg,varargin)
            % log(msg)
            % log(msg,sprintf-like inputs)
            % log(_,logTraceback) where logTraceback is a logical or stack struct
            % log(_,level) where level is an integer
            traceback = false;
            level = 1;
            numargs = sum(regexprep(msg,'%%','')=='%'); %find any % for potential variable input
            str_args = varargin(1:numargs);
            varargin(1:numargs) = [];
            % Parse remainder of inputs
            assert(length(varargin) <= 2,'Incorrect call: log(msg, [sprintf-like-inputs, [logTraceback, [level]]])');
            while ~isempty(varargin)
                if isstruct(varargin{end})
                    traceback = varargin{end};
                elseif isnumeric(varargin{end})
                    level = varargin{end};
                else
                    error('Incorrect call: log(msg, [sprintf-like-inputs, [logTraceback, [level]]])')
                end
                varargin(end) = [];
            end
            msg = strrep(msg,'\','\\');
            msg = sprintf(msg,str_args{:});
            msg = sprintf('(%s) - %s',obj.type,msg);
            if isstruct(traceback)
                obj.handles.logger.logTraceback(msg,traceback,level);
            elseif traceback
                obj.handles.logger.logTraceback(msg,level);
            else
                obj.handles.logger.log(msg,level);
            end
        end
        % Use to call methods in active_module (takes care of error handling)
        function varargout = sandboxed_function(obj,fn_specs,varargin)
            % sandboxed_function(fun_handle,input1,input2,...)
            % sandboxed_function({instance,method_name},input1,input2,...)
            
            % The most general sandboxed function
            obj.last_sandboxed_fn_eval_success = true;
            % Stop inactivity timer during execution
            timerH = obj.handles.inactivity_timer;
            managers = timerH.UserData;
            restart = false;
            if strcmp(timerH.Running,'on') || managers.inactivity
                managers.inactivity = false;
                restart = true;
                stop(timerH);
            end
            % Execute function/method
            if iscell(fn_specs) % method
                mmc = metaclass(fn_specs{1});
                method_meta = mmc.MethodList(ismember({mmc.MethodList.Name},fn_specs{2}));
                nout = numel(method_meta.OutputNames);
                varargout = cell(1,nargout);
                try
                    [varargout{:}] = fn_specs{1}.(fn_specs{2})(varargin{:});
                catch err
                    obj.last_sandboxed_fn_eval_success = false;
                    obj.error(err.message,err.stack)
                end
            else % fn
                nout = abs(nargout(fn_specs)); % The max of nargout method basically ignores varargout
                varargout = cell(1,nargout);
                try
                    [varargout{:}] = feval(fn_specs,varargin{:});
                catch err
                    obj.last_sandboxed_fn_eval_success = false;
                    obj.error(err.message,err.stack)
                end
            end
            varargout = varargout(1:nargout); % Cut down to requested number
            % Reset inactivity timer (if this was the call that stopped it)
            if restart
                timerH.StartDelay = obj.handles.Managers.timeout; % Maybe user changed
                start(timerH);
            end
        end
        function disable(obj)
            if obj.disabled > 0
                obj.disabled = obj.disabled + 1;
                return
            end
            default = findall(obj.panelHandle.content,'tag','default');
            obj.frozen_state = get(allchild(default),'enable');
            if ~iscell(obj.frozen_state)
                % Takes care of only having a single child
                obj.frozen_state = {obj.frozen_state};
            end
            set(allchild(default),'enable','off')
            obj.disabled = true;
        end
        function enable(obj)
            if obj.disabled > 1
                obj.disabled = obj.disabled - 1;
                return
            end
            default = findall(obj.panelHandle.content,'tag','default');
            % Restore frozen state
            children = allchild(default);
            for i = 1:numel(children)
                set(children(i),'enable',obj.frozen_state{i})
            end
            obj.disabled = false;
        end
        
        % Return string representation of modules
        function strs = get_modules_str(obj,method)
            % Method can be full or simple (simple is just the class name)
            if nargin < 2
                method = 'full';
            end
            strs = cell(1,numel(obj.modules));
            for i = 1:numel(obj.modules)
                if strcmpi(method,'simple')
                    fullname = strsplit(class(obj.modules{i}),'.');
                    strs{i} = fullname{end};
                else
                    strs{i} = class(obj.modules{i});
                end
            end
        end
        % Check if class as string exists; returns position (0 if not nonexistent).
        function pos = check_module_str(obj,class_str)
            pos = 0;
            for i = 1:numel(obj.modules)
                if strcmp(class(obj.modules{i}),class_str)
                    pos = i;
                    break
                end
            end
        end
        % Retrieve module object by its string name.
        function module = module_byString(obj,module_str)
            module_strs = obj.get_modules_str;
            mask = ismember(module_strs,module_str);
            if ~sum(mask)
                error('Name seems to be associated with untracked module!')
            elseif sum(mask) > 1
                error('There seems to be multiple modules associated with this name!')
            end
            module = obj.modules{mask};
        end
        function i = setActiveModule(obj,first)
            % Argument can be name of module that is loaded or an index
            % into active_modules
            % The previous active module index is returned.
            if isa(first,'char')
                pos = obj.check_module_str(first);
            elseif isnumeric(first)
                pos = first;
            else
                pos = false;
            end
            assert(logical(pos),'When setting active module, input must be a valid index, or name of loaded module.')
            i = get(obj.popupHandle,'value');
            set(obj.popupHandle,'value',pos)
            obj.module_selected;
            drawnow expose;
        end
        % Deleted module
        function moduleBeingDestroyed(obj,hObject,varargin)
            obj.log('Destroying <a href="matlab: opentoline(''%s'',1)">%s</a>',which(class(hObject)),class(hObject))
            mask = obj.check_module_str(class(hObject));
            obj.modules(mask) = [];
        end
        % Populates menu
        function getAvail(obj,parent_menu)
            fun_callback = @obj.module_initialized;
            fun_in_use = @obj.check_module_str;
            package = ['+' obj.type];
            obj.getAvailModules(package,parent_menu,fun_callback,fun_in_use);
        end
        % Callback for menu item click
        function module_initialized(obj,hObject,varargin)
            if strcmp(get(hObject,'checked'),'off')
                % This means the module is not currently loaded
                if obj.single && ~isempty(obj.modules)
                    tempMod = obj.modules{1};
                    delete(tempMod);
                    if ismember(class(tempMod),inmem)
                        obj.warning('Could not remove module from memory.')
                    end
                end
                temp = obj.load_module_str(get(hObject,'UserData'));
                if ~isempty(temp)
                    obj.modules{end+1} = temp{1};
                end
            else
                % This means the module IS currently loaded
                pos = obj.check_module_str(get(hObject,'UserData'));
                tempMod = obj.modules{pos};
                delete(tempMod)
                if mislocked(class(tempMod))
                    munlock(class(tempMod))
                elseif mislocked([class(tempMod) '.instance'])
                    munlock([class(tempMod) '.instance'])
                end
            end
        end
        % Callback for popup menu selection
        function module_selected(obj,varargin)
            val = get(obj.popupHandle,'Value');
            val = min(val,numel(obj.modules));
            module_strs = get(obj.popupHandle,'string');
            if strcmp(module_strs{1},obj.no_module_str)
                obj.active_module = [];
            else
                obj.active_module = obj.modules{val};
            end
        end
    end
end

