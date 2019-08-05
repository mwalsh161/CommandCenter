classdef PolarisationSpectrum < Modules.Experiment
    %PolarisationSpectrum Measures spectra at specified rotations of a motorised HWP or polariser to
    %                     give polarisation dependent spectra
    % Useful to list any dependencies here too

    properties(SetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        angles = '0:10:180';        % string of rotations at which spectra will be measured
        serial_number = @Drivers.APTMotor.getAvailMotors; % Serial number for the rotation mount, to be used to create a driver for the rotation mount
        spec_experiment = Experiments.Spectrum.instance % Handle for spectrum experiment to be run
    end
    properties
        prefs = {'spec_experiment', 'angles', 'serial_number'};  % String representation of desired prefs
        %show_prefs = {'spec_experiment', 'angles', 'serial_number'};   % Use for ordering and/or selecting which prefs to show in GUI
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
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        function setMotor(obj,val)
            val = str2double(val);
            assert(~isnan(val),'Motor SN must be a valid number.')
            % Remove old motor if not loaded by other axis
            motorOld = obj.rot; % Either motor obj or empty
            obj.rot = [];
            if val == 0
                delete(motorOld)
                return % Short circuit
            end
            % Add new motor
            obj.rot = Drivers.APTMotor.instance(val, [0 360]);
        end

        function set.serial_number(obj,val)
            obj.setMotor(val)
            obj.serial_number = val;
        end
        
        function set.angles(obj,val)
            ang = num2str(val);
            obj.angles = val;
            obj.angle_list = ang;
        end
    end
end