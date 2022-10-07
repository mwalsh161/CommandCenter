classdef MWsweep_MS < Modules.Experiment
    %MWsweeps Description of experiment
    % Useful to list any dependencies here too

    properties(SetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        
        voltageLine_I = 'AI0';
        voltageLine_Q = 'AI1';
        clockLine = 'CounterSync';
        SignalGenerator = Modules.Source.empty(0,1);
        nsamples = 10000; % number of samples the APD collects
        freqStart = 2820;
        freqEnd = 2920;
        numFreqPoints = 101;
    end
    properties
                prefs = {'voltageLine_I','voltageLine_Q','clockLine','nsamples','freqStart','freqEnd','numFreqPoints','SignalGenerator'};  % String representation of desired prefs
        %show_prefs = {};   % Use for ordering and/or selecting which prefs to show in GUI
        %readonly_prefs = {}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
        data = [] % Useful for saving data from run method
        meta = [] % Useful to store meta data in run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = MWsweep_MS()
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        run(obj,status,managers,ax) % Main run method in separate file

        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function dat = GetData(obj,stageManager,imagingManager)
            % Callback for saving methods
            meta = stageManager.position;
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        % Set methods allow validating property/pref set values
        function set.nsamples(obj,val)
            obj.nsamples = val;
        end
     
    end
end
