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
    properties(Constant,Hidden)
        no_server = 'No Server';  % Message when not connected
        MaxThickEtalonRange = 0.375; %nm
    end
    properties(Hidden)
        sOPO_power;
        sSHG_power;
        sPump_power;
    end
    
    properties(SetAccess=protected)
        range = [Sources.TunableLaser_invisible.c./[450, 650],Sources.TunableLaser_invisible.c./[900, 1300]];
    end
     properties
        prefs = {'tuning','enabled','target_wavelength','wavelength_lock','etalon_lock',...
            'opo_stepper','opo_temp','shg_stepper', 'shg_temp','thin_etalon',...
            'opo_lock','shg_lock','pump_emission','ref_temp','resonator_percent',...
            'etalon_percent','PSline','pulseStreamer_ip','cwave_ip','wavemeter_ip',...
            'resonator_tune_speed','MidEtalon_wl','MaxEtalon_wl','MinEtalon_wl','EtalonStep'};
         show_prefs = {'tuning','enabled','target_wavelength','wavelength_lock','etalon_lock',...
            'opo_stepper','opo_temp','shg_stepper', 'shg_temp','thin_etalon',...
            'opo_lock','shg_lock','pump_emission','ref_temp','resonator_percent',...
            'etalon_percent','PSline','pulseStreamer_ip','cwave_ip','wavemeter_ip',...
            'MidEtalon_wl','MaxEtalon_wl','MinEtalon_wl','EtalonStep'...
            'resonator_tune_speed'};
        readonly_prefs = {'tuning','etalon_lock','opo_stepper','opo_temp',...
            'shg_stepper', 'shg_temp','thin_etalon','opo_lock','shg_lock',...
            'pump_emission','ref_temp','MidEtalon_wl'};
    end
    properties(SetObservable,GetObservable)
        enabled = Prefs.Boolean();
        resonator_percent =  Prefs.Double(0.00,'units','percent','min',0.00,'max',100.00);
        tuning = Prefs.Boolean(false, 'help_text','This is a readonly string.','readonly',true);
%         cwave_ip = Prefs.String('default',Sources.CWave.no_server,'allow_empty',true,'set','');
%         pulseStreamer_ip = Prefs.String(Sources.CWave.no_server,'allow_empty',false),'set','';
%         wavemeter_ip = Prefs.String(Sources.CWave.no_server,'allow_empty',false),'set','';
        PSline = Prefs.Integer('min',0,'help_text','indexed from 0'); % Index from 0 (Pulsestreamer has 8 digital out channels)
        resonator_tune_speed = Prefs.Double(0.5,'units','percent','min',0.001,'max',1); % percent per step
        etalon_lock = Prefs.Boolean('help_text','This is a readonly string.','readonly',true);
        etalon_percent = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        opo_stepper = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        opo_temp = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        shg_stepper = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        shg_temp = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        thin_etalon = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        opo_lock = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        shg_lock = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        pump_emission = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        ref_temp = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        wavelength_lock = Prefs.Boolean();
        OPO_power =  Prefs.Double(0.0,'units','mW','min',0,'max',5000);
        SHG_power = Prefs.Double(0.0,'units','mW','min',0,'max',5000);
        Pump_power = Prefs.Double(0.0,'units','mW','min',0,'max',5000);
        TempRef =  Prefs.Double(20.00,'units','Celcius','min',20,'max',170.00);
        TempOPO =  Prefs.Double(20.00,'units','Celcius','min',20,'max',170.00);
        TempSHG =  Prefs.Double(20.00,'units','Celcius','min',20,'max',170.00);
        TempRef_setpoint =  Prefs.Double(20.00,'units','Celcius','min',20,'max',170.00);
        TempOPO_setpoint =  Prefs.Double(20.00,'units','Celcius','min',20,'max',170.00);
        TempSHG_setpoint =  Prefs.Double(20.00,'units','Celcius','min',20,'max',170.00);
        %target_wavelength = Prefs.Double('default',NaN,'units','nm','min',450,'max',1300,'set','set_target_wavelength');
        cwave_ip = Sources.CWave.no_server;
        pulseStreamer_ip = Sources.CWave.no_server;
        wavemeter_ip = Sources.CWave.no_server;
        EtalonStep='';
        target_wavelength;
        MinEtalon_wl = '0';
        MaxEtalon_wl = '.25';
        
    end
    
    properties(SetAccess=private)
        PulseStreamerHandle %hardware handle
        wavemeterHandle
        cwaveHandle
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
        function arm(obj)
            obj.enabled = true;
        end
        function blackout(obj)
            obj.off()
            %possibly add code to depower switch (assuming it can be
            %powered by nidaq)
        end

        % tunable laser methods

         % tunable laser methods
        function tune(obj, setpoint,target_dev,coarse,lock)
            % target in nm
            obj.tuning = true;
            if setpoint < 899
                assert(setpoint>=obj.c/max(obj.range(1:2))&&setpoint<=obj.c/min(obj.range(1:2)),...
                sprintf('Wavelength must be in range [%g, %g] nm!!',obj.c./obj.range(1:2)))
            elseif setpoint >= 899
                assert(target>=obj.c/max(obj.range(3:4))&&target<=obj.c/min(obj.range(3:4)),...
                sprintf('Wavelength must be in range [%g, %g] nm!!',obj.c./obj.range(3:4)))
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
                obj.updateStatus;
                if (coarse == true)
                     if (obj.sOPO_power | obj.sSHG_power |  obj.sPump_power | obj.wavemeterHandle.getExposure == 2000)
                         detune = 2*obj.MaxThickEtalonRange;
                         disp(detune)
                         obj.wavemeterHandle.setExposureMode(false); %Manually set exposure 
                         obj.wavemeterHandle.setExposure(1); %set to 1ms
                     else
                         detune = abs(setpoint-obj.getWavelength);
                     end
                     
                     if  (detune > abs(obj.MaxEtalon_wl-obj.MinEtalon_wl)) | (detune > obj.MaxThickEtalonRange )
                         % need to add warning option allowsing user to exit
                         % this is a very costly operation
                         dlg = questdlg('Target wavelength exceeds tuning etalon and OPO range (> 0.2 nm)! Tuning will be very slow. Do you wish to continue with tuning?', ...
                             'Tuning Warning', ...
                             'Continue Tuning','Abort','Abort');
                         % Handle response
                         switch dlg
                             case 'Continue Tuning'
                                 obj.cwaveHandle.target_wavelength = setpoint + 1;
                                 obj.cwaveHandle.set_target_wavelength();
                                 pause(10);
                                 obj.cwaveHandle.target_wavelength = setpoint;
                                 obj.cwaveHandle.set_target_wavelength();
                                 while(1)
                                     ret = obj.locked;
                                     if  (ret == true)
                                         obj.updateStatus;
                                         break;
                                     else
                                         obj.updateStatus;
                                         pause(1);
                                     end
                                 end
                                 obj.wavemeterHandle.setExposureMode(true);
                                 obj.updateStatus;
                             case 'Abort'
                                 return
                         end 
                     elseif  abs(setpoint-obj.getWavelength) < abs(obj.MaxEtalon_wl-obj.MinEtalon_wl)
                         abort = obj.centerThickEtalon;
                         if (abort )
                             delete(dlg)
                             return
                         end
                         
                         if (lock == true)
                             while ( obj.cwaveHandle.get_regopo() ~= 2)
                                 obj.cwaveHandle.set_regopo(2);
                             end
                             if (obj.cwaveHandle.get_ref_cavity_percent ~= 50) 
                                 obj.TuneRefPercent(50.0);
                             end
                             obj.etalon_pid(setpoint,obj.ThickEtalonTolerance);
                             %obj.etalon_pid(setpoint);
                             for i=1:2
                                 obj.WLM_tune(setpoint,target_dev)
                             end
                         elseif (lock == false)
                             while ( obj.cwaveHandle.get_regopo() ~= 4)
                                 obj.cwaveHandle.set_regopo(4);
                                 pause(1);
                                 disp('regopo');
                                 obj.cwaveHandle.get_regopo
                                 disp('end iteration')
                             end
                             if (obj.GetPercent() ~= 50)
                                 obj.TunePercent(50);
                             end
                             obj.etalon_pid(setpoint);
                             for i=1:2
                                 obj.opo_pid(setpoint,target_dev);
                             end
                         end
                         obj.updateStatus;
                     end
                    
                 elseif coarse == false
                     if (lock == true)
                         if (obj.cwaveHandle.get_ref_cavity_percent ~= 50)
                             obj.TuneRefPercent(50.0);
                         end
                         obj.cwaveHandle.set_regopo(2);
                         for i=1:2
                             obj.WLM_tune(setpoint,target_dev)
                         end
                     else
                         if (obj.GetPercent() ~= 50)
                             obj.TunePercent(50);
                         end
                         %obj.set_regopo(4);
                         %obj.cwaveHandle.set_intvalue(obj.cwaveHandle.RegOpo_On,4);
                         obj.cwaveHandle.set_regopo(4);
                         for i=1:2
                             obj.opo_pid(setpoint,target_dev);
                         end
                     end
                     obj.updateStatus;
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
            elseif (lock)
                obj.wavelength_lock = true;
            end
            obj.setpoint = setpoint;
        end
        
        function WLM_tune(obj,setpoint,target_dev)
             switch nargin
                 case 1
                     target_dev = 0.000001;
             end
             obj.cwaveHandle.fine_tune();
             obj.cwaveHandle.setWLM_gains(obj.pWLM_gain,obj.iWLM_gain);
             obj.cwaveHandle.set_target_deviation(target_dev);
             obj.cwaveHandle.set_pid_target_wavelength(setpoint);
             measured_wavelength = obj.wavemeterHandle.getWavelength();
             while abs(measured_wavelength - setpoint) > target_dev
                 obj.cwaveHandle.WLM_PID_Compute(measured_wavelength);
                 if obj.wavemeterHandle.getExposure() > 100
                     delay = obj.wavemeterHandle.getExposure()/1000; %in seconds
                      pause(delay)
                 else
                     pause(0.0001) %(was 0.001 s)
                 end
                 measured_wavelength = obj.wavemeterHandle.getWavelength(); 
             end
        end
        
        function TuneSetpoint(obj,setpoint)
            %TuneSetpoint Sets the wavemeter setpoint
            %   setpoint = setpoint in THz
            %obj.cwaveHandle.fine_tune();
            %cwave.cwaveHandle.setWLM_gains(20,150);
            target_dev = 0.000001;
            isLocked = true;
            isCoarse = false;
            user_speed = obj.resonator_tune_speed;
            obj.resonator_tune_speed = 0.1;
            obj.tune(obj.c/setpoint,target_dev,isCoarse, isLocked); 
            obj.resonator_tune_speed = user_speed;
%             parfor i = 1:500
%                 obj.tune(setpoint,target_dev,isCoarse);    
%             end
        end

         function TuneCoarse(obj, setpoint)
            %TuneCoarse moves the laser to the target frequency (THz)
            %
            %   It assumes the laser is already close enough to not 
            %   require changing of the OPO temperature to reach the target.
            %
            %   First it achieves accuracy to within a picometer by 
            %   changing the thick etalon piezo, then adjusts with
            %   the cavity piezo.
            % 
            %   setpoint = setpoint in nm
            %obj.cwaveHandle.setWLM_gains(20,150);
            %obj.cwaveHandle.coarse_tune();
            
            dlgs = questdlg('Tune with OPO Cavity (Open Loop) or Reference Cavity (Closed Loop)?', ...
                             'Tuning Warning', ...
                             'OPO Cavity','Reference Cavity','Reference Cavity');
                         % Handle response
                         switch dlgs
                             case 'OPO Cavity'
                                 isLocked = false;
                                  obj.MaxEtalon = 50; %25; %25; 
                                 obj.MinEtalon = -50; %-1; %-25;
                             case 'Reference Cavity'
                                 isLocked = true;
                                 obj.MaxEtalon = 15; 
                                 obj.MinEtalon = -10;
                         end
            target_dev = 0.000001;
            isCoarse = true;
            user_speed = obj.resonator_tune_speed;
            obj.resonator_tune_speed = 0.1;
            obj.tune( obj.c/setpoint,target_dev,isCoarse,isLocked);
            obj.resonator_tune_speed = user_speed;
            %include error checks for power and clamping
        end

        function TunePercent(obj, target)
            %TunePercent sets the resonator or the opo cavity piezo percentage
            %ref cavity has fsr = 10GHz, opo cavity has fsr = 40 GHz
            % For both cavties spectral drift for ~10 MHz steps is about 5-7 MHz
            %
            % percent = desired piezo percentage from 1 to 100 (float type)
            %This is the OPO resonator
            assert(~isempty(obj.cwaveHandle)&&isobject(obj.cwaveHandle) && isvalid(obj.cwaveHandle),'no cwave handle')
            assert(target>=0 && target<=100,'Target must be a percentage')
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
        
        function wl = TuneRefPercent(obj, target)
            %TunePercent sets the resonator or the opo cavity piezo percentage
            %ref cavity has fsr = 10GHz, opo cavity has fsr = 40 GHz
            % For both cavties spectral drift for ~10 MHz steps is about 5-7 MHz
            %
            % percent = desired piezo percentage from 1 to 100 (float type)
            %This is the OPO resonator
            assert(~isempty(obj.cwaveHandle)&&isobject(obj.cwaveHandle) && isvalid(obj.cwaveHandle),'no cwave handle')
            assert(target>=0 && target<=100,'Target must be a percentage')
            %set opo cavity to tuning mode 
            if (obj.cwaveHandle.get_regopo() ~= 2)
                %obj.cwaveHandle.set_intvalue(obj.cwaveHandle.RegOpo_On,4)
                obj.cwaveHandle.set_regopo(2);
            end
            % tune at a limited rate per step
            currentPercent = obj.GetPercent;
            numberSteps = floor(abs(currentPercent-target)/obj.resonator_tune_speed);
            direction = sign(target-currentPercent);
            for i = 1:numberSteps
                %tstart = tic;
                obj.cwaveHandle.tune_ref_cavity(currentPercent+(i)*direction*obj.resonator_tune_speed);
                wl(i) = obj.wavemeterHandle.getWavelength;
                %telapsed(i+1) = toc(tstart);
            end
            obj.cwaveHandle.tune_ref_cavity(target);
            obj.resonator_percent = obj.GetPercent();
            obj.updateStatus(); % Get voltage of resonator
        end
        
         function updateStatus(obj)
            % Get status report from laser and update a few fields
            tic
            obj.locked = ~(obj.cwaveHandle.get_statusbits);
            obj.etalon_lock = ~obj.cwaveHandle.etalon_lock_stat;
            obj.opo_stepper_lock = ~obj.cwaveHandle.opo_stepper_stat;
            obj.opo_temp_lock = ~obj.cwaveHandle.opo_temp_stat;
            obj.shg_stepper_lock = ~obj.cwaveHandle.shg_stepper_stat;
            obj.shg_temp_lock = ~obj.cwaveHandle.shg_temp_stat;
            obj.thin_etalon_lock = ~obj.cwaveHandle.thin_etalon_stat;
            obj.opo_lock = ~obj.cwaveHandle.opo_lock_stat;
            obj.shg_lock = ~obj.cwaveHandle.shg_lock_stat;
            obj.pump_emission = ~obj.cwaveHandle.laser_emission_stat;
            obj.ref_temp_lock = ~obj.cwaveHandle.get_status_temp_ref;
           
            [obj.OPO_power,obj.sOPO_power] = obj.cwaveHandle.get_photodiode_opo;
            [obj.SHG_power,obj.sSHG_power] = obj.cwaveHandle.get_photodiode_shg;
            [obj.Pump_power,obj.sPump_power] = obj.cwaveHandle.get_photodiode_laser;
            obj.TempRef = obj.cwaveHandle.get_tref;
            obj.TempOPO = obj.cwaveHandle.get_topo;
            obj.TempSHG = obj.cwaveHandle.get_tshg;
            obj.TempRef_setpoint = obj.cwaveHandle.get_tref_sp;
            obj.TempOPO_setpoint = obj.cwaveHandle.get_topo_sp;
            obj.TempSHG_setpoint = obj.cwaveHandle.get_tshg_sp;
            
            regopo4_locked =  obj.etalon_lock & obj.opo_stepper_lock & obj.opo_temp_lock...
                & obj.shg_stepper_lock & obj.shg_temp_lock & obj.thin_etalon_lock & obj.pump_emission;
          
            if(obj.locked | ((obj.cwaveHandle.get_regopo == 4) & regopo4_locked))
                obj.setpoint = obj.c/obj.getWavelength;  % This sets wavelength_lock
            end

            obj.tuning = ~(obj.locked);
            
            if (~obj.locked) 
                %replace below with dialog box 
                disp('CWAVE Warning: All elements are not stable and/or locked.');
            end
            
            toc
            fprintf('toc %.8f\n',toc);
            %obj.setpoint = obj.cwaveHandle.WLM_PID_Setpoint;
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
        
        function wavelength = getWavelength(obj)
            wavelength = obj.wavemeterHandle.getWavelength();
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
            err = obj.connect_driver('PulseStreamerHandle', 'PulseStreamerMaster.PulseStreamerMaster', ip);
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
            %edite 10/30/19 note sure why this is read only???
            %if isnan(val); obj.target_wavelength = val; return; end % Short circuit on NaN
            %if obj.internal_call; obj.target_wavelength = val; return;
            %else
            obj.target_wavelength = eval(val);
            %end
            if strcmp(val,''); return; end
            %target_dev = 0.000001;
            %isCoarse = true;
            %isLocked = false;
            
            
            %obj.tune(obj.target_wavelength,target_dev,isCoarse,isLocked);
            obj.TuneCoarse(obj.c/obj.target_wavelength);
                           
%             obj.centerThickEtalon;
%             if  abs(obj.target_wavelength-obj.getWavelength) > abs(obj.MaxEtalon_wl-obj.MinEtalon_wl)
%                 % need to add warning option allowsing user to exit
%                 % this is a very costly operation
%                 dlg = questdlg('Target wavelength exceeds tuning etalon and OPO range (> 0.2 nm)! Tuning will be very slow. Do you wish to continue with tuning?', ...
%                     'Tuning Warning', ...
%                     'Continue Tuning','Abort','Abort');
%                     % Handle response
%                     switch answer
%                         case 'Tune'
%                             obj.cwaveHandle.target_wavelength = obj.target_wavelength + 1;
%                             obj.cwaveHandle.set_target_wavelength();
%                             pause(30)
%                             obj.cwaveHandle.target_wavelength = obj.target_wavelength;
%                             obj.cwaveHandle.set_target_wavelength();
%                         case 'Abort'
%                             return
%                         case 'Abort'
%                             return
%                     end 
%             %elseif abs(obj.target_wavelength-obj.getWavelength) < abs(obj.MaxEtalon-obj.MinEtalon)
%             else
%                 obj.TuneCoarse(obj.target_wavelength);
%             end
          end
        
        function abort = centerThickEtalon(obj)
              dlgs = questdlg('Is Min and Max range of Etalon correctly set? MaxEtalon_wl and MinEtalon_wl must be measured by autotune or manually by adjusting EtalonStep. If tuning manually MaxEtalon_wl and MinEtalon_wl in Cwave Source preferences', ...
                             'Centering Etalon Warning', ...
                             'Yes, Continue Tuning','No, Abort','No, Abort');
                         % Handle response
                         switch dlgs
                             case 'Yes, Continue Tuning'
                                 
                                 if abs(obj.MaxEtalon_wl-obj.MinEtalon_wl) > obj.MaxThickEtalonRange
                                     dlgs2 = questdlg('Exiting Tuning. User Selected Etalon range exceeds thick etalon range. Difference bewteen MaxEtalon_wl and MinEtalon_wl should be less than 0.2 nm.', ...
                                         'Thick Etalon Range Warning', ...
                                         'Reselect MaxEtalon_wl and MinEtalon_wl','Reselect MaxEtalon_wl and MinEtalon_wl');
                                     abort = true;     
                                     return;
                                 else
                                     obj.MidEtalon_wl = obj.MinEtalon_wl + abs(obj.MaxEtalon_wl-obj.MinEtalon_wl)/2;
                                     obj.etalon_pid(obj.MidEtalon_wl);
                                     abort = false;
                                 end
                             case 'No, Abort'
                                 abort = true;
                                 return;
                         end
                                 
        end
        
        function set.MaxEtalon_wl(obj,val)
              a = eval(val);
              obj.MaxEtalon_wl = a;
        end
        function set.MinEtalon_wl(obj,val)
               a = eval(val);
               obj.MinEtalon_wl = a;
        end
%           
        function set.EtalonStep(obj,val)
              obj.EtalonStep = eval(val);
              %disp(val);
              %obj.tune_etalon;
              obj.cwaveHandle.set_intvalue(obj.cwaveHandle.ThickEtalon_Piezo_hr,obj.EtalonStep); 
              pause(obj.EtalonMeasureDelay);
              %obj.updateStatus;
        end
          
        function tune_etalon(obj)
              obj.cwaveHandle.tune_thick_etalon(obj.EtalonStep);
              %obj.cwaveHandle.set_intvalue(obj.cwaveHandle.ThickEtalon_Piezo_hr,obj.EtalonStep); 
        end
          
        function set_regopo(obj,val)
              obj.cwaveHandle.set_intvalue(obj.cwaveHandle.RegOpo_On,val);
        end
          
        function val = get_regopo(obj)
              val = obj.cwaveHandle.get_regopo;
        end
          
        function delete(obj)
              obj.cwaveHandle.delete()
              obj.PulseStreamerHandle.delete() 
              obj.wavemeterHandle.delete()
        end
    end
end