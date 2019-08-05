classdef PolarisationSpectrum < Modules.Experiment
    %PolarisationSpectrum Measures spectra at specified rotations of a motorised HWP or polariser to
    %                     give polarisation dependent spectra
    % Useful to list any dependencies here too

    properties(SetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        spec_experiment % Handle for spectrum experiment to be run
        angles = 0:10:180;        % List of rotations at which spectra will be measured
        rot_number = 0; % Serial number for the rotation mount, to be used to create a driver for the rotation mount
    end
    properties
        prefs = {'angles'};  % String representation of desired prefs
        show_prefs = {'spec_experiment', 'rot_number'};   % Use for ordering and/or selecting which prefs to show in GUI
        readonly_prefs = {'spec_experiment'}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
        data % Useful for saving data from run method
        meta % Useful to store meta data in run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
        rot %Handle for rotation mount driver
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = PolarisationSpectrum()
            % Constructor (should not be accessible to command line!)
            obj.spec_experiment = Experiments.Spectrum.instance;
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

        function set.rot_number(obj,val)
            assert(isnumeric(val),'Value must be numeric!')
            obj.rot_number = val;
        end
    end
end
