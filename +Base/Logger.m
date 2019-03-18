classdef Logger < handle
    %LOG Create a logging "daemon"
    %   Base.Logger(name,visible,fname)
    %       name = Name of logger figure that is created
    %       visible = initial visibility state (default: visible)
    %       fname = path/name to text file log (absolute or relative to
    %           this file)
    %
    %   Log levels
    %       0 -> DEBUG
    %       1 -> INFO
    %       2 -> WARNING
    %       3 -> ERROR
    %       4 -> CRITICAL
    %   Any log >= logLevel will be recorded.
    %   logLevel -> [listbox UI, textfile]
    %
    %   Logs to listbox in the created figure and to a textfile (json
    %     format)
    %
    %   Can send log entries in textfile to remote server via HTTP
    
    properties
        visible
        logLevel = [0,1]; % log level for [listbox,textfile]
    end
    properties(Hidden)
        URL = '';              % Server to send log to
        fig                    % Handle to parent figure
        text                   % Handle to listbox
        fname='../CC.log'      % Path to log txt file
        max_fsize=10;          % Truncates upon log call if larger than this (MB) to  half this size
        max_entries = 1000;    % Limit entries on listbox
    end
    properties(SetAccess=private)
        HTTP_pointer = 0        % byte to start sending to EOF (persistent in prefs)
        fullpath                % Full path to log file
        fid                     % File ID of log file
    end
    properties(Constant,Hidden)
        levels = {'DEBUG','INFO','WARNING','ERROR','CRITICAL'};
        DEBUG = 0
        INFO = 1
        WARNING = 2
        ERROR = 3
        CRITICAL = 4
    end
    
    methods
        function obj = Logger(name,visible,fname)
            if nargin < 2
                visible = true;
            end
            if nargin == 3
                obj.fname = fname;
            end
            % Create figure and hide it
            obj.fig = figure('name',sprintf('%s Logger',name),'HandleVisibility','callback','IntegerHandle','off',...
                           'menu','none','numbertitle','off','visible',visible,'CloseRequestFcn',@obj.closeRequest);
            obj.text = uicontrol(obj.fig,'style','listbox','units','normalized','position',[0 0 1 1],'value',[],'max',2,'callback',@obj.listboxCallback);
            if ispref(mfilename,'HTTP_pointer')
                obj.HTTP_pointer = getpref(mfilename,'HTTP_pointer');
            end
            obj.openLogFile;
        end
        function sendLogs(obj)
            if isempty(obj.URL); return; end % Short circuit if we dont want to send logs
            % Get GIT info
            GitInfo = '';
            try % If using git, append all the info of this version
                gitPath = mfilename('fullpath');
                gitPath = fileparts(gitPath); gitPath = fileparts(gitPath);
                GitInfo = getGitInfo(gitPath);
                GitInfo.status = strip(git('status'));
                GitInfo.diff = strip(git('diff'));
            end
            fseek(obj.fid,obj.HTTP_pointer,'bof');
            logs = fscanf(obj.fid,'%c'); % Should leave us back at EOF
            try
                r = webwrite(obj.URL,'logs',urlencode(logs),'git',urlencode(jsonencode(GitInfo)));
            catch err
                obj.logTraceback(sprintf('Failed to send to %s: %s',obj.URL,err.message),dbstack(1),obj.ERROR);
            end
            obj.HTTP_pointer = ftell(obj.fid);
        end
        function openLogFile(obj)
            % Open text file
            if obj.fname(1) ~= filesep % Then it is relative
                path = mfilename('fullpath');
                [path,~,~] = fileparts(path);
                path = fullfile(path,obj.fname);
            else
                path = obj.fname;
            end
            obj.fullpath = path;
            obj.fid = fopen(path,'at+'); % Append; read/write
            % If file deleted, we need ot reset HTTP_pointer
            obj.HTTP_pointer = min(ftell(obj.fid),obj.HTTP_pointer);
        end
        function truncateLogFile(obj)
            % Cut file size in half (note 1e6 B in 1 MB)
            approx_cut = obj.max_fsize*1e6/2;
            fseek(obj.fid,approx_cut,'bof');
            fgets(obj.fid); % Finish whatever line we jumped into
            % Update HTTP_pointer
            obj.HTTP_pointer = max(0,obj.HTTP_pointer - ftell(obj.fid)-1); % -1 to go back one byte from EOF (null)
            % Rewrite file from current location onward
            dat = fread(obj.fid); % Read the rest of file
            fclose(obj.fid);
            fopen(obj.fullpath,'w'); % Open for writing and delete contents
            fwrite(obj.fid,dat);
            fclose(obj.fid);
            fopen(obj.fullpath,'at+'); % Open for writing in regular append mode
        end
        function delete(obj)
            obj.log('Logger signing off')
            delete(obj.fig)
            fclose(obj.fid);
            setpref(mfilename,'HTTP_pointer',obj.HTTP_pointer);
        end
        function closeRequest(obj,varargin)
            obj.visible = 'off';
        end
        function set.visible(obj,val)
            set(obj.fig,'visible',val)
        end
        function val = get.visible(obj)
            val = get(obj.fig,'visible');
        end
        function logTraceback(obj,msg,varargin)
            % logTraceback(obj,msg) - will get the traceback struct here
            % logTraceback(_,stack) - user provided traceback struct
            % logTraceback(_,level) - user provided level integer
            level = 1;
            stack = dbstack(1);  % Remove this method from traceback
            assert(length(varargin) <= 2,'Incorrect call: logTraceback(msg, [stack, [level]])');
            while ~isempty(varargin)
                if isstruct(varargin{end})
                    stack = varargin{end};
                elseif isnumeric(varargin{end})
                    level = varargin{end};
                else
                    error('Incorrect call: logTraceback(msg, [stack, [level]])')
                end
                varargin(end) = [];
            end
            if level < min(obj.logLevel); return; end % Short circuit if loglevel too low
            for i = 1:length(stack)
                msg = [msg sprintf('\n%s <a href="matlab: opentoline(''%s'',%i)">(line %i)</a>',...
                    stack(i).name,stack(i).file,stack(i).line,stack(i).line)];
            end
            % Continue to log
            obj.log(msg,level,struct('traceback',stack));
        end
        function log(obj,orig_msg,level,info_struct)
            % info_struct is primarily for internal use, but can be used if
            % caller wants extra data in the file log.
            if nargin < 3
                level = 1;
            end
            if nargin < 4
                info_struct = struct();
            end
            assert(isnumeric(level),'log level input must be numeric');
            if level < min(obj.logLevel); return; end % Short circuit if loglevel too low
            % Use stack to find caller name
            s = dbstack;
            caller = '';
            if length(s)>1 % Could be called from command window
                for i = 1:length(s) % Get first caller outside Logger
                     caller = s(i).name;
                     if length(caller) >= 7 && all(caller(1:7)=='Logger.')
                         caller = ''; % In case we never get to break condition
                     else
                         break;
                     end
                 end
            end
            % Build message for listbox
            if level >= obj.logLevel(1)
                msg = strrep(orig_msg,'\','\\');
                header = [datestr(now,'mm/dd HH:MM:SS') ' '];
                if level >= 0 && level < length(obj.levels) % Make sure in list
                    levelName = obj.levels{level+1};
                else
                    levelName = num2str(level);
                end
                msg = sprintf('%s [%s] (%s) %s',header,levelName,caller,msg);
                msg = strsplit(msg,'\n');
                msg(1) = cellfun(@(str)sprintf('<HTML>%s</html>',str),msg(1),'UniformOutput',false);
                if numel(msg) > 1
                    spacer = '';
                    for i = 1:length(header)
                        spacer = [spacer '&nbsp;&nbsp;'];  % '&nbsp;' is a forced space character in HTML
                    end
                    msg(2:end) = cellfun(@(str)sprintf('<HTML>%s%s</html>',spacer,str),msg(2:end),'UniformOutput',false);
                end
                msg = strjoin(msg,'\n');
                strs = get(obj.text,'string');
                if ~iscell(strs)
                    strs = {strs};
                end
                NewStrs = [{msg}; strs(1:min(end,obj.max_entries))];
                set(obj.text,'string',NewStrs)
            end
            % Add to txt file
            if level >= obj.logLevel(2)
                if isfield(info_struct,'caller'); warning('LOGGER:file_log','Initial "info_struct" had field that is set by the logger; this field will be overwritten.'); end
                if isfield(info_struct,'msg'); warning('LOGGER:file_log','Initial "info_struct" had field that is set by the logger; this field will be overwritten.'); end
                if isfield(info_struct,'posixtime'); warning('LOGGER:file_log','Initial "info_struct" had field that is set by the logger; this field will be overwritten.'); end
                if isfield(info_struct,'level'); warning('LOGGER:file_log','Initial "info_struct" had field that is set by the logger; this field will be overwritten.'); end
                info_struct.caller = caller;
                info_struct.level = level;
                info_struct.msg = orig_msg;
                info_struct.posixtime = posixtime(datetime);
                try
                    msg = jsonencode(info_struct);
                    if ~exist(obj.fullpath,'file')
                        obj.openLogFile; % User might have deleted it
                    end
                    fprintf(obj.fid,'%s\n',msg);
                    s = dir(obj.fullpath);
                    if s.bytes > obj.max_fsize*1e6  % 1e6 B in MB
                        obj.truncateLogFile;
                    end
                catch err
                    warning('LOGGER:file_log','Failed to write log file entry: %s',err.message);
                end
            end
        end
        function listboxCallback(obj,hObj,~)
            if strcmp(get(obj.fig,'selectiontype'),'open')
                msg = get(hObj,'string');
                val = get(hObj,'value');
                % Scroll up to nearest
                while true
                    out{1} = msg{val}(7:end-7); % Strip html tags
                    if out{1}(1:6) == '&nbsp;'  % Will either be '&nbsp;' or 'mm/dd HH:MM:SS'
                        val = val - 1;
                    else
                        break
                    end
                end
                while val < numel(msg)-1
                    val = val + 1;
                    temp = msg{val}(7:end-7); % Strip html tags
                    if temp(1:6) ~= '&nbsp;'  % Will either be '&nbsp;' or 'mm/dd HH:MM:SS'
                        break
                    end
                    out{end+1} = temp;
                end
                out = strjoin(out,'\n');
                out = regexprep(out,'&nbsp;&nbsp;',' ');
                fprintf([out '\n'])
            end
            set(hObj,'value',[])
        end
    end
    
end

