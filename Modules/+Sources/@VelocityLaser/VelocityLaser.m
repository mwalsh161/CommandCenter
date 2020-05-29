classdef VelocityLaser < Modules.Source & Sources.TunableLaser_invisible
    %VelocityLaser used to control all aspects of the tunable laser.
    %
    %   Loads instances of serial connection and wavemeter. Used for
    %   course and fine tuning/scanning of laser.
    %
    %   The on/off state of laser is controlled by the PulseBlaster (loaded
    %   in set_host).  Note this state can switch to unknown if another
    %   module takes over the PulseBlaster program.
    %
    %   Power to the laser can be controlled through the serial object
    %   - obj.serial.on()/off() - however, time consuming calls!
    %   
    %   The laser tuning is controlled by the methods required by the
    %   TunableLaser_invisible superclass. In particular, the TuneCoarse
    %   method of this source class is recommended over directly calling
    %   the driver class equivalent (set_Wavelength), as the source method
    %   uses a calibration function to improve the accuracy of wavelength
    %   setting

    properties
        prefs = {'PBline','pb_host','velocity_host','wavemeter_host','wavemeter_channel',...
                 'wheel_host', 'wheel_pin', 'wheel_pos', 'cal_local','TuningTimeout','TuneSetpointAttempts','TuneSetpointNPoints'};
        show_prefs = {'PB_status','tuning','diode_on','wavemeter_active','PBline','pb_host',...
            'velocity_host','wavemeter_host','wavemeter_channel','wheel_host', 'wheel_pin', 'wheel_pos', 'TuningTimeout','TuneSetpointAttempts','TuneSetpointNPoints','debug'};
    end
    properties(SetAccess={?Base.Module})
        cal_local = struct('THz2nm',[],'gof',[],'datetime',[],'expired',{}); %calibration data for going from nm to THz
    end
    properties(Constant,Hidden)
        calibration_timeout = 7; %duration in days after which velocity will give warning to recalibrate
    end
    properties(SetAccess=protected,Hidden) % Hidden to avoid call to calibration when displayed
        %'range' is the range of valid inputs for the driver's set_Wavelength method (in nm);
        % note that calling get.range will run this value through the
        % calibration function before returning
        range = Sources.VelocityLaser.c./[634.8,639.4];
    end
    properties(SetAccess=protected)
        Vrange = [-2.3, 2.3]; %setting the piezo percentage maps (0,100)
        resolution = 0.01; %frequency tuning resolution in THz
    end
    properties(SetObservable,GetObservable)
        tuning =                Prefs.Boolean(false,'readonly',true);
        debug =                 Prefs.Boolean(false);
        TuningTimeout =         Prefs.Double(60,'units','sec','min',0,'help','Timeout for home-built PID used in TuneCoarse');
        
        pb_host =               Prefs.String('No Server','set','set_pb_host','help','IP/hostname of computer with PB server');
        PBline =                Prefs.Integer(12,'min',1,'allow_nan',false,'set','set_PBline','help','Indexed from 1');
        
        velocity_host =         Prefs.String('No Server','set','set_velocity_host','help','IP/hostname of computer with hwserver for velocity laser');
        
        wavemeter_host =        Prefs.String('No Server','set','set_wavemeter_host','help','IP/hostname of computer with hwserver for wavemeter');
        wavemeter_channel =     Prefs.Integer(3,'min',1,'allow_nan',false,'set','set_wavemeter_channel','help','Pulse Blaster flag bit (indexed from 1)');
        
        wheel_host =              Prefs.String('No Server', 'set','set_wheel_host', 'help', 'IP/hostname of computer with hwserver for Arduino-controlled filter wheel.');
        wheel_pin =             Prefs.Integer(2, 'min',2, 'max', 13, 'allow_nan', false, 'set', 'set_wheel_pin', 'help', 'Pin on the Arduino corresponding to the filter wheel servo.');
        wheel_pos =             Prefs.MultipleChoice('OD0', 'choices', Sources.VelocityLaser.wheel_choices, 'allow_empty', false, 'set' ,'set_wheel_pos' ,'help', 'Current position of the Arduino-controlled filter wheel. The wheel weaves as the wheel wills.');
        
        diode_on =              Prefs.Boolean(false,'set','set_diode_on','help','Power state of diode (on/off)');
        
        wavemeter_active =      Prefs.Boolean(false,'set','set_wavemeter_active','help','Wavemeter channel active');
        
        percent_setpoint =      Prefs.Double(NaN,'units','%','help','local memory of tuning percent as applied by the wavemeter');
        
        TuneSetpointAttempts =  Prefs.Integer(3,'min',1,'allow_nan',false);
        TuneSetpointNPoints =   Prefs.Integer(25,'min',1,'allow_nan',false,'help','number of wavemeter queries below wavemeter resolution to consider settled.');
    end
    properties(Constant)
        wheel_choices = {'OD.5', 'OD1', 'OD0', 'OD2'};
    end
    properties(SetObservable,SetAccess=private)
        source_on = false;
    end
    properties(SetObservable,GetObservable)
        running = Prefs.Boolean(false,'help','Boolean specifying if StaticLines program running');
        PB_status = Prefs.String('Unknown','readonly',true);
    end
    properties(Access=private)
        calibration_timeout_override = false; %if user chooses to ignore, ignore until inactive
        listeners
        path_button
    end
    properties(SetAccess=private)
        PulseBlaster %hardware handle
        serial
        wavemeter
        wheel
    end
    methods(Access=protected)
        function obj = VelocityLaser()
            obj.loadPrefs;
            try % Turn off wavemeter if diode isn't on (ignore not connected errors)
                if ~obj.diode_on
                    obj.wavemeter_active = false;
                end
            end
        end
    end
    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.VelocityLaser();
            end
            obj = Object;
        end
    end
    methods
        function task = inactive(obj)
            task = 'Turning diode power and wavemeter switch channel off';
            obj.calibration_timeout_override = false;
            obj.deactivate;
        end
        function activate(obj)
            % Will error if not able to
            assert(~isempty(obj.wavemeter)&&~isempty(obj.serial),'Wavemeter and velocity do not exist')
            obj.diode_on = true;
            obj.wavemeter_active = true;
            % Make sure piezo is reset correctly
            obj.TunePercent(50); % Should center input voltage range
            obj.serial.PiezoPercent = 50; % Force to mid point
            p = obj.serial.getPiezoPercent; % Verify
            assert(abs(p-50)<5,sprintf('Attempted to set laser to 50%%, but currently reads %g%%',p));
        end
        function deactivate(obj)
            % Deactivate where we can
            errs = {};
            if ~isempty(obj.wavemeter)
                try
                    obj.wavemeter_active = false;
                catch err
                    errs{end+1} = err.message;
                end
            elseif ~strcmp(obj.wavemeter_host,'No Server')
                warning('Wavemeter IP set, but not connected!');
            end
            if ~isempty(obj.serial)
                try
                    obj.diode_on = false;
                catch err
                    errs{end+1} = err.message;
                end
            elseif ~strcmp(obj.velocity_host,'No Server')
                warning('Velocity IP set, but not connected!');
            end
            if ~isempty(errs)
                error(strjoin(errs,[newline newline]))
            end
        end
        function delete(obj)
            delete(obj.listeners)
            obj.deactivate; % Close up
        end
        function err = connect_driver(obj,propname,drivername,varargin)
            err = [];
            if ~isempty(obj.(propname))
                delete(obj.(propname)); %remove any old connection
            end
            if ischar(varargin{1}) && strcmpi(varargin{1},'No Server') %first input is always an ip address
                obj.(propname) = [];
            else
                try
                    obj.(propname) = Drivers.(drivername).instance(varargin{:});
                catch err
                    obj.(propname) = [];
                end
            end
        end
        
        function val = set_velocity_host(obj,val,~)
            err = obj.connect_driver('serial','VelocityLaser',val);
            if isempty(obj.serial) %#ok<*MCSUP>
                obj.velocity_host = 'No Server';
                obj.diode_on = NaN;
                if ~isempty(err)
                    rethrow(err)
                end
                return
            end
            if ~isempty(err)
                rethrow(err)
            end
            obj.diode_on = obj.serial.getDiodeState;
        end
        
        function val = set_pb_host(obj,val,~)
            err = obj.connect_driver('PulseBlaster','PulseBlaster.StaticLines',val);
            obj.isRunning;
            if isempty(obj.PulseBlaster)
                obj.pb_host = 'No Server';
                if ~isempty(err)
                    rethrow(err)
                end
                return
            end
            if ~isempty(err)
                rethrow(err)
            end
            obj.source_on = obj.PulseBlaster.lines(obj.PBline);
            delete(obj.listeners);
            obj.listeners = addlistener(obj.PulseBlaster,'running','PostSet',@obj.isRunning);
        end
        function val = set_PBline(obj,val,~)
            if ~isempty(obj.PulseBlaster)
                obj.source_on = obj.PulseBlaster.lines(val);
            end
        end
        
        function val = set_wavemeter_host(obj,val,~)
            err = obj.connect_driver('wavemeter','Wavemeter',val,obj.wavemeter_channel);
            if isempty(obj.wavemeter)
                if ~isempty(err)
                    rethrow(err)
                end
                val = 'No Server';
                obj.wavemeter_active = NaN;
                return
            end
            if ~isempty(err)
                rethrow(err)
            end
            obj.wavemeter_active = obj.wavemeter.GetSwitcherSignalState;
        end
        function val = set_wavemeter_channel(obj,val,~)
            err = obj.connect_driver('wavemeter','Wavemeter',obj.wavemeter_host,val);
            if ~isempty(err)
                rethrow(err)
            end
        end
        
        function val = set_wheel_host(obj,val,~)
            err = obj.connect_driver('wheel', 'ArduinoServo', val, obj.wheel_pin);
            if isempty(obj.wheel)
                if ~isempty(err)
                    rethrow(err)
                end
                val = 'No Server';
                return
            end
            if ~isempty(err)
                rethrow(err)
            end
        end
        function val = set_wheel_pin(obj,val,~)
            err = obj.connect_driver('wheel', 'ArduinoServo', obj.wheel_host, val);
            if ~isempty(err)
                rethrow(err)
            end
        end
        function val = set_wheel_pos(obj,val,~)
            if ~isempty(obj.wheel)
                index = find(ismember(obj.wheel_choices, val));

                obj.wheel.angle = 60 * (index-1);
            end
        end
        
        function val = set_diode_on(obj,val,~)
            if isnan(val);val = false;return;end %short-circuit if set to nan but keep false for settings method
            assert(~isempty(obj.serial),'No Velocity Laser connected');
            % This requires some time, so have msgbox appear
            st = dbstack(1);
            if ~any(strcmpi({st.name},'VelocityLaser.set_velocity_host'))
                if val
                    f = msgbox('Turning laser diode on, please wait...');
                    obj.serial.on;
                    delete(f);
                else
                    obj.serial.off;
                end
            end
        end
        function val = set_wavemeter_active(obj,val,~)
            if isnan(val);val=false;return;end %short-circuit if set to nan but keep false for settings method
            assert(~isempty(obj.wavemeter),'No wavemeter connected');
            st = dbstack(1);
            if ~any(strcmpi({st.name},'VelocityLaser.set_wavemeter_host'))
                obj.wavemeter.SetSwitcherSignalState(val);
            end
            val = obj.wavemeter.GetSwitcherSignalState;
        end
        function range = get.range(obj)
            %run range through calibration to get actual range
            cal = obj.calibration.THz2nm;
            range = sort(cal.a./(obj.c./obj.range-cal.c)+cal.b);
        end
        
        function on(obj)
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            if ~obj.diode_on
                obj.activate;
            end
            obj.PulseBlaster.lines(obj.PBline) = true;
            obj.source_on = true;
        end
        function off(obj)
            assert(~isempty(obj.PulseBlaster),'No IP set!')
            obj.source_on = false;
            obj.PulseBlaster.lines(obj.PBline) = false;
        end
        function arm(obj)
            % Make sure calibration is available
            [~] = obj.calibration;
            if ~obj.diode_on
                obj.activate;
            end
        end
        function blackout(obj)
            if obj.diode_on
                obj.deactivate;
            end
        end
        
        function val = getFrequency(obj)
            val = obj.wavemeter.getFrequency();
        end
        function isRunning(obj,varargin)
            if isempty(obj.PulseBlaster)
                obj.PB_status = 'Not Connected';
            else
                obj.running = obj.PulseBlaster.running;
                if obj.running
                    obj.PB_status = 'Running';
                else
                    obj.PB_status = 'Unknown State, to update, change state.';
                end
            end
        end
        
        function calibrate(obj,ax)
            %calibrates the frequency as read by the wavemeter to the 
            %wavelength as set by the diode motor
            if ~obj.diode_on || ~obj.wavemeter_active
                answer = questdlg('Unarmed; Arm laser on for calibration?','Unarmed', 'Yes','No','No');
                switch answer
                    case 'No'
                        error('Laser must be armed for wavelength calibration');
                    case 'Yes'
                        obj.activate;
                end
            end
            set_range = findprop(obj,'range'); 
            set_range = obj.c./set_range.DefaultValue; %get the actual settable range in nm, which is the default value of range
            obj.serial.TrackMode = 'on'; % Keep trackmode on through calibration
            f = [];  % Placeholder if axes is supplied
            if nargin < 2
                f = figure;
                ax = axes('parent',f);
            end
            try
                % First set cal_local to x = y 
                obj.cal_local.THz2nm = cfit(fittype('a/x'),obj.c);
                obj.cal_local.datetime = datetime;
                % Continue with calibration
                setpoints = linspace(set_range(1),set_range(end),10); %take 10 points across the range of the laser
                wavelocs = NaN(1,length(setpoints)); %location as read by the wavemeter in THz
                obj.wavemeter.setDeviationChannel(false);
                cla(ax);
                hold(ax,'on');
                for i=1:length(setpoints)
                    title(ax,sprintf('Sweeping %i/%i points, please wait',i,length(setpoints)))
                    obj.serial.Wavelength = setpoints(i); pause(1); %allow to settle
                    wavelocs(i) = obj.getFrequency;
                    plt = plot(ax,wavelocs,setpoints,'bo');
                    drawnow nocallbacks;
                end
                fit_type = fittype('a/(x-b)+c');
                options = fitoptions(fit_type);
                options.Start = [obj.c,0,0];
                [temp.THz2nm,temp.gof] = fit(wavelocs',setpoints',fit_type,options);
                temp.datetime = datetime;
                obj.cal_local = temp;
                plotx = linspace(min(obj.c/max(setpoints),min(wavelocs)),...
                    max(obj.c/min(setpoints),max(wavelocs)),10*length(setpoints));
                plot(ax,plotx,temp.THz2nm(plotx));
                fitbounds = predint(temp.THz2nm,plotx,0.95,'functional','on'); %get confidence bounds on fit
                errorfill(plotx,temp.THz2nm(plotx)',[abs(temp.THz2nm(plotx)'-fitbounds(:,1)');abs(fitbounds(:,2)'-temp.THz2nm(plotx)')],'parent',ax);
                hold(ax,'off');
                xlabel(ax,'Wavemeter Reading')
                ylabel(ax,'Wavelength Set Command')
                answer = questdlg('Calibration satisfactory?','Velocity Calibration Verification','Yes','No, retake','No, abort','No, abort');
                if strcmp(answer,'No, retake')
                    obj.calibrate(ax)
                elseif strcmp(answer,'No, abort')
                    error('Failed calibration validation')
                end
            catch err
                obj.cal_local = [];
                delete(f)
                rethrow(err)
            end
            delete(f)
        end
        function cal = calibration(obj)
            %get the calibration of the frequency as read by the wavemeter
            %to the wavelength as set by the diode motor; this is stored as
            %cal_local
            if isempty(obj.cal_local)
                % If called in savePref method, ignore and return default
                st = dbstack;
                if length(st) > 1 && strcmp(st(2).name,'Module.savePrefs')
                    mp = findprop(obj,'cal_local');
                    cal = mp.DefaultValue;
                    return
                else
                    answer = questdlg('No VelocityLaser calibration found; calibrate now?','No VelocityLaser Calibration','Yes','No','No');
                    if strcmp(answer,'Yes')
                        obj.calibrate;
                    else
                        error('No VelocityLaser calibration found; calibrate using VelocityLaser.calibrate(tunable laser handle, exposure time in seconds)');
                    end
                end
            end
            % Potential flaws in calibration method may leave obj.cal_local.datetime invalid
            % Use assert to double check this condition to produce a parsable error
            assert(isdatetime(obj.cal_local.datetime),'cal_local.datetime is not a datetime. Likely error in calibration method.')
            if days(datetime-obj.cal_local.datetime) >= obj.calibration_timeout % expired
                obj.cal_local.expired = true;
                if  ~obj.calibration_timeout_override
                    warnstring = sprintf('Calibration not performed since %s. Recommend recalibrating by running VelocityLaser.calibrate.',datestr(obj.cal_local.datetime));
                    answer = questdlg([warnstring, ' Calibrate now?'],'VelocityLaser Calibration Expired','Yes','No','No');
                    if strcmp(answer,'Yes')
                        obj.calibrate
                        obj.cal_local.expired = false; % Retaken, so not expired
                    else
                        msgbox('Calibration timeout override in effect until inactivity timeout occurs.',...
                            'Calibration ignored','modal')
                        obj.calibration_timeout_override = true;
                    end
                end
            else % Not expired block
                obj.cal_local.expired = false;
            end
            cal = obj.cal_local;
        end
        function resetCalibration(obj)
            obj.cal_local = [];
        end
        
        function setMotorFrequency(obj,val)
            %internal method for setting the frequency using the motor;
            %talks to the driver and uses the internal calibration function
            %to send a wavelength command to the motor
            cal = obj.calibration; %grab the calibration function
            obj.serial.Wavelength = cal.THz2nm(val); %convert THz on wavemeter to nm in laser's hardware
        end
        function SpecSafeMode(obj,~)
            %turns the diode of the laser off to make it safe for taking
            %spectra
            obj.blackout;
        end
        function percent = GetPercent(obj)
            if obj.wavemeter.getDeviationChannel
                voltage = obj.wavemeter.getDeviationVoltage;
                percent = (obj.Vrange(2)-voltage)*100/diff(obj.Vrange);
            else %if DeviationChannel == false, can't read voltage, so return latest setpoint
                percent = obj.percent_setpoint;
            end
        end
    end
end
