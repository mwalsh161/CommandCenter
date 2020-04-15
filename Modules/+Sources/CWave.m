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
        OPOwindupGuardmax= 2; %1.5
        OPOwindupGuardmin= -2; %-1.5
        EtaWindupGuardmax = 10000; %was 100 on 11/6/19
        EtaWindupGuardmin = -10000; % was -100 on 11/6/19
        MaxPercent = 99.5; % percent
        MinPercent = 0.5; % percent
        MaxThickEtalonRange = 0.375; %nm
        pWLM_gain = 10; %10;
        iWLM_gain = 75 ; %75;
        EtalonStepperDelay = 0.1; % ms
        EtalonMeasureDelay = 1.5; %seconds
        wmExposureTolerance = 0.99; %was 0.05 % percent/100
        powerStatusDelay = 1; % seconds
        timeoutAllElements = 300;
        timeoutSHG = 95; % 7 sig = 95 secs seconds
        timeoutThickEtalon = 40;% mean %seconds
        wmPower_min = 0; %units?
        Eta_minSHGPower = 85; % wameter timout with set to 85; see if recurs at 100
        maxExpTime = 800;
        OPOrLambdaFloor = 10;
    end
    properties(Hidden)
        MaxEtalon = 15; % in pm %maybe step these down to 15 look a little unstable when trying to ajdust thick etalon manually with 0.025nm steps
        MinEtalon = -10;% in pm %maybe step this down to 15
        LocalMaxEtalon = 6;
        LocalMinEtalon = -6;
        windupGuardmax = 0;
        windupGuardmin = 0;
        sOPO_power;
        sSHG_power;
        sPump_power;
        ThickEtalonTolerance = 0.005; %nm
        midTuneTolerance = 0.1;
        MaxEtalon_wlSD;
        MinEtalon_wlSD;
    end
    properties(SetAccess=protected)
        range = [Sources.TunableLaser_invisible.c./[450, 650],Sources.TunableLaser_invisible.c./[900, 1300]];
    end
     properties
        prefs = {'tuning','enabled','target_wavelength','wavelength_lock','etalon_lock',...
            'opo_stepper_lock','opo_temp_lock','shg_stepper_lock', 'shg_temp_lock','thin_etalon_lock',...
            'opo_lock','shg_lock','pump_emission','ref_temp_lock','resonator_percent',...
            'etalon_percent','PBline','pulseStreamer_ip','cwave_ip','wavemeter_ip',...
            'resonator_tune_speed','tunePercentRange','MaxEtalon_wl','MinEtalon_wl',...
            'EtalonStep','MidEtalon_wl','OPO_power','SHG_power','Pump_power','AllElementStep',...
            'TempRef','TempOPO', 'TempSHG','TempRef_setpoint','TempOPO_setpoint', 'TempSHG_setpoint','TempBase','TempFPGA'}; %,'TempBase','TempFPGA'
         show_prefs = {'TempBase','TempFPGA','target_wavelength','resonator_percent','AllElementStep','EtalonStep','tunePercentRange',...
            'resonator_tune_speed','MidEtalon_wl','MaxEtalon_wl','MinEtalon_wl','tuning',...
            'enabled','wavelength_lock','etalon_lock','opo_stepper_lock','opo_temp_lock','shg_stepper_lock',...
            'shg_temp_lock','thin_etalon_lock','opo_lock','shg_lock','pump_emission','ref_temp_lock',...
            'etalon_percent','OPO_power','SHG_power','Pump_power','TempOPO','TempOPO_setpoint',...
            'TempSHG','TempSHG_setpoint','TempRef','TempRef_setpoint','PBline',...
            'pulseStreamer_ip','cwave_ip','wavemeter_ip'}; % 'TempBase','TempFPGA',
        readonly_prefs = {'tuning','etalon_lock','opo_stepper_lock','opo_temp_lock',...
            'shg_stepper_lock', 'shg_temp_lock','thin_etalon_lock','opo_lock','shg_lock',...
            'pump_emission','ref_temp_lock','MidEtalon_wl','resonator_percent', ...
            'OPO_power','SHG_power','Pump_power','TempRef','TempOPO', 'TempSHG',...
            'TempRef_setpoint','TempOPO_setpoint', 'TempSHG_setpoint','TempBase','TempFPGA'}; % ,'TempBase','TempFPGA'
     end
    properties(SetObservable,GetObservable)
        MidEtalon_wl = '';
        enabled = Prefs.Boolean();
        resonator_percent =  Prefs.Double(0.00,'units','percent','min',0.00,'max',100.00);
        tuning = Prefs.Boolean(false, 'help_text','This is a readonly string.','readonly',true);
%         cwave_ip = Prefs.String('default',Sources.CWave.no_server,'allow_empty',true,'set','');
%         pulseStreamer_ip = Prefs.String(Sources.CWave.no_server,'allow_empty',false),'set','';
%         wavemeter_ip = Prefs.String(Sources.CWave.no_server,'allow_empty',false),'set','';
        PBline = Prefs.Integer('min',0,'help_text','indexed from 0'); % Index from 0 (Pulsestreamer has 8 digital out channels)
        resonator_tune_speed = Prefs.Double(0.5,'units','percent','min',0.001,'max',1); % percent per step
        etalon_lock = Prefs.Boolean('help_text','This is a readonly string.','readonly',true);
        etalon_percent = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        opo_stepper_lock = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        opo_temp_lock = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        shg_stepper_lock = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        shg_temp_lock = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        thin_etalon_lock = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        opo_lock = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        shg_lock = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        pump_emission = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        ref_temp_lock = Prefs.Boolean( 'help_text','This is a readonly string.','readonly',true);
        wavelength_lock = Prefs.Boolean();
        OPO_power =  Prefs.Double(0.0,'units','mW','min',0,'max',5000);
        SHG_power = Prefs.Double(0.0,'units','mW','min',0,'max',5000);
        Pump_power = Prefs.Double(0.0,'units','mW','min',0,'max',5000);
        TempBase =  Prefs.Double(20.00,'units','Celcius','min',20,'max',170.00);
        TempFPGA =  Prefs.Double(20.00,'units','Celcius','min',20,'max',170.00);
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
        target_wavelength='';
        tunePercentRange = ''; %tunePercentRange = Prefs.DoubleArray();
        EtalonStep='';
        AllElementStep = '';
        MinEtalon_wl = '';
        MaxEtalon_wl = '';
    end
    
    properties(SetAccess=private)
        PulseStreamerHandle %hardware handle
        wavemeterHandle
        cwaveHandle
    end

    methods(Access=private)
        function obj = CWave()
            obj.loadPrefs;
            % while loop with poling to cehck that all drivers are loaded.
            % if they are then run updateStatus and set initial conditions
            % such as wavemeter continuous model alternatively set these to
            % directly in the set.ip methods.
            %obj.updateStatus; %updateStatus before cwave library loaded.
            %can have it here.
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
            state = PulseStreamer.OutputState([obj.PBline],0,0);
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
        function tune(obj, setpoint,target_dev,coarse,lock)
            if (obj.wavemeterHandle.getResultMode ~= 0)
                obj.wavemeterHandle.setResultMode(0);
                 % initialize into WavelengthVac mode.
                 %    'cReturnWavelengthVac' = 0
            end
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
                                 isCoarseTuned = false;
                                 while( isCoarseTuned == false)
                                     abort_tune = obj.is_cwaveReady(1);
                                     isCoarseTuned = obj.locked;
                                     if  (isCoarseTuned == true)
                                         return;
                                     elseif (abort_tune == true)
                                         
                                         return;
                                     end
                                 end
                                 %check if user has selected to exit
                                 %tuning
                                 if (abort_tune)
                                     delete(dlg)
                                     return
                                 end
                                 obj.wavemeterHandle.setExposureMode(true); %set exposure mode to automatic
                                 obj.updateStatus;
                                 
                                 if ( obj.locked == true & abs(setpoint-obj.getWavelength) > obj.midTuneTolerance )
                                     direction = sign(setpoint-obj.getWavelength);
                                     while abs(setpoint-obj.getWavelength) > obj.midTuneTolerance % = 0.1 nm
                                         control = direction*abs(setpoint-obj.getWavelength);
                                         if abs(control) < 2.5*obj.OPOrLambdaFloor
                                             control = direction*(obj.OPOrLambdaFloor);
                                         end
                                         obj.cwaveHandle.set_OPOrLambda(obj,floor(control));
                                         abort_tune = obj.is_cwaveReady(1,true);
                                         %check if user has selected to exit
                                         %tuning
                                         if (abort_tune )
                                             break
                                         end
                                         
                                         obj.updateStatus;
                                         tic
                                         while (( obj.SHG_power < obj.cwaveHandle.SHG_MinPower) )    % | powerSHG_status == false)
                                             pause(1)
                                             abort = obj.is_cwaveReady(1,false);
                                             %check if user has selected to exit
                                             %tuning
                                             if (abort_tune )
                                                break
                                             end
                                             obj.updateStatus;
                                             %[currSHG_power, powerSHG_status] = obj.cwaveHandle.get_photodiode_shg;
                                             timer = toc;
                                             if timer > obj.timeoutSHG
                                                 abort_tune = true;
                                                 break
                                             end
                                         end
                                     end
                                     %check if user has selected to exit
                                     %tuning
                                     if (abort_tune )
                                         delete(dlg)
                                         %maybe I should have a error
                                         %statement here
                                         return
                                     end
                                 elseif (obj.locked == false)
                                     error('Coarse tuning failed...Are you banging the table you fool. It is an OPO!')
                                 elseif (abs(setpoint-obj.getWavelength) > obj.midTuneTolerance)
                                     regopo4_locked =  obj.etalon_lock & obj.opo_stepper_lock & obj.opo_temp_lock...
                                         & obj.shg_stepper_lock & obj.shg_temp_lock & obj.thin_etalon_lock & obj.pump_emission;
                                     regOPO4_cond =  regopo4_locked == true & obj.cwaveHandle.get_regopo == 4 & ...
                                         abs(setpoint-obj.getWavelength) > obj.midTuneTolerance;
                                     regOPO2_cond =  obj.locked == true & obj.cwaveHandle.get_regopo == 2 & ... 
                                         abs(setpoint-obj.getWavelength) > obj.midTuneTolerance;
                                     
                                     obj.updateStatus;
                                     if (regOPO2_cond | regOPO4_cond)
                                         direction = sign(setpoint-obj.getWavelength);
                                         while abs(setpoint-obj.getWavelength) > obj.midTuneTolerance % = 0.1 nm
                                             control = direction*abs(setpoint-obj.getWavelength);
                                             if abs(control) < 2.5*obj.OPOrLambdaFloor
                                                 control = direction*(obj.OPOrLambdaFloor);
                                             end
                                             obj.cwaveHandle.set_OPOrLambda(obj,floor(control));
                                             abort_tune = obj.is_cwaveReady(1,true);
                                             %check if user has selected to exit
                                             %tuning
                                             if (abort_tune )
                                                 break
                                             end
                                             obj.updateStatus;
                                             tic
                                             while (( obj.SHG_power < obj.cwaveHandle.SHG_MinPower) )    % | powerSHG_status == false)
                                                 pause(1)
                                                 abort = obj.is_cwaveReady(1,false);
                                                 %check if user has selected to exit
                                                 %tuning
                                                 if (abort_tune )
                                                    break
                                                 end
                                                 obj.updateStatus;
                                                 timer = toc;
                                                 if timer > 2*obj.timeoutSHG
                                                     abort_tune = true;
                                                     break
                                                 end
                                             end
                                         end
                                         %check if user has selected to exit
                                         %tuning
                                         if (abort_tune )
                                             delete(dlg)
                                             %maybe I should have a error
                                             %statement here
                                             return
                                         end
                                     else
                                         error('Coarse tuning failed...Are you banging the table you fool. It is an OPO!')
                                     end
                                 elseif ( obj.locked == true & abs(setpoint-obj.getWavelength) < obj.midTuneTolerance &  abs(setpoint-obj.getWavelength) > obj.ThickEtalonTolerance )
                                     abort = obj.centerThickEtalon;
                                     if (abort )
                                         delete(dlg)
                                         return
                                     end
                                 else
                                     if (lock == true)
                                         while ( obj.cwaveHandle.get_regopo() ~= 2)
                                             obj.cwaveHandle.set_regopo(2);
                                             pause(0.1);
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
                                             pause(0.1);
                                         end
                                         % error tuning occure 11/08/19
                                         % somewhere between line 378-385
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
            target_dev = 0.000001;
            isLocked = true;
            isCoarse = false;
            user_speed = obj.resonator_tune_speed;
            obj.resonator_tune_speed = 0.1;
            obj.tune(obj.c/setpoint,target_dev,isCoarse, isLocked); 
            obj.resonator_tune_speed = user_speed;
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

        function wl = TunePercent(obj, target)
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
                %tstart = tic;
                obj.cwaveHandle.tune_opo_cavity(currentPercent+(i)*direction*obj.resonator_tune_speed);
                wl(i) = obj.wavemeterHandle.getWavelength;
                %telapsed(i+1) = toc(tstart);
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
            % taskes roughly 500 ms to run
            obj.TempBase = obj.cwaveHandle.get_tBase;
            assert(obj.TempBase < 23.25, 'CWave base temperature is high. Check the plumbing you fool!')
            obj.TempFPGA = obj.cwaveHandle.get_tFPGA;
            obj.TempRef = obj.cwaveHandle.get_tref;
            obj.TempOPO = obj.cwaveHandle.get_topo;
            obj.TempSHG = obj.cwaveHandle.get_tshg;
            obj.TempRef_setpoint = obj.cwaveHandle.get_tref_sp;
            obj.TempOPO_setpoint = obj.cwaveHandle.get_topo_sp;
            obj.TempSHG_setpoint = obj.cwaveHandle.get_tshg_sp;
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
            obj.ref_temp_lock = ~obj.cwaveHandle.ref_temp_stat;
           
            [obj.OPO_power,obj.sOPO_power] = obj.cwaveHandle.get_photodiode_opo;
            [obj.SHG_power,obj.sSHG_power] = obj.cwaveHandle.get_photodiode_shg;
            [obj.Pump_power,obj.sPump_power] = obj.cwaveHandle.get_photodiode_laser;
            
            
            regopo4_locked =  obj.etalon_lock & obj.opo_stepper_lock & obj.opo_temp_lock...
                & obj.shg_stepper_lock & obj.shg_temp_lock & obj.thin_etalon_lock & obj.pump_emission;
            
            if( (obj.locked & obj.SHG_power > obj.Eta_minSHGPower  ) | ( (obj.cwaveHandle.get_regopo == 4 ...
                    & regopo4_locked & obj.sSHG_power == false) & obj.SHG_power > obj.Eta_minSHGPower) )
                obj.setpoint = obj.c/obj.getWavelength;  % This sets wavelength_lock
            else
                obj.setpoint = NaN;
            end
 
            obj.tuning = ~(obj.locked);
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
            
            while(1)
                if libisloaded(obj.cwaveHandle.LibraryName)
                    obj.updateStatus;
                    break
                end
                pause(1);
            end
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
            obj.TuneCoarse(obj.c/obj.target_wavelength);
        end
        function set.MaxEtalon_wl(obj,val)
            if strcmp(val,'')
                return
            end
            a = eval(val);
            obj.MaxEtalon_wl = a;
        end
        function set.MinEtalon_wl(obj,val)
            if strcmp(val,'')
                return
            end
            a = eval(val);
            obj.MinEtalon_wl = a;
        end  
        function set.EtalonStep(obj,val)
            if strcmp(val,'')
                return
            end
            if obj.SHG_power < obj.Eta_minSHGPower
                if abs(eval(val)) >= 0  
                    i = 0;
                    while obj.SHG_power < obj.Eta_minSHGPower
                        i = i +1;
                        pause(0.1)
                        if obj.SHG_power > obj.Eta_minSHGPower | i > 5
                            break;
                        end
                    end
                    str = 'Please wait. CWave attempting to lock and optimize SHG power.';
                    dlg = msgbox(str,mfilename,'modal');
                    textH = findall(dlg,'tag','MessageBox');
                    delete(findall(dlg,'tag','OKButton'));
                    drawnow;
                    obj.is_cwaveReady(3.5,true,true);
                    pause(3)
                    delete(dlg)
                end
            else
                obj.is_cwaveReady(1,false,false);
                obj.EtalonStep = eval(val); 
                obj.tune_etalon;
            end
        end
        function set.AllElementStep(obj,val)
            if strcmp(val,'')
                return
            end
            [obj.SHG_power,~] = obj.cwaveHandle.get_photodiode_shg;
            if obj.SHG_power < obj.Eta_minSHGPower
                if abs(eval(val)) >= 0  
                    str = 'Please wait. CWave attempting to lock and optimize SHG power.';
                    dlg = msgbox(str,mfilename,'modal');
                    textH = findall(dlg,'tag','MessageBox');
                    delete(findall(dlg,'tag','OKButton'));
                    drawnow;
                    obj.is_cwaveReady(3.5,true,true);
                    pause(3)
                    delete(dlg)
                end
            else
                obj.is_cwaveReady(0.005,false,false);
                obj.AllElementStep = floor( eval(val) );
                obj.cwaveHandle.set_OPOrLambda(obj.AllElementStep);
                str = 'Please wait. CWave attempting to lock and optimize SHG power.';
                dlg = msgbox(str,mfilename,'modal');
                textH = findall(dlg,'tag','MessageBox');
                delete(findall(dlg,'tag','OKButton'));
                drawnow;
                obj.is_cwaveReady(3.5,true,true);
                pause(3)
                delete(dlg);
            end
        end

        function set.tunePercentRange(obj,val)
              
            obj.tunePercentRange = eval(val);
            if (strcmp( val,''))
                return
            end
              
            dlgs = questdlg('Tune with OPO Cavity (Open Loop) or Reference Cavity (Closed Loop)?', ...
                           'Tuning Warning', ...
                           'OPO Cavity','Reference Cavity','Reference Cavity');
                       % Handle response
                       switch dlgs
                           case 'OPO Cavity'
                               isLocked = false;
                           case 'Reference Cavity'
                               isLocked = true;
                       end
                                
            if (isLocked == true)
                while ( obj.get_regopo() ~= 2)
                    obj.set_regopo(2);
                    pause(1);
                    disp('regopo');
                    obj.get_regopo
                    disp('end iteration')
                end
            elseif (isLocked == false)
                obj.set_regopo(4);
                 while ( obj.get_regopo() ~= 4)
                    obj.set_regopo(4);
                    pause(1);
                    disp('regopo');
                    obj.get_regopo
                    disp('end iteration')
                end
            end
            tuneRange =  obj.tunePercentRange;
              
            %Tune to opo center
            str1 = 'Please wait while cavity tunes to';
            str = strcat(str1, ' 50%.');
            dlg = msgbox(str,mfilename,'modal');
            textH = findall(dlg,'tag','MessageBox');
            delete(findall(dlg,'tag','OKButton'));
            drawnow;
            if (isLocked == true)
                obj.TuneRefPercent(50);
            elseif (isLocked == false)
                obj.TunePercent(50);
            end
            delete(dlg);

            %Tune to low end
            str = strcat(str1, sprintf(' %.2f%%',tuneRange(1)));
            dlg = msgbox(str,mfilename,'modal');
            textH = findall(dlg,'tag','MessageBox');
            delete(findall(dlg,'tag','OKButton'));
            drawnow;
            if (isLocked == true)
                obj.TuneRefPercent(tuneRange(1));
            elseif (isLocked == false)
                obj.TunePercent(tuneRange(1));
            end
            delete(dlg);

            %Tune to high end
            str = strcat(str1, sprintf(' %.2f%%',tuneRange(2)));
            dlg = msgbox(str,mfilename,'modal');
            textH = findall(dlg,'tag','MessageBox');
            delete(findall(dlg,'tag','OKButton'));
            drawnow;
            if (isLocked == true)
                obj.TuneRefPercent(tuneRange(2));
            elseif (isLocked == false)
                obj.TunePercent(tuneRange(2));
            end
            delete(dlg);

            %Tune back to center
            str1 = 'Please wait while cavity tunes to';
            str = strcat(str1, ' 50%.');
            dlg = msgbox(str,mfilename,'modal');
            textH = findall(dlg,'tag','MessageBox');
            delete(findall(dlg,'tag','OKButton'));
            drawnow;
            if (isLocked == true)
                obj.TuneRefPercent(50.0);
            elseif (isLocked == false)
                obj.TunePercent(50.0);
            end
            delete(dlg);
        end          
          
        function exit = EtalonStepper(obj ,step, delay_val)
            %step etalon
            obj.cwaveHandle.tune_thick_etalon(step);
            pause(delay_val);
            exit = false;
            [obj.SHG_power, obj.sSHG_power] = obj.cwaveHandle.get_photodiode_shg;
            if (obj.SHG_power > obj.Eta_minSHGPower) %minimum threshold uncertian...
                exit = true;
            end                                            
        end
          
        function [wm_wl,wm_power,wm_exptime] = powerStatus(obj, tol,delay_val,errorHandling,timeOut)
                    
            switch nargin 
                case 1
                    tol = obj.wmExposureTolerance;
                    delay_val = 0.01;
                    errorHandling = false;
                    timeOut = 0.1;
                case 2
                    delay_val = 0.01;
                    errorHandling = false;
                    timeOut = 0.1;
                case 3
                    errorHandling = false;
                    timeOut = 0.1;
                case 4
                    timeOut = 0.1;

            end
            i = 0;
            max_interation = 5;
            MaxExposuretime = 1500;
            obj.is_EtalonRelocked();
            prev_expTime = obj.wavemeterHandle.getExposure();
            curr_expTime = 100000*prev_expTime;
            while (  curr_expTime <= (1-tol)*prev_expTime | curr_expTime >= (1+tol)*prev_expTime )
                prev_expTime = obj.wavemeterHandle.getExposure();
                pause(obj.wavemeterHandle.getExposure/2000+0.01);
                curr_expTime = obj.wavemeterHandle.getExposure();   
                i = i+1;

                if errorHandling == false
                    [obj.SHG_power, ~] = obj.cwaveHandle.get_photodiode_shg;
                else
                    obj.is_cwaveReady(delay_val,false,false,timeOut)
                end
                if i > max_interation & errorHandling == true
                    regopo4_locked =  obj.etalon_lock & obj.opo_stepper_lock & obj.opo_temp_lock...
                        & obj.shg_stepper_lock & obj.shg_temp_lock & obj.thin_etalon_lock & obj.pump_emission;

                    regopo4_noEta_locked =   obj.opo_stepper_lock & obj.opo_temp_lock...
                        & obj.shg_stepper_lock & obj.shg_temp_lock & obj.thin_etalon_lock & obj.pump_emission;

                    if (obj.cwaveHandle.get_regopo == 4)
                        if( regopo4_locked == false)
                            error('CWave is not locked for regopo4. Refer to lock status to determine failing elements. Currently in OPO regulator mode 4.');
                        elseif (regopo4_noEta_locked == true & obj.etalon_lock == false)
                            error('Etalon is not locked. Currently in OPO regulator mode 4.');
                        elseif (regopo4_locked == true & powerSHG_status == true)
                            dialog2 = msgbox('insufficient power from SHG.',mfilename,'modal');
                                             textH = findall(dlg,'tag','MessageBox');
                                             drawnow;
                            disp('insufficient power from SHG.');
                        end
                    end

                    if (obj.cwaveHandle.get_regopo == 2)
                        if (regopo4_locked == true &  obj.etalon_lock == true & obj.shg_lock == false )
                            error('SHG cannot lock. Try retuning manually. Currently in OPO regulator mode 2.')
                        elseif (regopo4_locked == true &  obj.etalon_lock == false & obj.shg_lock == true )
                            error('Etalon cannot lock. Try retuning manually. Currently in OPO regulator mode 2.')
                        elseif (regopo4_locked == true &  obj.etalon_lock == false & obj.shg_lock == false )
                            error('Etalon and SHG cannot lock. Try retuning manually. Currently in OPO regulator mode 2.')
                        end
                    end

                    if( obj.wavemeterHandle.setExposure >= MaxExposuretime)
                        error('Dim emission. Check that light is well coupled into wave meter')
                    else
                        error('Large fluctuations in CWave power.')
                    end


                elseif ( (1+tol)*prev_expTime >= curr_expTime & curr_expTime >= (1-tol)*prev_expTime )

                    if (obj.SHG_power > obj.Eta_minSHGPower) %obj.sSHG_power == false
                        %pause(0.005);
                        wm_wl = obj.getWavelength(); 
                        wm_power = obj.wavemeterHandle.getPower(); 
                        wm_exptime = obj.wavemeterHandle.getExposure(); 
                    elseif (obj.SHG_power < obj.Eta_minSHGPower) %obj.sSHG_power == true)
                        wm_wl = NaN;
                        wm_power = NaN;
                        wm_exptime = NaN;
                    end  
                    return;
                end

            end
        end
          
        function Lock_Status = regopo_lockStatus(obj)
            obj.updateStatus;
            pause(1);
            regOPO_State = obj.cwaveHandle.get_regopo;
            pause(1);
            if (regOPO_State == 4)
                Lock_Status =  (obj.etalon_lock & obj.opo_stepper_lock & obj.opo_temp_lock...
                    & obj.shg_stepper_lock & obj.shg_temp_lock & obj.thin_etalon_lock & obj.pump_emission);
            elseif (regOPO_State == 2)
                Lock_Status = obj.locked;
            elseif (regOPO_State  ~= 4 | regOPO_State  ~= 2 )
                Lock_Status = false;
            else
                Lock_Status = false;
            end    
        end
          
        function abort = is_cwaveReady(obj,delay_val,SHG_tuning,allStatus,timeOut)
            switch nargin
                case 1
                    delay_val = 1;
                    SHG_tuning = false;
                    allStatus = true;
                    timeOut = obj.timeoutThickEtalon;
                case 2
                    SHG_tuning = false;
                    allStatus = true;
                    timeOut = obj.timeoutThickEtalon;
                case 3
                    allStatus = true;
                    timeOut = obj.timeoutThickEtalon;
                case 4
                    timeOut = obj.timeoutThickEtalon;
            end
            OPOsettle_Delay = 2.5;        
            abort = false;
            time = 0;
            tic;
            i = 1;
            [obj.SHG_power, ~] = obj.cwaveHandle.get_photodiode_shg;
            while(obj.SHG_power < obj.Eta_minSHGPower) 
                pause(delay_val); %in seconds
                if allStatus == true
                    pause(OPOsettle_Delay);
                    LockStatus = obj.regopo_lockStatus; % this updates the status run updateStatus
                else
                    LockStatus = true; %force LockStatus true 
                    [obj.SHG_power, obj.sSHG_power] = obj.cwaveHandle.get_photodiode_shg;
                    if i == 1
                        dialog = msgbox('Please wait while Cwave status is checked.',mfilename,'modal');
                        textH = findall(dialog,'tag','MessageBox');
                        delete(findall(dialog,'tag','OKButton'));
                        drawnow;
                    end
                    i = i+1;
                end
                time = toc; 
                if (SHG_tuning == true & (obj.shg_lock == false | obj.shg_temp_lock == false | obj.SHG_power < obj.Eta_minSHGPower | obj.wavemeterHandle.getExposure() > obj.maxExpTime) )
                    dialog = msgbox('Please wait while CWave re-optimizes SHG power.',mfilename,'modal');
                    textH = findall(dialog,'tag','MessageBox');
                    delete(findall(dialog,'tag','OKButton'));
                    drawnow;
                    %try first relocking etalon upon first iteration otherwise try repomtimizing the SHG;
                    if (i ==1)
                        i = i+1;
                        obj.cwaveHandle.relock_etalon;
                    end
                    dialog0 = msgbox('Relocking etalon.',mfilename,'modal');
                    textH = findall(dialog0,'tag','MessageBox');
                    delete(findall(dialog0,'tag','OKButton'));
                    drawnow;
                    while obj.SHG_power < obj.Eta_minSHGPower 
                        pause(OPOsettle_Delay)
                        LockStatus = obj.regopo_lockStatus;
                        time = toc;
                        if (LockStatus & obj.SHG_power > obj.Eta_minSHGPower) 
                            delete(dialog)
                            break;
                        elseif (time > timeOut & obj.wavemeterHandle.getExposure() > obj.maxExpTime)
                           break;
                        end
                        
                    end
                    delete(dialog0)
                    pause(delay_val)
                    if (obj.SHG_power < obj.Eta_minSHGPower)  
                        time = 0;
                        timeOut = obj.timeoutSHG;
                        tic;
                        obj.cwaveHandle.set_regopo(2);
                        obj.cwaveHandle.optimize_shg();
                        dialog1 = msgbox('Please wait. Re-optimizing SHG.',mfilename,'modal');
                        textH = findall(dialog1,'tag','MessageBox');
                        delete(findall(dialog1,'tag','OKButton'));
                        drawnow;
                        
                        while (obj.SHG_power < obj.Eta_minSHGPower)
                            pause(5)
                            LockStatus = obj.regopo_lockStatus;
                            time = toc;
                            if LockStatus &  obj.SHG_power > obj.Eta_minSHGPower
                                delete(dialog)
                                delete(dialog1)
                                break;
                            elseif (time > timeOut & obj.wavemeterHandle.getExposure() > obj.maxExpTime)
                                delete(dialog);
                                delete(dialog1)
                                dialog2 = msgbox('SHG Power is low. Retune.',mfilename,'modal');
                                textH = findall(dialog,'tag','MessageBox');
                                drawnow;
                                break;
                            end
                              
                        end
                    elseif time > obj.timeoutAllElements
                        delete(dialog);
                        dialog3 =  questdlg('Tuning Timed out. Continue or abort tuning?', ...
                           'Cwave Not Ready', ...
                            'Continue','Abort','Abort');
                        % Handle response
                        switch dialog3
                            case 'Continue'
                                tic;
                            case 'Abort'
                                obj.cwaveHandle.abort_tune;
                                abort = true;
                                return;
                        end
                    end
                end
                  
                if (LockStatus & obj.SHG_power > obj.Eta_minSHGPower)
                    if LockStatus == true
                        delete(dialog)
                    end
                    abort = false;
                    break;
                elseif (time > timeOut & obj.wavemeterHandle.getExposure() > obj.maxExpTime)
                    if LockStatus == true
                        delete(dialog)
                    end
                    abort = true;
                    break;
                else
                    continue;
                end
            end
        end
          
          function abort = centerThickEtalon(obj)
              abort = false;
              dlgs = questdlg('Is Min and Max range of Etalon correctly set? MaxEtalon_wl and MinEtalon_wl must be measured by autotune or manually by adjusting EtalonStep. If tuning manually MaxEtalon_wl and MinEtalon_wl in Cwave Source preferences', ...
                             'Centering Etalon Warning', ...
                             'Yes, Continue Tuning','No, Please Autotune', 'No, Abort','No, Abort');
                         % Handle response
                         switch dlgs
                             case 'Yes, Continue Tuning'
                                 
                                 if abs(obj.MaxEtalon_wl-obj.MinEtalon_wl) > obj.MaxThickEtalonRange
                                     dlgs2 = questdlg('Exiting Tuning. User Selected Etalon range exceeds thick etalon range. Difference bewteen MaxEtalon_wl and MinEtalon_wl should be less than 0.2 nm.', ...
                                         'Thick Etalon Range Warning', ...
                                         'Overide', 'Reselect MaxEtalon_wl and MinEtalon_wl','Reselect MaxEtalon_wl and MinEtalon_wl');
                                     switch dlgs2
                                         case 'Reselect MaxEtalon_wl and MinEtalon_wl'
                                             abort = true;
                                             return;
                                         case 'Overide'
                                             obj.MidEtalon_wl = obj.MinEtalon_wl + abs(obj.MaxEtalon_wl-obj.MinEtalon_wl)/2;
                                             obj.cwaveHandle.relock_etalon();
                                             pause(1);
                                             obj.is_cwaveReady(3.5,false,false);
                                             obj.etalon_pid(obj.MidEtalon_wl);
                                             abort = false;
                                     end
                                 else
                                     obj.MidEtalon_wl = obj.MinEtalon_wl + abs(obj.MaxEtalon_wl-obj.MinEtalon_wl)/2;
                                     obj.cwaveHandle.relock_etalon();
                                     pause(1);
                                     obj.is_cwaveReady(3.5,false,false);
                                     obj.etalon_pid(obj.MidEtalon_wl);
                                     abort = false;
                                 end
                                 
                                 
                             case 'No, Please Autotune'
                                 pstep = 25;
                                 nstep = -25;
                                 obj.updateStatus;
 
                                 PowerMeasureCondition_regopo2 = (obj.ref_temp_lock == true) & (obj.pump_emission == true) & ...
                                     (obj.opo_lock == true) & (obj.thin_etalon_lock == true) & ...
                                     (obj.shg_temp_lock == true) & (obj.shg_stepper_lock == true) & ...
                                     (obj.opo_temp_lock == true) & (obj.opo_stepper_lock == true);
                                 
                                 PowerMeasureCondition_regopo4 = (obj.ref_temp_lock == true) & (obj.pump_emission == true) & ...
                                     (obj.thin_etalon_lock == true) & (obj.shg_temp_lock == true) &...
                                     (obj.shg_stepper_lock == true) & (obj.opo_temp_lock == true) & ...
                                     (obj.opo_stepper_lock == true);
                                     %(obj.etalon_lock == true) & (obj.shg_lock);
                                 if  (obj.cwaveHandle.get_regopo == 2 &    PowerMeasureCondition_regopo2 == false)
                                     obj.cwaveHandle.abort_tune;
                                     error('Etalon not tunable. Check lock status of OPO elements.')
                                 elseif (obj.cwaveHandle.get_regopo == 4 &    PowerMeasureCondition_regopo4 == false)
                                     obj.cwaveHandle.abort_tune;
                                     error('Etalon not tunable. Check lock status of OPO elements.')
                                 elseif (PowerMeasureCondition_regopo2 == true | PowerMeasureCondition_regopo4 | obj.locked)
                                     [wm_wl_i,wmPower_i,wm_exptime_i] = obj.powerStatus(obj.wmExposureTolerance, obj.powerStatusDelay);
                                     if (obj.SHG_power < obj.cwaveHandle.SHG_MinPower)
                                         dlgs1 = questdlg('SHG power is very low (SHG is not lock)! Would you like to reoptimize SHG power?', ...
                                             'Yes, optimize SHG Power', 'No, Abort','No, Abort');
                                         % Handle response
                                         switch dlgs1
                                             case 'Yes, optimize SHG Power'
                                                 obj.is_cwaveReady(3.5,true,true)
                                                 delete(dlgs1);
                                             case 'No, Abort'
                                                  abort = true;
                                                  return
                                         end
                                         %prompt user to either manually
                                         %tune first or to reset SHG
                                     end
                                 end
                                 
                                 obj.updateStatus;
                                 wm_exptime_c = wm_exptime_i;
                                 wm_wl_c = 10*wm_wl_i;
                                 
                                 i = 1;
                                 j =1;
                                 counts = i+1;
                                 delay = 0.01;
                                 tol = 0.99;
                                 step = pstep;
                                 EtalonV = [];

                                 obj.cwaveHandle.relock_etalon();
                                 pause(0.5);
                                 obj.is_cwaveReady(3.5,false,false); %need edit these lines with loop tesing if SHGpower and etalon locked
                                 unconditional_lock = obj.is_EtalonRelocked();
                                 if ~unconditional_lock
                                     obj.cwaveHandle.relock_etalon();
                                 end
                         
                                 while (i < counts)
                                      while( obj.SHG_power > obj.Eta_minSHGPower) %obj.cwaveHandle.SHG_MinPower)
                                          
                                         [wm_wl_i,~,wm_exptime_i] = obj.powerStatus(tol,delay);
                                         if isnan(wm_wl_i)
                                             wm_wl = wm_wl_i;
                                             wl_check = NaN;
                                         elseif abs(wm_wl_i) >= 0
                                             wm_wl = round(wm_wl_i,5);
                                             wl_check  = round(wm_wl_c,5);
                                         end
                                         if  wm_wl == wl_check
                                             j = j+1;
                                         end
                                         if j >= 2 & wm_wl == wl_check 
                                             step = floor((3/2)*step);
                                             j = 1;
                                         end
                                         if abs(step) > 2*pstep
                                             step = ceil(0.4444*step); %(2/3)^3 = 0.1975
                                         end
                                         if wm_exptime_i <  obj.maxExpTime & ((wm_exptime_i <= (wm_exptime_c+5)) & (wm_exptime_i >= (wm_exptime_c-5)))
                                             obj.EtalonStepper(step, delay);
                                             %pause(0.125)
                                             %obj.is_EtalonRelocked();
                                         end
                                         [wm_wl_c,~,wm_exptime_c] = obj.powerStatus(tol,delay);
                                         if obj.SHG_power > obj.Eta_minSHGPower
                                             pause(1);
                                             [obj.SHG_power,obj.sSHG_power] = obj.cwaveHandle.get_photodiode_shg;
                                             if obj.SHG_power < obj.Eta_minSHGPower
                                                 pause(1)
                                                 [obj.SHG_power,obj.sSHG_power] = obj.cwaveHandle.get_photodiode_shg;
                                                 if  isnan(wm_wl_c) & ~isnan(wm_wl_i) & obj.SHG_power < obj.Eta_minSHGPower %& ~obj.sSHG_power % obj.SHG_power < obj.Eta_minSHGPower
                                                     EtalonV(end+1) = wm_wl_i;
                                                     obj.cwaveHandle.relock_etalon();
                                                     pause(1);
                                                     i = i+1;
                                                     abort = obj.is_cwaveReady(3.5,false,false);
                                                     if abort == true
                                                         break;
                                                     end
                                                 elseif ~isnan(wm_wl_c) & obj.SHG_power >= obj.Eta_minSHGPower %& obj.sSHG_power
                                                     if isempty(EtalonV)
                                                         EtalonV(1) = wm_wl_c;
                                                     else
                                                         EtalonV(end) = wm_wl_c;
                                                     end
                                                     continue;
                                                 elseif isnan(wm_wl_c) & obj.SHG_power >= obj.Eta_minSHGPower
                                                     [wm_wl_c,~,wm_exptime_c] = obj.powerStatus(tol,delay);
                                                     if isempty(EtalonV)
                                                         EtalonV(1) = wm_wl_c;
                                                     else
                                                         EtalonV(end) = wm_wl_c;
                                                      end
                                                     continue;
                                                 end
                                             end
                                         end
                                         if  obj.SHG_power < obj.Eta_minSHGPower
                                             pause(1)
                                             [obj.SHG_power,obj.sSHG_power] = obj.cwaveHandle.get_photodiode_shg;
                                                 if  isnan(wm_wl_c) & ~isnan(wm_wl_i) & obj.SHG_power < obj.Eta_minSHGPower % & ~obj.sSHG_power %obj.SHG_power < obj.Eta_minSHGPower 
                                                     EtalonV(end+1) = wm_wl_i;
                                                     obj.cwaveHandle.relock_etalon();
                                                     pause(1);
                                                     obj.is_cwaveReady(3.5,false,false);
                                                     i = i+1;
                                                 elseif ~isnan(wm_wl_c) & obj.SHG_power >= obj.Eta_minSHGPower %& obj.sSHG_power
                                                      if isempty(EtalonV)
                                                         EtalonV(1) = wm_wl_c;
                                                     else
                                                         EtalonV(end) = wm_wl_c;
                                                      end
                                                      continue
                                                 elseif isnan(wm_wl_c) & obj.SHG_power >= obj.Eta_minSHGPower
                                                     [wm_wl_c,~,wm_exptime_c] = obj.powerStatus(tol,delay);
                                                     if isempty(EtalonV)
                                                         EtalonV(1) = wm_wl_c;
                                                     else
                                                         EtalonV(end) = wm_wl_c;
                                                      end
                                                     continue;
                                                 end
                                         end
                                         
                                        
                                         if i >= counts & step > 0
                                             i = 1;
                                             obj.MaxEtalon_wl = sprintf( '%.6f', mean(EtalonV) );
                                             obj.MaxEtalon_wlSD =  sprintf( '%.6f', std(EtalonV) ) ;
                                             step = nstep;
                                             EtalonV = [];
                                             break;
                                         elseif i >= counts & step < 0
                                             obj.MinEtalon_wl = sprintf( '%.6f', mean(EtalonV) );
                                             obj.MinEtalon_wlSD = sprintf( '%.6f', std(EtalonV) );
                                             break;
                                         end
                                         [obj.SHG_power, ~] = obj.cwaveHandle.get_photodiode_shg;
                                         if isnan(wm_exptime_c)
                                             wm_exptime_c = obj.maxExpTime +1;
                                         end
                                         if obj.SHG_power < obj.Eta_minSHGPower & wm_exptime_c <  obj.maxExpTime
                                             %reinitialize SHG_power to renter
                                             %loop
                                             obj.SHG_power = 101;
                                         elseif obj.SHG_power < obj.Eta_minSHGPower & wm_exptime_c >  obj.maxExpTime & ~obj.locked
                                              obj.SHG_power = 101;
                                              unconditional_lock = obj.is_EtalonRelocked();
                                         end
                                         if ~unconditional_lock
                                             obj.cwaveHandle.relock_etalon();
                                         end
                                      end 
                                 end

                                 obj.MidEtalon_wl = obj.MinEtalon_wl + abs(obj.MaxEtalon_wl-obj.MinEtalon_wl)/2;
                                 obj.cwaveHandle.relock_etalon();
                                 pause(1);
                                 obj.is_cwaveReady(3.5,false,false);
                                 obj.etalon_pid(obj.MidEtalon_wl);
                                 abort = false;
                                 
                             case 'No, Abort'
                                 abort = true;
                                 return
                         end
  
          end
          
          function uEtalonLock = is_EtalonRelocked(obj,update_status)
              switch nargin
                  case 1
                      update_status = false;
              end
              kk = 0;
              cnts = 0;
    %                     obj.wavemeterHandle.setExposureMode(false); % manually set exposure
    %                     obj.wavemeterHandle.setExposure(1) % set exposure to 1 ms
    %                     obj.wavemeterHandle.setExposureMode(true); %sert exposure mode auto
              expTime = obj.wavemeterHandle.getExposure();
              iterExit = 7;
              if update_status == true
                  obj.updateStatus;
                  lock_condition1 = (obj.etalon_lock == false | obj.SHG_power < obj.Eta_minSHGPower);
                  lock_condition2 = (obj.etalon_lock == true & obj.SHG_power > obj.Eta_minSHGPower);
              else 
                  lock_condition1 = true;
                  lock_condition2 = true;
              end
              while(lock_condition1)
                  if (lock_condition2)
                      if expTime ~= obj.wavemeterHandle.getExposure()
                          iterExit = 25;
                          while( expTime ~= obj.wavemeterHandle.getExposure() )
                              expTime = obj.wavemeterHandle.getExposure();
                              %pause(0.050);
                              if(expTime == obj.wavemeterHandle.getExposure())
                                  kk = kk + 1;
                                  cnts = expTime + cnts;
                                  if kk == iterExit & cnts == kk*expTime
                                      break;
                                  elseif kk > iterExit 
                                      kk = 0;
                                      cnts = 0;
                                      break;
                                  end
                                  %fprintf('expTime: %.2f\n',expTime)
                              end
                          end
                      elseif expTime == obj.wavemeterHandle.getExposure()
                        iterExit = 5;
                        while( expTime == obj.wavemeterHandle.getExposure() )
                            expTime = obj.wavemeterHandle.getExposure();
                              %pause(0.005);
                              if(expTime == obj.wavemeterHandle.getExposure())
                                  kk = kk + 1;
                                  cnts = expTime + cnts;
                                  if kk == iterExit & cnts == kk*expTime
                                      break;
                                  elseif kk > iterExit 
                                      kk = 0;
                                      cnts = 0;
                                      break;
                                  end
                                  %fprintf('expTime: %.2f\n',expTime)
                              end
                        end
                      end
                  end
                  if update_status == true
                      obj.updateStatus;
                  else
                      obj.etalon_lock = ~boolean(obj.cwaveHandle.get_status_lock_etalon());
                      [obj.SHG_power,~] = obj.cwaveHandle.get_photodiode_shg;
                  end
                  
                  %update lock conditions
                  lock_condition3 = (obj.etalon_lock == true & obj.SHG_power > obj.Eta_minSHGPower & kk == iterExit & cnts == kk*expTime);
                  if (lock_condition3)
                      uEtalonLock = true;
                      break;
                  elseif (obj.etalon_lock == true & obj.SHG_power < obj.Eta_minSHGPower)
                       uEtalonLock = false;
                      break;
                      %obj.cwaveHandle.relock_etalon();
                      %pause(0.1);
                      %delay = 1;
                      %obj.is_cwaveReady(delay,false,false);
                  end
                  if update_status == true
                      obj.updateStatus;
                      lock_condition1 = (obj.etalon_lock == false | obj.SHG_power < obj.Eta_minSHGPower);
                      lock_condition2 = (obj.etalon_lock == true & obj.SHG_power > obj.Eta_minSHGPower);
                  else 
                      lock_condition1 = true;
                      lock_condition2 = true;
                  end
              end 
          end

          function tune_etalon(obj)
              obj.cwaveHandle.tune_thick_etalon(obj.EtalonStep);
          end

          function set_regopo(obj,val)
              obj.cwaveHandle.set_intvalue(obj.cwaveHandle.RegOpo_On,val);
          end
          
          function val = get_regopo(obj)
              val = obj.cwaveHandle.get_regopo;
          end
          
          function delete(obj)
              obj.cwaveHandle.delete();
              obj.PulseStreamerHandle.delete(); 
              obj.wavemeterHandle.delete();
          end
          
          %%%%%%%%%%%%
        function [Control, Measured, Dt, IntError, Error, P_term,I_term,D_term] = opo_pid(obj,setpoint,tolerance)
            i=0;
            kp_slow = 200;
            ki_slow = 1;
            kd_slow = 0;
            kp_fast = 1250;%1000; %.1; %kcr = 5510, Pcr = 6.748-3.3046 = 3.4434
            ki_fast = 1250; %200; %.4; 
            kd_fast = 0;
            obj.windupGuardmax = obj.OPOwindupGuardmax;
            obj.windupGuardmin = obj.OPOwindupGuardmin;
       
            if (obj.cwaveHandle.get_regopo ~= 4)
                obj.cwaveHandle.set_regopo(4);
                %obj.cwaveHandle.set_intvalue(obj.cwaveHandle.RegOpo_On,4)
            end
                
            curr_error = 2*tolerance; %arbitrary condidtion to start PID loop.
            ctrl = 0;
            p_term = 0;
            i_term = 0;
            d_term = 0;
            Error = [];
            Dt = [];
            IntError = [];
            Control = [];
            Measured = [];
            while (abs(curr_error) > tolerance )
                tic
                measured = obj.getWavelength();
                initial_percent = obj.GetPercent();
                if i == 0
                    dt = 0;
                    prev_error = 0;
                    int_error = 0;
                    curr_error = setpoint - measured;
                else
                    curr_error = setpoint - measured;
                end
                i=i+1;
                
                %slow control
                if abs(curr_error) > 0.00125 
                    
                    [ctrl,prev_error,int_error,p_term,i_term,d_term] = obj.pid_update(curr_error,prev_error,int_error,kp_slow,ki_slow,kd_slow,dt);
                    if (initial_percent+ctrl < obj.MinPercent)
                        obj.TunePercent(obj.MinPercent);
                    elseif (initial_percent+ctrl > obj.MaxPercent)
                         obj.TunePercent(obj.MaxPercent);
                    else
                        obj.TunePercent(initial_percent+ctrl);
                    end
                    dt = toc;
                %fast control
                elseif abs(curr_error) > tolerance 
                      j = 0;
                      if j == 0
                          int_error = 0;
                          j = j+1;
                      end
                     
                      [ctrl,prev_error,int_error,p_term,i_term,d_term] = obj.pid_update(curr_error,prev_error,int_error,kp_fast,ki_fast,kd_fast,dt);
                      delay = obj.wavemeterHandle.getExposure()/1000 + 0.010; %in seconds
                      pause(delay)
                      if (initial_percent+ctrl < obj.MinPercent)
                          obj.cwaveHandle.tune_opo_cavity(obj.MinPercent);
                      elseif (initial_percent+ctrl > obj.MaxPercent)
                          obj.cwaveHandle.tune_opo_cavity(obj.MaxPercent);
                      else
                          obj.cwaveHandle.tune_opo_cavity(initial_percent+ctrl);
                      end
                      dt = toc;
                end
                 
                 Dt(i) = dt;
                 Error(i) = curr_error;
                 IntError(i) = int_error;
                 Control(i) = ctrl;
                 Measured(i) = measured;
                 P_term(i) = p_term;
                 I_term(i) = i_term;
                 D_term(i) = d_term;  
            end
        end
        
        function [Control, Measured, Dt, IntError, Error, P_term,I_term,D_term] = etalon_pid(obj,setpoint,tolerance,kp,ki,kd)
            
            obj.windupGuardmax = obj.EtaWindupGuardmax; 
            obj.windupGuardmin = obj.EtaWindupGuardmin;
            
            switch nargin
                case 2
                    tolerance = 0.005;
                    kp = 100; %was 500 on 11/6/19 noticed it has strong kick back sometimes when near edged of etalon.
                    ki = 100;
                    kd = 0;
                case 3
                    kp = 100; %was 500 on 11/6/19 noticed it has strong kick back sometimes
                    ki = 100;
                    kd = 0;     
            end
                  
            i=0;
            %if (obj.cwaveHandle.get_regopo ~= 4)
            %    obj.cwaveHandle.set_regopo(4);
            %    %obj.cwaveHandle.set_intvalue(obj.cwaveHandle.RegOpo_On,4)
            %end
                
            curr_error = 2*tolerance; %arbitrary condidtion to start PID loop.
            ctrl = 0;
            p_term = 0;
            i_term = 0;
            d_term = 0;
            Error = [];
            Dt = [];
            IntError = [];
            Control = [];
            Measured = [];
            stay = false;
            while (abs(curr_error) > tolerance )
                tic
                %obj.updateStatus;
                obj.is_cwaveReady(0.01,false,false);
                if obj.SHG_power < obj.cwaveHandle.SHG_MinPower
                    while ( (stay == false) & (uEtalonLock == true) & (obj.SHG_power < obj.cwaveHandle.SHG_MinPower) ) %| curr_error < 0)
                        pause(1)
                        if (obj.SHG_power <  obj.cwaveHandle.SHG_MinPower)
                            obj.cwaveHandle.relock_etalon();
                            pause(1);
                            stay = obj.is_cwaveReady(3.5,false,false);
                            uEtalonLock = obj.is_EtalonRelocked;
                            break;
                        elseif (stay == true) & (uEtalonLock == false) & (obj.SHG_power > obj.cwaveHandle.SHG_MinPower) 
                            break
                        end
                    end
                    curr_error = 2*tolerance; %arbitrary condidtion to start PID loop.
                    ctrl = 0;
                    p_term = 0;
                    i_term = 0;
                    d_term = 0;
                    Error = [];
                    Dt = [];
                    IntError = [];
                    Control = [];
                    Measured = [];
                    exit = false;
                end
                measured = obj.getWavelength();
                if i == 0
                    dt = 0;
                    prev_error = 0;
                    int_error = 0;
                    curr_error = setpoint - measured;
                else
                    curr_error = setpoint - measured;
                end
                i=i+1;
                
                 if abs(curr_error) > tolerance %was elseif
                      j = 0;
                      if j == 0
                          int_error = 0;
                          j = j+1;
                      end
                   
                      [ctrl,prev_error,int_error,p_term,i_term,d_term] = obj.pid_update(curr_error,prev_error,int_error,kp,ki,kd,dt);
                      if obj.wavemeterHandle.getExposure() > 25 % was 100
                          delay = obj.wavemeterHandle.getExposure()/1000+0.025; %in seconds
                          pause(delay)
                      else
                          if (obj.get_regopo == 2)
                              pause(0.075) %(was 0.001 s)
                          elseif (obj.get_regopo == 4)
                              pause(0.001); %pause(0.025)
                          end
                      end
                      if (ctrl < obj.MinEtalon)
                          obj.cwaveHandle.tune_thick_etalon(obj.MinEtalon);
                          Control(i) = obj.MinEtalon;
                      elseif (ctrl > obj.LocalMinEtalon & ctrl < 0)
                          obj.cwaveHandle.tune_thick_etalon(obj.LocalMinEtalon);
                          Control(i) = obj.MinEtalon;
                      elseif (ctrl > obj.MaxEtalon)
                          obj.cwaveHandle.tune_thick_etalon(obj.MaxEtalon);
                          Control(i) = obj.MaxEtalon;
                      elseif (ctrl < obj.LocalMaxEtalon & ctrl > 0)
                          obj.cwaveHandle.tune_thick_etalon(obj.LocalMaxEtalon);
                          Control(i) = obj.LocalMaxEtalon;
                      else
                          obj.cwaveHandle.tune_thick_etalon(ctrl);
                          Control(i) = round(ctrl);
                      end
                      dt = toc;
                   
                end
                 
                 Dt(i) = dt;
                 Error(i) = curr_error;
                 IntError(i) = int_error;
                 Measured(i) = measured;
                 P_term(i) = p_term;
                 I_term(i) = i_term;
                 D_term(i) = d_term;  
            end
        end

        function [ctrl,prev_error,int_error,p_term,i_term,d_term] = pid_update(obj, curr_error,prev_error, int_error, kp,ki,kd,dt)
 
            % integration
            int_error = int_error + (curr_error * dt);
 
            % integration windup guarding
            if (int_error < obj.windupGuardmin)
                int_error = obj.windupGuardmin;
                saturation = 1;
            elseif (int_error > obj.windupGuardmax)
                int_error = obj.windupGuardmax;
                saturation = 1;
            else 
                saturation = 0;
            end
    
            if ((sign(curr_error) == sign(prev_error)) && (saturation == 1))
                int_error = 0;
            end
    
            % differentiation
            if dt == 0
                int_error = 0;
                diff = 0;
            else
                diff = ((curr_error - prev_error) / dt);
            end

            % scaling
            p_term = (kp * curr_error);
            i_term = (ki     * int_error);
            d_term = (kd   * diff);
            
            % summation of terms
            ctrl = p_term + i_term + d_term;
             
            % save current error as previous error for next iteration
            prev_error = curr_error;
        end
      %%%%%%%%%%%%
         
   
    end
end