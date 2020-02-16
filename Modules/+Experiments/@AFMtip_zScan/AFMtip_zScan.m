classdef AFMtip_zScan < Modules.Experiment
    %AFMtip_zScan Description of experiment
    % Useful to list any dependencies here too

    properties(SetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        takeSpec = Experiments.Spectrum.instance;        % Default type here is numeric
        zRange = 'linspace(0,0.1,11)';
        ANC_address = 'COM6';
        BGVoltage = 0; % 
        TipVoltageRange = '[0]'; %eval(ScanRange) will define Scanning range (Range)
        Detection_Type = {'APD','Spectrometer'}; 
        APD_line = 'APD1'; % APD line name (for counter)
        APD_dwell = 100; % APD dwell time [ms]
        KeithleyBGadress = 1;
        KeithleyTipadress = 2;
        CurrentCompliance = 2e-9;
    end
    properties
        prefs = {'takeSpec','zRange','ANC_address','BGVoltageRange','TipVoltageRange','KeithleyBGadress','KeithleyTipadress','CurrentCompliance','Detection_Type','APD_line','APD_dwell'};  % String representation of desired prefs
        %show_prefs = {};   % Use for ordering and/or selecting which prefs to show in GUI
        %readonly_prefs = {}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
        ANC;
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

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = AFMtip_zScan()
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
            obj.ANC = Drivers.ANC300(obj.ANC_address,[1]); % only zAxis (1) enabled
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
            % Callback for saving methods
            meta = stageManager.position;
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        % Set methods allow validating property/pref set values
        function set.zRange(obj,val)
            t = eval(val);
            assert(~isempty(t),'zRange is empty')
            assert(isnumeric(t),'Value must be numeric')
            obj.zRange = val;
        end
        function set.ANC_address(obj,adress)
            obj.ANC_address = adress;
            if ~isempty(obj.ANC)
                delete(obj.ANC); % Either motor obj or empty
            end
            obj.ANC = Drivers.KANC300(obj.ANC_address, [1]); % only zAxis (1) enabled
            obj.ANC.set_mode(1,'off'); % Set offset mode

        end
        function set.BGVoltage(obj,val)

            obj.BGVoltage = val;
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
            delete(obj.ANC);
            delete(obj.KeithleyTip);
            delete(obj.KeithleyBG);
        end
    end
end
