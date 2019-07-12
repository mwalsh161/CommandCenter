classdef VelocityLaser < Modules.Source & Sources.TunableLaser_invisible
    %VelocityLaser used to control all aspects of the tunable laser.
    %
    %   Loads instances of serial connection and wavemeter. Used for
    %   course and fine tuning/scanning of laser.
    %
    %   The on/off state of laser is controlled by the PulseBlaster (loaded
    %   in set.ip).  Note this state can switch to unknown if another
    %   module takes over the PulseBlaster program.
    %
    %   Power to the laser can be controlled through the serial object
    %   - obj.serial.on()/off() - however, time consuming calls!
    %   
    %   The laser tuning is controlled by the methods required by the
    %   TunableLaser_invisible superclass. In particular, the TuneCoarse
    %   method of this source class is recommended over directly calling
    %   the driver class equivalent (set.Wavelength), as the source method
    %   uses a calibration function to improve the accuracy of wavelength
    %   setting

    properties(SetObservable,AbortSet)
        tuning = false;
        prefs = {'PBline','pb_ip','velocity_ip','wavemeter_ip','wavemeter_channel','cal_local'};
        show_prefs = {'PB_status','tuning','diode_on','wavemeter_active','PBline','pb_ip','velocity_ip','wavemeter_channel','wavemeter_ip'};
        readonly_prefs = {'PB_status','tuning'};
    end
    properties(SetAccess={?Base.Module},Hidden)
        cal_local = struct('THz2nm',[],'gof',[],'datetime',[],'expired',{}); %calibration data for going from nm to THz
    end
    properties(Constant,Hidden)
        calibration_timeout = 7; %duration in days after which velocity will give warning to recalibrate
    end
    properties(SetAccess=protected)
        %'range' is the range of valid inputs for the driver's set.Wavelength method (in nm);
        % note that calling get.range will run this value through the
        % calibration function before returning
        range = Sources.VelocityLaser.c./[634.8,639.4];  
        Vrange = [-2.3, 2.3]; %setting the piezo percentage maps (0,100)
        resolution = 0.01; %frequency tuning resolution in THz
    end
    properties(SetObservable)
        TuningTimeout = 60; %Timeout for home-built PID used in TuneCoarse
        pb_ip = 'No Server';         % IP of computer with PB and server
        PBline = 12;
        velocity_ip = 'No Server';
        wavemeter_ip = 'No Server';
        wavemeter_channel = 3;              % Pulse Blaster flag bit (indexed from 1)
        diode_on = false;         % Power state of diode (on/off); assume off everytime because we cant check easily
        wavemeter_active = false; % Wavemeter channel active
        percent_setpoint = NaN; %local memory of tuning percent as applied by the wavemeter
    end
    properties(SetObservable,SetAccess=private)
        calibration_timeout_override = false; %if user chooses to ignore, ignore until inactive
        source_on = false;
        running                      % Boolean specifying if StaticLines program running
        PB_status
    end
    properties(Access=private)
        listeners
        path_button
    end
    properties(SetAccess=private)
        PulseBlaster %hardware handle
        serial
        wavemeter
    end
    methods(Access=protected)
        function obj = VelocityLaser()
            obj.loadPrefs;
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
            else
                warning('Wavemeter not hooked up!');
            end
            if ~isempty(obj.serial)
                try
                    obj.diode_on = false;
                catch err
                    errs{end+1} = err.message;
                end
            else
                warning('Velocity hwserver not connected!');
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
        function set.velocity_ip(obj,val)
            err = obj.connect_driver('serial','VelocityLaser',val);
            if isempty(obj.serial) %#ok<*MCSUP>
                obj.velocity_ip = 'No Server';
                obj.diode_on = NaN;
                if ~isempty(err)
                    rethrow(err)
                end
                return
            end
            if ~isempty(err)
                rethrow(err)
            end
            obj.velocity_ip = val;
            obj.diode_on = obj.serial.getDiodeState;
        end
        function set.pb_ip(obj,val)
            err = obj.connect_driver('PulseBlaster','PulseBlaster.StaticLines',val);
            obj.isRunning;
            if isempty(obj.PulseBlaster)
                obj.pb_ip = 'No Server';
                if ~isempty(err)
                    rethrow(err)
                end
                return
            end
            if ~isempty(err)
                rethrow(err)
            end
            obj.pb_ip = val;
            obj.source_on = obj.PulseBlaster.lines(obj.PBline);
            delete(obj.listeners);
            obj.listeners = addlistener(obj.PulseBlaster,'running','PostSet',@obj.isRunning);
        end
        function set.PBline(obj,val)
            assert(round(val)==val&&val>0,'PBline must be an integer greater than 0.')
            obj.PBline = val;
            if ~isempty(obj.PulseBlaster)
                obj.source_on = obj.PulseBlaster.lines(obj.PBline);
            end
        end
        function set.wavemeter_ip(obj,val)
            err = obj.connect_driver('wavemeter','Wavemeter',val,obj.wavemeter_channel);
            if isempty(obj.wavemeter)
                if ~isempty(err)
                    rethrow(err)
                end
                obj.wavemeter_ip = 'No Server';
                obj.wavemeter_active = NaN;
                return
            end
            if ~isempty(err)
                rethrow(err)
            end
            obj.wavemeter_active = obj.wavemeter.GetSwitcherSignalState;
            obj.wavemeter_ip = val;
        end
        function set.wavemeter_channel(obj,val)
            assert(round(val)==val&&val>0,'wavemeter_channel must be an integer greater than 0.')
            obj.wavemeter_channel = val;
            err = obj.connect_driver('wavemeter','Wavemeter',obj.wavemeter_ip,val);
            if ~isempty(err)
                rethrow(err)
            end
        end
        function set.diode_on(obj,val)
            if isnan(val);obj.diode_on=false;return;end %short-circuit if set to nan but keep false for settings method
            assert(~isempty(obj.serial),'No Velocity Laser connected');
            % This requires some time, so have msgbox appear
            st = dbstack(1);
            if ~any(strcmpi({st.name},'VelocityLaser.set.velocity_ip'))
                if val
                    f = msgbox('Turning laser diode on, please wait...');
                    obj.serial.on;
                    delete(f);
                else
                    obj.serial.off;
                end
            end
            obj.diode_on = val;
        end
        function set.wavemeter_active(obj,val)
            if isnan(val);obj.wavemeter_active=false;return;end %short-circuit if set to nan but keep false for settings method
            assert(~isempty(obj.wavemeter),'No wavemeter connected');
            st = dbstack(1);
            if ~any(strcmpi({st.name},'VelocityLaser.set.wavemeter_ip'))
                obj.wavemeter.SetSwitcherSignalState(val);
            end
            obj.wavemeter_active = obj.wavemeter.GetSwitcherSignalState;
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
            if ~obj.diode_on
                obj.activate;
            end
        end
        function blackout(obj)
            if obj.diode_on
                obj.diode_on = false;
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
        function RangeCheck(obj,val)
            %checks if frequency is in tunable range of laser
            assert(val >= min(obj.range) && val <= max(obj.range),...
                sprintf('Laser frequency must be in range [%g,%g] THz',obj.range(1),obj.range(2)))
        end
        function calibrate(obj,ax) 
            %calibrates the frequency as read by the wavemeter to the 
            %wavelength as set by the diode motor
            if ~obj.diode_on
                answer = questdlg('Diode off; turn diode on for calibration?','Diode off', 'Yes','No','No');
                switch answer
                    case 'No'
                        error('Diode must be on for wavelength calibration');
                    case 'Yes'
                        obj.diode_on = true;
                end
            end
            set_range = findprop(obj,'range'); 
            set_range = obj.c./set_range.DefaultValue; %get the actual settable range in nm, which is the default value of range

            f= [];
            if nargin < 2
                f = figure;
                ax = axes('parent',f);
            end
            try
                setpoints = linspace(set_range(1),set_range(end),10); %take 10 points across the range of the laser
                wavelocs = NaN(1,length(setpoints)); %location as read by the wavemeter in THz
                obj.wavemeter.setDeviationChannel(false);
                for i=1:length(setpoints)
                    obj.serial.Wavelength = setpoints(i); pause(1); %allow to settle
                    wavelocs(i) = obj.getFrequency;
                end
                fit_type = fittype('a/(x-b)+c');
                options = fitoptions(fit_type);
                options.Start = [obj.c,0,0];
                [temp.THz2nm,temp.gof] = fit(wavelocs',setpoints',fit_type,options);
                temp.datetime = datetime;
                obj.cal_local = temp;
                cla(ax)
                plotx = linspace(min(obj.c/max(setpoints),min(wavelocs)),max(obj.c/min(setpoints),max(wavelocs)),10*length(setpoints));
                plot(ax,wavelocs,setpoints,'bo');
                hold(ax,'on')
                plot(ax,plotx,temp.THz2nm(plotx));
                fitbounds = predint(temp.THz2nm,plotx,0.95,'functional','on'); %get confidence bounds on fit
                errorfill(plotx,temp.THz2nm(plotx)',[abs(temp.THz2nm(plotx)'-fitbounds(:,1)');abs(fitbounds(:,2)'-temp.THz2nm(plotx)')],'parent',ax);
                hold(ax,'off')
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
            obj.cal_local.expired = false;
            if days(datetime-obj.cal_local.datetime) >= obj.calibration_timeout && ~obj.calibration_timeout_override
                warnstring = sprintf('Calibration not performed since %s. Recommend recalibrating by running VelocityLaser.calibrate.',datestr(obj.cal_local.datetime));
                answer = questdlg([warnstring, ' Calibrate now?'],'VelocityLaser Calibration Expired','Yes','No','No');
                if strcmp(answer,'Yes')
                    obj.calibrate
                else
                    obj.calibration_timeout_override = true;
                    obj.cal_local.expired = true;
                end
            end
            cal = obj.cal_local;
        end
        function setMotorFrequency(obj,val)
            %internal method for setting the frequency using the motor;
            %talks to the driver and uses the internal calibration function
            %to send a wavelength command to the motor
            cal = obj.calibration; %grab the calibration function
            obj.serial.Wavelength = cal.THz2nm(val); %convert THz on wavemeter to nm in laser's hardware
            obj.serial.TrackMode = 'off'; %obj.serial.Wavelength turns TrackMode on, so turn back off
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
