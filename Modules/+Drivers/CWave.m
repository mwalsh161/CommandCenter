classdef CWave < Modules.Driver
    %CWave connects with host machine to control cwave laser
    %   
    %   for fine-tuning best used with a wavemeter feedback loop
    
    %properties(SetAccess = immutable)
        %ip = '192.168.11.3';
        %password = 457; %457 gives engineering access. 111 gives full superuser access. Not recommended...why?
    %end
    
    properties
        init_warnings
        dll_ver
        target_wavelength = 615.000001; % Target Wavelength
        all_shutters = 'open';
        shg_shutter = 'close';
        lsr_shutter = 'open'; 
        opo_stepper_stat = 0;
        opo_temp_stat = false(1);
        shg_stepper_stat = false(1);
        shg_temp_stat = false(1);
        thin_etalon_stat = false(1);
        opo_lock_stat = false(1);
        shg_lock_stat = false(1);
        etalon_lock_stat = false(1);
        laser_emission_stat = false(1);
        ref_temp_stat = false(1);  
    end
    
    properties(Constant,Hidden)
    % constants for C library
        Pathx64 = 'C:\Program Files (x86)\Hubner\C-WAVE Control\MatlabControl\x64\';
        Pathx86 = 'C:\Program Files (x86)\Hubner\C-WAVE Control\MatlabControl\x86\';
        HPath = 'C:\Program Files (x86)\Hubner\C-WAVE Control\MatlabControl\';
        LibraryName = 'CWAVE_DLL';            % alias for library
        LibraryFilePath = 'CWAVE_DLL.dll';     % Path to dll
        LibraryHeader = 'CWAVE_DLL.h';
        OS_64bit = 'win64';
        ComputerArch = 'arch';
        ConnectCwave = 'cwave_connect';
        DLL_Version= 'DLL_Version';
        DLL_identity = 20;
        Admin = 'admin_elevate';
        UpdateStatus = 'cwave_updatestatus';
        Get_IntValue = 'get_intvalue';
        Get_floatValue = 'get_floatvalue';
        Set_IntValue = 'set_intvalue';
        Set_FloatValue = 'set_floatvalue';
        Is_Ready = 'is_ready';
        SetCommand = 'set_command';
        LaserPower = 'get_photodiode_laser';
        OPO_Power = 'get_photodiode_opo';
        SHG_Power = 'get_photodiode_shg';
        StatusReport = 'get_statusbits';
        LaserStatus  = 'get_status_laser';
        Reference_TempStatus = 'get_status_temp_ref';
        OPO_TempStatus = 'get_status_temp_opo';
        SHG_TempStatus = 'get_status_temp_shg';
        OPO_LockStatus = 'get_status_lock_opo';
        SHG_LockStatus = 'get_status_lock_shg';
        Etalon_LockStatus = 'get_status_lock_etalon';
        WLM_PID_Optimize = 'WLM_PID_Compute';
        WLM_PID_Setpoint = 'WLM_pid_setpoint'; % valid range 450 - 1300 (nm), double
        WLM_BigSteps = 'WLM_bigsteps';
        WLM_PiezoSteps = 'WLM_piezosteps'
        Ext_SetCommand = 'ext_set_command';
        ExtGet_IntValue = 'ext_get_intvalue';
        ExtGet_FloatValue = 'ext_get_floatvalue';
        ShutterSHG = 'shtter_shg';
        ShutterLaser = 'shtter_las';
        Open = 'open';
        Close = 'close';
        StopOptimization = 'opt_stop';
        CoarseTune = 'coarse';
        FineTune = 'fine'; 
        Disconnect = 'cwave_disconnect';
        RefCavity_Piezo = 'x';
        ThickEtalon_Piezo_hr = 'thicketa_rel_hr';
        ThickEtalon_Piezo = 'thicketa_rel';
        RefCavityPiezo_maxBit = 65535/100;
        Laser_MaxPower = 1000000; %dummy value. value needs to be calibrated (testing needed)
        Laser_MinPower = 0; %dummy value. value needs to be calibrated (testing needed)
        OPO_MaxPower = 1000000; %dummy value. value needs to be calibrated (testing needed)
        OPO_MinPower = 0; %dummy value. value needs to be calibrated (testing needed)
        SHG_MaxPower = 1000000; %dummy value. value needs to be calibrated (testing needed)
        SHG_MinPower = 0; %dummy value. value needs to be calibrated (testing needed)
    end
    %% Signleton Method
    methods(Static)
        function obj = instance(ip)
            mlock;
            persistent Objects
            if isempty(Objects)
                Objects = Drivers.CWave.empty(1,0);
            end
            for i = 1:length(Objects)
                if isvalid(Objects(i)) && isequal({ip},Objects(i).singleton_id)
                    obj = Objects(i);
                    return
                end
            end
            obj = Drivers.CWave(ip);
            obj.singleton_id = {ip};
            Objects(end+1) = obj;
        end
    end
    
    %% Constructor Method
    methods(Access={?Drivers.CWave})
         function obj = CWave(ip)
            obj.dll_ver =  load_cwave_dll(obj); %load dll for cwave
            obj.status = obj.cwave_connect(ip); %connect cwave
            % open all internal and output shutters in cwave system
            obj.shutter_lsr();
            obj.shutter_shg();
            %obj.initialize_shutters; 
            ret = obj.set_intvalue(WLM_BigSteps, 0);
            assert(ret == 1, 'Turning off large steps in PID failed');
         end
    end
    
    %% Methods accessible to user
    methods
        
        function dll_ver = load_cwave_dll(obj)
        % load DLL
            if (~libisloaded(obj.LibraryName))
                if (strcmp(computer(obj.ComputerArch), obj.OS_64bit))
                %Change file path to full file path. Do not use relative
                %file path. Also all strings should be switched to constant
                %properties 
                    %loadlibrary('x64/CWAVE_DLL',  obj.LibraryHeader);    
                    path = fullfile(obj.Pathx64 ,obj.LibraryFilePath); % 64bit
                    hpath = fullfile(obj.HPath, obj.LibraryHeader);
                    [~,obj.init_warnings] = loadlibrary(path, hpath, 'alias',obj.LibraryName);
                else
                    %loadlibrary('x86/CWAVE_DLL', obj.LibraryHeader);  
                    path = fullfile(obj.Pathx86 ,obj.LibraryFilePath); % 32bit
                    hpath = fullfile(obj.HPath, obj.LibraryHeader);
                    [~,obj.init_warnings] = loadlibrary(path, hpath, 'alias',obj.LibraryName);
                end
            end
            if (libisloaded(obj.LibraryName))
                %% return dll version
                [~,dll_ver] = obj.dll_version();
                if (dll_ver ~= obj.DLL_identity)
                    assert(dll_ver == obj.DLL_identity, ['CWAVE DLL library not loaded, DLL version ' dll_ver ' not equal to ' obj.DLL_identity]);
                end   
            end
        end
        
        function [varargout] = LibraryFunction(obj,FunctionName,varargin)
            % use this function to call arbitrary library functions from
            % CWAVE DLL. Checks for error, and returns all bit status
    
            nargs = Base.libnargout(obj.LibraryName,FunctionName);
            if nargs < 2
                varargout = '';
                status = calllib(obj.LibraryName,FunctionName,varargin{:});
            else
                [status,varargout{1:nargs-1}] = calllib(obj.LibraryName,FunctionName,varargin{:});
            end
            obj.CheckErrorStatus(status);
        end
        
        function CheckErrorStatus(obj,status,FunctionName)
            %edit cases TBD. Need to sort out string to report and
            %flag/status for each function
            inversion_condition = {obj.ConnectCwave,obj.Admin,obj.UpdateStatus,obj.Set_IntValue, ...
                                   obj.Set_FloatValue,obj.SetCommand,obj.LaserStatus, obj.Ext_SetCommand};
            if(ismember(FunctionName, inversion_condition))
                status = ~status;
            end
            switch FunctionName
                case obj.ConnectCwave
                    % 0=connection failed, 1==connection successful
                    assert(status == 0, ['CWAVE Error: Connecting to ' obj.ip ' failed']);
                case obj.DLL_Version
                    assert(status == 0, ['CWAVE Error: Unauthorized CWAVE DLL version loaded']);
                case obj.Admin
                    % 0==admin rights granted, 1=no admin rights granted
                    assert(admin_status == 0, ['CWAVE Error: Admin Rights Not Granted. Incorrect password given']);
                case obj.UpdateStatus
                    %  0==update succeeded, 1=update failed
                    assert(measure_status == 0, ['CWAVE Error: Measurement status of C-wave not updated']);
                case obj.Set_IntValue
                    %  0== integer value set, 1= integer value not set
                    assert(measure_status == 0, ['CWAVE Error: Int value not set']);
                case obj.Is_Ready
                    % 0=C-wave is ready, Optimization has completed; 1==C-wave still optimizing
                     assert(optimize_status == 0, ['CWAVE Error: C-Wave not ready. Optimization still in progress']);
                case obj.Set_FloatValue
                    %  0==update succeeded, 1=update failed
                    assert(measure_status == 0, ['CWAVE Error: float value not set']);
                case obj.SetCommand
                    % 0=update succeeded,  1=update failed
                    assert(status == 0, ['CWAVE Error: command not executed. Check that set_command input are valid.']);
                case obj.LaserPower
                    % 0=update succeeded,  1=update failed
                    assert(status == 0, ['CWAVE Error: Laser power not within standard operating range.']);
                case obj.OPO_Power
                    % 0=update succeeded,  1=update failed
                    assert(status == 0, ['CWAVE Error: OPO power not within standard operating range.']);
                case obj.SHG_Power
                    % 0=update succeeded,  1=update failed
                    assert(status == 0, ['CWAVE Error: SHG power not within standard operating range.']);
                case obj.StatusReport
                    % 0=update succeeded,  1=update failed
                    assert(status == 0, ['CWAVE Error: All elements are not stable and/or locked.']);
                case obj.LaserStatus
                    % 0=update failed, 1==update succeeded
                    assert(status == 0, ['Insufficient Laser power. Check that pump laser is active and that the laser shutter is open']);
                case obj.Reference_TempStatus
                    % 0=referance temperature stabilized, 1==reference temperature not at setpoint
                    assert(ref_temp_status == 0, ['Reference temperature not at setpoint']);
                case obj.OPO_TempStatus
                    % 0=referance temperature stabilized, 1==reference temperature not at setpoint
                    assert(opo_temp_status == 0, ['OPO temperature not at setpoint']);
                case obj.SHG_TempStatus
                    % 0=SHG temperature stabilized, 1==SHG temperature not at setpoint
                    assert(shg_temp_status == 0, ['SHG temperature not at setpoint']);
                case obj.OPO_LockStatus
                    % 0=OPO lock stabilized, 1==OPO not locked to reference cavity. Still optimizing
                    assert(opo_lock_status == 0, ['OPO not locked to reference cavity. Optimization still in progress']);
                case obj.SHG_LockStatus
                    % 0=SHG lock stabilized, 1==SHG not locked to reference cavity. Still optimizing
                    assert(shg_lock_status == 0, ['SHG not locked to reference cavity. Optimization still in progress']);
                case obj.Etalon_LockStatus
                    % 0=etalon lock stabilized, 1==etalon not locked to reference cavity. Still optimizing
                    assert(etalon_lock_status == 0, ['etalon not locked to reference cavity. Optimization still in progress']);
                case obj.WLM_PID_Optimize
                case obj.Ext_SetCommand
                    % 0=command executed correctly, 1==error command not executed by external module
                    assert(etalon_lock_status == 1, ['Command not executed by external module. Check that it is on.']);
            end
        end
        
        function [status] = cwave_connect(obj, ip)
            %Description: Connects to the C-Wave. This function has to be executed once during runtime.
            %Arguments: ipAddress is the IP address of the CWAVE as string in the format 123.123.123.123
            %Returns: int value, 0 means connection failed, 1 means successfully connected. 
            %Logic inverted from original DLL status bit by LibraryFunction.
            %% connect to device
            status = obj.LibraryFunction(obj.LibraryName, obj.ConnectCwave, ip);
            % mitigate bug in DLL, first connection attempt might fail -> retry
            if (status == 0)
                status = LibraryFunction(obj.LibraryName,obj.ConnectCwave, ip);
            end
        end
       
        function [status,dllVer] = dll_version(obj)
            %Description: Reads version of the DLL
            %Returns: Returns an integer value with the version of the DLL
            % also return status bit (0 =  correct dll version, 1 =
            % incorrect dll version).
            dllVer = calllib(obj.LibraryName, obj.DLL_Version);
            disp('dllver:')
            disp(dllVer)
            if( dllVer ~= obj.DLL_identity)
                status = 1;
            else 
                status = 0;
            end
            disp(['C-WAVE DLL loaded. Version: ' num2str(dllVer)]);
            obj.CheckErrorStatus(status,obj.DLL_Version);
        end 
        
        function admin_status = admin_elevate(obj,password)
            %Description: Grants admin rights to the user to access advanced commands.
            %Arguments: password is the password as string.
            %Returns: Returns an integer value. 1 means no admin rights, 0 means admin rights
            admin_status = LibraryFunction(obj.LibraryName,obj.Admin,password);
        end
       
        function measure_status = cwave_updatestatus(obj)
            %Description: Manually updates status info (photodiode values, temperatures, statusbits) in the library. 
            %This function is automatically executed on demand, so there is usually no need to execute it manually.
            %Returns: Returns status int value. 0 means update succeeded, 1 means update failed.
            measure_status = LibraryFunction(obj.LibraryName,obj.UpdateStatus);
        end

        function intvalue = get_intvalue(cmd)
            %Description: Reads the value of an integer parameter.
            %Arguments: Parameter as string. See parameter list for valid parameters.
            %Returns: Returns the requested integer value.
            
            %% INT PARAMETER LIST
            %  Name             Type     Valid range     Read / Write	Description
            %% topo_set         Int	    20000-170000        RW          Setpoint of the OPO temperature in mK
            %  topo_is          Int	    20000-170000        R           Current OPO temperature in mK
            %% tshg_set         Int     20000-170000        RW          Setpoint of the SHG temperature in mK
            %  tshg_is1         Int     20000-170000        R           Current SHG1 temperature in mK
            %% tshg_is2         Int     20000-170000        R           Current SHG2 temperature in mK
            %  tref_set         Int     20000-170000        RW          Setpoint of the reference temperature in mK
            %% tref_is          Int     20000-170000        R           Current reference temperature in mK
            %  shtter_las       Int     0, 1                RW          Laser shutter position. 1 means open, 0 closed
            %% shtter_shg       Int     0, 1                RW          SHG shutter position. 1 means open, 0 closed
            %  shtter_las_out   Int     0, 1                RW          Laser output shutter position. 1 means open, 0 closed
            %% shtter_opo_out   Int     0, 1                RW          OPO output shutter position. 1 means open, 0 closed
            %  shtter_shg_out   Int     0, 1                RW          SHG output shutter position. 1 means open, 0 closed
            %% laser_en         Int     0, 1                RW          Enable internal pump laser. 0 disabled, 1 enabled
            %  monout_sel       Int     0-12                RW          Select Signal at monitor 1 output.
            %                                                            0:  Error Signal OPO
            %                                                            1: Error Signal SHG
            %                                                            2: Error Signal Etalon
            %                                                            4: Piezo OPO
            %                                                            5: Piezo SHG
            %                                                            6: Piezo Etalon
            %                                                            7: Piezo Reference
            %                                                            9: Pump laser power
            %                                                            11: SHG power
            %                                                            12: OPO power
            %% monout2_sel      Int     0-12                RW          Select Signal at monitor 2 output. See Monitor 1 for details.
            %  regopo_on        Int     0-2                 RW          OPO regulator mode.
            %                                                            0: off
            %                                                            1: scan
            %                                                            2: regulate
            %% regshg_on        Int     0-2                 RW          SHG regulator mode. Mode description see regopo_on
            %  regeta_on        Int     0-2                 RW          SHG regulator mode. Mode description see regopo_on
            %% regopo_set       Int     0-65535             RW          Setpoint of the OPO regulator. Mid-range values are normal. 
            %%                                                           Should not need to be touched.
            %  regshg_set       Int     0-65535             RW          Setpoint of the OPO regulator. Mid-range values are normal. 
            %                                                            Should not need to be touched.
            %% regeta_set       Int     0-65535             RW          Setpoint of the OPO regulator. Mid-range values  are normal. 
            %%                                                           Should not need to be touched.
            %  reghsg_threshold	Int     0-4095              RW          SHG power threshold above which SHG regulator is active. 
            %                                                            Needed to select proper mode. Is set automatically, 
            %                                                            usually no user input required.
            %% opo_lambda       Int     45000-130000        W           Wavelength setpoint of the C-Wave in nm*100.
            %  opo_rlambda      Int     -100-100            W           Execute relative wavelength step (fundamental wavelength!) 
            %                                                            in nm*100. Maximum step is 1 nm. 
            %% thicketa_rel	    Int     -100-100            W           Execute relative wavelength step of the thick etalon only 
            %%                                                           (fundamental wavelength!) in nm*100. Maximum step is 1 nm. 
            %  thicketa_rel_hr	Int     -1000...1000        W           Same as thicketa_rel but resolution is 1 pm
            
            %% WAVELENGTH STABILIZATION PARAMETERS
            % Name               Type	Valid range     Default     Description
            %% WLM_pid_p           Int     0-100000        0           Proportional constant of the wavelength regulator. 
            %%                                                         Not needed for many applications
            %  WLM_pid_i           Int     0-100000        500         Integral constant for wavelength regulator
            %% WLM_pid_direction   Int     -1, 0, 1        -1          Direction of the regulator. Does not have to be changed
            %%                                                          in most cases.
            %  WLM_bigsteps        Int     0, 1            1           Allow the regulator to do big wavelength steps, e. g. completely 
            %                                                           re-dial a wavelength if the setpoint is too far away from the 
            %                                                           current output wavelength.
            %% WLM_etalonsteps     Int     0, 1            1           Allow the regulator to touch the thick etalon to reach
            %%                                                          the desired wavelength.
            %  WLM_piezosteps      Int     0, 1            1           Allow the regulator to move the cavity piezo to reach 
            %                                                           the desired wavelength.
            %% WLM_regout          Int     0-65535         0           Regulator output, good for checking if it works

            %% Read value of integer parameter
            % no error status bit is returned so calllib is used.
            intvalue = calllib(obj.LibraryName,obj.Get_IntValue,cmd);
        end
        
        function floatvalue = get_floatvalue(cmd)
            %Description: Reads the value of an floating point parameter.
            %Arguments: Parameter as string. See parameter list for valid parameters.
            %Returns: Returns the requested floating point value.

            %% INT PARAMETER LIST
            %  Name             Type        Valid range     Read / Write	Description
            %% laser_pow	    Double      0?1.5               RW          Laser power of internal pump laser in W

            %% WAVELENGTH STABILIZATION PARAMETERS
            %  Name                Type	    Valid range     Default     Description
            %% WLM_pid_setpoint    Double	450?1300                    Desired wavelength in nm. 
            %  WLM_targetdeviation Double	0?1	0.01	                Desired maximum deviation from the setpoint in nm. 
            %                                                            The minimum value depends on the used wavemeter resolution. 
            %                                                            Smaller values give higher accuracy but may require longer 
            %                                                            time or manual input. Larger values result in faster settling
            %                                                            but a less accurate output wavelength.

            %% Read value of float parameter
            floatvalue = calllib(obj.LibraryName,obj.Get_floatValue,cmd);        
        end
            
        function status = set_intvalue( cmd,value)
            % Description: Sets the value of an integer parameter.
            % Arguments: cmd is the Parameter as string. See parameter list 
            % for valid parameters. value is the desired new value of the parameter.
            % Returns: Returns 0 (1 before inversion) if the new value was set correctly. 
            % Returns 1 (-1 before inversion) if an error occurred.
            %% Writable Int Parameters are listed above in get_intvalue function comments
            %% Writable Wavelength stabilization parameters are listed above in get_intvalue function comments
            status = LibraryFunction(obj.LibraryName,obj.Set_IntValue,cmd, value);
        end
       
        function optimize_status = is_ready(obj)
            %Description: Checks if all C-Wave routines have finished and the C-Wave produces the desired output
            %Arguments: none
            %Returns: Returns an integer value. 0 means no errors, C-Wave is ready. 1 means C-Wave is still in optimization
            %% Check if optimization is complete
            optimize_status = LibraryFunction(obj.LibraryName, obj.Is_Ready); 
        end

        function status = set_floatvalue(cmd,value)
            % Description: Sets the value of an floating point parameter.
            % Arguments: cmd is the Parameter as string. See parameter list 
            % for valid parameters. value is the desired new value of the parameter.
            % Returns: Returns 0 (1 before inversion) if the new value was set correctly. 
            % Returns 1 (-1 before inversion) if an error occurred.
            %% Writable Int Parameters are listed above in get_floatvalue function comments
            %% Writable Wavelength stabilization parameters are listed above in get_floatvalue function comments
            status = LibraryFunction(obj.LibraryName, obj.Set_FloatValue,cmd, value); 
        end

        function status = set_command(cmd)
            % Description: Executes a command which has no numerical argument.
            % Arguments: cmd is the command as string. See the command list for reference.
            % Returns: Returns 0 (1 before inversion) if the new command was executed correctly. Returns 1 (-1 before inversion)
            % if an error occurred.
            %% Parameter Name   Description
            %  opt_tempshg      Re-optimize SHG temperature by doing a temperature search. 
            %                    This command is automatically executed each time a new wavelength is selected.
            %% regeta_catch     Try to re-lock thick etalon to prevent multimode operation. 
            %%                     If SHG output is required, a successive SHG temperature search may be required.
            %  opt_stop         Stop all optimizations. Usefull for full manual control of the C-Wave.
            %% Set Command
            status = LibraryFunction(obj.LibraryName, obj.SetCommand,cmd);   
        end
        
        function [status,laser_power] = get_photodiode_laser(obj)
            % Description: Reads the current laser power (what unit??)
            % Arguments: none
            % Returns: Returns the laser photodiode value
            %% Read laser power
            laser_power = calllib(obj.LibraryName,obj.LaserPower);
            if( laser_power > obj.Laser_MaxPower || laser_power < obj.Laser_MinPower)
                status = 1;
            else 
                status = 0;
            end
            obj.CheckErrorStatus(obj,status,obj.LaserPower)
        end

        function [status,opo_power] = get_photodiode_opo(obj)
            % Description: Reads the current OPO infrared power
            % Arguments: none
            % Returns: Returns the infrared output power in mW
            %% Read IR opo power
            opo_power = calllib(obj.LibraryName,obj.OPO_Power);
            if (opo_power > obj.OPO_MaxPower || opo_power < obj.OPO_MinPower)
                status = 1;
            else
                status = 0;
            end
            obj.CheckErrorStatus(obj,status,obj.OPO_Power);
        end
        
        function [shg_power] = get_photodiode_shg(obj)
            % Description: Reads the current (second harmonic generator) SHG visible power
            % Arguments: none
            % Returns: Returns the visible output power in mW
            %% Read SHG power
            shg_power = calllib(obj.LibraryName, obj.SHG_Power);
            if (shg_power > obj.SHG_MaxPower || opo_power < obj.OPO_MinPower)
                status = 1;
            else 
                status = 0;
            end
            obj.CheckErrorStatus(obj,status,obj.SHG_Power);
        end
        
        function status = get_statusbits(obj)
            % Description: Reads the current status of the C-Wave
            % Arguments: none
            % Returns: Returns an 16-bit integer value. Each bit corresponds to the 
            % status of one component. 0 means, the component is ready for operation, 
            % 1 means the component is not yet stable. Current valid bits from LSB to MSB are:
            %       0	OPO stepper
            %       1	OPO temperature
            %       2	SHG stepper
            %       3	SHG temperature
            %       4	Thin etalon
            %       5	OPO lock
            %       6	SHG lock
            %       7	Etalon lock
            %       8	Laser emission (inverted)
            %       9	Reference temperature
            % Poll cwave status
            cwave_status = calllib(obj.LibraryName, obj.StatusReport); %change to callib
            status_vector = de2bi(cwave_status);
            obj.opo_stepper_stat = status_vector(1);
            obj.opo_temp_stat = status_vector(2);
            obj.shg_stepper_stat = status_vector(3);
            obj.shg_temp_stat = status_vector(4);
            obj.thin_etalon_stat = status_vector(5);
            obj.opo_lock_stat = status_vector(6);
            obj.shg_lock_stat = status_vector(7);
            obj.etalon_lock_stat = status_vector(8);
            obj.laser_emission_stat = ~status_vector(9);
            obj.ref_temp_stat = status_vector(10); 
            if(cwave_status ~=0)
                status = 1;
            else 
                status = 0;
            end
            obj.CheckErrorStatus(obj,status,obj.StatusReport) 
        end
   
        function WLM_PID_Compute(wl_measured)
            % Description: This function executes automatic wavelength regulation of the 
            %  C-Wave if the current output wavelength is measured by an external wavemeter 
            %  and monitored back into the C-Wave by this function. See WLM parameters for
            %  details. The C-Wave is automatically adapted to the new wavelength measurement
            %  each time this function is executed. To disable the automatic wavelength 
            %  regulation just do not execute this function.
            % Arguments: measurement is the current measured wavelength in nm. You can 
            %  provide fundamental or SHG measurement. However, measuring the fundamental 
            %  wavelength will be more reliable for complete automation.
            % Returns: none
            LibraryFunction(obj.LibraryName,obj.WLM_PID_Optimize,wl_measured); % suggest change to callib
        end
        
        function shutter_lsr(obj)
            %open or close internal pump laser shutter
            if strcmp(obj.lsr_shutter, obj.Open)
                ret = set_intvalue(obj.ShutterLaser,1);
                assert(ret == 1, 'Opening pump laser shutter failed'); 
            elseif strcmp(obj.lsr_shutter, obj.Close)
                ret = set_intvalue(obj.ShutterLaser,0);
                assert(ret == 0, 'Closing pump laser shutter failed'); 
            end 
        end 
        
        function shutter_shg(obj)
            %open or close SHG shutter
            if strcmp(obj.shg_shutter, obj.Open)
                ret = set_intvalue(obj.ShutterSHG,1);
                assert(ret == 1, 'Opening SHG shutter failed'); 
            elseif strcmp(shg.lsr_shutter, obj.Close)
                ret = set_intvalue(obj.ShutterSHG,0);
                assert(ret == 0, 'Closing SHG shutter failed'); 
            end 
        end 
        
        function status = getStatus(obj)
            % poll connection status if CWAVE
            % Function Call currently not avialable waiting DLL file info
            % from Hubner
            status = obj.cwave_connect(ipAddr);
        end
        
        function status = delete(obj)
            %Delete instance of CWAVE object.
            %Disconnect CWAVE 
            obj.disconnect_cwave();
            %clean up loaded library from memory 
            unloadlibrary(obj.LibraryName);
            status = libisloaded(obj.LibraryName);
            if status
                assert(status==1, 'CWAVE Library still in memory!');
            end      
        end
        
        function disconnect_cwave(obj)
            % Probably easiset if using a disconnect function to disconnect
            % CWAVE
            LibraryFunction(obj.LibraryName,obj.Disconnect); 
        end
        
        function set_target_wavelength(obj)
            %set target wavelength with a coarse 0.01 nm resolution
            ret = obj.set_intvalue('opo_lambda',round(obj.target_wavelength*100));
            assert(ret == 1, 'Setting target wavelength failed');
            disp(['Target wavelength set: ' num2str(round(obj.target_wavelength*100)/100) 'nm']);
            % IMPORTANT: wait one second before starting to poll for ready
            pause(1);       
        end
        
        function set_pid_target_wavelength(obj, setpoint)
            % set the target wavelength to fine tune toward
            typecheck = isa(setpoint, 'double')
            assert(typecheck == 1, 'Setpoint must be double precision float')
            ret = obj.set_intvalue(WLM_PID_Setpoint, setpoint);
            assert(ret == 1, 'Setting setpoint wavelength failed');
            disp(['Setpoint wavelength set: ' num2str(setpoint) 'nm']);
            % IMPORTANT: wait one second before starting to poll for ready
            pause(1);
        end

        function fine_tune(obj, measured_wavelength)
            % fine tune based on wavemeter measurement
            ret = obj.set_intvalue(WLM_PiezoSteps, 1);
            assert(ret == 1, 'Turning on cavity piezo during PID failed');
            ret = obj.set_intvalue(WLM_etalonsteps, 0);
            assert(ret == 1, 'Turning off etalon steps during PID failed');
            obj.WLM_PID_Compute(measured_wavelength);
        end

        function coarse_tune(obj, measured_wavelength)
            % coarse tune based on wavemeter measurement
            ret = obj.set_intvalue(WLM_PiezoSteps, 1);
            assert(ret == 1,'Turning on cavity piezo during PID failed');
            ret = obj.set_intvalue(WLM_etalonsteps, 1);
            assert(ret == 1, 'Turning on etalon steps during PID failed');
            obj.WLM_PID_Compute(measured_wavelength);
        end
        
        function flag = abort_tune(obj)
            %Stops optimization of wavelength tuning.
            flag = obj.set_command(obj.StopOptimization);
            assert(flag==1, 'Optimization has not stopped');
        end

        function piezo = get_ref_cavity_percent(obj)
            % returns reference cavity piezo percent value
            piezo_voltage = obj.get_intvalue(x);
            piezo = piezo_voltage/obj.Piezo_maxBit;
        end
        
        function piezo = tune_ref_cavity(obj,piezo_percent)
            %Piezo voltage is passed a a percentage of the total range
            %Total range is 0-65535
            %Convert from percentage to integer
            peizo_voltage = round(piezo_percent*obj.Piezo_maxBit);
          
            flag = LibraryFunction(obj.LibraryName,obj.Set_IntValue,obj.RefCavity_Piezo,peizo_voltage);
            if (flag == 1)
                piezo = piezo_percent;
            elseif (flag == -1)
                piezo = get_ref_cavity_percent();
            end    
        end
        
        function piezo = tune_thick_etalon(obj,relative_wl_pm)
            %Piezo voltage is passed a a percentage of the total range
            %Total range is 0-65535
            %Convert from percentage to integer
            flag = LibraryFunction(obj.LibraryName,obj.Set_IntValue,obj.ThickEtalon_Piezo_hr,relative_wl_pm);
            if (flag == 1)
                piezo = piezo_percent;
            elseif (flag == -1)
                piezo = get_ref_cavity_percent();
            end    
        end     
    end
    
    %Methods I will likey never use
    methods
        function initialize_shutters(obj)
            %Open or close all shutters
            %Our CWAVE only has internal pump laser and SHG shutters
            if strcmp(obj.all_shutters,obj.Open)
                ret_lsr = set_intvalue(obj.ShutterLaser,1);
                assert(ret_lsr == 1, 'Opening pump laser shutter failed'); 
                ret_shg = set_intvalue(obj.ShutterSHG,1);
                assert(ret_shg == 1, 'Opening shg shutter failed'); 
            elseif strcmp(obj.all_shutters,obj.Close)
                ret_lsr = set_intvalue(obj.ShutterLaser,0);
                assert(ret_lsr == 1, 'Closing pump laser shutter failed'); 
                ret_shg = set_intvalue(obj.ShutterSHG,0);
                assert(ret_shg == 1, 'Closing shg shutter failed'); 
            end
        end
        
         function [status] = ext_set_command(cmd)
            % Description: Sends a command to the external module.
            % Arguments: cmd is the command as string. See the documentation of the external module for valid commands.
            % Returns: Returns 1 if the new command was executed correctly. Returns -1 if an error occurred.
            %% external commands for WS8-10 High Finesse wavemeter
            %% set command for external module (i.e. the wavemeter)
            status = LibraryFunction(obj.LibraryName,obj.Ext_SetCommand,cmd);
        end
       
        function [ext_intvalue] = ext_get_intvalue(cmd)
            % Description: Reads the value of an integer parameter from the external module.
            % Arguments: Parameter as string. See documentation of external module for valid parameters.
            % Returns: Returns the requested integer value.
            %% Table of allowing integer paramters for high finesse WS8-10 wavemeter
            ext_intvalue = calllib(obj.LibraryName, obj.ExtGet_IntValue,cmd);
        end

        function [ext_floatvalue] = ext_get_floatvalue(cmd)
            % Description: Reads the value of an floating point parameter from the external module.
            % Arguments: Parameter as string. See documentation of external module for valid parameters.
            % Returns: Returns the requested floating point value.
            %% Table of allowable float parameters for High Finesse WS8-10 wavemeter
            ext_floatvalue = calllib(obj.LibraryName, obj.ExtGet_FloatValue, cmd);
        end
        
        function [laser_status] = get_status_laser(obj)
            % Description: Reads the current status of the pump laser.
            % Arguments: none
            % Returns: Returns 0 (1 before inversion) if the pump laser is active and the laser shutter is open. 
            %  Returns 1 (0 before inversion) if no or not sufficient laser power is available.
            laser_status = LibraryFunction(obj.LibraryName,obj.LaserStatus);
        end

        function [ref_temp_status] = get_status_temp_ref(obj)
            % Description: Reads the current status of the reference temperature.
            % Arguments: none
            % Returns: Returns 0 if the reference temperature is stable. 
            %  Returns 1 if the reference temperature is not at setpoint.
            %% Poll temperature status
            ref_temp_status = LibraryFunction(obj.LibraryName, obj.Reference_TempStatus);
        end
        
        function [opo_temp_status] = get_status_temp_opo(obj)
            % Description: Reads the current status of the OPO temperature.
            % Arguments: none
            % Returns: Returns 0 if the OPO temperature is stable. 
            %  Returns 1 if the OPO temperature is not at setpoint.
            %% Poll OPO Temperature Status
            opo_temp_status = LibraryFunction(obj.LibraryName, obj.OPO_TempStatus);
        end

        function [shg_temp_status] = get_status_temp_shg(obj)
            % Description: Reads the current status of the SHG temperature.
            % Arguments: none
            % Returns: Returns 0 if the SHG temperature is stable. 
            %  Returns 1 if the SHG temperature is not at setpoint.
            %% Poll SHG temperature Status
            shg_temp_status = LibraryFunction(obj.LibraryName, obj.SHG_TempStatus); 
        end

        function [opo_lock_status] = get_status_lock_opo(obj)
            % Description: Reads the current status of the OPO lock.
            % Arguments: none
            % Returns: Returns 0 if the OPO is locked to the reference cavity and 
            %  produces stable output. Returns 1 if optimization is still in progress.
            %% Poll opo_lock_status...What exactly is the OPO lock?
            opo_lock_status = LibraryFunction(obj.LibraryName, obj.OPO_LockStatus);
        end

        function [shg_lock_status] = get_status_lock_shg(obj)
            % Description: Reads the current status of the SHG lock.
            % Arguments: none
            % Returns: Returns 0 if the SHG cavity is locked and produces stable output. 
            %  Returns 1 if optimization is still in progress.
            shg_lock_status = LibraryFunction(obj.LibraryName, obj.SHG_LockStatus);
        end
        
        function [etalon_lock_status] = get_status_lock_etalon(obj)
            % Description: Reads the current status of the etalon lock.
            % Arguments: none
            % Returns: Returns 0 if the etalon is locked. Returns 1 if optimization is still in progress.
            etalon_lock_status = LibraryFunction(obj.LibraryName, obj.Etalon_LockStatus);
        end
    end
        
end

