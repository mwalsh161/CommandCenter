classdef CWave < Modules.Source & Sources.TunableLaser_invisible & Sources.ConnectableMixin_invisible
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
        % TODO I have no idea what the cwave's range is
        range = Sources.TunableLaser_invisible.c./[300, 1000];
    end

    properties(SetObservable,AbortSet)
        resonator_percent = 0;
        tuning = false;
        cwave_ip = Sources.CWave.no_server;
        pulseStreamer_ip = Sources.CWave.no_server;
        wavemeter_ip = Sources.CWave.no_server;
        wavemeter_channel = 1; % set to integer value
        % TODO fill in prefs all the way
        show_prefs = {'tuning', 'cwave_ip', 'pulseStreamer_ip', 'wavemeter_ip'};
        readonly_prefs = {'tuning'};
    end

    properties(SetAccess=private)
        PulseStreamer %hardware handle
        wavemeter
        cwaveHandle
    end

    properties(Constant,Hidden)
        no_server = 'No Server';  % Message when not connected
    end

    methods(Access=private)
        function obj = CWave()
            obj.loadPrefs;
        end
    end

    methods(Static)
        function obj = instance()
            mlock;
            persistent Object
            if isempty(Object) || ~isvalid(Object)
                Object = Sources.CWave();
                disp('instantiated cwave')
            end
            disp('assigning Object')
            obj = Object;
            disp('function returning')
        end
    end

    methods

        % source methods

        function on(obj)
            assert(~isempty(obj.PulseStreamer), 'No IP set for PulseStreamer!')
            % TODO say something to PulseStreamer
            obj.source_on = true;
            
        end
        function off(obj)
            assert(~isempty(obj.PulseStreamer), 'No IP set for PulseStreamer!')
            % TODO say something to PulseStreamer
            obj.source_on = false;
        end

        % tunable laser methods

        function tune(obj, setpoint)
            tuning = true;
            assert(~isempty(cwaveHandle), 'no cwave handle')
            target_dev = 0.5;
            measured_wavelength = wavemeter.getWavelength();
            mid_setpoint = measured_wavelength;
            while round(target_dev, 5) > 0
                while abs(mid_setpoint - setpoint) > 2*target_dev
                    mid_setpoint = mid_setpoint + 2*target_dev;
                    cwave.set_target_deviation(target_dev);
                    cwaveHandle.set_pid_target_wavelength(mid_setpoint);
                    while abs(measured_wavelength - mid_setpoint) > target_dev
                        cwave.WLM_PID_Compute(measured_wavelength);
                        pause(0.001);
                    end
                end
                target_dev = target_dev/10;
            end
            tuning = false;
        end

        function TuneSetpoint(obj,setpoint)
            %TuneSetpoint Sets the wavemeter setpoint
            %   setpoint = setpoint in nm
            cwaveHandle.fine_tune();
            obj.tune(setpoint);
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
            cwaveHandle.coarse_tune();
            obj.tune(setpoint);
        end

        function TunePercent(obj, percent)
            %TunePercent sets the resonator cavity piezo percentage
            %
            % percent = desired piezo percentage from 1 to 100
            assert(~isempty(obj.cwaveHandle)&&isobject(obj.cwaveHandle) && isvalid(obj.cwaveHandle),'no cwave handle')
            assert(percent>=0 && percent<=100,'Target must be a percentage')
            obj.resonator_percent = obj.cwaveHandle.tune_ref_cavity(percent)
        end

        function piezo = GetPercent(obj)
            piezo = cwaveHandle.get_ref_cavity_percent();
        end

        function freq = getFrequency(obj)
            wavelength = wavemeter.getWavelength();
            freq = Sources.TunableLaser_invisible.c/wavelength
        end

        % set methods

        function set.cwave_ip(obj,ip)
            err = obj.connect_driver('cwaveHandle', cwave, ip);
            if ~isempty(err)
                obj.cwave_ip = obj.no_server;
                rethrow(err)
            end
            obj.cwave_ip = ip;
        end

        function set.pulseStreamer_ip(obj, ip)
            err = obj.connect_driver('PulseStreamer', PulseStreamerMaster.PulseStreamerMaster, ip);
            if ~isempty(err)
                obj.pulseStreamer_ip = obj.no_server;
                rethrow(err)
            end
            pulseStreamer_ip = ip;
        end

        function set.wavemeter_ip(obj, ip)
            err = obj.connect_driver('Wavemeter', Wavemeter.Wavemeter, ip, obj.wavemeter_channel);
            if ~isempty(err)
                obj.wavemeter_ip = obj.no_server;
                rethrow(err)
            end
            wavemeter_ip = ip;
        end

        function set.wavemeter_channel(obj, channel)
            assert(round(channel)==channel&&channel>0,'wavemeter_channel must be an integer greater than 0.')
            obj.wavemeter_channel = channel
            err = obj.connect_driver('wavemeter','Wavemeter',obj.wavemeter_ip,val);
            if ~isempty(err)
                rethrow(err)
            end
        end
    end
end