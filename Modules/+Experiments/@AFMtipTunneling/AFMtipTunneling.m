classdef AFMtipTunneling < Modules.Experiment
    %AFMtipTunneling Description of experiment
    % Useful to list any dependencies here too

    properties(SetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        BGVoltageRange = 'linspace(0,0.1,11)';
        TipVoltageRange = 'linspace(0,0.1,11)';
        KeithleyBGadress = 1;       % 
        KeithleyTipadress = 2;       % 
        ANC300adress = "COM1";
        zAxis = 1;  % 
        CurrentCompliance = 2e-9;
    end
    properties
        prefs = {'TipVoltageRange','BGVoltageRange','KeithleyBGadress','KeithleyTipadress','CurrentCompliance',' ANC300adress','zAxis'};  % String representation of desired prefs
        %show_prefs = {};   % Use for ordering and/or selecting which prefs to show in GUI
        %readonly_prefs = {}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
        KeithleyBG;
        KeithleyTip;
        PiezoController;
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
        function obj = AFMtipTunneling()
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
            obj.KeithleyBG = Drivers.Keithley2400(obj.KeithleyBGadress);
            obj.KeithleyTip = Drivers.Keithley2400(obj.KeithleyTipadress);
            obj.PiezoController = Drivers.ANC300(obj.ANC300adress,[zAxis]);
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
        function set.zAxis(obj,val)
            obj.zAxis = val;
        end
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
            delete(obj.PiezoController);
        end
    end
end
