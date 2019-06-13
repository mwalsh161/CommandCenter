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
    end

    properties(SetAccess=private)
        PulseStreamer %hardware handle
        wavemeter
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
            if ischar(varargin{1}) && strcmpi(varargin{1},obj.no_server) %first input is always an ip address
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

    methods
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

        function TunePercent(obj, ppercent)
            %TunePercent sets the cavity piezo percentage
            %
            % ppercent = desired piezo percentage from 1 to 100
        end

        function on(obj)
            %{
            assert(~isempty(obj.PulseStreamer),'No IP set!')
            if ~obj.diode_on
                obj.activate;
            end
            obj.PulseStreamer.lines(obj.PBline) = true;
            obj.source_on = true;
            %}
        end
        function off(obj)
            %{
            assert(~isempty(obj.PulseStreamer),'No IP set!')
            obj.source_on = false;
            obj.PulseStreamer.lines(obj.PBline) = false;
            %}
        end
