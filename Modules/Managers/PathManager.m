classdef PathManager < Base.Manager
    % This will handle different paths that are configured
    % PathManager_instance.select_path(obj,name,prompt,update_active)
    %
    %   Configuration:
    %       1) Choose module (can be empty for regular function call, e.g. if necessary to call pause)
    %       2) Provide inputs necessary to load module
    %       3) Choose method in module
    %       4) Provide inputs necessary to call method for desired path
    %   A path can also be an alias for another path by putting the name of
    %     the target path as a string instead of the instructions. Note,
    %     an alias can point to a non-existing path (case of deletion), so
    %     be careful!
    % It is not a typical "manager" for modules, but a manager for storing
    % and executing path changes (e.g. "simple" manager)
    %
    % paths, and active_path are SetObservable
    %
    % If a path errors upon setting, the error is raised and the path is in
    % an unknown state
    %
    % TIP: Might be useful to call the GUI methods for creating
    % paths/alias:
    %   obj.new_path_GUI([default name])
    %   obj.new_alias_GUI([default name])
    %
    % TIP: If calling in a setting where the user is not intended to be
    % around (e.g. long, automated experiment), might want to call
    % select_path(NAME,false), where seccond arg prevents userdlg asking to
    % create an alias (and haulting code flow).
    %
    % TIP: select_path can be called with optional second argument: prompt
    %   If true, and the path doesn't exist, user prompted to create alias.
    %   Default is true
    %
    % TIP: Be sure to include in instructions, any wait method if something
    % takes time, and uiwait if relying on msgbox interaction for
    % completion
    
    properties(SetAccess={?Base.Manager},SetObservable)
        % Paths is a struct array where each element has the form:
        %   name -> name of path
        %   instructions -> struct array with form (or string if alias):
        %       module_name -> name of module to grab
        %       module_inputs -> cell array of ordered inputs
        %       method_name -> name of method in module to call
        %       method_inputs -> cell array of ordered inputs
        paths = struct('name',{},'instructions',{});  % Path struct (will change upon adding/deletion)
        active_path = '';    % Active path name (will change upon path selection). Empty if unknown.
    end
    properties
        module_types = {};
    end
    
    methods(Static,Hidden)
        function instruction_strings = get_string_instructions(instructions)
            instruction_strings = {};
            if isstruct(instructions)
                for i = 1:length(instructions)
                    narin = length(instructions(i).method_inputs);
                    inputs = cell(1,narin);
                    for j = 1:narin
                        inputs{j} = PathManager.format_instruction_inputs(instructions(i).method_inputs{j});
                    end
                    if ~isempty(instructions(i).module_name)
                        instruction_strings{end+1} = sprintf('%s.%s(%s)',...
                            instructions(i).module_name,...
                            instructions(i).method_name,...
                            strjoin(inputs,', '));
                    else
                        instruction_strings{end+1} = sprintf('%s(%s)',...
                            instructions(i).method_name,...
                            strjoin(inputs,', '));
                    end
                end
            elseif ischar(instructions)
                instruction_strings = {'alias',sprintf('---> %s',instructions)};
            else
                error('Instructions are in the wrong format.')
            end
        end
        function fmt = format_instruction_inputs(input)
            if isnumeric(input)
                fmt = ['[' num2str(input) ']'];
            elseif ischar(input)
                fmt = ['''' input ''''];
            elseif iscell(input)
                input = cellfun(@PathManager.format_instruction_inputs,input,'UniformOutput',false);
                fmt = ['{' strjoin(input,', ') '}'];
            else
                fmt = '??';
            end
        end
    end
    methods
        function obj = PathManager(handles)
            obj = obj@Base.Manager('Paths',handles); % "Simple" manager
            obj.prefs = [obj.prefs {'paths'}];
            % Grab all classes in Modules package
            [~,obj.module_types,~] = Base.GetClasses('+Modules');
            % Add menu to CommandCenter and tie in some callbacks
            uimenu(handles.figure1,'Text','Path',...
                'Callback',@obj.menu_open_CB,'tag',[mfilename '_menu']);
            obj.loadPrefs;
        end
        % Functional methods
        function validate_name(obj,name)
            obj.assert(~isempty(name),'Name cannot be empty (reserved for unknown path)');
            map = ismember({obj.paths.name},name);
            obj.assert(~any(map),'Path with this name already exists, remove it and try again.');
        end
        function new_path(obj,name,instructions)
            obj.assert(isstruct(instructions)||ischar(instructions),'Instructions either need to be an array of structs or a string if this path is an alias.')
            obj.validate_name(name);
            if ischar(instructions) % Alias (validate target)
                map = ismember({obj.paths.name},instructions);
                obj.assert(any(map),'The target path for this alias does not exist.');
            end
            new_path = struct('name',name,'instructions',instructions);
            temp_paths = obj.paths; % Don't write immediately so SetObservable listeners not triggered twice
            temp_paths(end+1) = new_path;
            % Alphabetical ordering
            [~,order] = sort({temp_paths.name});
            obj.paths = temp_paths(order);
        end
        function remove_path(obj,name)
            % Note this will not clean up any potential aliases pointing to this path
            map = ismember({obj.paths.name},name);
            obj.assert(any(map),sprintf('No path found by name "%s"',name));
            if strcmp(obj.paths(map).name,obj.active_path)
                obj.active_path = '';
            end
            obj.paths(map) = [];
        end
        function select_path(obj,name,prompt,update_active)
            % Users should not call with update_active specified
            if nargin < 3
                prompt = true;
            end
            if nargin < 4
                update_active = false;
            end
            % Check to see if exists
            if isempty(obj.paths)
                obj.error(sprintf('Attempted to select "%s", but there are currently no paths defined.',name),true);
            end
            map = ismember({obj.paths.name},name);
            if ~any(map)
                if prompt
                    answer = questdlg(sprintf('Attempted to select "%s" which does not exist. If it exists under a different name, you can make an alias for it.',name),...
                                        mfilename,'Make Alias','Cancel','Make Alias');
                    if strcmp(answer,'Make Alias')
                        obj.new_alias_GUI(name)
                        select_path(obj,name,false) % Call again this time without prompt
                        return
                    end
                end % If no prompt is desired, error
                obj.error(sprintf('No path found by name "%s"',name),true);
            end
            
            path = obj.paths(map);
            if ischar(path.instructions) % Alias
                % Error handling here for better error message (try/catch
                % wont work with manager error handling
                map = ismember({obj.paths.name},path.instructions);
                obj.assert(any(map),sprintf('The target path for this alias does not exist: "%s"',path.instructions));
                obj.select_path(path.instructions,prompt,true);
                obj.active_path = name;
                return
            end
            try
                for i = 1:length(path.instructions)
                    instruction = path.instructions(i);
                    if isempty(instruction.module_name) % Regular function call
                        feval(instruction.method_name,instruction.method_inputs{:});
                    else
                        module = eval(sprintf('%s.instance(instruction.module_inputs{:})',instruction.module_name));
                        module.(instruction.method_name)(instruction.method_inputs{:});
                    end
                end
            catch err
                obj.active_path = '';
                obj.error(err.message,err)
            end
            if ~update_active
                obj.active_path = name;
            end
        end
    end
    
    methods(Hidden)
        % GUI methods
        function menu_open_CB(obj,hObj,~)
            % Redraw each time
            delete(allchild(hObj));
            function checked = getchecked(name)
                checked = 'off';
                if strcmp(name,obj.active_path)
                    checked = 'on';
                end
            end
            cellfun(@(name)uimenu(hObj,...
                'text',name,...
                'callback',@obj.path_selected_CB,...
                'tag',name,...
                'checked',getchecked(name)),...
                {obj.paths.name},'uniformoutput',false);
            uimenu(hObj,'separator','on','Text','New Path','callback',@obj.new_path_GUI);
            if ~isempty(obj.paths)
                uimenu(hObj,'Text','New Alias','callback',@obj.new_alias_GUI);
            end
            if ~isempty(obj.paths)
                uimenu(hObj,'Text','Remove Path/Alias','callback',@obj.remove_path_CB);
            end
            if ~isempty(obj.paths)
                uimenu(hObj,'Text','View All','callback',@obj.view_path);
            end
        end
        function view_path(obj,~,~)
            obj.assert(~isempty(obj.paths),'No paths!')
            f = figure('name',mfilename,'IntegerHandle','off','menu','none',...
                'toolbar','none','visible','off','units','characters');
            left = uicontrol(f,'style','listbox','units','normalized','string',{obj.paths.name},...
                'position',[0 0 0.5 1],'callback',@obj.update_view,'value',1);
            right = uicontrol(f,'style','listbox','units','normalized','position',[0.51 0 0.49 1]);
            left.UserData.right = right;
            obj.update_view(left);
            f.Visible = 'on';
        end
        function update_view(obj,hObj,~)
            val = hObj.Value;
            hObj.UserData.right.String = obj.get_string_instructions(obj.paths(val).instructions);
        end
        
        function path_selected_CB(obj,hObj,~)
            obj.select_path(hObj.Tag);
        end
        function new_alias_GUI(obj,varargin)
            default_name = '';
            if ~isempty(varargin)&&ischar(varargin{1})
                default_name = varargin{1};
            end
            assert(~isempty(obj.paths),'No paths!')
            f = figure('name','New Alias','IntegerHandle','off','menu','none',...
                'toolbar','none','visible','off','units','characters','resize','off');
            f.Units = 'characters';
            f.Position(3:4) = [50,10];
            
            spacing = 2.25;
            ui = uicontrol(f,'units','characters','style','text','string','Name:');
            ui.Position(2:3) = [spacing*3, ui.Extent(3)];
            name = uicontrol(f,'units','characters','style','edit','string',default_name,'horizontalAlignment','left');
            name.Position(1:3) = [sum(ui.Position([1,3]))+1,spacing*3,33];
            
            ui = uicontrol(f,'units','characters','style','text','string','Choose target path:');
            ui.Position(2:3) = [spacing*2, ui.Extent(3)];
            target = uicontrol(f,'units','characters','style','popup','string',{obj.paths.name});
            target.Position(1:3) = [sum(ui.Position([1,3]))+1,spacing*2,20];
            
            ui = uicontrol(f,'units','characters','style','pushbutton','string','Cancel','callback','closereq');
            ui.Position(1:2) = [20,spacing];
            ui = uicontrol(f,'units','characters','style','pushbutton','string','OK','callback','uiresume');
            ui.Position(2) = spacing;
            f.Visible = 'on';
            uiwait(f);
            if ~isvalid(f); return; end % aborted
            obj.new_path(name.String,target.String{target.Value});
            delete(f);
        end
        function new_path_GUI(obj,varargin)
            default_name = '';
            if ~isempty(varargin)&&ischar(varargin{1})
                default_name = varargin{1};
            end
            name = inputdlg('Name:','New Path: Name',[1 75],{default_name});
            if isempty(name) % User aborted, no worries
                return
            end
            name = name{1};
            obj.validate_name(name);
            f = figure('name',sprintf('Instructions for "%s": Select instruction type',name),'IntegerHandle','off','menu','none',...
                'toolbar','none','visible','off','units','characters');
            f.UserData.uiwait = false;
            [lbox,ok] = listbox(f,'OK','string',{},'min',0,'max',0);
            delete(ok)
            % Get module (optional)
            for i = 1:length(obj.module_types)
                package = ['+' Modules.(obj.module_types{i}).modules_package];
                mod_name = strsplit(obj.module_types{i},'.'); mod_name = mod_name{end};
                parent_menu = uimenu(f,'Text',mod_name);
                Base.Manager.getAvailModules(package,parent_menu,@obj.selected,@(~)false);
            end
            uimenu(f,'Text','Function (no module)','callback',@obj.selected,'tag','','UserData','');
            f.UserData.module = '';
            
            instructions = struct('module_name',{},'module_inputs',{},'method_name',{},'method_inputs',{});
            while true
                temp = obj.UIgetInstruction(f);
                if ~isempty(temp)
                    instructions(end+1) = temp;
                end
                if ~isvalid(f) % User aborted
                    return
                end
                % Update listbox strings
                lbox.String = obj.get_string_instructions(instructions);
                answer = questdlg('Add another instruction?',mfilename,'Yes','No','Yes');
                if ~strcmp('Yes',answer)
                    break
                end
            end
            delete(f);
            if ~isempty(instructions)
                obj.new_path(name,instructions)
            end
        end
        function instruction = UIgetInstruction(obj,f)
            instruction = [];
            try
                f.UserData.module = ''; % Reset
                uiwait(f);
                if ~isvalid(f)||isempty(f.UserData) % User aborted, no worries
                    return
                end
                module_name = f.UserData.module;
                
                % Get module/function name and inputs
                module_inputs = {};
                method_inputs = {};
                if ~isempty(module_name) % Module stuff
                    % Modules might need module input too
                    mc = meta.class.fromName(module_name);
                    ind = cellfun(@(a)strcmp(a,'instance'),{mc.MethodList.Name});
                    m_instance = mc.MethodList(ind);
                    if ~isempty(m_instance.InputNames) % Only if input
                        module_inputs = inputdlg(m_instance.InputNames,'Module instance arguments (MATLAB expression!!)',[1 75]);
                        if isempty(module_inputs) % User aborted, no worries
                            return
                        end
                        % Convert to strings and numbers as necessary
                        module_inputs = cellfun(@eval,module_inputs,'UniformOutput',false);
                    end
                    
                    % Now get method name
                    f = figure('name','Select Method','IntegerHandle','off','menu','none',...
                        'toolbar','none','visible','off','units','characters');
                    f.Position(3) = 50;
                    ind = cellfun(@(a)~iscell(a)&&strcmp(a,'public'),{mc.MethodList.Access}); % Cell if specific access granted (i.e. not public)
                    avail_methods = mc.MethodList(ind);
                    lbox = listbox(f,'OK','string',{avail_methods.Name});
                    if ~isvalid(f) % User aborted, no worries
                        return
                    end
                    m_method = avail_methods(lbox.Value);
                    delete(f);
                    method_name = m_method.Name;
                    
                    % Get method inputs
                    inp_names = m_method.InputNames;
                    if ~m_method.Static
                        inp_names = m_method.InputNames(2:end); % Ignore obj
                    end
                    method_inputs = inputdlg(inp_names,sprintf('Module %s arguments (MATLAB expression!!)',method_name),[1 75]);
                    if isempty(method_inputs) % User aborted, no worries
                        return
                    end
                    % Convert to strings and numbers as necessary
                    method_inputs = cellfun(@eval,method_inputs,'UniformOutput',false);
                else % Function stuff
                    method_call = inputdlg({'Function; e.g. pause(1):'},'Function Call');
                    if isempty(method_call) % User aborted, no worries
                        return
                    end
                    method_call = method_call{1};
                    % Clever parse strategy to offload work to MATLAB
                    % Replace first and last parenthesis with cell bracket and eval it
                    inds = find(or(method_call=='(',method_call==')'));
                    if ~any(inds) % assume no inputs
                        method_name = method_call;
                    else
                        method_name = method_call(1:inds(1)-1);
                        method_inputs = eval(sprintf('{%s}',method_call(inds(1)+1:inds(end)-1)));
                    end
                end
                temp.module_name = module_name;
                temp.module_inputs = module_inputs;
                temp.method_name = method_name;
                temp.method_inputs = method_inputs;
                instruction = temp;
            catch err
                obj.error(err.message,err.stack); % Does not hault execution
            end
        end
        function selected(obj,hObj,~) % Nested method instead of module method; just needs local stuff
            [~,fig] = gcbo;
            fig.UserData.module = hObj.UserData;
            uiresume(fig);
        end
        function remove_path_CB(obj,hObj,eventdata)
            f = figure('name','Select Paths to Remove','IntegerHandle','off','menu','none',...
                'toolbar','none','visible','off','units','characters');
            f.Position(3) = 50;
            paths_names = {obj.paths.name};
            lbox = listbox(f,'OK','string',paths_names);
            if ~isvalid(f) % User aborted, no worries
                return
            end
            try
                cellfun(@(name)obj.remove_path(name),paths_names(lbox.Value));
            catch err
                delete(f);
                obj.error(err)
            end
            delete(f);
        end
    end
end