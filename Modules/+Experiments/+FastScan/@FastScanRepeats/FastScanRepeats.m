classdef FastScanRepeats < Modules.Experiment
    %FastScan Description of experiment
    % Useful to list any dependencies here too

    properties(SetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        start_V = -0.1;
        stop_V = 0.1;
        dwell_ms = 1; % ms
        total_time = 0.1;  % secondsn
        repetitions = 10;
    end
    properties
        prefs = {'start_V','stop_V','dwell_ms','total_time','repetitions'};  % String representation of desired prefs
        %show_prefs = {};   % Use for ordering and/or selecting which prefs to show in GUI
        %readonly_prefs = {}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
        data = [] % Useful for saving data from run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = FastScanRepeats()
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        function run(obj,status,managers,ax)
            runSweep(obj,status,managers,ax)
        end

        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function dat = GetData(obj,stageManager,imagingManager)
            % Callback for saving methods (note, lots more info in the two managers input!)
            objdata = obj.data; % As to not delete obj.data.meta
            if isfield(obj.data,'meta')
                meta = obj.data.meta;
                objdata = rmfield(obj.data,'meta');
            end
            meta.position = stageManager.position;
            meta.start_V = obj.start_V;
            meta.stop_V = obj.stop_V;
            meta.dwell_ms = obj.dwell_ms;
            meta.total_time = obj.total_time;
            meta.repetitions = obj.repetitions;
            
            dat.data = objdata;
            dat.meta = meta;
        end

    end
end
