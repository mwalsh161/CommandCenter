classdef SSH < handle
    %SSH(server,username,port[,privateKey,privateKey password])
    %SSH provides wrapper for SSH with linux based or PC
    
    properties
        server
        user
        port
        PC
        channel=NaN;
        debug=false;
    end
    properties (Access=private)
        key=NaN;
        key_pswd=NaN;
    end
    
    methods
        function obj = SSH(server,user,port,varargin)
            obj.server=server;
            obj.user=user;
            obj.port=port;
            obj.PC=ispc;
            if obj.PC
                if numel(varargin) ~= 2
                    error('Detected a PC - need a private key path and password')
                end
                obj.key=varargin{1};
                obj.key_pswd=varargin{2};
                warning('off','MATLAB:Java:DuplicateClass');
                path = strsplit((mfilename('fullpath')),'\');
                path = fullfile(path{1:end-1},'ganymed-ssh2-build250/ganymed-ssh2-build250.jar');
                javaaddpath(path);
                obj.channel=obj.sshfrommatlab_publickey_file(obj.user,obj.server,obj.port,obj.key,obj.key_pswd);
            end
        end
        
        function response = issue(obj,msg)
            if obj.PC
                response = obj.SSH_PC(msg);
            else
                response = obj.SSH_linux(msg);
            end
        end
        
    end
        
    methods(Access=private)
        function response = SSH_PC(obj,msg)
            if obj.debug
                fprintf('SSH_PC\n')
                fprintf([msg '\n'])
            end
            [obj.channel,response]=obj.sshfrommatlabissue(obj.channel,msg);
            if numel(response)==1
                if isempty(response{1})
                    response={};
                end
            end
        end
        
        function response = SSH_linux(obj,msg)
            msg = sprintf('ssh -T -p %s %s@%s %s',num2str(obj.port),obj.user,obj.server,msg);
            if obj.debug
                fprintf('SSH_linux\n')
                fprintf([msg '\n'])
            end
            [status,response] = system(msg);
            if status
                uiwait(errordlg(response))
                response={false};
            else
                response=regexp(response, '[\f\n\r]', 'split');
                response = response(1:end-1)';
            end
        end
    end
    methods(Static)
        scptomatlab(userName,hostName,password,localFolder,remotefilename)
        sftpfrommatlab(userName,hostName,password,localfilename,remotefilename)
        channel  =  sshfrommatlab(userName,hostName,port,password)
        channel  =  sshfrommatlab_publickey(userName,hostName,private_key, private_key_password)
        channel  =  sshfrommatlab_publickey_file(userName,hostName,port,private_key, private_key_password)
        channel  =  sshfrommatlabclose(channel)
        sshfrommatlabinstall(args)
        [channel, result]  =  sshfrommatlabissue(channel,command)
        [channel]  =  sshfrommatlabissue_dontwait(channel,command)
    end
    
end

