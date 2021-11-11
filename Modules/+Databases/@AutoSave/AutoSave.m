classdef AutoSave < Modules.Database
    %AUTOSAVE Saves data structures to file system with predefined format.
    %   Can override file name with the last input in SaveExp
    %   The PreviousImageViewer will look back through this sessions
    %       images. Should be robust to crashes (as long as obj.delete
    %       isn't called)!
    %         It is a mat file with each image a separate variable in the
    %         format of a#.
    %   Behavior with experiment force_save:
    %       If an experiment module has a public boolean property
    %       "first_save", when true, AUTOSAVE will make a folder instead of
    %       a file using formatspec. When false, the last folder created by
    %       AUTOSAVE will be used and files will still use formatspec
    %       within this folder.
    %       If the folder doesn't exist, it will treat as the first_save
    %       and issue a warning.
    %       This is not persistent through reloading AUTOSAVE.
    %       Appends "_\i" if none used in format spec to prevent data loss
    %       This is not super intelligent.
    %           Deleting a folder mid experiment results in an error just
    %             as if you specified an incorrect path.
    %           Not setting force_save correctly will likely result in an
    %             error (if module loaded and never saw force_save true) or
    %             saving to an incorrect folder (the last one it saw
    %             force_save true).
    %
    %   formatspec - {Image,Experiment}
    %       Do not include the file extension.
    %       \mod will be evaluated before \m
    %       \date will be evaluated before \d
    %       Available special characters:
    %           \mod - module name (with . replaced with _)
    %           \y - year   (4 digits)
    %           \m - month  (2 digits)
    %           \d - day    (2 digits)
    %           \h - hour   (2 digits), 24 cycle
    %           \M - minute (2 digits)
    %           \s - second (2 digits)
    %           \date - \y_\M_\d
    %           \time - \h_\m_\s
    %           \i - integer (will find lowest integer that does not
    %                exist in directory, starting from 0) NOTE: This is
    %                evaluated last
    
    properties(SetAccess=private)
        autosave = true;    % Save everytime without user
    end
    properties(SetObservable,AbortSet)
        im_dir_last = '';   % If inactivity reset, remember where to still!
        im_dir = '';        % drive/im_dir is where images are saved.
        last_im_fname = ''; % Last filename for use in Diamondbase
        exp_dir_last = '';   % If inactivity reset, remember where to still!
        exp_dir = '';       % drive/exp_dir is where experiment data is saved.
        last_exp_fname = '';% Last filename for use in Diamondbase
        im_enable = true;   % Enabled for image autosave
        exp_enable = true;  % Enabled for experiments
        n_history = 100;    % Limit size of DB (on delete)
        formatspec = {'Image\date_\time',...
                      '\mod-\date_\time'};    % File name format spec {Image, Experiment}
        first_save_rel_path = ''; % Relative path from exp_dir if force_save used in experiment
        prefs = {'im_dir','exp_dir','im_enable','exp_enable','n_history','formatspec'};
    end
    properties(Access=private)
        prop_listeners;     % Keep track of preferences in the GUI to keep updated
    end
    properties(Constant)
        default_formatspec = {'Image\date_\time',...
                      '\mod\date_\time'};    % To reset
        formatstrHelp = ['Available special characters:\n'...
                         '    \\mod - module name (with . replaced with _)\n'...
                         '    \\y - year   (4 digits)\n'...
                         '    \\m - month  (2 digits)\n'...
                         '    \\d - day    (2 digits)\n'...
                         '    \\h - hour   (2 digits), 24 cycle\n'...
                         '    \\M - minute (2 digits)\n'...
                         '    \\s - second (2 digits)\n'...
                         '    \\date - \\y_\\M_\\d\n'...
                         '    \\time - \\h_\\m_\\s\n'...
                         '    \\i - integer (will find lowest integer that does not\n'...
                         '         exist in directory, starting from 0)\n\n',...
                         '->Do not include the file extension.\n'...
                         '->\\mod will be evaluated before \\m\n'...
                         '->\\date will be evaluated before \\d\n'...
                         '->\\i is evaluated last, so if another special character\n',...
                         '  changes the filename to be unique, i will go back to 0!'];
    end
    properties(Access=private)
        gui_spec               % Handle to formatspec edit boxes in GUI settings
        previousImagesDB = ''; % Path to previous images file (mat file)
        nImages = 0;           % Number of images in the previousImagesDB
    end
    
    methods(Access=private)
        function obj = AutoSave()
            obj.loadPrefs;
            [path,~,~]=fileparts(mfilename('fullpath'));
            fname = fullfile(path,'PreviousImageDB.mat');
            if ~exist(fname,'file')
                % Start DB file
                old = {}; % 1xN
                save(fname,'old','-v7.3')
            end
            obj.previousImagesDB = matfile(fname,'Writable',true);
            [~,obj.nImages] = size(obj.previousImagesDB,'old');
        end
    end
    methods(Static)
        function obj = instance()
            mlock
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Databases.AutoSave();
            end
            obj = Object;
        end
        function filename = format_filename(spec,dir,module,ext)
            % Evaluate spec using provided dir and module
            module = strrep(class(module),'.','_');
            filename = strrep(spec,'\mod',module);
            filename = strrep(filename,'\date',datestr(now,'yyyy_mm_dd'));
            filename = strrep(filename,'\time',datestr(now,'HH_MM_ss'));
            filename = strrep(filename,'\y',datestr(now,'yyyy'));
            filename = strrep(filename,'\m',datestr(now,'mm'));
            filename = strrep(filename,'\d',datestr(now,'dd'));
            filename = strrep(filename,'\h',datestr(now,'HH'));
            filename = strrep(filename,'\M',datestr(now,'MM'));
            filename = strrep(filename,'\s',datestr(now,'ss'));
            if contains(filename,'\i')
                i = 0;
                test = strrep(filename,'\i',num2str(i));
                while exist(fullfile(dir,[test '.' ext]),'file')
                    i = i + 1;
                    test = strrep(filename,'\i',num2str(i));
                end
                filename = test;
            end
            filename = [filename '.' ext];
        end
        function [status,remoteName] = checkNetwork(path)
            % First confirm we are looking at a fullpath not relative
            % Works for windows only
            assert(ispc,'Function only works on windows.')
            if ~(length(path)>1 && path(2)==':')
                path = fullfile(pwd,path);
            end
            drive = path(1:2);
            [~,cmdout] = system(sprintf('net use %s',drive));
            remoteName = 'local'; status = 'OK';
            % Parse system output
            key = 'The network connection could not be found.';
            if ~(length(cmdout)>=length(key) && strcmp(cmdout(1:length(key)),key))
                lines = split(cmdout,newline);
                remoteName = split(lines{2},' '); remoteName = remoteName{end};
                status = split(lines{4},' '); status = status{end};  % Should be 'OK'
            end
        end
    end
    methods
        function task = inactive(obj)
            task = 'Resetting im and exp directories';
            inactive@Modules.Database(obj);
            obj.im_dir = '';
            obj.exp_dir = '';
            obj.first_save_rel_path = '';
        end
        function delete(obj)
            if ~isempty(obj.previousImagesDB)
                % Clean up files that showed error then check rest
                h = msgbox(sprintf('%s checking and cleaning DB\nPlease wait...',mfilename),'help');
                temp = obj.previousImagesDB.old;
                map = cellfun(@(a)~isempty(a),temp);
                temp = temp(map);
                map = logical(cellfun(@(a)exist(a,'file'),temp));
                temp = temp(map);
                obj.previousImagesDB.old = temp(max(1,end-obj.n_history+1):end);
                delete(obj.previousImagesDB)
                delete(h);
            end
        end
        function SaveIm(obj,image,~,module,notes) %#ok<*INUSL>
            if ~obj.im_enable
                return
            end
            assert(~isempty(obj.im_dir),'Image directory path not set.')
            filename = obj.format_filename(obj.formatspec{1},obj.im_dir,module,'mat');
            fullpath = fullfile(obj.im_dir,filename);
            if ispc
                [status,remoteName] = obj.checkNetwork(fullpath);
                assert(strcmp(status,'OK'),sprintf('Attempting to save to networked disc, but remote "%s" seems down.',remoteName))
            end
            image.notes = notes;  % Add in notes string
            if exist(fullpath,'file')
                resp = questdlg('Overwrite file?','File exists already','Yes','No','No');
                if ~strcmp(resp,'Yes')  % Closed window returns empty string
                    warndlg('Consider modifying format spec to include "\i" in filename.',['Save Settings: ' mfilename])
                    return
                end
            end
            save(fullpath,'image')
            obj.last_im_fname = fullpath;
            obj.nImages = obj.nImages + 1;
            obj.previousImagesDB.old(1,obj.nImages) = {fullpath};
        end
        function SaveExp(obj,data,~,module,notes,varargin)
            if ~obj.exp_enable
                return
            end
            assert(~isempty(obj.exp_dir),'Experiment directory path not set.')
            % use the last input to override the filename
            formatspec = obj.formatspec{2}; %#ok<*PROPLC>
            if numel(varargin) == 1
                filename = varargin{1};
            else
                filename = obj.format_filename(formatspec,obj.exp_dir,module,'mat');
            end
            if isprop(module,'first_save') && (islogical(module.first_save) || any(module.first_save==[0,1]))
                if ~contains(formatspec,'\i')
                    formatspec = obj.formatspec{2}+'_\i';
                end
                if module.first_save
                    obj.first_save_rel_path = obj.format_filename(formatspec,obj.exp_dir,module,'');
                    mkdir(fullfile(obj.exp_dir,obj.first_save_rel_path));
                end
                assert(~isempty(obj.first_save_rel_path),'first_save set to false, but no relative path has been made.')
                fullpath = fullfile(obj.exp_dir,obj.first_save_rel_path,filename);
            else
                fullpath = fullfile(obj.exp_dir,filename);
            end
            if ispc
                [status,remoteName] = obj.checkNetwork(fullpath);
                assert(strcmp(status,'OK'),sprintf('Attempting to save to networked disc, but remote "%s" seems down.',remoteName))
            end
            data.notes = notes;  % Add in notes string
            if exist(fullpath,'file')
                resp = questdlg('Overwrite file?','File exists already','Yes','No','No');
                if ~strcmp(resp,'Yes')  % Closed window returns empty string
                    warndlg('Consider modifying format spec to include "\i" in filename.',['Save Settings: ' mfilename])
                    return
                end
            end
            save(fullpath,'data','-v7.3')
            obj.last_exp_fname = fullpath;
        end
        function data = LoadExp(obj)
            [fname,path] = uigetfile('*.mat','Open Experiment',obj.exp_dir);
            assert(~isnumeric(fname),'No file selected');
            file = load(fullfile(path,fname));
            data = file.data.data;
        end
        
        % Settings and Callbacks
        function  settings(obj,panelH,~,~)
            spacing = 2.25;
            num_lines = 8;
            line = 1;
            uicontrol(panelH,'style','PushButton','String','Previous Images Viewer',...
                'units','characters','position',[11 spacing*(num_lines-line) 27 2],...
                'callback',@obj.PreviousImageViewer);
            line = 2;
            tip = obj.im_dir;
            lis(1) = uicontrol(panelH,'style','PushButton','String','Image Dir','tooltipstring',tip,...
                'units','characters','position',[3 spacing*(num_lines-line) 20 2],...
                'callback',@obj.change_im_dir);
            line = 2;
            tip = obj.exp_dir;
            lis(2) = uicontrol(panelH,'style','PushButton','String','Experiment Dir','tooltipstring',tip,...
                'units','characters','position',[25 spacing*(num_lines-line) 20 2],...
                'callback',@obj.change_exp_dir);
            line = 3;
            uicontrol(panelH,'style','CheckBox','String','Experiment Enabled','Value',obj.exp_enable,...
                'units','characters','position',[3 spacing*(num_lines-line) 40 2],...
                'callback',@obj.enableCallback,'tag','exp_enable');
            line = 4;
            uicontrol(panelH,'style','CheckBox','String','Image Enabled','Value',obj.im_enable,...
                'units','characters','position',[3 spacing*(num_lines-line) 40 2],...
                'callback',@obj.enableCallback,'tag','im_enable');
            line = 5;
            uicontrol(panelH,'style','text','string','DB Size (entries):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 20 1.25]);
            uicontrol(panelH,'style','edit','string',num2str(obj.n_history),...
                'units','characters','callback',@obj.nCallback,'tag','n_history',...
                'horizontalalignment','left','position',[21 spacing*(num_lines-line) 10 1.5]);
            line = 6;
            uicontrol(panelH,'style','text','string','Format spec (im):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 20 1.25]);
            obj.gui_spec(1) = uicontrol(panelH,'style','edit','string',obj.formatspec{1},...
                'units','characters','callback',@obj.formatspecCallback,'UserData',1,...
                'horizontalalignment','left','position',[21 spacing*(num_lines-line) 25 1.5]);
            line = 7;
            uicontrol(panelH,'style','text','string','Format spec (exp):','horizontalalignment','right',...
                'units','characters','position',[0 spacing*(num_lines-line) 20 1.25]);
            obj.gui_spec(2) = uicontrol(panelH,'style','edit','string',obj.formatspec{2},...
                'units','characters','callback',@obj.formatspecCallback,'UserData',2,...
                'horizontalalignment','left','position',[21 spacing*(num_lines-line) 25 1.5]);
            line = 8;
            uicontrol(panelH,'style','PushButton','string','Reset Format Specs',...
                'units','characters','callback',@obj.formatspecCallback,'tag','reset',...
                'horizontalalignment','left','position',[3 spacing*(num_lines-line) 24 1.5]);
            uicontrol(panelH,'style','PushButton','string','Help',...
                'units','characters','callback',@obj.formatspecHelp,...
                'horizontalalignment','left','position',[30 spacing*(num_lines-line) 10 1.5]);
            obj.prop_listeners = addlistener(obj,'im_dir','PostSet',@(a,b)obj.update_dir(lis(1),b));
            obj.prop_listeners(2) = addlistener(obj,'exp_dir','PostSet',@(a,b)obj.update_dir(lis(2),b));
            addlistener(panelH,'ObjectBeingDestroyed',@(~,~)delete(obj.prop_listeners));
        end
        function update_dir(obj,hObj,eventdata)
            set(hObj,'tooltipstring',obj.(eventdata.Source.Name));
        end
        function formatspecHelp(obj,~,~)
            helpdlg(sprintf(obj.formatstrHelp));
        end
        function formatspecCallback(obj,hObj,~)
            if strcmp(hObj.Tag,'reset')
                obj.formatspec = obj.default_formatspec;
            else
                obj.formatspec{get(hObj,'UserData')} = get(hObj,'String');
            end
            set(obj.gui_spec(1),'string',obj.formatspec{1});
            set(obj.gui_spec(2),'string',obj.formatspec{2});
        end
        function nCallback(obj,hObj,~)
            val = get(hObj,'string');
            if ~isnan(val)
                obj.(get(hObj,'tag')) = val;
            end
            set(hObj,'string',num2str(obj.(get(hObj,'tag'))))
        end
        function enableCallback(obj,hObj,~)
            obj.(hObj.Tag) = hObj.Value;
        end
        function change_im_dir(obj,hObj,varargin)
            folder_name = uigetdir(obj.im_dir_last,'Image Directory');
            if folder_name
                obj.im_dir = folder_name; % This one will be reset after inactivity
                obj.im_dir_last = folder_name; % This one will persist
            end
        end
        function change_exp_dir(obj,hObj,varargin)
            folder_name = uigetdir(obj.exp_dir_last,'Experiment Directory');
            if folder_name
                obj.exp_dir = folder_name; % This one will be reset after inactivity
                obj.exp_dir_last = folder_name; % This one will persist
            end
        end
    end
    
end

