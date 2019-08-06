classdef PolarisationSpectrum < Modules.Experiment
    %PolarisationSpectrum Measures spectra at specified rotations of a motorised HWP or polariser to
    %                     give polarisation dependent spectra

    properties(SetObservable,AbortSet)
        angles = '0:10:180';        % string of rotations (in degrees) at which spectra will be measured. Can specify a list or MATLAB range
        motor_serial_number = @Drivers.APTMotor.getAvailMotors; % Serial number for the rotation mount, to be used to create a driver for the rotation mount. Must be connected through APT Config first.
        spec_experiment = Experiments.Spectrum.instance % Handle for spectrum experiment to be run. Settings for the experiment accessed from GUI
    end
    properties
        prefs = {'spec_experiment', 'angles', 'motor_serial_number'};  % String representation of desired prefs
        %show_prefs = {'spec_experiment', 'angles', 'motor_serial_number'};   % Use for ordering and/or selecting which prefs to show in GUI
        readonly_prefs = {'spec_experiment'}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
        data % Useful for saving data from run method
        meta % Useful to store meta data in run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
        rot %Handle for rotation mount driver
        angle_list %List of angles at which spectra will be measured
        active_experiment %actively running experiment used for aborting mid spectrum
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
            if ~isempty(obj.active_experiment) && isvalid(obj.active_experiment)
                obj.active_experiment.abort();
            end
        end

        function dat = GetData(obj,stageManager,imagingManager)
            % Callback for saving methods
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        function set.motor_serial_number(obj,val)
            val_as_double = str2double(val); % must be double to instantiate motor
            assert(~isnan(val_as_double),'Motor SN must be a valid number.')

            % Handle proper deleting of unused motor driver object
            delete(obj.rot); % Either motor obj or empty
            obj.rot = [];

            obj.motor_serial_number = val;
            if val_as_double == 0
                %Leave obj.rot empty if no serial number selected
                return % Short circuit
            end
            
            % Add new motor
            obj.rot = Drivers.APTMotor.instance(val_as_double, [0 360]);
        end
        
        function set.angles(obj,val)
            obj.angle_list = str2num(val);
            obj.angles = val;
        end
        
        function delete(obj)
            delete(obj.spec_experiment);
            delete(obj.rot);
        end
    end
end