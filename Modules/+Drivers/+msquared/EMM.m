classdef EMM < Modules.Driver
    %EMM Instantiates hwserver for the msquared EMM laser
    % Implements setting wavelength and cleaning up solstis settings on
    % exiting.
    %
    % Most EMM calls require the hwserver launching man-in-the-middle and
    % then the EMM ICE BLOC connecting. This is an expensive operation!
    % getStatus is a method that does not require it, making it faster than
    % the others if it has to move from a solstis state
    
    properties
        % for calls to HWserver
        moduleName = 'msquared';
        laserName = 'EMM';
        blocking_timeout = 60;  % If call is blocking, adjust wait time
    end

    properties (SetAccess=immutable)
        hwserver;  % Handle to hwserver
        default_timeout; % Used to set back after a blocking call
    end
    methods(Static)
        
        function obj = instance(ip)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.msquared.EMM.empty(1,0);
            end
            [~,resolvedIP] = resolvehost(ip);
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(resolvedIP,Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.msquared.EMM(ip);
            obj.singleton_id = resolvedIP;
            Objects(end+1) = obj;
        end
    end
     methods(Access=private)
        function obj = EMM(ip)
            obj.hwserver = hwserver(ip);
            obj.default_timeout = obj.hwserver.connection.Timeout;
            obj.hwserver.ping; % Make sure we are connected
        end
        function reply = com(obj,fn,varargin)
            try
                reply = obj.hwserver.com(obj.moduleName,fn,obj.laserName,varargin{:});
            catch err
                if contains(err.message,'Another client was using')
                    % Grab line with exception in it
                    exception = strsplit(err.message,newline);
                    mask = cellfun(@(a)startswith(a,'Exception: '),exception);
                    exception = exception{mask};
                    answer = questdlg(sprintf('%s\nDo you want to override the other client?',exception),...
                        mfilename,'Yes','No','No');
                    if strcmp(answer,'Yes')
                        % Override and recall
                        obj.com('force_client');
                        reply = obj.hwserver.com(obj.moduleName,fn,obj.laserName,varargin{:});
                        return
                    else
                        error(exception);
                    end
                end
                rethrow(err);
            end
        end
        function reply = com_blocking(obj,fn,varargin)
            obj.hwserver.connection.Timeout = obj.blocking_timeout;
            try
                reply = obj.com(fn,varargin{:});
            catch err
                obj.hwserver.connection.Timeout = obj.default_timeout;
                rethrow(err);
            end
            obj.hwserver.connection.Timeout = obj.default_timeout;
        end
     end
    methods

        function status = getStatus(obj)
            % Note, this is a unique command in that it can be called
            % without man-in-the-middle active (e.g it is fast)
            status = obj.com('status');
        end
        
        function status = getStatusBlocking(obj)
            status = obj.com_blocking('status');
        end
        
        function delete(obj)
            % Tell server to delete instance, then delete local instance
            err = [];
            try  % Might not be a good IP, so try only
                % Give control back to solstis ICE BLOC
                obj.com('set_wavelength',800,false,'infrared');
                obj.com('close');
            catch err
            end
            delete(obj.hwserver);
            if ~isempty(err)
                msgbox(sprintf('Error cleaning up EMM. Might want to check web interface!\n\nError: %s',...
                    err.message),mfilename,'modal');
            end
        end
        
        function ready(obj)
            % Will either return nothing or error
            obj.com_blocking('ready');
        end
        function optimize_power(obj)
            obj.com_blocking('optimise_ppln');
        end
        function set_target_wavelength(obj,val)
            obj.com('set_wavelength',val,0);
        end
        function set_wavelength(obj,val)
            out = obj.com_blocking('set_wavelength',val,60);
            if out{2}.report == 1
                error('Tuning failed')
            end
        end
        function abort_tune(obj)
            obj.com('abort_tune')
        end
        
    end
end

