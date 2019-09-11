classdef hwserver < handle
    %HWSERVER Connects with server.py on host machine to control
    % varoius pieces of equipment
    % Note, some hwserver operations could conveivably take longer than the
    % default timeout used here. If so, obj.connection.Timeout should be
    % adjusted appropriately
    %
    % obj.ping will retun the client's ip addresss and binding port
        
    properties
        connection
    end
    
    methods
        function obj = hwserver(ip,~)
            if nargin > 1
                warning('CC:legacy','Port (second input) is legacy. Consider updating your code.')
            end
            obj.connection = tcpip(ip,36577);
            obj.connection.Timeout = 2;
            obj.connection.Terminator = 'LF';
            obj.connection.OutputBufferSize = 4096;
            obj.connection.InputBufferSize = 4096;
        end
        function delete(obj)
            if strcmp(obj.connection.status,'open')
                fclose(obj.connection);
            end
            delete(obj.connection);
        end
        function response = reload(obj,module)
            if ~exist('module','var')
                module = '';
            end
            module = urlencode(module);
            handshake = urlencode(jsonencode(struct('name',['_reload_' module])));
            fopen(obj.connection);
            try
                fprintf(obj.connection,'%s\n',handshake);
                response = obj.receive; % Error handling in method
            catch err
                fclose(obj.connection);
                rethrow(err)
            end
            fclose(obj.connection);
        end
        function response = help(obj)
            handshake = urlencode(jsonencode(struct('name','_help')));
            fopen(obj.connection);
            try
                fprintf(obj.connection,'%s\n',handshake);
                response = obj.receive; % Error handling in method
            catch err
                fclose(obj.connection);
                rethrow(err)
            end
            fclose(obj.connection);
        end
        function response = ping(obj)
            handshake = urlencode(jsonencode(struct('name','_ping')));
            fopen(obj.connection);
            try
                fprintf(obj.connection,'%s\n',handshake);
                response = obj.receive; % Error handling in method
            catch err
                fclose(obj.connection);
                rethrow(err)
            end
            fclose(obj.connection);
        end
        function response = com(obj,hwname,funcname,varargin)
            % Server always replies and always closes connection after msg
            % assert funcname is a string, and cast varargin (cell array)
            % to strings (use cellfun - operates on each entry of cell)
            %
            % last input is the keep_alive; for now, functionality not
            % included
            assert(ischar(hwname),'hwname must be a string');
            % Prepare both parts of message in case one errors
            handshake = urlencode(jsonencode(struct('name',hwname)));
            msg = struct('function',funcname,'args',{varargin},'keep_alive',false);
            msg = urlencode(jsonencode(msg));
            abort = struct('function',NaN,'args',{{}},'keep_alive',false);
            abort = urlencode(jsonencode(abort));
            fopen(obj.connection);
            err = [];
            try
                fprintf(obj.connection,'%s\n',handshake);
                obj.receive; % Error handling in method
                fprintf(obj.connection,'%s\n',msg);
                response = obj.receive;
            catch err
                % For future use in more parallel hwserver;
                % for now, it is redundant with keep_alive: false and is
                % error-prone server-side if called too quickly
                % fprintf(obj.connection,'%s\n',abort);
            end
            fclose(obj.connection);
            if ~isempty(err)
                rethrow(err)
            end
        end
        
    end
    methods(Access=protected)
        function response = receive(obj)
            % Read until timeout or newline character; utility of this is
            % if the response is larger than the buffer
            % Take care of serverside error handling and only return
            % response
            response = '';
            t = tic;
            while toc(t) < obj.connection.Timeout
                [partial,~,msg] = fscanf(obj.connection);
                response = [response, partial]; %#ok<AGROW>
                if isempty(msg) && ~isempty(response)
                    break
                elseif ~contains(lower(msg),'input buffer was filled')
                    warning(msg);
                end
            end
            if isempty(response)
                ME = MException('HWSERVER:empty','empty response after timeout');
                throwAsCaller(ME);
            end
            response = jsondecode(urldecode(response));
            if response.error
                % Make sure we escape the % character because it will likely go 
                % through another format string during error handling
                ME = MException('HWSERVER:error',...
                    'hwserver error: %s\n%s',strrep(response.response,'%','%%'),...
                    strrep(response.traceback,'%','%%'));
                throwAsCaller(ME);
            end
            response = response.response;
        end
    end
end

