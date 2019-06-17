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

    properties(SetObservable,AbortSet)
        resonator_percent = 0;
        tuning = false;
        cwave_ip = Sources.CWave.no_server;
        pulseStreamer_ip = Sources.CWave.no_server;
    end

    properties(SetAccess=private)
        PulseStreamer %hardware handle
        wavemeter
        cwaveHandle
    end

    properties(Constant,Hidden)
        no_server = 'No Server';  % Message when not connected
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

        function TuneSetpoint(obj,setpoint)
            %TuneSetpoint Sets the wavemeter setpoint
            %   frequency = desired setpoint in THz or nm
            
            %check if in range
        end

        function TuneCoarse(obj, target)
            %TuneCoarse moves the laser to the target frequency
            %
            %   It assumes the laser is close enough to not require
            %   changing of the OPO temperature to reach the target.
            %
            %   First it achieves accuracy to within a picometer by 
            %   changing the thick etalon piezo, then adjusts with
            %   the cavity piezo.
            % 
            %   target = frequency in THz
        end

        function TunePercent(obj, percent)
            %TunePercent sets the resonator cavity piezo percentage
            %
            % percent = desired piezo percentage from 1 to 100
            assert(~isempty(obj.cwaveHandle)&&isobject(obj.cwaveHandle) && isvalid(obj.cwaveHandle),'no cwave handle')
            assert(percent>=0 && percent<=100,'Target must be a percentage')
            obj.resonator_percent = obj.cwaveHandle.tune_ref_cavity(percent)
        end

        function GetPercent(obj)
            % TODO get piezo percent from cwave
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
