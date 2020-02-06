classdef PLEwide < Modules.Experiment
    %PLEwide Description of experiment
    % Useful to list any dependencies here too
    
    properties(SetObservable,AbortSet)
        
        resLaser = Modules.Source.empty(1,0); % Call EMM or solstis
        takeSpec = Experiments.Spectrum.instance; % Call Spectrometer
        ScanRange = 'linspace(710,720,11)'; % %eval(ScanRange) will define Scanning range (Range)
        Detection_Type = {'APD','Spectrometer'}; 
        APD_line = 'APD1'; % APD line name (for counter)
        APD_dwell = 100; % APD dwell time [ms]
%         Counter = Modules.Driver.Counter.instance; % Call Counter for APD
%         hwserver_ip = Experiments.PLE_WideScan_SPEC.no_server;
    end
    properties
        prefs = {'resLaser','ScanRange'};  % String representation of desired prefs
        show_prefs = {'resLaser','takeSpec','ScanRange','Detection_Type','APD_line','APD_dwell'};   % Use for ordering and/or selecting which prefs to show in GUI
        %readonly_prefs = {}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
        PM;
        counter;                % APD counter
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
        data = [] % Useful for saving data from run method
        meta = [] % Useful to store meta data in run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
    end
    properties(Constant,Hidden)
        no_server = 'No Server';  % Message when not connected
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = PLEwide()
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
%             obj.ni = Drivers.NIDAQ.dev.instance('dev1');
            obj.PM = Drivers.PM100.instance;
            obj.counter = Drivers.Counter.instance(obj.APD_line,'CounterSync');
        end
    end

    methods
        run(obj,status,managers,ax) % Main run method in separate file

        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function dat = GetData(obj,stageManager,imagingManager) 
            % Callback for saving methods (in CommandCenter)
%             meta = stageManager.position;
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        % Set methods allow validating property/pref set values
        function set.resLaser(obj,val)
            if isempty(val)
                obj.resLaser = val;
                return
            end
            h = superclasses(val);
            assert(ismember('Sources.TunableLaser_invisible',h),'Laser must be tunable')
            obj.resLaser = val;
        end
        function set.ScanRange(obj,val)
            t = eval(val);
            assert(~isempty(t),'ScanRange is empty')
            assert(isnumeric(t),'Value must be numeric')
            obj.ScanRange = val;
        end
    end
end
