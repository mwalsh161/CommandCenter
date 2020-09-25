classdef(Abstract) common_invisible < Modules.Source & Sources.TunableLaser_invisible
    % Code and methods shared by EMM and SolsTiS will be inherited from this class

    properties
        resVolt2Percent = struct('fcn',cfit(),'gof',[],'datetime',[]);
        prefs = {'hwserver_host','PB_line','pb_host','resonator_tune_speed','resVolt2Percent','moduleName'};
        show_prefs = {'tuning','target_wavelength','wavelength_lock','etalon_lock','resonator_percent','resonator_voltage',...
            'etalon_percent','etalon_voltage','hwserver_host','moduleName','PB_line','pb_host','resonator_tune_speed','calibrateRes'};
    end
    properties(SetObservable,GetObservable)
        moduleName = Prefs.MultipleChoice('set','set_moduleName','help_text','Modules will be loaded when a hwserver hostname is supplied.');
        calibrateRes = Prefs.Boolean(false,'set','set_calibrateRes',...
            'help_text','Begin resonator voltage -> percent calibration (changes resVolt2Percent).');
        tuning = Prefs.Boolean(false,'readonly',true);
        hwserver_host = Prefs.String(Sources.msquared.common_invisible.no_server,'set','set_hwserver_host');
        etalon_percent = Prefs.Double(NaN,'unit','%','help_text','Set etalon percent. This will change the etalon_voltage that is read.');  % Settable
        etalon_voltage = Prefs.Double(NaN,'unit','V','readonly',true);  % Readable
        etalon_lock = Prefs.Boolean(false,'set','set_etalon_lock');  % Settable
        resonator_percent = Prefs.Double(NaN,'unit','%','min',0,'max',100,'set','set_resonator_percent',...
            'help_text','Set resonator percent. This will change the resonator_voltage that is read.');  % Settable
        resonator_voltage = Prefs.Double(NaN,'unit','V','readonly',true);  % Readable
        target_wavelength = Prefs.Double(NaN,'unit','nm','set','set_target_wavelength'); % nm settable
        wavelength_lock = Prefs.Boolean(false,'set','set_wavelength_lock'); % Settable
        PB_line = Prefs.Integer(1,'min',1,'set','set_PBline','help_text','Indexed from 1.');
        pb_host = Prefs.String(Sources.msquared.common_invisible.no_server,'set','set_pb_host');
        resonator_tune_speed = Prefs.Double(2,'unit','%/step','min',0,'allow_nan',false,'help_text','Maximum % per step allowed. Lower numbers will take longer to tune.');
    end
    properties(Access=protected)
        timeout = 30   % Ignore errors within this timeout on wavelength read (getWavelength)
        PulseBlaster   % handle to PulseBlaster Driver
        solstisHandle  % handle to Solstis Driver
        updatingVal = false; % This signals to set methods to not talk to hardware
    end
    properties(Constant,Hidden)
        no_server = 'No Server';  % Message when not connected
    end

    methods(Access=protected)
        function init(obj) % Call in subclass constructor
            obj.loadPrefs;  % This will call set.(*_host) too which instantiate hardware
            obj.updateStatus(); % Redundant with set.(*_host) but useful for if no host pref
        end
        function err = connect_driver(obj,propname,drivername,varargin)
            err = [];
            if ~isempty(obj.(propname))
                delete(obj.(propname)); %remove any old connection
            end
            if ischar(varargin{1}) && strcmpi(varargin{1},obj.no_server) %first input is always an host address
                obj.(propname) = [];
            else
                try
                    obj.(propname) = Drivers.(drivername).instance(varargin{:});
                catch err
                    obj.(propname) = [];
                end
            end
        end
    end
    methods(Abstract,Hidden)
        host = loadLaser(obj);
    end
    methods
        function val = set_source_on(obj, val, ~)
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.PulseBlaster.lines(obj.PB_line).state = val;
        end

        function updateStatus(obj)
            % Get status report from SolsTiS laser and update fields
            obj.updatingVal = true;
            if isempty(obj.solstisHandle) || ~isvalid(obj.solstisHandle)
                obj.etalon_lock = false; %NaN; logical cannot be NaN or creation of the ui is failing
                obj.locked = false; %NaN;
                obj.etalon_voltage = NaN;
                obj.resonator_voltage = NaN;
                obj.wavelength_lock = false; %NaN;
                obj.setpoint = NaN;
            else
                reply = obj.solstisHandle.getStatus();
                obj.etalon_lock = strcmp(reply.etalon_lock,'on');
                obj.etalon_voltage = reply.etalon_voltage;
                obj.resonator_voltage = reply.resonator_voltage;
                obj.getWavelength; % This sets wavelength_lock (and potentially etalon_lock)
            end
            obj.updatingVal = false;
        end
        function calibrate_voltageToPercent(obj)
            if isempty(obj.solstisHandle) || ~isvalid(obj.solstisHandle)
                error('Need to connect to SolsTiS first.')
            end
            obj.WavelengthLock(false);
            % Put resonator at zero percent and wait to settle just in case
            obj.solstisHandle.set_resonator_percent(0);
            pause(0.5);
            % Calls will go to driver directly since no assumptions on
            % calibration being there or accurate yet
            n = 101;
            voltages = NaN(n,1);
            percents = linspace(0,100,n)';
            f = UseFigure('SolsTiS.calibrate_voltageToPercent',true);
            ax = axes('parent',f); hold(ax,'on');
            figure(f);
            lnH = plot(ax,voltages,percents,'-o');
            ylabel(ax,'Percent (%)');
            xlabel(ax,'Voltage (V)');
            tH = title(ax,'Starting Calibration');
            for i = 1:n
                tH.String = sprintf('Calibrating: %i/%i',i,n);
                obj.solstisHandle.set_resonator_percent(percents(i));
                pause(1);
                reply = obj.solstisHandle.getStatus();
                voltages(i) = reply.resonator_voltage;
                lnH.XData(i) = voltages(i);
                drawnow limitrate;
            end
            [ft,gof] = fit(voltages,percents,'poly2');
            tH.String = sprintf('adjR^2: %g',gof.adjrsquare);
            plotV = linspace(min(voltages),max(voltages),1001);
            fitbounds = predint(ft,plotV,0.95,'functional','on'); %get confidence bounds on fit
            errorfill(plotV,ft(plotV),[abs(ft(plotV)'-fitbounds(:,1)');abs(fitbounds(:,2)'-ft(plotV)')],'parent',ax);
            subplot(2,1,1,ax);
            ax_resid = subplot(2,1,2,'parent',f);
            plot(ax_resid,voltages,percents-ft(voltages),'-o');
            ylabel(ax_resid,'Percent (%)');
            xlabel(ax_resid,'Voltage (V)');
            title(ax_resid,'Residuals');
            answer = questdlg('Calibration satisfactory?','SolsTiS Resonator Calibration Verification','Yes','No, abort','Yes');
            if strcmp(answer,'No, abort')
                error('Failed SolsTiS resonator calibration validation.')
            end
            obj.resVolt2Percent.fcn = ft;
            obj.resVolt2Percent.gof = gof;
            obj.resVolt2Percent.datetime = datetime;
        end
        function percent = GetPercent(obj)
            if isempty(obj.resVolt2Percent.fcn)
                error('Calibrate resonator first. Click "calibrateRes" setting or call "calibrate_voltageToPercent".');
            end
            obj.updateStatus();
            percent = obj.resVolt2Percent.fcn(obj.resonator_voltage);
        end
        function [wavelength] = getWavelength(obj)
            % Attempt to get non-error value until timeout
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_host')
            t = tic;
            while true
                try
                    [wavelength,lock,istuning] = obj.solstisHandle.getWavelength();
                    break
                catch err
                    if toc(t) > obj.timeout
                        rethrow(err)
                    end
                end
            end
            obj.updatingVal = true;
                obj.setpoint = obj.c/wavelength;
                obj.tuning = istuning;
                obj.wavelength_lock = lock;
                obj.locked = lock;
                if lock
                    obj.etalon_lock = true;
                end
            obj.updatingVal = false;
        end
        function tune(~,~)
            % This is specific per device and should be overloaded
            error('Not Implemented')
        end
        function WavelengthLock(obj,lock)
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_host')
            assert(islogical(lock)||lock==0||lock==1,'lock must be true/false')
            if lock
                strlock = 'on';
            else
                strlock = 'off';
            end
            obj.solstisHandle.lock_wavelength(strlock);
            obj.tuning = true;
            pause(1) % Wait for msquared to start tuning
            obj.trackFrequency; % Will block until obj.tuning = false (calling obj.getFrequency)
            obj.updateStatus(); % Resonator, etalon both changed after tune
        end
        function EtalonLock(obj,lock)
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_host')
            assert(islogical(lock)||lock==0||lock==1,'lock must be true/false')
            if lock
                lock = 'on';
            else
                lock = 'off';
            end
            obj.solstisHandle.set_etalon_lock(lock);
        end

        % tunable laser methods
        function freq = getFrequency(obj)
            wavelength = obj.getWavelength;
            freq = obj.c/wavelength;
        end
        function TuneCoarse(obj,target)
            obj.tune(obj.c/target);
            if obj.locked
                pause(3); % Required for the EMM to reach the target wavelength
                obj.WavelengthLock(false);
            end
        end
        function TuneSetpoint(obj,target) % THz
            obj.tune(obj.c/target);
        end
        function TunePercent(obj,target)
            % This is the solstis resonator
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_host')
            assert(target>=0&&target<=100,'Target must be a percentage')
            % tune at a limited rate per step
            currentPercent = obj.GetPercent;
            numberSteps = floor(abs(currentPercent-target)/obj.resonator_tune_speed);
            direction = sign(target-currentPercent);
            for i = 1:numberSteps
                obj.solstisHandle.set_resonator_percent(currentPercent+(i)*direction*obj.resonator_tune_speed);
            end
            obj.solstisHandle.set_resonator_percent(target);
            obj.updatingVal = true;
                obj.resonator_percent = target;
            obj.updatingVal = false;
            obj.updateStatus(); % Get voltage of resonator
        end
    end

    methods % Set methods
        function val = set_calibrateRes(obj,~,~)
            % Check mark used to call calibration method
            obj.calibrate_voltageToPercent();
            val = false;
        end
        function val = set_moduleName(obj,val,~)
            obj.loadLaser();
        end
        function host = set_hwserver_host(obj,host,~)
            % Get list of lasers at this host
            opts = {};
            if ~isempty(host) && ~strcmp(host,obj.no_server)
                opts = Drivers.msquared.solstis.getLasers(host);
            end
            mp = obj.get_meta_pref('moduleName');
            if ~isequal(mp.choices,opts) % Only update if different
                if ~isempty(mp.value)
                    % If we need to reset it, we also need to re-grab the metapref
                    obj.moduleName = '';
                    mp = obj.get_meta_pref('moduleName');
                end
                mp.choices = opts;
                obj.set_meta_pref('moduleName',mp);
                notify(obj,'update_settings');
            end
            host = obj.loadLaser();
        end
        function val = set_etalon_percent(obj,val,~)
            if isnan(val); return; end % Short circuit on NaN
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_host')
            if obj.updatingVal; return; end
            obj.solstisHandle.set_etalon_percent(val);
            obj.updateStatus();
        end
        function val = set_etalon_lock(obj,val,~)
            % Changing etalon lock changes resonator too
            if isnan(val); return; end % Short circuit on NaN
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_host')
            assert(islogical(val)||val==0||val==1,'Value must be true/false')
            if obj.updatingVal; return; end
            if val
                strval = 'on';
            else
                strval = 'off';
            end
            obj.solstisHandle.set_etalon_lock(strval);
            obj.updateStatus();
        end
        function val = set_resonator_percent(obj,val,~)
            if isnan(val); return; end % Short circuit on NaN
            if obj.updatingVal; return; end
            obj.TunePercent(val);
        end
        function val = set_target_wavelength(obj,val,~)
            if isnan(val); return; end % Short circuit on NaN
            if obj.updatingVal; return; end
            obj.tune(val);
        end
        function val = set_wavelength_lock(obj,val,~)
            if isnan(val); return; end % Short circuit on NaN
            if obj.updatingVal; return; end
            obj.WavelengthLock(val);
        end

        function val = set_PBline(obj,val,~)
            if ~isempty(obj.PulseBlaster)
                obj.source_on = obj.PulseBlaster.lines(obj.PB_line).state;
            end
        end
        function host = set_pb_host(obj,host,~)
            err = obj.connect_driver('PulseBlaster','PulseBlaster',host);
            if isempty(obj.PulseBlaster)
                host = obj.no_server;
                obj.pb_host = host; % Set explicitly because might error below if we got here
            else
                obj.source_on = obj.PulseBlaster.lines(obj.PB_line).state;
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
    end
end
