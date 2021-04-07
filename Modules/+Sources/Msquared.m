classdef Msquared < Modules.Source & Sources.TunableLaser_invisible
    %MSQUARED is a driverless unified class for SolsTiS, EMM, and ECD-X control.
    
    properties(Access=private, Hidden)
        hwserver = [];          % TCPIP handle to the python hardware server for laser and wavemeter connectivity.
        PulseBlaster = [];      % Handle to the appropriate Drivers.PulseBlaster.
        updatingVal = false;    % Flag to prevent attempting to tune to multiple wavelengths at once.
        output_monitor = 0;     % Output of the SolsTiS photodiode. Used for determining whether the laser is armed.
    end
    
    properties(SetAccess=protected)
        range = [-Inf Inf];     % Ignoring limits for now. % Sources.TunableLaser_invisible.c./[700,1000]; %tunable range in THz
    end
    
    properties
        show_prefs = {};
    end
    
    properties (Constant, Hidden)
        moduleNIR = 'SolsTiS';
        moduleVIS = 'EMM';
        moduleUV =  'ECD-X';
        
        no_server = 'No Server';
        
        statusList = {'Open Loop', 'No Wavemeter', 'Tuning', 'Closed Loop'};    % Interpretation of msquared status (see callGetWavelength).
        lockList = {'off', 'on'};                                               % Used to convert logical 0/1 to 'off'/'on' for comms with the laser.
    end
    
    properties(SetObservable,GetObservable)
        % BASE prefs
        moduleName =        Prefs.MultipleChoice('set', 'set_moduleName', ...
                                                                    'help_text', 'Modules will be loaded when a hwserver hostname is supplied.');
        hwserver_host =     Prefs.String(Sources.Msquared.no_server, 'set', 'set_hwserver_host', ...
                                                                    'help_text', 'The host for the laser and wavemeter');
        refresh =           Prefs.Button('Poll hwserver',       'set', 'set_refresh', ...
                                                                    'help_text', 'Get information (voltages, wavelengths, states) from the laser and wavemeters');
        
        % WAVELENGTH prefs
        setpoint_ =         Prefs.Double(NaN,   'units', 'nm',  'set', 'set_target_wavelength', ...
                                                                    'help_text', 'Use this knob to tune the laser to a certain wavelength. The laser will decide the appropriate module to use based on the chosen wavelength');
        active_module =     Prefs.MultipleChoice(Sources.Msquared.moduleNIR, 'readonly', true, 'allow_empty', true, 'choices', {Sources.Msquared.no_server, Sources.Msquared.moduleUV, Sources.Msquared.moduleVIS, Sources.Msquared.moduleNIR}, ... %{'ECD-X', 'EMM', 'SolsTiS'}, ...
                                                                    'help_text', 'ECD-X (350-525), EMM (515-582/580-661), SolsTiS (700-1100)');
        status =            Prefs.String(Sources.Msquared.no_server, 'readonly', true, ...
                                                                    'help_text', 'Current tuning status of the laser.');
        tuning =            Prefs.Boolean(NaN, 'readonly', true, 'allow_nan', true, ...
                                                                    'help_text', 'Required by TunableLaser_invisible. True if status == tuning.');
%         emm_crystal =       Prefs.Integer(2,   'readonly', true, 'set', 'set_fitted_oven', ...
%                                                                     'help_text', 'Crystal being used: 1,2,3. This also sets range');
        
        % WAVEMETER prefs
        solstis_setpoint =  Prefs.Double(NaN,   'units', 'nm',  'readonly', true, ...
                                                                    'help_text', 'Target wavelength for the SolsTiS Ti:Saph');
        emm_setpoint =      Prefs.Double(NaN,   'units', 'nm',  'readonly', true, ...
                                                                    'help_text', 'Target wavelength for the alignment of the EMM PPLN');
        NIR_wavelength =    Prefs.Double(NaN,   'units', 'nm',  'readonly', true, ...
                                                                    'help_text', 'Wavemeter output for the current wavelength of this msquared laser''s SolsTiS. Additionally, this is double the ECD-X output wavelength, if this module is used.');
        VIS_wavelength =    Prefs.Double(NaN,   'units', 'nm',  'readonly', true, ...
                                                                    'help_text', 'Wavemeter output for the current wavelength of this msquared laser''s EMM, if an EMM is connected.');
        diff_wavelength =   Prefs.Double(1950,  'units', 'nm',  'readonly', true, ...
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
        etalon_percent =    Prefs.Double(NaN,   'units', '%',   'set', 'set_etalon_percent', 'min', 0, 'max', 100, ...
                                                                    'help_text', 'Apply fine tuning to the etalon in units of percent of total range (0 -> 200 V).');
        etalon_voltage =    Prefs.Double(NaN,   'units', 'V',   'readonly', true, ...
                                                                    'help_text', 'The amount of fine tuning upon the etalon. Interact with this via etalon_percent.');
        
        % RESONATOR prefs
        do_wavelength_lock= Prefs.Boolean(false,                'set', 'set_do_wavelength_lock', ...
                                                                    'help_text', 'Default for whether to hold the wavelength lock. When using an external voltage or the resonator percentage to finely tune the laser, this should be *off*, lest this active feedback negates your desired tuning.');
        wavelength_lock =   Prefs.Boolean(false,                'readonly', true, 'allow_nan', true, ... 'set', 'set_wavelength_lock', ...
                                                                    'help_text', 'Whether the laser is currently using the wavemeter for closed loop locking to the setpoint. Note that this is different from the resonator lock, which is not implemented in this interface.');
        resonator_percent = Prefs.Double(NaN,   'units', '%',   'set', 'set_resonator_percent', 'min', 0, 'max', 100,...
                                                                    'help_text', 'Apply fine tuning to the resonator in units of percent of total range (0 -> 200 V).');
        resonator_voltage = Prefs.Double(NaN,   'units', 'V',   'readonly', true, ...
                                                                    'help_text', 'The amount of fine tuning upon the resonator. Interact with this via resonator_percent.');

        % PULSEBLASTER prefs
        PB_line =           Prefs.Integer(1, 'min', 1, 'set', 'set_PB_line', 'help_text', 'Indexed from 1.');
        PB_host =           Prefs.String(Sources.Msquared.no_server, 'set', 'set_PB_host');
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
    
    methods     % Helper methods for communication/datapolling.
        function reply = com(obj, fn, varargin)     % Helper function for hwsever communication (fills in moduleName and deals with reserved clients).
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
                        error(exception);
                    end
                end
                rethrow(err);
            end
        end
        
        function callGetWavelength(obj)             % Calls the solstis method 'get_wavelength' and fills prefs in.
            if isempty(obj.hwserver) || ~isvalid(obj.hwserver)
                obj.status = obj.no_server;
                obj.tuning = false;
%                 obj.wavelength = NaN;
                obj.wavelength_lock = NaN;
            else
                reply = obj.com('get_wavelength', 'solstis');
                
                obj.status = obj.statusList{reply.status+1};
                obj.tuning = reply.status == 2;
%                 obj.wavelength = reply.current_wavelength;    % We will preference the wavemeter.
                obj.wavelength_lock = logical(reply.lock_status);
            end
        end
        function callStatus(obj)                    % Calls the solstis method 'status' and fills prefs in.
            % Get status report from SolsTiS laser and update fields
            if isempty(obj.hwserver) || ~isvalid(obj.hwserver)
                obj.etalon_lock = NaN;
                obj.etalon_voltage = NaN;
%                 obj.resonator_lock = false;
                obj.resonator_voltage = NaN;
                obj.output_monitor = 0;
            else
                reply = obj.com('status', 'solstis');
                
                obj.etalon_lock =       strcmp(reply.etalon_lock,'on');
                obj.etalon_voltage =    reply.etalon_voltage;
%                 obj.resonator_lock =    strcmp(reply.cavity_lock,'on');
                obj.resonator_voltage = reply.resonator_voltage;
                obj.output_monitor =    reply.output_monitor;
            end
            
            obj.callGetWavelength()
        end
        
        function getWavemeterWavelength(obj)        % Measures the output wavelength directly from the wavemeter. Also uses the EMM channel if the EMM module is active.
            if isempty(obj.hwserver) || ~isvalid(obj.hwserver)
                obj.NIR_wavelength =  NaN;
                obj.VIS_wavelength =  NaN;
                obj.diff_wavelength = 1950;
            else
                obj.NIR_wavelength = obj.hwserver.com('wavemeter', 'GetWavelengthNum', obj.NIR_channel, 0);

                if strcmp(obj.determineModule(obj.setpoint_), obj.moduleVIS)
                    obj.com('SetSwitcherSignalStates', obj.VIS_channel, 1, 1);
                    obj.VIS_wavelength = obj.hwserver.com('wavemeter', 'GetWavelengthNum', obj.VIS_channel, 0);

                    if obj.VIS_wavelength > 0 && obj.NIR_wavelength > 0
                        diff_wavelength_ = 1/(1/obj.VIS_wavelength - 1/obj.NIR_wavelength);

                        if diff_wavelength_ < 1951 && diff_wavelength_ > 1949
                            obj.diff_wavelength = diff_wavelength_;
                        end
                    end
                else
                    obj.com('SetSwitcherSignalStates', obj.VIS_channel, 0, 0);
                end
            end
        end
    end
    
    methods     % The meat of this tunable source.
        function tune(obj, target)                  % This is the tuning method that interacts with hardware (target in nm)
            assert(~isempty(obj.hwserver) && isobject(obj.hwserver) && isvalid(obj.hwserver), 'No hwserver host!')
            
            obj.updatingVal = true;
            module = obj.determineModule(target);
            obj.active_module = module;

            if strcmp(module, obj.moduleVIS)
                obj.emm_setpoint = target;
                try
                    out = obj.com('set_wavelength', 'EMM', target, .1); % last arg is timeout
                
                    if out.status ~= 0
        %                 obj.setpoint_ = NaN;
                        obj.updatingVal = false;
                        error('Failed to set target')
                    end
                catch
                    % expected
                end
            else
                obj.emm_setpoint = NaN;
            end
            
            nir_wavelength = obj.determineNIRWavelength(target);
            obj.solstis_setpoint = nir_wavelength;
            out = obj.com('set_wavelength', 'solstis', nir_wavelength, 0); % last arg is timeout
            
            if out.status ~= 0
%                 obj.setpoint_ = NaN;
                obj.updatingVal = false;
                error('Failed to set target')
            end
            obj.tuning = true;
            obj.updatingVal = false;
            
            obj.getFrequency();
            
%             pause(1) % Wait for msquared to start tuning
            obj.trackFrequency(obj.c/target);   % Will block until obj.tuning = false (calling obj.getFrequency each tick)
            
            if      ~obj.do_etalon_lock
                obj.com('lock_wavelength', 'solstis', obj.lockList{1});
                obj.com('set_etalon_lock', 'solstis', obj.lockList{1});
            elseif  ~obj.do_wavelength_lock
                obj.com('lock_wavelength', 'solstis', obj.lockList{1});
            end
            
            obj.getFrequency();
        end
    end
    
    methods     % Pref set methods.
        function val = set_source_on(obj, val, ~)   % 'Fast' modulation method -- usually the PulseBlaster.
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.PulseBlaster.lines(obj.PB_line).state = val;
        end
        function val = set_armed(obj, val, ~)       % Checks if the laser is outputting power (i.e. has been armed) and complains if result was contradictory.
            obj.getFrequency(); 
            
            if val ~= (obj.output_monitor > .01)    % If we are setting armed to an incorrect value...
                val = ~val;
                if val
                    warndlg(['Request to arm laser. Laser is off, as output_monitor reads ' num2str(obj.output_monitor) '; please turn the laser on'], 'Arm (Sources.Msquared)')
                else
                    warndlg(['Request to blackout laser. Laser is on, as output_monitor reads ' num2str(obj.output_monitor) '; please turn the laser off'], 'Blackout (Sources.Msquared)')
                end
            end
        end
        
        function host= set_hwserver_host(obj, host, ~)
            try
                obj.hwserver = hwserver(host); %#ok<CPROPLC>
                
                % Update laser list.
                opts = obj.hwserver.get_modules('msquared.');
                mp = obj.get_meta_pref('moduleName');
                if ~isequal(mp.choices,opts) % Only update if different
                    if ~isempty(mp.value)
                        % If we need to reset it, we also need to re-grab the metapref
                        obj.moduleName = '';
                        mp = obj.get_meta_pref('moduleName');
                    end
                    mp.choices = opts;
                    obj.set_meta_pref('moduleName', mp);
                    notify(obj,'update_settings');
                end
            catch
                host = Sources.Msquared.no_server;
                obj.active_module = host;
                obj.status = host;
            end
        end
        function val = set_moduleName(obj,val,~)
            obj.getFrequency();
        end
        
        function val = set_refresh(obj,val,~)       % Polls hwserver by calling getFrequency().
            obj.getFrequency();
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
                obj.pb_host = host;
            end
        end
        
        function val = set_target_wavelength(obj, val, ~)   % Calls the tune() method.
            if isnan(val); return; end % Short circuit on NaN
            if obj.updatingVal; return; end
            obj.tune(val);
        end
        
        function val = set_etalon_percent(obj, val, ~)
            if isnan(val); return; end % Short circuit on NaN
            obj.getFrequency();
            obj.do_etalon_lock = false;
            obj.com('set_etalon_val', 'solstis', val);
        end
        function val = set_do_etalon_lock(obj, val, pref)
            if val == pref.value; return; end
            if obj.do_wavelength_lock && ~val   % Wavelength lock cannot be on without etalon lock.
                obj.do_wavelength_lock = false;
            end
            obj.com('set_etalon_lock', 'solstis', obj.lockList{val+1});
            obj.getFrequency();
        end
        
        function val = set_resonator_percent(obj, val, ~)
            if isnan(val); return; end % Short circuit on NaN
            obj.getFrequency();
            obj.do_wavelength_lock = false;
            obj.com('set_resonator_val', 'solstis', val);
        end
        function val = set_do_wavelength_lock(obj, val, pref)
            if val == pref.value; return; end
            if ~obj.do_etalon_lock && val       % Wavelength lock cannot be on without etalon lock.
                obj.do_etalon_lock = true;
            end
            obj.com('lock_wavelength', 'solstis', obj.lockList{val+1});
%             if val
%                 try
%                     obj.tune(obj.setpoint_)
%                 catch
%                     obj.getFrequency();
%                 end
%             else
                obj.getFrequency();
%             end
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
            obj.getWavemeterWavelength();
            obj.callStatus();
            wavelength = obj.determineResultingWavelength();
            freq = obj.c/wavelength;    % Not sure if this should be used; imprecise.
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
                    nir_wavelength = 2*wavelength;                                  % ECD-X is a freqeuncy doubler, wavelength halver.
                case Sources.Msquared.moduleVIS %'EMM'
                    nir_wavelength = 1./(1./wavelength - 1/obj.diff_wavelength);    % EMM is a sum freqency module.
                case Sources.Msquared.moduleNIR %'SolsTiS'
                    nir_wavelength = wavelength;                                    % SolsTiS is itself.
                otherwise
                    nir_wavelength = NaN;
            end
        end
        function resulting_wavelength = determineResultingWavelength(obj)   % Interprets the results from the two wavemeter channels to return the resulting wavelength.
            if nargin < 2
                wavelength = obj.setpoint_;
            end
            
            switch obj.determineModule(wavelength)  % Use our other function to determine which mode we are in.
                case Sources.Msquared.moduleUV  %'ECD-X'
                    resulting_wavelength = obj.NIR_wavelength/2;                     % ECD-X is a freqeuncy doubler, wavelength halver.
                case Sources.Msquared.moduleVIS %'EMM'
                    resulting_wavelength = obj.VIS_wavelength;                       % EMM is a sum freqency module.
                case Sources.Msquared.moduleNIR %'SolsTiS'
                    resulting_wavelength = obj.NIR_wavelength;                       % SolsTiS is itself.
                otherwise
                    resulting_wavelength = NaN;
            end
        end
    end
end
