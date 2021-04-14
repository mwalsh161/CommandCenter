classdef Module < Base.Singleton & Base.PrefHandler & matlab.mixin.Heterogeneous
    %MODULE Abstract Class for Modules.
    %   Simply enforces required properties.
    %
    %   All module managers will look for an optional invisible property (must be constant).
    %   If this exists, and is set to true, it will not render it in the
    %   menus.
    %
    %   If there is a Constant property "visible" and it is set to false,
    %   this will prevent CommandCenter from displaying it.
    
    properties(Access=private)
        prop_listeners              % Keep track of preferences in the GUI to keep updated
    end
    properties(Access=protected)
        module_delete_listener      % Used in garbage collecting
    end
    properties(Abstract,Constant,Hidden)
        modules_package;
    end

    events
        update_settings % Listened to by CC to allow modules to request settings to be reloaded
    end

    methods(Static)
        [code,f] = uibuild(block,varargin)
    end
    methods
        function obj = Module()
        end
    end 
    methods(Sealed)
        function module_clean(obj,hObj,prop)
            to_remove = false(size(obj.(prop)));
            for i = 1:length(obj.(prop)) % Heterogeneous list; cant do in one line
                if obj.(prop)(i) == hObj
                    to_remove(i) = true;
                end
            end
            obj.(prop)(to_remove) = [];
        end
        function module_garbage_collect(obj,hObj,~)
            % Reset lifetime listeners
            mods = obj.(hObj.Name);
            to_remove = false(size(mods));
            % Reset listeners (easiest to go through cleanly each time
            delete(obj.module_delete_listener);
            obj.module_delete_listener = [];
            for i = 1:length(mods)
                if isvalid(mods(i))
                    l = addlistener(mods(i),'ObjectBeingDestroyed',@(modH,~)obj.module_clean(modH,hObj.Name));
                    if isempty(obj.module_delete_listener)
                        obj.module_delete_listener = l;
                    else
                        obj.module_delete_listener(end+1) = l;
                    end
                else
                    to_remove(i) = true;
                end
            end
            obj.(hObj.Name)(to_remove) = []; % Remove if not valid
        end
    end
    methods
        function delete(obj)
            warning(obj.StructOnObject_state,'MATLAB:structOnObject')
            obj.savePrefs;
            delete(obj.prop_listeners);
            delete(obj.module_delete_listener);
            hObject = findall(0,'name','CommandCenter');
            if isempty(hObject)
                return
            end
            mods = getappdata(hObject,'ALLmodules');
            obj.logger = getappdata(hObject,'logger');
            pos = 0;
            for i = 1:numel(mods)
                if mods{i}==obj
                    pos = i;
                end
            end
            if pos > 0
                mods(pos) = [];
                setappdata(hObject,'ALLmodules',mods)
            end
            obj.logger.log(['Destroyed ' class(obj)])
        end
        
        % Default inactive is nothing
        function task = inactive(obj)
            task = '';
        end
        
        function settings = get_settings(obj)
            % Override to change how settings are acquired
            % Must output cell array of strings
            % Order matters; first is on top, last is at the bottom.
            props = properties(obj);
            settings = {};
            if ismember('show_prefs',props)
                settings = obj.show_prefs;
            elseif ismember('prefs',props)
                settings = obj.prefs;
            end
            % Append any additional class-based prefs (no order)
            class_based = obj.get_class_based_prefs()';
            settings = [settings, class_based(~ismember(class_based,settings))];
        end

        % Adds custom settings to main GUI.
        %   This can be a simple settings button that opens a new GUI!
        %   Callbacks must be taken care of in the module.
        %   Module length can be adjusted, but not width.
        %   There are a few things to keep in mind when making these
        %   settings. If another program/command line alters a property in
        %   your settings, if you aren't careful, you will have an
        %   inconsitency and confusion will follow.
        %   See documentation for how the default settings works below
        function settings(obj,panelH,pad,margin)
            % panelH: handle to the MATLAB panel
            % pad: double; vertical distance in pixels to leave between UI elements
            % margin: 1x2 double; additional space in pixels to leave on [left, right]
            
            panelH.Units = 'pixels';
            try % Make backwards compatible (around 2017a I think)
                widthPx = panelH.('InnerPosition')(3);
            catch err
                if ~strcmp(err.identifier,'MATLAB:noSuchMethodOrField')
                    rethrow(err)
                end
                widthPx = panelH.('Position')(3);
                warning('CC:legacy',['Using a version of MATLAB that does not use "InnerPosition" for uipanel.',...
                                    'Consider upgrading if you notice display issues.'])
            end

            % Establish legacy read_only settings
            readonly_settings = {};
            props = properties(obj);
            if ismember('readonly_prefs',props)
                warning('CC:legacy',['"readonly_prefs" will override any class-based setting.',...
                        'Note that it is legacy and should be updated to readonly property in class-based prefs.'])
                readonly_settings = obj.readonly_prefs;
            end
            
            try
                setting_names = obj.get_settings();
            catch err
                error('Error fetching settings names:\n%s',getReport(err,'basic','hyperlinks','off'));
            end
            nsettings = length(setting_names);

            panelH_loc = pad;
            mps = cell(1,nsettings); % meta pref
            label_size = NaN(1,nsettings);
            % Build up, starting from end to beginning
            for i = nsettings:-1:1
                try
                    mp = obj.get_meta_pref(setting_names{i});
                catch err
                    warning('Skipped pref "%s":\n%s', setting_names{i}, err.message)
                    continue
                end
                if isempty(mp.name) % Default to setting (i.e. property) name
                    mp.name = strrep(setting_names{i}, '_', ' ');
                end
                if ismember(setting_names{i}, readonly_settings)
                    mp.readonly = true; % Allowing readonly_prefs to override
                end
                
                % Make UI element and add to panelH (note mp is not a handle class)
                [mp,height_px,label_size(i)] = mp.make_UI(panelH, panelH_loc, widthPx, margin);
                mp = mp.link_callback(@obj.settings_callback);
                panelH_loc = panelH_loc + height_px + pad;
                mps{i} = mp;
                %obj.set_meta_pref(setting_names{i},mp);
%                 try
                    mp.set_ui_value(mp.value); % Update to current value
%                 catch err
%                     warning(err.identifier,'Failed to set pref "%s" to value of type "%s":\n%s',...
%                         setting_names{i},class(mp.value),err.message)
%                 end
            end
            max_label_width = widthPx/2;
            suggested_label_width = max(label_size(label_size < max_label_width)); % px
            if isempty(suggested_label_width)
                suggested_label_width = max_label_width;
            end
            lsh = Base.PrefListener.empty;
            if ~isnan(suggested_label_width) % All must have been NaN for this to be false
                for i = 1:nsettings
                    if ~isnan(label_size(i)) % no error in fetching mp
                        mps{i}.adjust_UI(suggested_label_width, margin);
                        obj.set_meta_pref(setting_names{i},mps{i});
                        lsh(end+1) = addlistener(obj,setting_names{i},'PostSet',@(el,~)obj.settings_listener(el,mps{i}));
                    end
                end
            end
            addlistener(panelH,'ObjectBeingDestroyed',@(~,~)delete(lsh)); % Clean up listeners
        end
        function settings_callback(obj,~,~,mp)
            obj.pref_set_try = true;  % try block for validation
            try % try block for retrieving UI value
                obj.(mp.property_name) = mp.get_validated_ui_value();
                err = obj.last_pref_set_err; % Either [] or MException
            catch err % MException if we get here
            end
            
            % set method might notify "update_settings"
            mp = obj.get_meta_pref(mp.property_name);
            obj.pref_set_try = false; % "unset" try block for validation to route errors back to console
            try
                mp.set_ui_value(obj.(mp.property_name)); % clean methods may have changed it
            catch err
                error('MODULE:UI',['Failed to (re)set value in UI. ',... 
                       'Perhaps got deleted during callback? ',...
                       'You can click the settings refresh button to try and restore.',...
                       '\n\nError:\n%s'],err.message)
                % FUTURE UPDATE: make this an errordlg instead, and
                % provide a button to the user in the errordlg figure to
                % reload settings.
            end
            
            if ~isempty(err) % catch for both try blocks: Reset to old value and present errordlg
                try
                    val_help = mp.validationSummary(obj.PrefHandler_indentation);
                catch val_help_err
                    val_help = sprintf('Failed to generate validation help:\n%s',...
                        getReport(val_help_err,'basic','hyperlinks','off'));
                end
                errmsg = err.message;
                % Escape tex modifiers
                val_help = strrep(val_help,'\','\\'); errmsg = strrep(errmsg,'\','\\');
                val_help = strrep(val_help,'_','\_'); errmsg = strrep(errmsg,'_','\_');
                val_help = strrep(val_help,'^','\^'); errmsg = strrep(errmsg,'^','\^');
                opts.WindowStyle = 'non-modal';
                opts.Interpreter = 'tex';
                errordlg(sprintf('%s\n\\fontname{Courier}%s',errmsg,val_help),...
                    sprintf('%s Error',class(mp)),opts);
            end
        end
        function settings_listener(obj,el,mp)
            mp.set_ui_value(obj.(el.Name));
        end
    end
end
