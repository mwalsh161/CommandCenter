classdef CWave < Modules.Source & Sources.TunableLaser_invisible
    %Cwave controls all aspects of the cwave laser which powers AOM
    % and the PulseStreamer which triggers AOM
    %
    %   Wavemeter used for tuning and scanning of laser
    %   
    %   The cwave is continuously operated and used to control
    %   an AOM whose on/off state is controlled by the 
    %   PulseStreamer.
    %
    %   The laser tuning is controlled by the methods required by the
    %   TunableLaser_invisible superclass.

    properties(SetObservable,SetAccess=private)
        source_on = false;
    end

    properties(SetAccess=protected)
        vis_range = Sources.TunableLaser_invisible.c./[450, 650];
        nir_range = Sources.TunableLaser_invisible.c./[900, 1300];
    end

    properties(SetObservable,AbortSet)
        resonator_percent = 0;
        tuning = false;
        cwave_ip = Sources.CWave.no_server;
        pulseStreamer_ip = Sources.CWave.no_server;
        wavemeter_ip = Sources.CWave.no_server;
        % TODO fill in prefs all the way
        PSline = 1; % Index from 1 (Pulsestreamer has 8 digital out channels)
        resonator_tune_speed = 0.5; % percent per step
        etalon_lock;
        etalon_percent;
        opo_stepper;
        opo_temp;
        shg_stepper;
        shg_temp;
        thin_etalon;
        opo_lock;
        shg_lock;
        pump_emission;
        ref_temp;
        wavelength_lock;
        target_wavelength;
        show_prefs = {'tuning','target_wavelength','wavelength_lock','etalon_lock',...
            'opo_stepper','opo_temp','shg_stepper', 'shg_temp','thin_etalon',...
            'opo_lock','shg_lock','pump_emission','ref_temp','resonator_percent',...
            'etalon_percent','PSline','pulseStreamer_ip','cwave_ip','wavemeter_ip',...
            'resonator_tune_speed'};
        readonly_prefs = {'tuning','etalon_lock','opo_stepper','opo_temp',...
            'shg_stepper', 'shg_temp','thin_etalon','opo_lock','shg_lock',...
            'pump_emission','ref_temp'};
    end

    properties(SetAccess=private)
        PulseStreamerHandle %hardware handle
        wavemeterHandle
        cwaveHandle
    end

    properties(Constant,Hidden)
        no_server = 'No Server';  % Message when not connected
    end

    methods(Access=private)
        function obj = CWave()
            obj.loadPrefs;
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
    end

    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.CWave();
            end
            obj = Object;
        end
    end

    methods

        % source methods

        function on(obj)
            assert(~isempty(obj.PulseStreamerHandle), 'No IP set for PulseStreamer!')
            state = PulseStreamer.OutputState([obj.PSline],0,0);
            obj.PulseStreamerHandle.PS.constant(state);
            obj.source_on = true;
            
        end
        function off(obj)
            assert(~isempty(obj.PulseStreamerHandle), 'No IP set for PulseStreamer!')
            obj.source_on = false;
            state = PulseStreamer.OutputState([],0,0);
            obj.PulseStreamerHandle.PS.constant(state);
        end

        % tunable laser methods

        function tune(obj, setpoint,target_dev)
            % target in nm
            obj.tuning = true;
            if setpoint < 899
                assert(target>=obj.c/max(obj.vis_range)&&target<=obj.c/min(obj.vis_range),...
                sprintf('Wavelength must be in range [%g, %g] nm!!',obj.c./obj.vis_range))
            elseif setpoint >= 899
                assert(target>=obj.c/max(obj.nir_range)&&target<=obj.c/min(obj.nir_range),...
                sprintf('Wavelength must be in range [%g, %g] nm!!',obj.c./obj.nir_range))
            end
            assert(~isempty(obj.cwaveHandle), 'no cwave handle')
            err = [];
            % The CWave is slow at tuning, so message is useful until a non-blocking operation exists
            dlg = msgbox('Please wait while CWave tunes to target wavelength.',mfilename,'modal');
            textH = findall(dlg,'tag','MessageBox');
            delete(findall(dlg,'tag','OKButton'));
            drawnow;
            obj.tuning = true;
            
            try 
                %target_dev = 0.5;
                %measured_wavelength = obj.wavemeterHandle.getWavelength();
                %mid_setpoint = measured_wavelength;
                %while round(target_dev, 5) > 0
                %    while abs(mid_setpoint - setpoint) > 2*target_dev
                %        mid_setpoint = mid_setpoint + 2*target_dev;
                %        obj.cwaveHandle.set_target_deviation(target_dev);
                %        obj.cwaveHandle.set_pid_target_wavelength(mid_setpoint);
                %        while abs(measured_wavelength - mid_setpoint) > target_dev
                %            obj.cwaveHandle.WLM_PID_Compute(measured_wavelength);
                %           pause(0.001);
                %        end
                %    end
                %    target_dev = target_dev/10;
                    
               
                while round(target_dev, 5) > 0
                    measured_wavelength = obj.wavemeterHandle.getWavelength();
                    mid_setpoint = measured_wavelength;
                    direction = sign(setpoint-mid_setpoint);
                    while abs(mid_setpoint - setpoint) > 2*target_dev
                        mid_setpoint = mid_setpoint + direction*target_dev/5;
                        obj.cwaveHandle.set_target_deviation(target_dev);
                        obj.cwaveHandle.set_pid_target_wavelength(mid_setpoint);
                        while abs(measured_wavelength - mid_setpoint) > target_dev
                            obj.cwaveHandle.WLM_PID_Compute(measured_wavelength);
                            pause(0.001);
                        end
                    end
                    target_dev = target_dev/10;    
                end
                obj.tuning = false;
            catch err 
            end
            delete(dlg)
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

        function TuneSetpoint(obj,setpoint)
            %TuneSetpoint Sets the wavemeter setpoint
            %   setpoint = setpoint in nm
            obj.cwaveHandle.fine_tune();
            target_dev = 0.02;
            obj.tune(setpoint,target_dev);
        end

        function TuneCoarse(obj, setpoint)
            %TuneCoarse moves the laser to the target frequency
            %
            %   It assumes the laser is already close enough to not 
            %   require changing of the OPO temperature to reach the target.
            %
            %   First it achieves accuracy to within a picometer by 
            %   changing the thick etalon piezo, then adjusts with
            %   the cavity piezo.
            % 
            %   setpoint = setpoint in nm
            obj.cwaveHandle.coarse_tune();
            target_dev = 0.2;
            obj.tune(setpoint,target_dev);
        end

        function TunePercent(obj, target)
            %TunePercent sets the resonator or the opo cavity piezo percentage
            %ref cavity has fsr = 10GHz, opo cavity has fsr = 40 GHz
            % For both cavties spectral drift for ~10 MHz steps is about 5-7 MHz
            %
            % percent = desired piezo percentage from 1 to 100 (float type)
            %This is the OPO resonator
            assert(~isempty(obj.cwaveHandle)&&isobject(obj.cwaveHandle) && isvalid(obj.cwaveHandle),'no cwave handle')
            assert(percent>=0 && percent<=100,'Target must be a percentage')
            %set opo cavity to tuning mode 
            if (obj.cwaveHandle.get_regopo() ~= 4)
                obj.cwaveHandle.set_regopo(4);
            end
            % tune at a limited rate per step
            currentPercent = obj.GetPercent;
            numberSteps = floor(abs(currentPercent-target)/obj.resonator_tune_speed);
            direction = sign(target-currentPercent);
            for i = 1:numberSteps
                obj.cwaveHandle.tune_opo_cavity(currentPercent+(i)*direction*obj.resonator_tune_speed);
            end
            obj.cwaveHandle.tune_opo_cavity(target);
            obj.resonator_percent = obj.GetPercent();
            obj.updateStatus(); % Get voltage of resonator
        end
        
        function updateStatus(obj)
            % Get status report from laser and update a few fields
            
            lock_status = obj.cwaveHandle.getStatus();
            obj.etalon_lock = obj.cwaveHandle.etalon_lock_stat;
            obj.opo_stepper = obj.cwaveHandle.opo_stepper_stat;
            obj.opo_temp = obj.cwaveHandle.opo_temp_stat;
            obj.shg_stepper = obj.cwaveHandle.shg_stepper_stat;
            obj.shg_temp = obj.cwaveHandle.shg_temp_stat;
            obj.thin_etalon = obj.cwaveHandle.thin_etalon_stat;
            obj.opo_lock = obj.cwaveHandle.opo_lock_stat;
            obj.shg_lock = obj.cwaveHandle.shg_lock_stat;
            obj.pump_emission = obj.cwaveHandle.laser_emission_stat;
            obj.ref_temp = obj.cwaveHandle.ref_temp_stat; 
            obj.getWavelength; % This sets wavelength_lock
            obj.tuning = ~lock_status;
            obj.setpoint = obj.cwaveHandle.WLM_PID_Setpoint;
            % Overwrite getWavelength tuning status with EMM tuning state 
        end

        function piezo = GetPercent(obj)
            piezo = obj.cwaveHandle.get_opo_cavity_percent();
            %piezo = obj.cwaveHandle.get_ref_cavity_percent();
        end

        function freq = getFrequency(obj)
            wavelength = obj.wavemeterHandle.getWavelength();
            freq = Sources.TunableLaser_invisible.c/wavelength;
        end

        % set methods

        function set.cwave_ip(obj,ip)
            err = obj.connect_driver('cwaveHandle', 'CWave', ip);
            if ~isempty(err)
                obj.cwave_ip = obj.no_server;
                rethrow(err)
            end
            obj.cwave_ip = ip;
        end

        function set.pulseStreamer_ip(obj, ip)
            err = obj.connect_driver('PulseStreamerMaster', 'PulseStreamerMaster.PulseStreamerMaster', ip);
            if ~isempty(err)
                obj.pulseStreamer_ip = obj.no_server;
                rethrow(err)
            end
            obj.pulseStreamer_ip = ip;
        end

        function set.wavemeter_ip(obj, ip)
            err = obj.connect_driver('wavemeterHandle', 'Wavemeter1Ch', ip);
            if ~isempty(err)
                obj.wavemeter_ip = obj.no_server;
                rethrow(err)
            end
            obj.wavemeter_ip = ip;
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
        
        function set.target_wavelength(obj,val)
            if isnan(val); obj.target_wavelength = val; return; end % Short circuit on NaN
            if obj.internal_call; obj.target_wavelength = val; return; end
            obj.tune(val);
        end
        
        

        
    end
end