classdef ModuleSelectionField < Base.Input
    %MODULESELECTIONFIELD provides UI to choose modules and access their settings
    %   If a module gets deleted, it will turn red in the dropdown but will not
    %   be removed.
    %   When removing a module, that module is returned in the eventdata of the
    %   callback, but is not deleted.
    %   When adding a module, if it seems (from the metaclass) that input is
    %   necessary, the user will be prompted to help in the construction.

    properties
        label = gobjects(1);
        selection = gobjects(1);
        buttons = gobjects(1,3);
        empty_val = '<None>';
        % Specify which set of Modules to use (must match file in Modules package (e.g. +Modules/))
        module_types = {'Experiment','Stage','Imaging','Source','Database','Driver'};
        readonly = false;  % Modified in make_UI
    end

    methods % Helpers
        function strings = get_module_strings(obj, modules)
            strings = arrayfun(@obj.get_module_string, modules,'uniformoutput',false);
            if isempty(strings)
                strings = {obj.empty_val};
            end
        end
        function string = get_module_string(~,module)
            string = class(module);
        end
        function module = build_module(~,module_name)
            mc = meta.class.fromName(module_name);
            assert(length(mc) == 1,...
                sprintf('Could not find single "%s" on path (found %i)',module_name,length(mc)));
            shortname = strsplit(module_name,'.'); shortname = shortname{end};
            mconstructor = mc.MethodList(strcmp({mc.MethodList.Name},shortname));
            minstance = mc.MethodList(strcmp({mc.MethodList.Name},'instance'));
            assert(length(mconstructor) == 1,...
                sprintf('Could not find constructor "%s" (found %i)',shortname,length(mconstructor)));
            assert(length(minstance) == 1,...
                sprintf('Could not "%s.instance" (found %i)',shortname,length(minstance)));
            if isempty(minstance.InputNames)
                module = eval(sprintf('%s.instance',module_name));
            else
                help_text = ['InputArguments seem to be required:' newline ...
                             '  ' module_name '.instance( ' strjoin(minstance.InputNames, ', ')  ' )' newline ...
                             '  ' module_name '.' shortname '( ' strjoin(mconstructor.InputNames, ', ')  ' )' newline];
                inputs = inputdlg([help_text newline,...
                    'Type a valid MATLAB expression (will be evaluated in base workspace) for part between arg parethesis:'],...
                    ['Building ' module_name]);
                assert(~isempty(inputs),'User cancelled input entry.');
                module = evalin('base',sprintf('%s.instance(%s)',module_name,inputs{1}));
            end
        end
        function user_callback(obj,action,module,ind)
            % We will use the selection UI as the "caller" and an eventdata
            % struct with fields:
            %   action: "add" or "rm"
            %   ind: index of affected module in obj.selection.objects
            %   module: the module that was add or removed
            if ~isempty(obj.selection.UserData.callback)
                switch class(obj.selection.UserData.callback)
                    case 'cell'
                        obj.selection.UserData.callback{1}(obj.selection,...
                            struct('action',action,'module',module,'ind',ind),...
                            obj.selection.UserData.callback{2:end});
                    case 'function_handle'
                        obj.selection.UserData.callback(obj.selection,...
                            struct('action',action,'module',module,'ind',ind));
                end
            end
        end
    end
    methods
        function obj = set.module_types(obj,val)
            assert(iscell(val) & all(cellfun(@(a)ischar(a)&isvector(a),val)),...
                '"module_typess" must be a cell array of char vectors.')
            for i = 1:length(val)
                try
                    Modules.(val{i}).modules_package;
                catch err
                    error('Could not load "%s" with a constant property "modules_package"',val{i})
                end
            end
            obj.module_types = val;
        end
        function tf = isvalid(obj)
            tf = isgraphics(obj.label) && isvalid(obj.label);
        end
        function [obj,height_px,label_width_px] = make_UI(obj,pref,parent,yloc_px,width_px,margin)
            % Line 1: Label
            % Line 2: popupmenu
            % Line 3: add/remove/settings buttons
            % Prepare/format values
            obj.readonly = pref.readonly;
            obj.empty_val = pref.empty_val;
            label_width_px = 0;
            pad = 5; % px between lines
            tag = strrep(pref.name,' ','_');
            labeltext = pref.name;
            enabled = 'on';
            if obj.readonly
                enabled = 'off';
            end
            if ~isempty(pref.unit)
                labeltext = sprintf('%s [%s]', pref.name, pref.unit);
            end
            % Line 3
            height_px = 0;
            obj.buttons(1) = uicontrol(parent, 'style', 'pushbutton',...
                            'string', 'Add', 'units', 'pixels',...
                            'tag', [tag '_add'],...
                            'enable', enabled); % Only controlled here
            obj.buttons(2) = uicontrol(parent, 'style', 'pushbutton',...
                            'string', 'Remove', 'units', 'pixels',...
                            'tag', [tag '_remove'],...
                            'Tooltip','Selected module (above)',...
                            'enable','off');
            obj.buttons(3) = uicontrol(parent, 'style', 'pushbutton',...
                            'string', 'Settings', 'units', 'pixels',...
                            'tag', [tag '_settings'],...
                            'Tooltip','For selected module (above)',...
                            'enable','off');
            obj.buttons(1).Position(2) = yloc_px;
            obj.buttons(2).Position(2) = yloc_px;
            obj.buttons(3).Position(2) = yloc_px;
            height_px = obj.buttons(1).Extent(4) + pad;
            % Line 2
            obj.selection = uicontrol(parent, 'style', 'popupmenu',...
                        'String', {obj.empty_val},...
                        'horizontalalignment','left',...
                        'units', 'pixels',...
                        'tag', tag,...
                        'UserData', struct('objects',Base.Module.empty(0),'callback',[]));
            obj.selection.Position(2) = yloc_px + height_px;
            height_px = height_px + obj.selection.Extent(4) + pad;
            % Line 1
            obj.label = uicontrol(parent, 'style', 'text',...
                        'string', [labeltext ': '],...
                        'horizontalalignment', 'right',...
                        'units', 'pixels',...
                        'tag', [tag '_label']);
            obj.label.Position(2) = yloc_px + height_px;
            height_px = height_px + obj.label.Position(4);

            if ~isempty(pref.help_text)
                set(obj.label, 'Tooltip', pref.help_text);
            end
        end
        function obj = link_callback(obj,callback)
            assert(isa(callback,'function_handle')||iscell(callback),...
                sprintf('%s only supports function handle or cell array callbacks (received %s).',...
                mfilename,class(callback)));
            obj.selection.UserData.callback = callback;
            obj.selection.Callback = @obj.update_buttons;
            obj.buttons(1).Callback = @obj.add_module;
            obj.buttons(2).Callback = @obj.rm_module;
            obj.buttons(3).Callback = @obj.module_settings;
        end
        function obj = adjust_UI(obj, suggested_label_width, margin)
            % Position UI elements on separate lines from bottom up
            total_width = obj.label.Parent.Position(3);
            indent = 2*margin(1);
            if all(isgraphics(obj.buttons))
                pad = 5; % pixels between buttons
                btn_wid = (total_width - indent - margin(2) - pad*2)/3;
                for i = 1:3
                    obj.buttons(i).Position(1) = indent + (btn_wid + pad)*(i-1);
                    obj.buttons(i).Position(3) = btn_wid;
                end
            end
            obj.label.Position(1) = margin(1);
            obj.label.Position(3) = suggested_label_width;
            obj.selection.Position(1) = indent;
            obj.selection.Position(3) = total_width - indent - margin(2);
            if any(obj.label.Extent(3:4) > obj.label.Position(3:4))
                help_text = get(obj.label, 'Tooltip');
                set(obj.label, 'Tooltip',...
                    ['<html>' obj.label.String(1:end-2) '<br/>' help_text(7:end)]);
            end
        end
        function set_value(obj,val)
            if isempty(val)
                obj.selection.Value = 1;
                obj.selection.String = {obj.empty_val};
                obj.selection.UserData.objects = Base.Module.empty(0);
            else
                obj.selection.String = get_module_strings(obj, val(:));
                obj.selection.UserData.objects = val(:);
                nval = numel(val);
                if obj.selection.Value > nval
                    obj.selection.Value = nval;
                end
                % Add deleted listeners
                lsh = Base.PrefListener.empty;
                for i = 1:nval
                    lsh(end+1) = addlistener(val(i),'ObjectBeingDestroyed',@obj.module_deleted);
                end
                addlistener(obj.selection,'ObjectBeingDestroyed',@(~,~)delete(lsh)); % Clean up listeners
            end
            obj.update_buttons;
        end
        function val = get_value(obj)
            val = obj.selection.UserData.objects;
        end
    end

    methods(Hidden) % Callbacks
        function update_buttons(obj,varargin) % obj.selection callback (and direct call)
            % Extra check for readonly for buttons 1 and 2. Settings (3) is
            % always ok to change even if readonly
            if isempty(obj.selection.UserData.objects)
                obj.buttons(2).Enable = 'off';
                obj.buttons(3).Enable = 'off';
            else
                ind = obj.selection.Value;
                if isvalid(obj.selection.UserData.objects(ind))
                    if ~obj.readonly
                        obj.buttons(2).Enable = 'on';
                    end
                    obj.buttons(3).Enable = 'on';
                else
                    if ~obj.readonly
                        obj.buttons(2).Enable = 'on'; % You can remove it still
                    end
                    obj.buttons(3).Enable = 'off';
                end
            end
        end
        function module_deleted(obj,hObj,eventdata) % listener callback
            % Turn that text red
            objects = obj.selection.UserData.objects;
            inds = find(~arrayfun(@isvalid,objects));
            for i = inds
                % Listener deleted with module means can only get called once per module
                obj.selection.String{i} = sprintf('<HTML><FONT COLOR="red">%s</HTML>',...
                    obj.selection.String{i});
            end
            obj.update_buttons;
        end
        function add_module(obj,hObj,eventdata) % obj.button(1) callback
            f = figure('name','Select Module','IntegerHandle','off','menu','none','HitTest','off',...
                'toolbar','none','visible','off','units','characters','resize','off');
            % Determine length needed
            nmenus = length(obj.module_types);
            lenmenu = 0;
            for i = 1:nmenus
                temp = uicontrol(f,'units','characters','style','text','string',obj.module_types{i});
                lenmenu = lenmenu + temp.Extent(3);
                delete(temp);
            end
            f.Position(3:4) = [lenmenu*1.5 ,0];
            for i = 1:nmenus
                parent_menu = uimenu(f,'Text', obj.module_types{i});
                package = ['+' Modules.(obj.module_types{i}).modules_package];
                Base.Manager.getAvailModules(package,parent_menu,@obj.selected,@(~)false);
            end
            f.Visible = 'on';
            uiwait(f); % Let user select
            if ~isvalid(f) % User aborted/closed
                return
            end
            module_name = f.UserData;
            delete(f);
            module = obj.build_module(module_name);
            % Update UI when/if module successfully built
            ind = length(obj.selection.UserData.objects) + 1;
            obj.selection.UserData.objects(ind) = module;
            obj.selection.String{ind} = obj.get_module_string(module);
            obj.selection.Value = ind;
            obj.update_buttons;
            obj.user_callback('add',module,ind);
        end
        function selected(~,hObj,~) % Callback from obj.add_module upon choosing
            [~,fig] = gcbo;
            fig.UserData = hObj.UserData;
            uiresume(fig);
        end
        function rm_module(obj,hObj,eventdata) % obj.button(2) callback
            if isempty(obj.selection.UserData.objects)
                error('No module selected.')
            end
            ind = obj.selection.Value;
            module = obj.selection.UserData.objects(ind);
            obj.selection.UserData.objects(ind) = [];
            % Regenerate to cover edge cases of removing all
            obj.selection.String = obj.get_module_strings(obj.selection.UserData.objects);
            nval = length(obj.selection.UserData.objects);
            if ind > nval
                obj.selection.Value = max(1,nval);
            end
            obj.update_buttons;
            obj.user_callback('rm',module,ind);
        end
        function module_settings(obj,hObj,eventdata) % obj.button(3) callback
            if isempty(obj.selection.UserData.objects)
                error('No module selected.')
            end
            % Grab instance and call settings
            ind = obj.selection.Value;
            module = obj.selection.UserData.objects(ind);
            module_str = obj.get_module_string(module);
            f = figure('name',sprintf('%s Settings (close when done)',module_str),'IntegerHandle','off','menu','none',...
                'toolbar','none','visible','off','units','pixels','resize','off','HitTest','off');
            f.Position(3) = 500;
            panel = uipanel(f);
            try
                module.settings(panel,5,[20, 20]);
            catch err
                delete(f)
                errordlg(sprintf('Failed to get settings for "%s":\n%s',module_str,getReport(err,'basic','hyperlinks','off')),...
                    sprintf('%s Settings',module_str));
                return
            end
            child = allchild(panel);
            if isempty(child)
                child = uicontrol(panel,'style','text','String','No settings implemented!');
                child.Position(3) = child.Extent(3);
            end
            nchild = length(child);
            set(child,'units','pixels');
            positions = [0, NaN(1,nchild)]; % 0, bottom1, top1, bottom2, top2, ...
            for i = 1:nchild
                contents_pos = get(child(i),'position');
                positions(2*i-1) = contents_pos(2);
                positions(2*i) = positions(2*i-1) + contents_pos(4);
            end
            bottom = min(positions);
            top = max(positions);

            f.Position(4) = top;
            panel.Position(3:4) = f.Position(3:4);
            f.Position(2) = 100;
            f.Visible = 'on';
        end
    end

end
