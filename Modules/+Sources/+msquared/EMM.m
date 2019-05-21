classdef EMM < Modules.Source & Sources.TunableLaser_invisible
    % EMM Mainly to implement coarse tuning and solstis resonator tuning.
    % Similar to the SolsTiS, this cannot load if the SolsTiS is loaded
    % already. It will error in loading the solstis driver.
    %
    % Do not trust any reported values! Always update status if you want to read a value.
    %
    % When setting hwserver_ip, it is important that this class loads the
    % solstis driver before the EMM in case it is in use and needs to
    % report an error instead of loading.
    %
    % EMM takes control of solstis by updating wavemeter channel. As such,
    % the solstis wavelength query is used here too.
    %
    % NOTE: might be a way to inherit Sources.msquared.SolsTiS and cut way
    % back on redundant code. Would need to consider how to overload
    % setmethods in this subclass and consider where prefs get loaded
    
    properties(SetObservable,SetAccess=private)
        source_on = false;  % Always assume on (cant be changed here)
    end
    properties(SetAccess=protected)
        % total tunable range in THz (should be updated when crystal changed; see obj.fitted_oven)
        range = Sources.TunableLaser_invisible.c./[580,661];
    end
    properties(SetObservable,AbortSet)
        tuning = false;
        hwserver_ip = Sources.msquared.EMM.no_server;
        resonatorVoltageToPercentCalibration = [-0.000425732939240   0.599558121753631  -5.361161084160642]; %second order polynomial
        fitted_oven = 1;        % Readable (crystal being used: 1,2,3). This also sets range
        etalon_percent = 0;  % Settable
        etalon_voltage = 0;  % Readable
        etalon_lock = false;  % Settable
        resonator_percent = 0;  % Settable
        resonator_voltage = 0;  % Readable
        target_wavelength = 0; % nm settable
        wavelength_lock = false; % settable (so this is necessary ontop of "locked")
        resonator_tune_speed = 0.5; % percent per step
        PBline = 1; % Indexed from 1
        pb_ip = Sources.msquared.EMM.no_server;
        prefs = {'hwserver_ip','PBline','pb_ip','resonator_tune_speed'};
        show_prefs = {'tuning','target_wavelength','wavelength_lock','etalon_lock','fitted_oven','resonator_percent','resonator_voltage','etalon_percent','etalon_voltage','hwserver_ip','PBline','pb_ip','resonator_tune_speed'};
        readonly_prefs = {'tuning','fitted_oven','resonator_voltage','etalon_voltage'};
    end
    properties(Access=private)
        PulseBlaster  % handle to PulseBlaster Driver
        solstisHandle % handle to Solstis Driver
        emmHandle     % handle to EMM driver
        timeout = 30;
    end
    properties(Constant,Hidden)
        no_server = 'No Server';  % Message when not connected
    end
    
    methods(Access=private)
        function obj = EMM()
            obj.hwserver_ip = obj.no_server; % Default value (overriden in loadPrefs if saved)
            obj.pb_ip = obj.no_server; % Default value (overriden in loadPrefs if saved)
            obj.loadPrefs;  % This will call set.(*_ip) too which instantiate hardware
            obj.updateStatus(); % Redundant with set.(*_ip) but useful for if no ip pref
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
        function err = connect_driver(obj,propname,drivername,varargin)
            err = [];
            if ~isempty(obj.(propname))
                delete(obj.(propname)); %remove any old connection
            end
            if ischar(varargin{1}) && strcmpi(varargin{1},obj.no_server) %first input is always an ip address
                obj.(propname) = [];
            else
                try
                    obj.(propname) = Drivers.(drivername).instance(varargin{:});
                catch err
                    obj.(propname) = [];
                end
            end
        end
        function tf = internal_call(obj)
            tf = false; % Assume false, verify that true later
            st = dbstack(2);  % Exclude this method, and its caller
            if ~isempty(st)
                caller_class = strsplit(st(1).name,'.');
                caller_class = caller_class{1};
                this_class = strsplit(class(obj),'.');
                this_class = this_class{end};
                tf = strcmp(this_class,caller_class);
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
            % Get status report from laser and update a few fields
            % This kills man-in-the-middle!!
            if strcmp(obj.hwserver_ip,obj.no_server)
                obj.locked = false; %NaN; logical cannot be NaN or creation of the ui is failing
                obj.etalon_lock = false;
                obj.etalon_voltage = NaN;
                obj.resonator_voltage = NaN;
                obj.wavelength_lock = false; %NaN;
                obj.fitted_oven = NaN;
            else
                reply = obj.solstisHandle.getStatus();
                obj.etalon_lock = strcmp(reply.etalon_lock,'on');
                obj.etalon_voltage = reply.etalon_voltage;
                obj.resonator_voltage = reply.resonator_voltage;
                obj.getWavelength; % This sets wavelength_lock
                
                reply = obj.emmHandle.getStatus();
                obj.fitted_oven = reply.fitted_oven;
                obj.tuning = strcmp(reply.tuning,'active'); % Overwrite getWavelength tuning status with EMM tuning state
            end
        end
        
        function on(obj)
            assert(~isempty(obj.PulseBlaster),'No PulseBlaster IP set!')
            obj.PulseBlaster.lines(obj.PBline) = true;
            obj.source_on = true;
        end
        function off(obj)
            assert(~isempty(obj.PulseBlaster),'No PulseBlaster IP set!')
            obj.source_on = false;
            obj.PulseBlaster.lines(obj.PBline) = false;
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
        
        function [wavelength] = getWavelength(obj)
            % Use solstis handle to get wavelength
            % Attempt to get non-error value until timeout
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
            obj.setpoint = obj.c/wavelength;
            obj.tuning = istuning;
            obj.wavelength_lock = lock;
            obj.locked = lock;
        end
        
        function resonatorPercent = resonatorVoltageToPercent(obj,voltage)
            resonatorPercent = obj.resonatorVoltageToPercentCalibration(1)*voltage^2 ...
                +obj.resonatorVoltageToPercentCalibration(2)*voltage+obj.resonatorVoltageToPercentCalibration(3);
        end
        function tune(obj,target)
            % This is the tuning method that interacts with hardware
            % (potentially a very expensive operation if switching from
            % solstis)
            % target in nm
            assert(~isempty(obj.emmHandle)&&isobject(obj.emmHandle) && isvalid(obj.emmHandle),'no emmHandle, check hwserver_ip')
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
                obj.trackFrequency; % Will block until obj.tuning = false (calling obj.getFrequency)
            catch err
            end
            delete(dlg);
            obj.tuning = false;
            if ~isempty(err)
                obj.locked = false;
                obj.wavelength_lock = false;
                obj.setpoint = NaN;
                rethrow(err)
            end
            obj.setpoint = obj.c/target;
            obj.locked = true;
            obj.wavelength_lock = true;
            obj.etalon_lock = true;  % We don't know at this point anything about etalon if not locked
        end
        
        function WavelengthLock(obj,lock)
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_ip')
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
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_ip')
            assert(target>=0&&target<=100,'Target must be a percentage')
            % tune at a limited rate per step
            currentPercent = obj.GetPercent;
            numberSteps = floor(abs(currentPercent-target)/obj.resonator_tune_speed);
            direction = sign(target-currentPercent);
            for i = 1:numberSteps
                obj.solstisHandle.set_resonator_percent(currentPercent+(i)*direction*obj.resonator_tune_speed);
            end
            obj.solstisHandle.set_resonator_percent(target);
            obj.resonator_percent = target;
            obj.updateStatus(); % Get voltage of resonator
        end
        
        % Set methods
        function set.hwserver_ip(obj,ip)
            % solstis
            err = obj.connect_driver('solstisHandle','msquared.solstis',ip);
            if ~isempty(err)
                obj.hwserver_ip = obj.no_server;
                obj.updateStatus();
                if contains(err.message,'driver is already instantiated')
                    error('solstis driver already instantiated. Likely due to an active SolsTiS source; please close it and retry.')
                end
                rethrow(err)
            end
            % EMM (if here, we can assume solstis loaded correctly)
            err = obj.connect_driver('emmHandle','msquared.EMM',ip);
            if ~isempty(err)
                obj.hwserver_ip = obj.no_server;
                obj.updateStatus();
                delete(obj.solstisHandle);
                obj.solstisHandle = [];
                error('solstis loaded, but EMM failed. Solstis handle destroyed:\n%s',err.message);
            end
            % Can only get here if both successful
            obj.hwserver_ip = ip;
            obj.updateStatus();
        end
        function set.target_wavelength(obj,val)
            if isnan(val); obj.target_wavelength = val; return; end % Short circuit on NaN
            if obj.internal_call; obj.target_wavelength = val; return; end
            obj.tune(val);
        end
        function percent = GetPercent(obj)
                obj.updateStatus();
                percent =  obj.resonatorVoltageToPercent(obj.resonator_voltage);
        end
        function set.wavelength_lock(obj,val)
            if isnan(val); obj.wavelength_lock = val; return; end % Short circuit on NaN
            if obj.internal_call; obj.wavelength_lock = val; return; end
            obj.WavelengthLock(val);
        end
        function set.resonator_percent(obj,val)
            if isnan(val); obj.resonator_percent = val; return; end % Short circuit on NaN
            if obj.internal_call; obj.resonator_percent = val; return; end
            obj.TunePercent(val);
        end
        function set.etalon_percent(obj,val)
            if isnan(val); obj.etalon_percent = val; return; end % Short circuit on NaN
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_ip')
            assert(val>=0&&val<=100,'Value must be a percentage')
            if obj.internal_call; obj.etalon_percent = val; return; end
            obj.solstisHandle.set_etalon_percent(val);
            obj.etalon_percent = val;
            obj.updateStatus(); % Update the value of the voltage
        end
        function set.etalon_lock(obj,val)
            % Changing etalon lock changes resonator too
            if isnan(val); obj.etalon_lock = val; return; end % Short circuit on NaN
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_ip')
            assert(islogical(val)||val==0||val==1,'Value must be true/false')
            if obj.internal_call; obj.etalon_lock = val; return; end
            if val
                strval = 'on';
            else
                strval = 'off';
            end
            obj.solstisHandle.set_etalon_lock(strval);
            obj.etalon_lock = val;
        end
        function set.fitted_oven(obj,val)
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
        function updateCalibration(obj,range)
            for i = 1:length(range)
                obj.TunePercent(range(i));
                pause(0.1)
                obj.updateStatus;
                voltages(i) = obj.resonator_voltage;
            end
            ft = fittype( 'poly2' );
            opts = fitoptions( 'Method', 'LinearLeastSquares' );
            [fitresult, gof] = fit( voltages, range, ft, opts );
            obj.resonatorVoltageToPercentCalibration = coeffvalues(fitresult);
        end
        
        %PB methods
        function set.pb_ip(obj,ip)
            err = obj.connect_driver('PulseBlaster','PulseBlaster.StaticLines',ip);
            if isempty(obj.PulseBlaster)
                obj.pb_ip = obj.no_server;
            else
                obj.pb_ip = ip;
                obj.source_on = obj.PulseBlaster.lines(obj.PBline);
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        
        function set.PBline(obj,val)
            assert(round(val)==val&&val>0,'PBline is indexed from 1.')
            obj.PBline = val;
            if ~isempty(obj.PulseBlaster)
                obj.source_on = obj.PulseBlaster.lines(obj.PBline);
            end
        end
        
    end
end

