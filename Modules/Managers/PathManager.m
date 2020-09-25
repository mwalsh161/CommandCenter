classdef PathManager < Base.Manager
    % This will handle different paths that are configured
    % PathManager_instance.select_path(obj,name,prompt,update_active)
    %
    %   Configuration:
    %       1) Choose module (can be empty for regular function call, e.g. if necessary to call pause)
    %       2) Provide inputs necessary to load module
    %       3) Choose method in module
    %       4) Provide inputs necessary to call method for desired path
    %   A path can also be an alias for another path by declaring it. Note,
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
    %   obj.new_path_GUI([default_name])
    %   obj.new_alias_GUI([default_name])
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
        paths = struct('name',{},'alias',false,'instructions','');  % Path struct (will change upon adding/deletion)
        active_path = '';    % Active path name (will change upon path selection). Empty if unknown.
    end
    properties(SetAccess=private,Hidden)
        temp_file = '';    % Set in constructor
    end
    properties
        module_types = {};
    end

    methods
        function obj = PathManager(handles)
            obj = obj@Base.Manager('Paths',handles); % "Simple" manager
            base = fileparts(mfilename('fullpath'));
            obj.temp_file = fullfile(base,'temp','PathTransition.m');
            if ~isfolder(fullfile(base,'temp'))
                mkdir(base,'temp');
            end
            obj.prefs = [obj.prefs {'paths'}];
            % Grab all classes in Modules package
            [~,obj.module_types,~] = Base.GetClasses('+Modules');
            % Add menu to CommandCenter and tie in some callbacks
            uimenu(handles.figure1,'Text','Path',...
                'Callback',@obj.menu_open_CB,'tag',[mfilename '_menu']);
            obj.loadPrefs;
            
            % Backwards compatibility; check for old style
            if ~isfield(obj.paths,'alias')
                temp = obj.paths;
                if ~isempty(temp) % Avoid dissimilar structs in updating
                    temp(1).alias = false;
                end
                for i = 1:length(temp)
                    temp(i) = obj.update_path(temp(i));
                end
                obj.paths = temp;
            end
        end
        % Functional methods
        function validate_name(obj,name)
            obj.assert(~isempty(name),'Name cannot be empty (reserved for unknown path)');
            map = ismember({obj.paths.name},name);
            obj.assert(~any(map),'Path with this name already exists, remove it and try again.');
        end
        function new_path(obj,name,instructions,alias)
            % obj.new_path('foo','drawnow;',[false]); % new instruction "foo"
            % obj.new_path('foo','bar',true); % alias to path "bar"
            if nargin < 4
                alias = false;
            end
            obj.assert(islogical(alias)&&isscalar(alias),'"alias" flag should be a scalar logical.');
            obj.assert(ischar(instructions),'Instructions should be a char vector.')
            obj.validate_name(name);
            if alias % Alias (validate target)
                map = ismember({obj.paths.name},instructions);
                obj.assert(any(map),'The target path for this alias does not exist.');
            end
            new_path = struct('name',name,'instructions',instructions,'alias',alias);
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
                update_active = true;
            end
            % Check to see if exists
            if isempty(obj.paths)
                return
%                 obj.error(sprintf('Attempted to select "%s", but there are currently no paths defined.',name),true);

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
                return;
                obj.error(sprintf('No path found by name "%s"',name),true);
            end
            
            path = obj.paths(map);
            if isequal(path.name,obj.active_path); return; end
            if path.alias % Alias
                % Error handling here for better error message (try/catch
                % wont work with manager error handling
                map = ismember({obj.paths.name},path.instructions);
                obj.assert(any(map),sprintf('The target path for this alias does not exist: "%s"',path.instructions));
                obj.select_path(path.instructions,prompt,false);
                obj.active_path = name;
                return
            end
            try % to set path
                if ~isempty(path.instructions)
                    evalc(path.instructions);
                end
            catch err
                obj.active_path = '';
                obj.error(sprintf('Error in setting path "%s":\n\n%s',path.name,err.message),err)
            end
            if update_active
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
            f = figure('name',[mfilename '(right click for more options)'],...
                'IntegerHandle','off','menu','none','toolbar','none','units','characters');
            left = uicontrol(f,'style','listbox','units','normalized','string',{obj.paths.name},...
                'position',[0 0 0.5 1],'callback',@obj.update_view,'value',1);
            right = uicontrol(f,'style','listbox','units','normalized','position',[0.51 0 0.49 1]);
            c = uicontextmenu(f);
            uimenu(c,'Label','Edit path','callback',{@obj.edit_path_view_path_CB,left});
            uimenu(c,'Label','Delete path','callback',{@obj.delete_path_view_path_CB,left});
            left.UIContextMenu = c;
            right.UIContextMenu = c;
            left.UserData.right = right;
            obj.update_view(left);
        end
        function update_view(obj,hObj,~)
            % hObj -> left panel
            val = hObj.Value;
            if val > 0
                if obj.paths(val).alias
                    hObj.UserData.right.String = {'alias',sprintf('---> %s',obj.paths(val).instructions)};
                else
                    hObj.UserData.right.String = strsplit(obj.paths(val).instructions,newline);
                end
            else
                hObj.UserData.right.String = '';
            end
        end
        function delete_path_view_path_CB(obj,~,~,left)
            path = obj.paths(left.Value).name;
            obj.remove_path(path);
            if isempty(obj.paths)
                delete(left.Parent); % Close figure (no more paths to view)
                return
            end
            left.String = {obj.paths.name};
            left.Value = min(length(obj.paths),left.Value); % Keep in bounds
            obj.update_view(left);
        end
        function edit_path_view_path_CB(obj,~,~,left)
            I = left.Value;
            path = obj.paths(I);
            if path.alias
                obj.error('Currently no support for editing an alias :(');
                return
            end
            pre = ['% Edit code for "' path.name '"' newline,...
                   '%     You can use CommandCenter''s "**" menu to help with modules' newline];
            [path.instructions,~] = uigetcode(obj.temp_file,path.name,pre,'',path.instructions,false);
            obj.paths(I) = path;
            obj.update_view(left);
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
            obj.new_path(name.String,target.String{target.Value},true);
            delete(f);
        end
        function new_path_GUI(obj,varargin)
            default_name = 'PATH_NAME';
            if ~isempty(varargin)&&ischar(varargin{1})
                default_name = varargin{1};
            end
            code = '';
            lock_name = false;
            while true
                % Prepare code for path
                pre = ['% Write the relevant code to transition to relevant path.' newline,...
                       '% The function name will become the path name.', newline,...
                       '%     You can use CommandCenter''s File->"Build Module UI" tool to help' newline];
                [code,name] = uigetcode(obj.temp_file,default_name,pre,'',code,~lock_name);
                if isempty(code) && strcmp(name,'PATH_NAME') % Silenty fail
                    return
                elseif strcmp(name,'PATH_NAME')
                    resp = questdlg('Did you mean to keep the "PATH_NAME" default name?',mfilename,'Yes','No','No');
                    if strcmp(resp,'Yes')
                        break
                    end
                else
                    break
                end
            end
            % Save
            if ~isempty(code)
                obj.new_path(name,code,false)
            else
                warndlg('Empty code block; no new path was made.',mfilename);
            end
        end
        function remove_path_CB(obj,varargin)
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
    
    methods(Static,Hidden)
        function path = update_path(path)
            % Exclusively used for backwards compatibility
            if ischar(path.instructions)
                alias = true;
                instructions = path.instructions;
            else
                alias = false;
                instructions = strjoin(PathManager.get_string_instructions(path.instructions),newline);
                suspects = strfind(instructions,'??');
                suspects = [suspects-1 suspects+2]; % check before and after
                dblcheck = false;
                for i = 1:length(suspects)
                    if instructions(suspects(i)) ~= '''' && instructions(suspects(i)) ~= '"' % single or double quote
                        dblcheck = true;
                        break
                    end
                end
                if dblcheck
                    % Even if false positive, worth checking
                    temp_file = fullfile(fileparts(mfilename('fullpath')),'temp','transition.m');
                    pre = ['% PathManger is trying to update your path instructions to the new,',...
                           '% plain-code format. There was an issue updating "' path.name '".',...
                           '% Edit the attempted update to be correct.' newline,...
                           '%     You can use CommandCenter''s "**" menu to help with modules' newline];
                    [instructions,~] = uigetcode(temp_file,path.name,pre,'',instructions,false);
                end
            end
            path.alias = alias;
            path.instructions = instructions;
        end
        function instruction_strings = get_string_instructions(instructions)
            % Now exclusively used for backwards compatibility
            instruction_strings = {};
            if isstruct(instructions)
                for i = 1:length(instructions)
                    narin = length(instructions(i).method_inputs);
                    method_inputs = cell(1,narin);
                    for j = 1:narin
                        method_inputs{j} = PathManager.format_instruction_inputs(instructions(i).method_inputs{j});
                    end
                    if ~isempty(instructions(i).module_name) % Module method
                        narin = length(instructions(i).module_inputs);
                        module_inputs = cell(1,narin);
                        for j = 1:narin
                            module_inputs{j} = PathManager.format_instruction_inputs(instructions(i).module_inputs{j});
                        end
                        % Instantiate into variable
                        instruction_strings{end+1} = sprintf('a = %s.instance(%s)',...
                            instructions(i).module_name,...
                            strjoin(module_inputs,', '));
                        % Then call method
                        instruction_strings{end+1} = sprintf('a.%s(%s)',...
                            instructions(i).method_name,...
                            strjoin(method_inputs,', '));
                    else % Function
                        instruction_strings{end+1} = sprintf('%s(%s)',...
                            instructions(i).method_name,...
                            strjoin(method_inputs,', '));
                    end
                end
            else
                error('Instructions are in the wrong format.')
            end
        end
        function fmt = format_instruction_inputs(input)
            % Now exclusively used for backwards compatibility
            if isnumeric(input)
                fmt = ['[' num2str(input) ']'];
            elseif ischar(input)
                fmt = ['''' input ''''];
            elseif iscell(input)
                fmt = '??';
            else
                fmt = '??';
            end
        end
    end
end
