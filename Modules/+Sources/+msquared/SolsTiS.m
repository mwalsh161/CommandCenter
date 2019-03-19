classdef SolsTiS < Modules.Source & Sources.TunableLaser_invisible
    %SOLSTIS Control parts of SolsTis (msquared) laser
    %   Talks via the hwserver (via the driver)
    %   All methods go through a set.method to perform operation
    %
    % Similar to the EMM, this cannot load if the EMM is loaded
    % already. It will error in loading the solstis driver.
    %
    % A few notes:
    %   - updateStatus will set showprefs to NaN if no server
    %   - The range of this laser is updated upon successful connection to
    %       Drivers.msquared.solstis
    %   - The etalon lock removal resets resonator percentage/voltage and
    %       is not updated in this source
    %   - tune and WavelengthLock will try and track frequency as tuning
    %       (both use a pause(1) to wait for msquared to begin tuning)
    %   - updateStatus at the end of the set methods may be executed before
    %       the operation on the laser has finished (setting outdated values)

    properties
        timeout = 1; % Ignore errors within this timeout on wavelength read (used in getWavelength)
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;  % Always assume on (cant be changed here)
    end
    properties(SetAccess=protected)
        range = Sources.TunableLaser_invisible.c./[700,1000]; %tunable range in THz
    end
    properties(SetObservable,AbortSet)
        resonatorVoltageToPercentCalibration = [-0.000425732939240   0.599558121753631  -5.361161084160642]; %second order polynomial
        tuning = false;
        hwserver_ip = Sources.msquared.SolsTiS.no_server;
        etalon_percent = 0;  % Settable
        etalon_voltage = 0;  % Readable
        etalon_lock = false;  % Settable
        resonator_percent = 0;  % Settable
        resonator_voltage = 0;  % Readable
        target_wavelength = 0; % nm settable
        wavelength_lock = false; % Settable
        PBline = 1; % Indexed from 1
        resonator_tune_speed = 2; % percent per step
        pb_ip = Sources.msquared.SolsTiS.no_server;
        prefs = {'hwserver_ip','PBline','pb_ip'};
        show_prefs = {'tuning','target_wavelength','wavelength_lock','etalon_lock','resonator_percent','resonator_voltage','etalon_percent','etalon_voltage','hwserver_ip','PBline','pb_ip'};
        readonly_prefs = {'tuning','resonator_voltage','etalon_voltage'};
    end
    properties(Access=private)
        PulseBlaster   % handle to PulseBlaster Driver
        solstisHandle % handle to Solstis Driver
    end
    properties(Constant,Hidden)
        no_server = 'No Server';  % Message when not connected
    end
    
    methods(Access=private)
        function obj = SolsTiS()
            obj.hwserver_ip = obj.no_server; % Default value (overriden in loadPrefs if saved)
            obj.pb_ip = obj.no_server; % Default value (overriden in loadPrefs if saved)
            obj.loadPrefs;  % This will call set.(*_ip) too which instantiate hardware
            obj.updateStatus();
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
                Object = Sources.msquared.SolsTiS();
            end
            obj = Object;
        end
    end
    methods
        function resonatorPercent = resonatorVoltageToPercent(obj,voltage)
            resonatorPercent = obj.resonatorVoltageToPercentCalibration(1)*voltage^2 ...
            +obj.resonatorVoltageToPercentCalibration(2)*voltage+obj.resonatorVoltageToPercentCalibration(3);
        end
        function updateStatus(obj)
            % Get status report from laser and update a few fields
            if strcmp(obj.hwserver_ip,obj.no_server)
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
        function percent = GetPercent(obj)
                obj.updateStatus();
                percent =  obj.resonatorVoltageToPercent(obj.resonator_voltage);
        end
        function delete(obj)
            if ~isempty(obj.solstisHandle)
                delete(obj.solstisHandle);
            end
        end
        function [wavelength] = getWavelength(obj)
            % Attempt to get non-error value until timeout
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_ip')
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
            if lock
                obj.etalon_lock = true;
            end
        end
        function tune(obj,target)
            % This is the tuning method that interacts with hardware
            % target in nm
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_ip')
            assert(target>obj.c/max(obj.range)&&target<obj.c/min(obj.range),sprintf('Wavelength must be in range [%g, %g] nm!!',obj.c./obj.range))
            obj.solstisHandle.set_target_wavelength(target);
            obj.target_wavelength = target;
            obj.tuning = true;
            pause(1) % Wait for msquared to start tuning
            obj.trackFrequency; % Will block until obj.tuning = false (calling obj.getFrequency)
            obj.updateStatus();
        end
        
        % tunable laser methods
        function freq = getFrequency(obj)
            wavelength = obj.getWavelength;
            freq = obj.c/wavelength;
        end
        function TuneCoarse(obj,target)
            obj.tune(obj.c/target);
            if obj.locked
                obj.WavelengthLock(false);
            end
        end
        function TuneSetpoint(obj,target) % THz
            obj.tune(obj.c/target);
        end
        function TunePercent(obj,target)
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_ip')
            assert(target>=0&&target<=100,'Target must be a percentage')
            % tune at a limited rate per step
            currentPercent = obj.GetPercent;
            numberSteps = mod(abs(currentPercent-target),obj.resonator_tune_speed);
            direction = sign(target-currentPercent);
            for i = 1:numberSteps
                obj.solstisHandle.set_resonator_percent(currentPercent+(i)*direction*obj.resonator_tune_speed);
            end
            obj.solstisHandle.set_resonator_percent(target);
            obj.resonator_percent = target;
            obj.updateStatus(); % Get voltage
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
            obj.wavelength_lock = lock;
            obj.updateStatus(); % Get resonator/etalon
        end
        function EtalonLock(obj,lock)
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_ip')
            assert(islogical(lock)||lock==0||lock==1,'lock must be true/false')
            if lock
                lock = 'on';
            else
                lock = 'off';
            end
            obj.solstisHandle.set_etalon_lock(lock);
        end
        
        % Set methods
        function set.hwserver_ip(obj,ip)
            if isempty(ip); return; end % Short circuit on empty IP
            err = obj.connect_driver('solstisHandle','msquared.solstis',ip);
            if ~isempty(err)
                obj.hwserver_ip = obj.no_server;
                obj.updateStatus();
                if contains(err.message,'driver is already instantiated')
                    error('solstis driver already instantiated. Likely due to an active EMM source; please close it and retry.')
                end
                rethrow(err)
            end
            range = obj.solstisHandle.get_wavelength_range; %#ok<*PROPLC> % solstis hardware handle
            obj.range = obj.c./[range.minimum_wavelength, range.maximum_wavelength];
            obj.hwserver_ip = ip;
            obj.updateStatus();
        end
        function set.target_wavelength(obj,val)
            if isnan(val); obj.target_wavelength = val; return; end % Short circuit on NaN
            if obj.internal_call; obj.target_wavelength = val; return; end
            obj.tune(val);
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
        % Set methods without parent method to interact with hardware
        function set.etalon_percent(obj,val)
            if isnan(val); obj.etalon_percent = val; return; end % Short circuit on NaN
            assert(~isempty(obj.solstisHandle)&&isobject(obj.solstisHandle) && isvalid(obj.solstisHandle),'no solstisHandle, check hwserver_ip')
            assert(val>=0&&val<=100,'Value must be a percentage')
            if obj.internal_call; obj.etalon_percent = val; return; end
            obj.solstisHandle.set_etalon_percent(val);
            obj.etalon_percent = val;
            obj.updateStatus();
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
            obj.updateStatus();
        end
        
        %PB methods
        function set.pb_ip(obj,ip)
            err = obj.connect_driver('PulseBlaster','PulseBlaster.StaticLines',ip);
            if ~isempty(err)
                obj.pb_ip = obj.no_server;
                rethrow(err)
            end
            obj.pb_ip = ip;
            obj.source_on = obj.PulseBlaster.lines(obj.PBline);
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

