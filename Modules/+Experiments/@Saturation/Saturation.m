classdef Saturation < Modules.Experiment
    % Saturation changes intensity on a sample using a HWP (motorised or manually moved) and monitors the APD to measure saturation. Optionally also monitors a power meter to calibrate measurement with power.

    properties(SetObservable,GetObservable)
        angles = Prefs.String('0','help_text', 'Matlab expression evaluated to find angles at which to measure APDs','units','degree','set','setAngle','allow_empty',false);
        exposure = Prefs.Double(100, 'help_text', 'Exposure time to measure APD counts','units','ms','min',0,'allow_nan',false)
        motor_move_time = Prefs.Double(30, 'help_text', 'Maximum time allowed for the motor to move','units','s','min',0,'allow_nan',false)
        motor_home_time = Prefs.Double(120, 'help_text', 'Maximum time allowed for the motor to home','units','s','min',0,'allow_nan',false)
        motor_serial_number = Prefs.MultipleChoice('help_text','Serial number of APT motor controlling the HWP','set','set_motor_serial_number','allow_empty',true)
        reload = Prefs.Boolean(false,'set','reload_toggle','help_text','Toggle this to reload list of available motors')
        APD_line = Prefs.String('APD1','help_text','NiDAQ line to apd','allow_empty',false);
        APD_sync_line = Prefs.String('CounterSync','help_text','NiDAQ synchronisation line','allow_empty',false);

    end
    properties
        prefs = {'angles','exposure','motor_move_time','motor_home_time','motor_serial_number'};  % String representation of desired prefs
        show_prefs = {'angles','exposure','motor_move_time','motor_home_time','motor_serial_number','reload'};   % Use for ordering and/or selecting which prefs to show in GUI
        %readonly_prefs = {}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
        data = [] % Useful for saving data from run method
        meta = [] % Useful to store meta data in run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
        angle_list
        rot %Handle for rotation mount driver
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = Saturation()
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
            obj.reload_toggle()
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
        function newVal = setAngle(obj,val,pref)
            obj.angle_list = str2num(val);
            newVal = val;
        end
        
        function val = reload_toggle(obj,~,~)
            % TODO: replace with a Prefs.Button
            % Pretends to be a button from a boolean pref
            val = false; % Swap back to false
            mp = obj.get_meta_pref('motor_serial_number');
            mp.choices = Drivers.APTMotor.getAvailMotors(); % set new choices
            obj.set_meta_pref('motor_serial_number', mp);
        end

        function val = set_motor_serial_number(obj,val,~)
            if isempty(val)
                % If '<None>', delete handle and short-circuit
                delete(obj.rot); % Either motor obj or empty
                obj.rot = [];
                return
            end
            
            val_as_double = str2double(val); % must be double to instantiate motor
            
            assert(~isnan(val_as_double),'Motor SN must be a valid number.')
            if isnan(val_as_double)
                return
            end
            % Handle proper deleting of smotor driver object
            delete(obj.rot); % Either motor obj or empty
            obj.rot = [];

            if val_as_double == 0
                %Leave obj.rot empty if no serial number selected
                return % Short circuit
            end

            % Add new motor
            obj.rot = Drivers.APTMotor.instance(val_as_double, [0 360]);
        end
        
    end
end
