classdef CWAVE < Modules.Source & Sources.TunableLaser_invisible
    %CWAVE is a driverless class for control of a CWAVE laser.
    
    properties(Access=private, Hidden)
        hwserver = [];          % TCPIP handle to the python hardware server for laser and wavemeter connectivity.
        PulseBlaster = [];      % Handle to the appropriate Drivers.PulseBlaster.
        updatingVal = false;    % Flag to prevent attempting to tune to multiple wavelengths at once.
    end
    
    properties(Constant, Hidden)
        moduleName = 'cwave';
        no_server = 'No Server';
    end
    
    properties(SetAccess=protected)
        range = [-Inf Inf];     % Ignoring limits for now. % Sources.TunableLaser_invisible.c./[700,1000]; %tunable range in THz
    end
    
    properties
        prefs = {'hwserver_host', 'VIS_channel', 'PB_line', 'PB_host'}
        show_prefs = {};
    end
    
    properties(SetObservable,GetObservable)
        % BASE prefs
        hwserver_host =     Prefs.String(Sources.CWAVE.no_server, 'set', 'set_hwserver_host', ...
                                                                    'help_text', 'The host for the laser and wavemeter');
        refresh =           Prefs.Button('Poll hwserver',       'set', 'set_refresh', ...
                                                                    'help_text', 'Get information (voltages, wavelengths, states) from the laser and wavemeters');
        
        % WAVELENGTH prefs
%         setpoint_ =         Prefs.Double(NaN,   'units', 'nm',  'set', 'set_target_wavelength', ...
%                                                                     'help_text', 'Use this knob to tune the laser to a certain wavelength. Availible ranges: ECD-X (350-525), EMM (515-582/580-661), SolsTiS (700-1100). The laser will decide the appropriate module to use based on the chosen wavelength');
%         center_percent =    Prefs.Boolean(false, ...
%                                                                     'help_text', 'Whether to attempt to target resonator_voltage = 50% after tuning (currently hardcoded to be between 40% and 60% [between 80V and 120V]). This is done by repeatedly moving to and from the target wavelength until a good resonator percent value is found.');
        tuning =            Prefs.Boolean(NaN, 'readonly', true, 'allow_nan', true, ...
                                                                    'help_text', 'Required by TunableLaser_invisible. True if status == tuning.');

        % WAVEMETER prefs
        VIS_wavelength =    Prefs.Double(NaN,   'units', 'nm',  'readonly', true, ...
                                                                    'help_text', 'Wavemeter output for the current wavelength of this msquared laser''s EMM, if an EMM is connected.');
        VIS_channel =       Prefs.Integer(7,    'min', 1, 'max', 8, ...
                                                                    'help_text', 'Wavemeter channel for this msquared laser''s EMM. Indexed from 1.');

        opo_percent =       Prefs.Double(NaN,   'units', '%',   'set', 'set_opo_percent', 'min', 0, 'max', 100, ...
                                                                    'help_text', '.');
        shg_percent =       Prefs.Double(NaN,   'units', '%',   'set', 'set_shg_percent', 'min', 0, 'max', 100,...
                                                                    'help_text', '.');
%         etalon_percent =    Prefs.Double(NaN,   'units', '%',   'set', 'set_etalon_percent', 'min', 0, 'max', 100, ...
%                                                                     'help_text', '.');
        resonator_percent = Prefs.Double(NaN,   'units', '%',   'set', 'set_resonator_percent', 'min', 0, 'max', 100,...
                                                                    'help_text', '.');
        
        % PULSEBLASTER prefs
        PB_host =           Prefs.String(Sources.CWAVE.no_server, 'set', 'set_PB_host');
        PB_line =           Prefs.Integer(1, 'min', 1, 'set', 'set_PB_line', 'help_text', 'Indexed from 1.');
    end
    
    methods(Access=private)
        function obj = CWAVE()
            obj.loadPrefs;      % This will call set_hwserver_host, which will instantiate the hardware.
            obj.getFrequency(); % Update prefs based on current values.
        end
    end
    methods(Static)
        function obj = instance()                   % Standard instance method to prevent duplication.
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.CWAVE();
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
                        error(exception);
                    end
                end
                rethrow(err);
            end
        end
        
        function getWavemeterWavelength(obj)        % Measures the output wavelength directly from the wavemeter. Also uses the EMM channel if the EMM module is active.
            if isempty(obj.hwserver) || ~isvalid(obj.hwserver)
                obj.VIS_wavelength =  NaN;
            else
                obj.VIS_wavelength = obj.hwserver.com('wavemeter', 'GetWavelengthNum', obj.VIS_channel, 0);
            end
        end
        function getStatus(obj)
            obj.opo_percent = obj.get_opo_percent();
            obj.shg_percent = obj.get_shg_percent();
%             obj.etalon_percent = obj.get_etalon_percent();
            obj.resonator_percent = obj.get_resonator_percent();
            obj.armed = obj.get_shutter('shg_out');
        end
    end
    
    methods     % Pref set methods.
        function val = set_source_on(obj, val, ~)   % 'Fast' modulation method -- usually the PulseBlaster.
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.PulseBlaster.lines(obj.PB_line).state = val;
        end
        function val = set_armed(obj, val, ~)       % Checks if the laser is outputting power (i.e. has been armed) and complains if result was contradictory.
            val = obj.set_shutter('shg_out', val);
            
%             obj.getFrequency(); 
%             
%             isarmed = (obj.output_monitor > .01);   % We can tell that the laser is armed if the output monitor is reading power.
%             
%             if val ~= isarmed                       % If we are setting armed to an incorrect value...
%                 val = ~val;                         % ...then prevent this incorrect setting...
%                 if val                              % And send warning messages.
%                     warndlg(['Request to blackout laser. Laser is on, as output_monitor reads ' num2str(obj.output_monitor) '; please turn the laser off'], 'Blackout (Sources.Msquared)')
%                 else
%                     warndlg(['Request to arm laser. Laser is off, as output_monitor reads ' num2str(obj.output_monitor) '; please turn the laser on'], 'Arm (Sources.Msquared)')
%                 end
%             end
        end
        
        function host= set_hwserver_host(obj, host, ~)
            try
                obj.hwserver = hwserver(host); %#ok<CPROPLC>
                
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
                host = Sources.CWAVE.no_server;
                obj.active_module = host;
                obj.status = host;
            end
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
            end
        end
        
        function val = set_opo_percent(obj, val, ~)
            val = obj.set_piezo_percent('opo', val);
        end
        function val = set_shg_percent(obj, val, ~)
            val = obj.set_piezo_percent('shg', val);
        end
        function val = set_etalon_percent(obj, val, ~)
            val = obj.set_piezo_percent('eta', val);
        end
        function val = set_resonator_percent(obj, val, ~)
            val = obj.set_piezo_percent('ref', val);
        end
        function val = set_piezo_percent(obj, channel, val)
            if isnan(val); return; end % Short circuit on NaN            
            obj.com('set_piezo_manual_output', channel, int64(round((2^16 - 1) * val / 100)));
            val = 100 * obj.com('get_piezo_manual_output', channel) / (2^16 - 1);
        end
        
        function val = get_opo_percent(obj)
            val = obj.get_piezo_percent('opo');
        end
        function val = get_shg_percent(obj)
            val = obj.get_piezo_percent('shg');
        end
        function val = get_etalon_percent(obj)
            val = obj.get_piezo_percent('eta');
        end
        function val = get_resonator_percent(obj)
            val = obj.get_piezo_percent('ref');
        end
        function val = get_piezo_percent(obj, channel)
            val = 100 * obj.com('get_piezo_manual_output', channel) / (2^16 - 1);
        end
        
        function val = set_shutter(obj, channel, val)
            obj.com('set_shutter', channel, logical(val));
            val = obj.com('get_shutter', channel);
        end
        function val = get_shutter(obj, channel)
            val = obj.com('get_shutter', channel);
        end
        
%         function val = goto_resonator_percent(obj, val, ~)
%             if isnan(val); return; end % Short circuit on NaN
%             %obj.getFrequency();
%             obj.do_wavelength_lock = false;
%             %%%
%           
%             currentPercent = obj.GetPercent;
%             numberSteps = floor(abs(currentPercent-val));
%             direction = sign(val-currentPercent);
%             for i = 1:numberSteps-1
%                 obj.com('set_resonator_val', 'solstis', currentPercent+(i)*direction);
%             end
%             %%%
%             obj.com('set_resonator_val', 'solstis', val);
%         end
    end
    
    methods     % python wrapper methods; copied from Driver
        function dial(obj,wavelength,request_shg)
            %assert(val>0 && val < 100,‘Power should be between 0% and 100%’)
            strwavelength = num2str(wavelength,10);
            strrequest = num2str(request_shg,10);
            obj.com('setpower',strwavelength,strrequest);
        end
        function output = get_dial_done(obj)
            output = obj.com('get_dial_done');
        end
        function output = get_firmware_version(obj)
            output = obj.com('get_firmware_version');
        end
        function output = get_fpga_version(obj)
            output = obj.com('get_fpga_version');
        end
        function output = get_serialnumber(obj)
            output = obj.com('get_serialnumber');
        end
        function optimize_stop(obj)
            obj.com('optimize_stop');
        end
        function optimize_etalon(obj)
            obj.com('get_fpga_version');
        end
        function etalon_move(obj,val)
            strval = num2str(val,10);
            obj.com('etalon_move',strval);
        end
        function elements_move(obj,val)
            %strval = num2str(val,10);
            obj.com('elements_move',val);
        end
        % Didn’t define set_stepper period
        % Didn’t define set_piezo_mode
        % Didn’t define get_piezo_mode
        % Didn’t define set_piezo_manual_output
        % Didn’t define get_piezo_manual_output
        function set_etalon_offset(obj,val)
            strval = num2str(val,10);
            obj.com('set_etalon_offset',strval);
        end
        function output = get_etalon_offset(obj)
            output = obj.com('get_etalon_offset');
        end
        function set_galvo_position(obj,val)
            strval = num2str(val,10);
            obj.com('set_galvo_position',strval);
        end
        function set_laser(obj,enable)
            strenable = num2str(enable)
            obj.com('set_laser',strenable);
        end
        function get_laser(obj)
            output = obj.com('get_laser');
        end
        function set_opo_extramp_settings(obj, duration_s, lower, upper)
            duration = int64(duration_s * 1000);
            lower = int64(lower);
            upper = int64(upper);
            
            assert(lower >= 0 && lower <= 100)
            assert(upper >= 0 && upper <= 100)
            assert(upper > lower)
            
            obj.com('set_opo_extramp_settings', duration, 1, lower, upper);
        end
        function start_opo_extramp(obj)
            obj.com('set_piezo_mode', 'opo', 3);
        end
        function stop_opo_extramp(obj)
            obj.com('set_piezo_mode', 'opo', 4);
        end
        % Didn’t define set_shutter
        % Didn’t define get_shutter
        % Didn’t define set_mirror
        % Didn’t define get_mirror
        % Didn’t define get_status_bits
        % Didn’t define get_external_pump
        % Didn’t define set_temperature_setpoint
        % Didn’t define get_temperature_setpoint
        % Didn’t define get_mapping_temperature
        % Didn’t define set_opo_extramp_settings
        % Didn’t define get_log
        % Didn’t define test_status_bits
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
            %percent = obj.resonator_percent;
            percent = obj.opo_percent;
        end
        function freq = getFrequency(obj)
            obj.getWavemeterWavelength();
%             obj.getStatus()
            freq = obj.c/obj.VIS_wavelength;    % Not sure if this should be used; imprecise.
            obj.setpoint = freq;
        end
    end
end
