classdef Remote < Modules.Driver & Drivers.PulseTimer_invisible
    %INTERPRETERCLIENT Connects with server.py on host machine to control
    % the PulseBlaster via the interpreter program. Port 36576.
    %
    % Call with the IP of the host computer (singleton based on ip)
    
    properties
        clk = 500  % Hz (isn't this MHz?)
        resolution = 2; % ns
        minDuration = 10; % ns
    end
    properties(SetAccess=private)
        connection
    end
    properties(SetAccess=private,SetObservable,AbortSet)
        % If something is running, this will be name of caller
        % else, an empty str (or called directly from command line)
        % Caller module can verify by comparing to mfilename('class') output
        running = '';
    end
    
    methods(Static)
        function obj = instance(ip)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.PulseBlaster.Remote.empty(1,0);
            end
            [~,resolvedIP] = resolvehost(ip);
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(resolvedIP,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.PulseBlaster.Remote(ip);
            obj.singleton_id = resolvedIP;
            Objects(end+1) = obj;
        end
    end
    methods(Access=private)
        function obj = Remote(ip)
            obj.connection = tcpip(ip,36576,'OutputBufferSize',1024,'InputBufferSize',1024);
            obj.connection.Timeout = 2;
            obj.connection.Terminator = 'LF';
        end
        function response = com(obj,msg,close_after)
            if nargin < 3
                close_after = true;
            end
            % Server always replies and always closes connection after msg
            if strcmp(obj.connection.Status,'closed')
                fopen(obj.connection);
            end
            msg = [urlencode(msg) newline];
            buffsz = obj.connection.OutputBufferSize;
            for i = 1:ceil(length(msg)/buffsz)
                fprintf(obj.connection,'%s',msg(buffsz*(i-1)+1:min(end,buffsz*i)));
            end
            response = '';
            while true
                [partial,~,msg] = fscanf(obj.connection);
                response = [response partial]; %#ok<AGROW>
                if isempty(msg)
                    break
                elseif ~contains(msg,'input buffer was filled before the Terminator was reached')
                    warning(msg)
                end
            end
            response = urldecode(strip(response));  % Decode
            if close_after
                fclose(obj.connection);
            end
            assert(~startswith(response,'Error: '),response(8:end))
        end
    end
    methods
        function delete(obj)
            try %#ok<TRYNC>
                % Try statement, because maybe not in session, or someone
                % else reset the session.
                obj.close;
            end
            delete(obj.connection)
        end
        function set.clk(obj,val)
            assert(isnumeric(val),'clk must be numeric.')
            obj.clk = num2str(val);
        end
        function open(obj)
            % open session with host and get termination character
            response = obj.com(jsonencode(struct('cmd','open')));
            assert(startswith(response,'Session opened'),...
                ['Unexpected response: ',response])
        end
        function close(obj)
            % close session with host
            response = obj.com(jsonencode(struct('cmd','close')));
            assert(startswith(response,'Session closed'),...
                ['Unexpected response: ',response])
        end
        function reset(obj)
            % reset session on host, overrides other sessions on host
            response = obj.com(jsonencode(struct('cmd','reset')));
            assert(startswith(response,'Session reset'),...
                ['Unexpected response: ',response])
        end
        function start(obj)
            % Get caller info
            a = dbstack('-completenames');
            caller = strsplit(a(end).file,filesep);
            prefix = '';
            for i = 1:numel(caller)
                if numel(caller{i}) && caller{i}(1)=='+'
                    prefix = [prefix caller{i}(2:end) '.'];
                end
            end
            [~,name,~]=fileparts(caller{end});
            caller = [prefix name];
            % start the pulse blaster
            response = obj.com(jsonencode(struct('cmd','start')));
            assert(startswith(response,'Program execution started.'),...
                ['Unexpected response: ',response])
            obj.running = caller;
        end
        function stop(obj)
            % stop the pulse blaster
            response = obj.com(jsonencode(struct('cmd','stop')));
            assert(startswith(response,'Program execution stopped.'),...
                ['Unexpected response: ',response])
            obj.running = '';
        end
        function response = load(obj,program)
            % load program to pulse blaster
            % program should be cell array of instructions or formatted
            % string (with newlines per instruction)
            if iscell(program)
                program = strjoin(program,'\n');
            end
            % Send program
            response = obj.com(jsonencode(struct('cmd','load','clk',obj.clk,'code',program)));
        end
    end
end