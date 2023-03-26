classdef WideFieldParameterSweep < Modules.Experiment
    %WideFieldParameterSweep Description of experiment
    % Useful to list any dependencies here too

    properties(SetObservable,AbortSet)
        % These should be preferences you want set in default settings method
               imaging = Modules.Imaging.empty(1,0);
               greenLaser = Modules.Source.empty(1,0);

               exposureTimeString = 'linspace(10,10000,51)'; % ms
               exposureTime = 10;
               numberImages = 5;
               emGain = 2000;
               emGainString = 'linspace(100,5000,21)';
               
% Default type is important; here it is a string for example
    end
    properties
        prefs = {'imaging','exposureTimeString','exposureTime','numberImages','greenLaser','emGain','emGainString'};  % String representation of desired prefs
        show_prefs = {'imaging','exposureTimeString','numberImages','greenLaser','emGainString'};   % Use for ordering and/or selecting which prefs to show in GUI
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
        function obj = WideFieldParameterSweep()
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
        function set.imaging(obj,val)
            obj.imaging = val;
        end
          function set.greenLaser(obj,val)
            obj.greenLaser = val;
        end
        function set.numberImages(obj,val)
            obj.numberImages = val;
        end
        
        function set.exposureTimeString(obj,val)
            %assert(isnumeric(val),'Value must be numeric!')
            %assert(val>=0 && val<=10,'Value must fall between 0 and 10.')
            obj.exposureTime = str2num(val);
            obj.exposureTimeString = val;

        end
        
        function set.emGainString(obj,val)
            %assert(isnumeric(val),'Value must be numeric!')
            %assert(val>=0 && val<=10,'Value must fall between 0 and 10.')
            obj.emGain = str2num(val);
            obj.emGainString = val;

        end
    end
end
