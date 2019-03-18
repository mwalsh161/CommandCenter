classdef solstis < Modules.Driver
    %SOLSTIS Instantiates hwserver for the msquared solstis laser
    %
    % This driver will only ALLOW a SINGLE instantiation. This is to
    % protect the SolsTis from getting stuck in an EMM state, since only
    % the EMM knows how to recover from that.
    %
    % When setting target wavelength, the command does not block. The
    % command may also fail to perform any tuning operation, and the user
    % should be responsible to check the lock/tuning status using the
    % getWavelength method.
    %
    % The resonator and etalon tuner methods will error if used when the
    % laser is locked.
    %
    % Also note, setting locks usually return before lock is registered on
    % web-interface. There is a chance that the lock is not applied
    % immediately after setting. Best to check status if needed.
    
    properties
        % for calls to HWserver
        moduleName = 'msquared';
        laserName = 'solstis';
    end
    
    properties (SetAccess=immutable)
        hwserver;  % Handle to hwserver
    end
    methods(Static)
        
        function obj = instance(ip)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.msquared.solstis.empty(1,0);
            end
            [~,resolvedIP] = resolvehost(ip);
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal(resolvedIP,Objects(i).singleton_id)
                    error('%s driver is already instantiated!',mfilename)
                end
            end
            obj = Drivers.msquared.solstis(ip);
            obj.singleton_id = resolvedIP;
            Objects(end+1) = obj;
        end
    end
     methods(Access=private)
        function obj = solstis(ip)
            obj.hwserver = hwserver(ip);
            obj.hwserver.ping; % Make sure we are connected
        end
        function reply = com(obj,fn,varargin)
            reply = obj.hwserver.com(obj.moduleName,fn,obj.laserName,varargin{:});
        end
     end
    methods
        
        
        function status = getStatus(obj)
            status = obj.com('status');
        end
        
        function delete(obj)
            % Tell server to delete instance, then delete local instance
            try  % Might not be a good IP, so try only
                obj.com('close');
            end
            delete(obj.hwserver);
        end
        
        function [wavelength,locked,tuning] = getWavelength(obj)
            reply = obj.com('get_wavelength');
            wavelength = reply.current_wavelength;
            locked = logical(reply.lock_status);
            tuning = false;
            switch reply.status
                % status of 0 means open loop, 3 means maintaing wavelength (closed loop)
                case 1
                    error('No wavemeter connected');
                case 2
                    tuning = true;
            end
        end


        % removed method for 'set target wavelength', restarting
        % tuning/active wavemeter locking
        % after an abort
        function locked = lock_wavelength(obj,val)
            assert(ismember(val,{'on','off'}),'val must be either "on" or "off"')
            obj.com('lock_wavelength',val);
            locked = strcmp(val,'on');
        end
        
        function set_resonator_percent(obj,val)
            [~,locked,~] = obj.getWavelength();
            assert(~locked,'Laser is currently locked, remove with obj.lock_wavelength("off")');
            assert(val >=0 && val <= val, 'Resonator percent must be between 0 and 100');
            obj.com('set_resonator_val',val);
        end
        
        function set_etalon_lock(obj,val)
            assert(ismember(val,{'on','off'}),'val must be either "on" or "off"')
            [~,locked,~] = obj.getWavelength();
            assert(~locked,'Laser is currently locked, remove with obj.lock_wavelength("off")');
            out = obj.com('set_etalon_lock',val);
            assert(out{1}.status==0,sprintf('Command failed with status: %i',out{1}.status))
            assert(out{2}.report==0,sprintf('Completion failed with status: %i',out{2}.report))
        end
        function set_etalon_percent(obj,val)
            [~,locked,~] = obj.getWavelength();
            assert(~locked,'Laser is currently locked, remove with obj.lock_wavelength("off")');
            assert(val >=0 && val <= val, 'Resonator percent must be between 0 and 100');
            obj.com('set_etalon_val',val);
        end
        function reply = get_wavelength_range(obj)
            reply = obj.com('get_wavelength_range');
        end
        function set_target_wavelength(obj,val)
            range = obj.get_wavelength_range;
            min = range.minimum_wavelength;
            max = range.maximum_wavelength;
            assert(val>=min && val<=max,sprintf('Target wavelength out of range [%g, %g]',min,max))
            out = obj.com('lock_wavelength_to',val);
            assert(out.status==0,'Failed to set target')
        end
        function set_wavelength(obj,val)
            error('Not implemented')
        end
    end
end

