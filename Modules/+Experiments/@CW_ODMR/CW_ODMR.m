classdef CW_ODMR < Modules.Experiment
    %CW_ODMR Description of experiment
    % Useful to list any dependencies here too

    properties(SetObservable,AbortSet)
        averages = 2;
        Laser = Modules.Source.empty(0,1);

        APD_line = 'APD1';
        APD_Sync_line = 'CounterSync';
        Exposure_ms = 100;

        SignalGenerator = Modules.Source.empty(0,1);
        MW_freqs_GHz = 'linspace(2.85,2.91,101)';
        MW_Power_dBm = -30;
        MW_freq_norm_GHz = 2; % If set to -1, will turn off
    end
    properties
        prefs = {'MW_freqs_GHz','MW_freq_norm_GHz','MW_Power_dBm','Exposure_ms','averages','Laser',...
                 'SignalGenerator','APD_line','APD_Sync_line'};
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        freq_list = linspace(2.85,2.91,101)*1e9; % Internal, set using MW_freqs_GHz
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
        function obj = CW_ODMR()
            % Constructor (should not be accessible to command line!)
            obj.path = 'APD1';
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
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        % Set methods allow validating property/pref set values
        function set.MW_freqs_GHz(obj,val)
            obj.freq_list = str2num(val)*1e9;
            obj.MW_freqs_GHz = val;
        end
    end
end
