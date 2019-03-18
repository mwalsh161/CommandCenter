classdef Logger_console < handle
    %LOG Create a logging "daemon" as alternative to "Logger"
    %   Base.Logger_console(name,visible,fname)
    %       name = unused
    %       visible = unused
    %       fname = unused
    %
    %   Log levels (all are printed)
    %       0 -> DEBUG
    %       1 -> INFO
    %       2 -> WARNING
    %       3 -> ERROR
    %       4 -> CRITICAL
    %   Any log >= logLevel will be recorded.
    %   logLevel -> [listbox UI, textfile]
    %
    %   This is the default alternative to "Logger".  All log
    %   only go to console, and sendLogs is ignored. As such, 
    %   all properties are kept, but simply unused.
    
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
        end
        function sendLogs(obj)
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
                if numel(msg) > 1
                    spacer = '';
                    for i = 1:length(header)
                        spacer = [spacer ' '];
                    end
                    msg(2:end) = cellfun(@(str)sprintf('%s%s',spacer,str),msg(2:end),'UniformOutput',false);
                end
                msg = strjoin(msg,'\n');
                fprintf('%s\n',msg)
            end
        end
    end
    
end

