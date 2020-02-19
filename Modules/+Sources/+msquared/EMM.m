classdef EMM < Sources.msquared.common_invisible
    % EMM Mainly to implement coarse tuning and solstis resonator tuning.
    % Similar to the SolsTiS, this cannot load if the SolsTiS is loaded
    % already. It will error in loading the solstis driver.
    %
    % Do not trust any reported values! Always update status if you want to read a value.
    %
    % When setting hwserver_host, it is important that this class loads the
    % solstis driver before the EMM in case it is in use and needs to
    % report an error instead of loading.
    %
    % EMM takes control of solstis by updating wavemeter channel. As such,
    % the solstis wavelength query is used here too.
    %
    % NOTE: might be a way to inherit Sources.msquared.SolsTiS and cut way
    % back on redundant code. Would need to consider how to overload
    % setmethods in this subclass and consider where prefs get loaded
    
    properties(SetAccess=protected)
        % total tunable range in THz (should be updated when crystal changed; see obj.fitted_oven)
        range = Sources.TunableLaser_invisible.c./[580,661];
    end
    properties(SetObservable,AbortSet)
        fitted_oven = Prefs.Integer(1,'readonly',true,'set','set_fitted_oven',...
            'help_text','Crystal being used: 1,2,3. This also sets range');
    end
    properties(Access=protected)
        emmHandle     % handle to EMM driver
    end
    
    methods(Access=private)
        function obj = EMM()
            obj.show_prefs = [obj.prefs(1:8), {'fitted_oven'}, obj.prefs(9:end)];
            obj.init();
            if obj.tuning
                dlg = msgbox('Please wait while tuning completes from previous tuning...',mfilename,'modal');
                try
                    obj.emmHandle.ready();
                    while true
                        status = obj.emmHandle.getStatus();
                        if ~strcmp(status.tuning,'active')
                            break
                        end
                        drawnow;
                    end
                    obj.tuning = false;
                catch err
                    delete(dlg)
                    rethrow(err)
                end
                delete(dlg)
            end
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.msquared.EMM();
            end
            obj = Object;
        end
    end
    methods
        function ready(obj)
            obj.emmHandle.ready;
        end
        function updateStatus(obj)
            % Common gets solstis stuff
            updateStatus@Sources.msquared.common_invisible(obj)
            % Now get EMM stuff. This kills man-in-the-middle!!
            if ~strcmp(obj.hwserver_host,obj.no_server)
                reply = obj.emmHandle.getStatus();
                obj.updatingVal = true;
                    obj.fitted_oven = reply.fitted_oven;
                    obj.tuning = strcmp(reply.tuning,'active'); % Overwrite getWavelength tuning status with EMM tuning state
                obj.updatingVal = false;
            end
        end
        function tune(obj,target)
            % This is the tuning method that interacts with hardware
            % (potentially a very expensive operation if switching from
            % solstis)
            % target in nm
            obj.updatingVal = true;
            assert(~isempty(obj.emmHandle)&&isobject(obj.emmHandle) && isvalid(obj.emmHandle),'no emmHandle, check hwserver_host')
            assert(target>=obj.c/max(obj.range)&&target<=obj.c/min(obj.range),sprintf('Wavelength must be in range [%g, %g] nm!!',obj.c./obj.range))
            err = [];
            % The EMM blocks during tuning, so message is useful until a non-blocking operation exists
            dlg = msgbox('Please wait while EMM tunes to target wavelength.',mfilename,'modal');
            textH = findall(dlg,'tag','MessageBox');
            delete(findall(dlg,'tag','OKButton'));
            drawnow;
            obj.tuning = true;
            try
                textH.String = 'Launching MITM, please wait...'; drawnow;
                obj.emmHandle.ready()
                textH.String = 'Please wait while EMM tunes to taget wavelength.'; drawnow;
                obj.emmHandle.set_wavelength(target);
                obj.target_wavelength = target;
                obj.trackFrequency(obj.c/target); % Will block until obj.tuning = false (calling obj.getFrequency)
            catch err
            end
            delete(dlg);
            obj.tuning = false;
            if ~isempty(err)
                obj.locked = false;
                obj.wavelength_lock = false;
                obj.setpoint = NaN;
                obj.updatingVal = false;
                rethrow(err)
            end
            obj.setpoint = obj.c/target;
            obj.locked = true;
            obj.wavelength_lock = true;
            obj.etalon_lock = true;  % We don't know at this point anything about etalon if not locked
            obj.updatingVal = false;
        end

        function delete(obj)
            errs = {};
            try
                if ~isempty(obj.solstisHandle)
                    delete(obj.solstisHandle);
                end
            catch err
                errs{end+1} = err.message;
            end
            try % Cleaning this up second should leave hwserver in EMM state (e.g. MITM spawned)
                if ~isempty(obj.emmHandle)
                    delete(obj.emmHandle);
                end
            catch err
                errs{end+1} = err.message;
            end
            if ~isempty(errs)
                error('Error(s) cleaning up EMM:\n%s',strjoin(errs,newline))
            end
        end
        
        % Set methods
        function host = set_hwserver_host(obj,host,~)
            if isempty(host); return; end % Short circuit on empty hostname
            % solstis
            err = obj.connect_driver('solstisHandle','msquared.solstis',host);
            if ~isempty(err)
                obj.hwserver_host = obj.no_server;
                obj.updateStatus();
                if contains(err.message,'driver is already instantiated')
                    error('solstis driver already instantiated. Likely due to an active SolsTiS source; please close it and retry.')
                end
                rethrow(err)
            end
            % EMM (if here, we can assume solstis loaded correctly)
            err = obj.connect_driver('emmHandle','msquared.EMM',host);
            if ~isempty(err)
                obj.hwserver_host = obj.no_server;
                obj.updateStatus();
                delete(obj.solstisHandle);
                obj.solstisHandle = [];
                error('solstis loaded, but EMM failed. Solstis handle destroyed:\n%s',err.message);
            end
            % Can only get here if both successful
            obj.updateStatus();
        end
        function val = set_fitted_oven(obj,val,~)
            if isnan(val); obj.fitted_oven = val; return; end % Short circuit on NaN
            obj.fitted_oven = val;
            % Update range
            switch val
                case 1
                    obj.range = obj.c./[515, 582];
                case 2
                    obj.range = obj.c./[580, 661];
                otherwise
                    obj.range = NaN(1,2);
                    error('Unknown fitted_oven id (cannot set range): %i',val)
            end
        end
    end
end

