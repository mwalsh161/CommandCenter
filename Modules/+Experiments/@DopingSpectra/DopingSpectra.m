classdef DopingSpectra < Modules.Experiment
    %DopingSpectra Description of experiment
    % Useful to list any dependencies here too
    
    properties(SetObservable,AbortSet)
        
        takeSpec = Experiments.Spectrum.instance; % Call Spectrometer
        BGVoltageRange = 'linspace(0,0.1,11)'; % %eval(ScanRange) will define Scanning range (Range)
        TipVoltageRange = 'linspace(0,0.1,11)';
        Detection_Type = {'APD','Spectrometer'}; 
        APD_line = 'APD1'; % APD line name (for counter)
        APD_dwell = 100; % APD dwell time [ms]
        KeithleyBGadress = 1;
        KeithleyTipadress = 2;
        CurrentCompliance = 2e-9;
%         Counter = Modules.Driver.Counter.instance; % Call Counter for APD

    end
    properties
        prefs = {'BGVoltageRange','TipVoltageRange','KeithleyBGadress','KeithleyTipadress','CurrentCompliance'};  % String representation of desired prefs
        show_prefs = {'takeSpec','BGVoltageRange','TipVoltageRange','KeithleyBGadress','KeithleyTipadress','CurrentCompliance','Detection_Type','APD_line','APD_dwell'};   % Use for ordering and/or selecting which prefs to show in GUI
        %readonly_prefs = {}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
        counter;                % APD counter
        KeithleyBG;
        KeithleyTip;
        
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
        function obj = DopingSpectra()
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
            obj.counter = Drivers.Counter.instance(obj.APD_line,'CounterSync');
            obj.KeithleyBG = Drivers.Keithley2400(obj.KeithleyBGadress);
            obj.KeithleyTip = Drivers.Keithley2400(obj.KeithleyTipadress);
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

        function set.BGVoltageRange(obj,val)
            t = eval(val);
            assert(~isempty(t),'ScanRange is empty')
            assert(isnumeric(t),'Value must be numeric')
            obj.BGVoltageRange = val;
        end
        function set.TipVoltageRange(obj,val)
            t = eval(val);
            assert(~isempty(t),'ScanRange is empty')
            assert(isnumeric(t),'Value must be numeric')
            obj.TipVoltageRange = val;
        end
        function set.KeithleyBGadress(obj,adress)

            obj.KeithleyBGadress = adress;
            % Handle proper deleting of smotor driver object
            if ~isempty(obj.KeithleyBG)
                delete(obj.KeithleyBG); % Either motor obj or empty
            end
            obj.KeithleyBG = Drivers.Keithley2400(adress);
            obj.KeithleyBG.setOutputMode('VOLT');
 
        end
        function set.KeithleyTipadress(obj,adress)

            obj.KeithleyTipadress = adress;
            if ~isempty(obj.KeithleyTip)
                delete(obj.KeithleyTip); % Either motor obj or empty
            end
            obj.KeithleyTip = Drivers.Keithley2400(adress);
            obj.KeithleyTip.setOutputMode('VOLT');

        end        
        function set.CurrentCompliance(obj,current)
            obj.CurrentCompliance = current;
            obj.KeithleyBG.setComplianceCurrent(current);
            obj.KeithleyTip.setComplianceCurrent(current);

        end
        function delete(obj)
            delete(obj.KeithleyTip);
            delete(obj.KeithleyBG);
        end
    end
end
