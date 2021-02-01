classdef Widefield_CW_ODMR < Modules.Experiment
%CW_ODMR Description of experiment
    % Useful to list any dependencies here too

    properties(GetObservable,SetObservable,AbortSet)
        averages = Prefs.Integer(2,'min', 1, 'help_text', 'Number of averages to perform');
        Laser = Prefs.ModuleInstance('help_text','PulseBlaster enabled laser');
        Camera = Prefs.ModuleInstance('help_text','Camera used to take ODMR images');
        Exposure = Prefs.Double(100, 'min', 0, 'help_text', 'Camera exposure to use during experiment', 'unit', 'ms');
        SignalGenerator = Prefs.ModuleInstance('help_text','Signal generator used to produce ODMR MW frequency');
        MW_freqs_GHz = Prefs.String('linspace(2.85,2.91,101)', 'help_text','List of MW frequencies to be used in ODMR experiment specified as a Matlab evaluatable string', 'unit','GHz', 'set','set_MW_freqs_GHz');
        MW_Power = Prefs.Double(-30, 'help_text', 'Signal generator MW power', 'unit', 'dBm');
        MW_freq_norm = Prefs.Double(2, 'help_text', 'Frequency used to normalise fluorescence. Should be far off resonance. If set to <=0, MW will be turned off for normalisation period', 'unit', 'GHz');
        Pixel_of_Interest_x = Prefs.String('', 'help_text', 'x-coordinate of pixel of interest to plot during experiment', 'set','set_x_pixel', 'custom_validate','validate_pixel');
        Pixel_of_Interest_y = Prefs.String('', 'help_text', 'y-coordinate of pixel of interest to plot during experiment', 'set','set_y_pixel', 'custom_validate','validate_pixel');

    end
    properties
        prefs = {'MW_freqs_GHz','MW_freq_norm','MW_Power','Exposure','Pixel_of_Interest_x','Pixel_of_Interest_y','averages','Laser','SignalGenerator','Camera'};
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        freq_list = linspace(2.85,2.91,101)*1e9; % Internal, set using MW_freqs
        pixel_x = linspace(2.85,2.91,101)*1e9; % Internal, set using Pixel_of_Interest_y
        pixel_y = linspace(2.85,2.91,101)*1e9; % Internal, set using Pixel_of_Interest_y
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
        function obj = Widefield_CW_ODMR()
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
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        % Set methods allow validating property/pref set values
        function val = set_MW_freqs_GHz(obj,val,pref)
            obj.freq_list = str2num(val)*1e3;
        end
        function val = set_x_pixel(obj,val,pref)
            obj.pixel_x = str2num(val);
        end
        function val = set_y_pixel(obj,val,pref)
            obj.pixel_y = str2num(val);
        end
        function validate_pixel(obj,val,pref)
            val = str2num(val);
            assert( isempty(val) || isrow(val), 'Pixel must be empty or a row vector')
        end
    end
end