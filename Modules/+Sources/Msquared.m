classdef Msquared < Modules.Source & Sources.TunableLaser_invisible
    % MSQUARED is a driverless unified class for SolsTiS, EMM, and ECD-X control.
    %   Tune by either using the tune(frequency) method or .setpoint_ = wavelength pref.
    
    properties(Access=private, Hidden)
        hwserver = [];          % TCPIP handle to the python hardware server for laser and wavemeter connectivity.
        PulseBlaster = [];      % Handle to the appropriate Drivers.PulseBlaster.
        updatingVal = false;    % Flag to prevent attempting to tune to multiple wavelengths at once.
        output_monitor = 0;     % Output of the SolsTiS photodiode. Used for determining whether the laser is armed.
        aborted = false;        % Flag to check whether we aborted during a scan.
    end
    
    properties(SetAccess=protected)
        range = [-Inf Inf];     % Ignoring limits for now. % Sources.TunableLaser_invisible.c./[700,1000]; %tunable range in THz
    end
    
    properties
        prefs = {'hwserver_host', 'moduleName', 'center_percent', 'early_abort', 'do_etalon_lock', 'do_wavelength_lock', 'NIR_channel', 'VIS_channel', 'PB_line', 'PB_host'}
        show_prefs = {};
    end
    
    properties (Constant, Hidden)
        moduleNIR = 'SolsTiS';
        moduleVIS = 'EMM';
        moduleUV =  'ECD-X';
        
        no_server = 'No Server';
        
        statusList = {'Open Loop', 'No Wavemeter', 'Tuning', 'Closed Loop'};    % Interpretation of msquared status (see callGetWavelength).
        lockList = {'off', 'on'};                                               % Used to convert logical 0/1 to 'off'/'on' for comms with the laser.
        
        emm_tolerance = .001 % nm                                               % If we are further away than this, assumed bad diff_wavelength estimate.
    end
    
    properties(SetObservable,GetObservable)
        % BASE prefs
        moduleName =        Prefs.MultipleChoice('set', 'set_moduleName', 'allow_empty', true, 'choices', {'msquared.NW', 'msquared.SE'}, ...
                                                                    'help_text', 'Which of our two lasers to use.'); % 'Modules will be loaded when a hwserver hostname is supplied.');
        hwserver_host =     Prefs.String(Sources.Msquared.no_server, 'set', 'set_hwserver_host', ...
                                                                    'help_text', 'The host for the laser and wavemeter');
        refresh =           Prefs.Button('unit', 'Poll hwserver',   'get', 'get_refresh', 'set', 'set_refresh', ... 
                                                                    'help_text', 'Get information (voltages, wavelengths, states) from the laser and wavemeters');
        abort =             Prefs.Button('unit', 'Stop Tuning',     'set', 'set_abort', ...
                                                                    'help_text', 'Stop the current tuning operation.');
        
        % WAVELENGTH prefs
        setpoint_ =         Prefs.Double(NaN,   'unit', 'nm',  'set', 'set_target_wavelength', ...
                                                                    'help_text', 'Use this knob to tune the laser to a certain wavelength. Availible ranges: ECD-X (350-525), EMM (515-582/580-661), SolsTiS (700-1100). The laser will decide the appropriate module to use based on the chosen wavelength');
        center_percent =    Prefs.Boolean(false, ...
                                                                    'help_text', 'Whether to attempt to target resonator_voltage = 50% after tuning (currently hardcoded to be between 40% and 60% [between 80V and 120V]). This is done by repeatedly moving to and from the target wavelength until a good resonator percent value is found.');
        early_abort =       Prefs.Boolean(false, ...
                                                                    'help_text', 'Abort when within .01 nm.');
        active_module =     Prefs.MultipleChoice(Sources.Msquared.moduleNIR, 'readonly', true, 'allow_empty', true, 'choices', {Sources.Msquared.no_server, Sources.Msquared.moduleUV, Sources.Msquared.moduleVIS, Sources.Msquared.moduleNIR}, ... %{'ECD-X', 'EMM', 'SolsTiS'}, ...
                                                                    'help_text', 'ECD-X (350-525), EMM (515-582/580-661), SolsTiS (700-1100)');
        status =            Prefs.String(Sources.Msquared.no_server, 'readonly', true, ...
                                                                    'help_text', 'Current tuning status of the laser.');
        tuning =            Prefs.Boolean(NaN, 'readonly', true, 'allow_nan', true, ...
                                                                    'help_text', 'Required by TunableLaser_invisible. True if status == Tuning.');
%         emm_crystal =       Prefs.Integer(2,   'readonly', true, 'set', 'set_fitted_oven', ...
%                                                                     'help_text', 'Crystal being used: 1,2,3. This also sets range');
        
        % WAVEMETER prefs
        solstis_setpoint =  Prefs.Double(NaN,   'unit', 'nm',  'readonly', true, ...
                                                                    'help_text', 'Target wavelength for the SolsTiS Ti:Saph');
        emm_setpoint =      Prefs.Double(NaN,   'unit', 'nm',  'readonly', true, ...
                                                                    'help_text', 'Target wavelength for the alignment of the EMM PPLN');
        NIR_wavelength =    Prefs.Double(NaN,   'unit', 'nm',  'readonly', true, ...
                                                                    'help_text', 'Wavemeter output for the current wavelength of this msquared laser''s SolsTiS. Additionally, this is double the ECD-X output wavelength, if this module is used.');
        VIS_wavelength =    Prefs.Double(NaN,   'unit', 'nm',  'readonly', true, ...
                                                                    'help_text', 'Wavemeter output for the current wavelength of this msquared laser''s EMM, if an EMM is connected.');
        diff_wavelength =   Prefs.Double(1950,  'unit', 'nm',  'readonly', true, ...
                                                                    'help_text', 'Calculated EMM difference wavelength that is used to target EMM wavelengths via controlling the SolsTiS via 1/EMM_wl = 1/SolsTiS_wl - 1/diff_wl. This wavelength is roughly 1950, but is calculated and updated based on wavemeter measurments to catch and compensate drift.');
        NIR_channel =       Prefs.Integer(6,    'min', 1, 'max', 8, ...
                                                                    'help_text', 'Wavemeter channel for this msquared laser''s SolsTiS. Indexed from 1.');
        VIS_channel =       Prefs.Integer(7,    'min', 1, 'max', 8, ...
                                                                    'help_text', 'Wavemeter channel for this msquared laser''s EMM. Indexed from 1.');
                                                                
        % ETALON prefs
        do_etalon_lock =    Prefs.Boolean(false,                'set', 'set_do_etalon_lock', ...
                                                                    'help_text', 'Default for whether to hold the etalon lock. Note that disabling this auto-disables do_wavelength_lock, as the etalon must be locked for the wavelength to be locked.');
        etalon_lock =       Prefs.Boolean(false,                'readonly', true, 'allow_nan', true, ... 'set', 'set_etalon_lock', ...
                                                                    'help_text', 'Whether a lock is applied to the etalon.');
        etalon_percent =    Prefs.Double(NaN,   'unit', '%',   'set', 'set_etalon_percent', 'min', 0, 'max', 100, ...
                                                                    'help_text', 'Apply fine tuning to the etalon in units of percent of total range (0 -> 200 V).');
        etalon_voltage =    Prefs.Double(NaN,   'unit', 'V',   'readonly', true, ...
                                                                    'help_text', 'The amount of fine tuning upon the etalon. Maybe rename this. Interact with this via etalon_percent.');
        
        % RESONATOR prefs
        do_wavelength_lock= Prefs.Boolean(false,                'set', 'set_do_wavelength_lock', ...
                                                                    'help_text', 'Default for whether to hold the wavelength lock. When using an external voltage or the resonator percentage to finely tune the laser, this should be *off*, lest this active feedback negates your desired tuning.');
        wavelength_lock =   Prefs.Boolean(false,                'readonly', true, 'allow_nan', true, ... 'set', 'set_wavelength_lock', ...
                                                                    'help_text', 'Whether the laser is currently using the wavemeter for closed loop locking to the setpoint. Note that this is different from the resonator lock, which is not implemented in this interface.');
        resonator_percent = Prefs.Double(NaN,   'unit', '%',   'set', 'set_resonator_percent', 'min', 0, 'max', 100,...
                                                                    'help_text', 'Apply fine tuning to the resonator in units of percent of total range (0 -> 200 V).');
        resonator_voltage = Prefs.Double(NaN,   'unit', 'V',   'readonly', true, ...
                                                                    'help_text', 'The amount of fine tuning upon the resonator. Interact with this via resonator_percent.');

        % PULSEBLASTER prefs
        PB_host =           Prefs.String(Sources.Msquared.no_server, 'set', 'set_PB_host');
        PB_line =           Prefs.Integer(1, 'min', 1, 'set', 'set_PB_line', 'help_text', 'Indexed from 1.');
    end
    
    methods(Access=private)
        function obj = Msquared()
            obj.loadPrefs;      % This will call set_hwserver_host, which will instantiate the hardware.
            obj.getFrequency(); % Update prefs based on current values.
        end
    end
    methods(Static)
        function obj = instance()                   % Standard instance method to prevent duplication.
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.Msquared();
            end
            obj = Object;
        end
    end
    
    methods     % Helper methods for laser/wavemeter communication/datapolling.
        function reply = com(obj, fn, varargin)     % Helper function for hwsever communication (fills in moduleName and deals with reserved clients).
            if isempty(obj.moduleName); return; end
            
            try
                reply = obj.hwserver.com(obj.moduleName, fn, varargin{:});
            catch err
                if contains(err.message, 'Another client was using')
                    % Grab line with exception in it
                    exception = strsplit(err.message, newline);
                    mask = cellfun(@(a)startswith(a, 'Exception: '), exception);
                    exception = exception{mask};
                    answer = questdlg(sprintf('%s\nDo you want to override the other client?', exception),...
                        mfilename, 'Yes', 'No', 'No');
                    if strcmp(answer,'Yes')
                        % Override and recall
                        obj.com('force_client');
                        reply = obj.hwserver.com(obj.moduleName, fn, varargin{:});
                        return
                    else
%                         error(exception);
                        rethrow(err);
                    end
                else
                    % obj.hwserver_host = obj.no_server;
                end
            end
        end
        
        function callGetWavelength(obj)             % Calls the solstis method 'get_wavelength' and fills prefs in.
            if isempty(obj.hwserver) || ~isvalid(obj.hwserver) || isempty(obj.moduleName)
                obj.status = obj.no_server;
                obj.tuning = false;
                obj.NIR_wavelength = NaN;
                obj.wavelength_lock = NaN;
                obj.locked = NaN;
            else
                try
                    reply = obj.com('get_wavelength', 'solstis');

                    obj.status =            obj.statusList{reply.status+1};
                    obj.tuning =            reply.status == 2;
                    obj.NIR_wavelength =    reply.current_wavelength;
                    obj.wavelength_lock =   logical(reply.lock_status);
                    obj.locked =            logical(reply.lock_status);
                catch
                    warning('SolsTiS get_wavelength call failed; leaving variables unchanged.')
                end
            end
        end
        function callStatus(obj)                    % Calls the solstis method 'status' and fills prefs in.
            % Get status report from SolsTiS laser and update fields
            if isempty(obj.hwserver) || ~isvalid(obj.hwserver) || isempty(obj.moduleName)
                obj.etalon_lock = NaN;
                obj.etalon_voltage = NaN;
%                 obj.resonator_lock = false;                           % Future: add this to the interface?
                obj.resonator_voltage = NaN;
                obj.output_monitor = NaN;
                obj.armed = NaN;
            else
                try
                    reply = obj.com('status', 'solstis');

                    obj.etalon_lock =       strcmp(reply.etalon_lock,'on');
                    obj.etalon_voltage =    reply.etalon_voltage;
    %                 obj.resonator_lock =    strcmp(reply.cavity_lock,'on');   % Future: add this to the interface?
                    obj.resonator_voltage = reply.resonator_voltage;
                    obj.output_monitor =    reply.output_monitor;
                    obj.armed =             obj.get_armed();
                catch
                    warning('SolsTiS status call failed; leaving variables unchanged.')
                end
            end
        end
        
        function getWavemeterWavelength(obj)        % Measures the output wavelength directly from the wavemeter. Also uses the EMM channel if the EMM module is active.
            if isempty(obj.hwserver) || ~isvalid(obj.hwserver)
                obj.NIR_wavelength =  NaN;
                obj.VIS_wavelength =  NaN;
                obj.diff_wavelength = 1950;
            else
%                 obj.NIR_wavelength = obj.hwserver.com('wavemeter', 'GetWavelengthNum', obj.NIR_channel, 0);
%                 
%                 % If the proper channel is off but the laser should be outputting power...
%                 if obj.NIR_wavelength == 0 && obj.laserOn()
%                     obj.hwserver.com('wavemeter', 'SetSwitcherSignalStates', obj.NIR_channel, 1, 1);
%                     obj.NIR_wavelength = obj.hwserver.com('wavemeter', 'GetWavelengthNum', obj.NIR_channel, 0);
%                 end

                % If we need to grab the visible wavelength...
                if strcmp(obj.determineModule(obj.setpoint_), obj.moduleVIS)
                    obj.VIS_wavelength = obj.hwserver.com('wavemeter', 'GetWavelengthNum', obj.VIS_channel, 0);
                    
                    % If the proper channel is but and the laser should be outputting power...
                    if obj.VIS_wavelength == 0 && obj.laserOn()
                        obj.hwserver.com('wavemeter', 'SetSwitcherSignalStates', obj.VIS_channel, 1, 1);
                        obj.VIS_wavelength = obj.hwserver.com('wavemeter', 'GetWavelengthNum', obj.VIS_channel, 0);
                    end
                    
                    % Do math on the wavelengths if they are real
                    if obj.VIS_wavelength > 0 && obj.NIR_wavelength > 0
                        diff_wavelength_ = 1/(1/obj.VIS_wavelength - 1/obj.NIR_wavelength);

                        if diff_wavelength_ > 1949 && diff_wavelength_ < 1951   % This range is just so a silly value isn't set. Not sure if this is a good range.
                            obj.diff_wavelength = diff_wavelength_;
                        end
                    elseif obj.VIS_wavelength <= 0
                        obj.VIS_wavelength = NaN;
                    end
                else
%                     if obj.VIS_channel ~= obj.NIR_channel && ~isnan(obj.VIS_channel)
%                         obj.hwserver.com('wavemeter', 'SetSwitcherSignalStates', obj.VIS_channel, 0, 0);
%                     end
%                     obj.VIS_wavelength = NaN;
                end
            end
        end
    end
    
    methods(Hidden)
        % Helper method to check if hwserver is connected and the laser is armed.
        function tf = laserOn(obj)
            tf = ~isempty(obj.hwserver) && isobject(obj.hwserver) && isvalid(obj.hwserver) && ~isnan(obj.armed) && obj.armed;
        end
    end
    
    methods     % The meat of this tunable source.
        function tune(obj, target, recursion)       % This is the tuning method that interacts with hardware (target in nm)
            if isnan(target); return; end           % Do nothing if NaN
            obj.aborted = false;
            if nargin < 3
                recursion = 0;
            end
            if recursion >= 3
                return
            end
            
            % Make sure we are connected
            assert(~isempty(obj.hwserver) && isobject(obj.hwserver) && isvalid(obj.hwserver), 'No hwserver host!')
            
            % If we don't think we are armed...
            if isnan(obj.armed) || ~obj.armed
                obj.callStatus(); % ...Check...
                assert(~isnan(obj.armed) && obj.armed, 'Laser must be armed to tune!')  % ...And error if blacked out.
            end
            
            % Decide which hardware we need.
            module = obj.determineModule(target);
            if isempty(module)
                error(['Wavelength ' num2str(target) ' nm is outside the range of this msquared laser.'])
            end
            obj.active_module = module;
            
            % With error-handling done, proclaim that we are updating.
            obj.updatingVal = true;
            
            % Turn the visible channel off at the start of every tune, for speed.
            if obj.VIS_channel ~= obj.NIR_channel && ~isnan(obj.VIS_channel)
                obj.hwserver.com('wavemeter', 'SetSwitcherSignalStates', obj.VIS_channel, 0, 0);
            end

            % If necessary, tune the EMM PPLN setpoint
            if strcmp(module, obj.moduleVIS)
                obj.emm_setpoint = target;
                try
                    out = obj.com('set_wavelength', 'EMM', target, 0); % last arg is timeout

                    if out.status ~= 0
                        error('Failed to set EMM target')
                    end
                catch
                    disp('EMM Failure')
                    % expected?
                end
            else
                obj.emm_setpoint = NaN;
            end

            attempting = true;
            failcount = 0;
            centercount = 0;

            % Main loop
            while attempting
                try
                    failcount = failcount + 1;

                    if failcount > 5
                        attempting = false;
                    end
%                     if centercount > 5
%                         attempting = false;
%                     end
                    
                    nir_wavelength = obj.determineNIRWavelength(target);
                    obj.solstis_setpoint = nir_wavelength;
                    out = obj.com('set_wavelength', 'solstis', nir_wavelength, 0); % last arg is timeout

                    if out.status == 0  % Call success
                        obj.trackFrequency(obj.c/target, 60);   % Will block until obj.tuning = false (calling obj.getFrequency each tick). Timeout of 60 sec.
                        
                        if ~obj.tuning  % If we are not still tuning...
                            if ~obj.center_percent || (obj.resonator_voltage < 120 && obj.resonator_voltage > 80)    % If we are good with anything or we are inside the acceptable range...
                                attempting = false;
                            else
                                detuning = 1 - 2*(nir_wavelength > 900);    % Tune up if wavelength < 900, down otherwise.
                                out = obj.com('set_wavelength', 'solstis', nir_wavelength + detuning, 0);

                                centercount = centercount + 1;
                                
                                if out.status ~= 0  % Call failed
                                    failcount = failcount + 1;
                                end

                                pause(.5);          % After a little bit, continue with the while loop to tune back.
                            end
                        end
                    end
                catch err
                    warning(err.message)
                    obj.hwserver.reload(obj.moduleName);
                end
            end
            obj.updatingVal = false;
            
            % Failcount warning
            if failcount > 5
                warning('Failed to set the SolsTiS wavelength five times, aborting tuning attempt.')
            end
            
            % Abort warning
            if obj.aborted
                warning('SolsTiS aborted tuning operation.')
            end
            
            % Success events
            if ~obj.aborted && failcount <= 5
                warning('SolsTiS success.')
                if strcmp(module, obj.moduleVIS) && abs(obj.VIS_wavelength - target) > obj.emm_tolerance    % If we're off with the EMM, we probably didn't initially have a good reading on the diff_wavelength.
                    obj.tune(target, recursion+1)    % Try tuning again.
                end
                
                % Unlock if desired.
                if      ~obj.do_etalon_lock
                    obj.com('lock_wavelength', 'solstis', obj.lockList{1});
                    obj.com('set_etalon_lock', 'solstis', obj.lockList{1});
                elseif  ~obj.do_wavelength_lock
                    obj.com('lock_wavelength', 'solstis', obj.lockList{1});
                end
                
                % Give time to settle.
                pause(.1);
            
                % Update values.
                obj.getFrequency();
            end
            
            obj.aborted = false;
        end
    end
    
    methods     % Pref set methods.
        function val = set_source_on(obj, val, ~)   % 'Fast' modulation method -- usually the PulseBlaster.
            if ~isempty(obj.PulseBlaster)
                obj.PulseBlaster.lines(obj.PB_line).state = val;
            end
        end
        function val = set_armed(obj, val, ~)       % Checks if the laser is outputting power (i.e. has been armed) and complains if result was contradictory.
            if isnan(val); return; end % Short circuit on NaN
            
            val = obj.get_armed();
        end
        function val = get_armed(obj, ~)
            if isnan(obj.output_monitor)
                val = NaN;
            else
                val = (obj.output_monitor > .01);       % We can tell that the laser is armed if the output monitor is reading power.
            end
        end
        
        function host= set_hwserver_host(obj, host, ~)
            try
                obj.hwserver = hwserver(host); %#ok<CPROPLC>
                obj.hwserver.get_modules();
                obj.getFrequency();
                
                % Update laser list. (This piece of code was breaking due to update_settings trying to update hwserver_host, which is in use. Instead hardcode moduleName options.)
%                 opts = obj.hwserver.get_modules('msquared.');
%                 mp = obj.get_meta_pref('moduleName');
%                 if ~isequal(mp.choices,opts) % Only update if different
%                     if ~isempty(mp.value)
%                         % If we need to reset it, we also need to re-grab the metapref
%                         obj.moduleName = '';
%                         mp = obj.get_meta_pref('moduleName');
%                     end
%                     mp.choices = opts;
%                     obj.set_meta_pref('moduleName', mp);
%                     notify(obj,'update_settings');
%                 end
            catch
                obj.hwserver = [];
                
                host = obj.no_server;
                obj.active_module = host;
                obj.status = host;
                
                obj.armed = NaN;
                obj.locked = NaN;
                obj.tuning = false;
                
                obj.getFrequency();
            end
        end
        function val = set_moduleName(obj,val,~)    % Polls hwserver by calling getFrequency(). Important to do to update settings.
            obj.getFrequency();
        end
        
        function val = set_refresh(obj,val,~)       % Polls hwserver by calling getFrequency().
            obj.getFrequency();
        end
        function val = get_refresh(obj,~)           % Polls hwserver by calling getFrequency().
            val = true;
            try
                obj.getFrequency();
            catch
                val = false;
            end
        end
        
        function val = set_abort(obj,val,~)         % Calls the M^2 method abort_tune to stop the current tuning operation.
            obj.aborted = true;
            
            obj.com('abort_tune', 'solstis');
            
            switch obj.active_module
                case Sources.Msquared.moduleVIS
                    obj.com('abort_tune', 'EMM');
            end
            
            obj.getFrequency();
            
%             if obj.laserOn()
%                 if obj.do_wavelength_lock && ~obj.wavelength_lock
%                     obj.com('lock_wavelength', 'solstis', obj.lockList{2});
%                 elseif  obj.do_etalon_lock && ~obj.etalon_lock
%                     obj.com('set_etalon_lock', 'solstis', obj.lockList{2});
%                 end
%             end
        end
        
        function val = set_PB_line(obj,val,~)
            if ~isempty(obj.PulseBlaster)
                obj.source_on = obj.PulseBlaster.lines(obj.PB_line).state;
            end
        end
        function host= set_PB_host(obj,host,~)
            try
                obj.PulseBlaster = Drivers.PulseBlaster.instance(host);
                obj.source_on = obj.PulseBlaster.lines(obj.PB_line).state;
            catch
                host = obj.no_server;
            end
        end
        
        function val = set_target_wavelength(obj, val, pref)   % Calls the tune() method.
            if isnan(val); return; end % Short circuit on NaN
            if obj.updatingVal; val = pref.value; warning('Laser is currently tuning.'); return; end
            obj.tune(val);
        end
        
        function val = set_etalon_percent(obj, val, ~)
            if isnan(val); return; end % Short circuit on NaN
            obj.do_etalon_lock = false;
            if obj.laserOn()
                obj.com('set_etalon_val', 'solstis', val);
                obj.getFrequency();
            end
        end
        function val = set_do_etalon_lock(obj, val, pref)
            if val == pref.value; return; end
            if obj.do_wavelength_lock && ~val   % Wavelength lock cannot be on without etalon lock.
                obj.do_wavelength_lock = false;
            end
            if obj.laserOn()
                obj.com('set_etalon_lock', 'solstis', obj.lockList{val+1});
                obj.getFrequency();
            end
        end
        
        function val = set_resonator_percent(obj, val, ~)
            if isnan(val); return; end % Short circuit on NaN
            obj.do_wavelength_lock = false;
            if obj.laserOn()
                obj.com('set_resonator_val', 'solstis', val);
                obj.getFrequency();
            end
        end
        function val = set_do_wavelength_lock(obj, val, pref)
            if val == pref.value; return; end
            if ~obj.do_etalon_lock && val       % Wavelength lock cannot be on without etalon lock.
                obj.do_etalon_lock = true;
            end
            if obj.laserOn()
                obj.com('lock_wavelength', 'solstis', obj.lockList{val+1});
                if val
                    try
                        obj.tune(obj.setpoint_) % If this line is neglected, the laser will lock to whatever the current value is (which often is slightly off the setpoint).
                    catch
                        obj.getFrequency();
                    end
                else
                    obj.getFrequency();
                end
            end
        end
    end
    
    methods     % TunableLaser_invisible methods
        function TuneCoarse(obj, target)
            obj.TuneSetpoint(target);
            obj.do_wavelength_lock = false;
        end
        function TunePercent(obj, target)
            assert(target >= 0 && target <= 100, 'Target must be a percentage')
            obj.resonator_percent = target;
        end
        function TuneSetpoint(obj, target)
            obj.tune(obj.c/target);
        end
        function percent = GetPercent(obj)
            obj.getFrequency();
            obj.resonator_percent = obj.resonator_voltage/2;
            percent = obj.resonator_percent;
        end
        function freq = getFrequency(obj)
            obj.callStatus();
            obj.callGetWavelength();
            
            if obj.laserOn()
                if obj.early_abort && obj.tuning && abs(obj.NIR_wavelength - obj.solstis_setpoint) < .005
                    obj.abort = true;
                else
                    if strcmp(obj.active_module, obj.moduleVIS)
                        % Only call getWavemeterWavelength if we expect to get power from the EMM
                        if ~obj.tuning || abs(obj.NIR_wavelength - obj.solstis_setpoint) < .1
                            obj.getWavemeterWavelength();
                        else
                            obj.VIS_wavelength = NaN; % 1./(1./obj.NIR_wavelength + 1/obj.diff_wavelength);
                        end
                    else
                        if ~obj.tuning
                            obj.getWavemeterWavelength();
                        end
                    end
                end
            else
                obj.NIR_wavelength = NaN;
                obj.VIS_wavelength = NaN;
            end
            
            freq = obj.c/obj.determineResultingWavelength();    % Not sure if this should be used; imprecise.
            obj.setpoint = freq;
        end
    end
    
    methods     % Module interpretation functions.
        function module = determineModule(obj, wavelength)                  % Determines the module most appropriate for the target wavelength. If wavelength is not given, uses wavelength = obj.setpoint_
            if nargin < 2
                wavelength = obj.setpoint_;
            end
            
            emm_crystal = 2;    % For now, the second (582-661 nm) crystal is the only one enabled. In the future, this should reference a pref.
            
            if     wavelength >= 515 && wavelength <= 582 && emm_crystal == 1   % For the 515-525 nm range where crystal 1 EMM and ECD-X have overlap, prefer EMM. There should be some way to override.
                module = Sources.Msquared.moduleVIS;    %'EMM';
            elseif wavelength >= 350 && wavelength <= 525
                module = Sources.Msquared.moduleUV;     %'ECD-X';
            elseif wavelength >= 515 && wavelength <= 582 && emm_crystal ~= 2
                error('Crystal is currently hard-coded to 2, and EMM wavelengths in the 515-582 nm range are unavailible. Change crystal and/or remove hardcoding to fix.')
            elseif wavelength >= 580 && wavelength <= 661 && emm_crystal == 2
                module = Sources.Msquared.moduleVIS;    %'EMM';
            elseif wavelength >= 700 && wavelength <= 1000
                module = Sources.Msquared.moduleNIR;    %'SolsTiS';
            else
                module = '';    % Return empty if the wavelength is invalid. Easy to check with isempty().
            end
        end
        function nir_wavelength = determineNIRWavelength(obj, wavelength)   % Determines the SolsTiS setpoint based on the target wavelength, with the same caviats as above.
            if nargin < 2
                wavelength = obj.setpoint_;
            end
            
            switch obj.determineModule(wavelength)  % Use our other function to determine which mode we are in.
                case Sources.Msquared.moduleUV  %'ECD-X'
                    nir_wavelength = 2*wavelength;                                  % ECD-X is a frequency doubler, wavelength halver.
                case Sources.Msquared.moduleVIS %'EMM'
                    nir_wavelength = 1./(1./wavelength - 1/obj.diff_wavelength);    % EMM is a sum frequency module.
                case Sources.Msquared.moduleNIR %'SolsTiS'
                    nir_wavelength = wavelength;                                    % SolsTiS is itself.
                otherwise
                    nir_wavelength = NaN;
            end
        end
        function resulting_wavelength = determineResultingWavelength(obj, wavelength)   % Interprets the results from the two wavemeter channels to return the resulting wavelength.
            if nargin < 2
                wavelength = obj.setpoint_;
            end
            
            switch obj.determineModule(wavelength)  % Use our other function to determine which mode we are in.
                case Sources.Msquared.moduleUV  %'ECD-X'
                    resulting_wavelength = obj.NIR_wavelength/2;                     % ECD-X is a frequency doubler, wavelength halver.
                case Sources.Msquared.moduleVIS %'EMM'
                    resulting_wavelength = obj.VIS_wavelength;                       % EMM is a sum frequency module.
                case Sources.Msquared.moduleNIR %'SolsTiS'
                    resulting_wavelength = obj.NIR_wavelength;                       % SolsTiS is itself.
                otherwise
                    resulting_wavelength = NaN;
            end
            
            if resulting_wavelength <= 0    % Account for wavemeter errorcodes.
                resulting_wavelength = NaN;
            end
        end
    end
end
