classdef CMOS_CW_ODMR < Modules.Experiment
    %CMOS_CW_ODMR Measures CW ODMR with proper control of bias and control of CMOS chip
    % Data structure
    % data:
    % meta: 
    % Dependencies
    % Sources/SignalGenerators
    % Sources/PowerSupplies
    % Drivers/Counter
    

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

        % CMOS MW control properties
        MW_Control_line = 1;               % Pulse Blaster flag bit (indexed from 1)
        ip = 'No Server';         % ip of host computer (with PB)

        % CMOS bias properties
        PowerSupply = Modules.Source.empty(0,1); % Power supply source object
        keep_bias_on = false; % Boolean whether to keep bias on in between experiments
        VDD_VCO = 1; % Number representing VCO voltage (volts)
        VDD_Driver = 1; % Double representing river voltage (volts)
        Driver_Bias_1 = 1; % Double representing driver bias 1 (volts)
        Driver_Bias_2 = 1; % Double representing driver bias 2 (volts)
        VDD_VCO_Channel = ''; % String channel for VCO; no channel if empty
        VDD_Driver_Channel = ''; % String channel for Driver voltage; no channel if empty
        Driver_Bias_1_Channel = ''; % String channel for bias 1; no channel if empty
        Driver_Bias_2_Channel = ''; % String channel for bias 2; no channel if empty
    end
    properties
        prefs = {'MW_freqs_GHz','MW_freq_norm_GHz','MW_Power_dBm','Exposure_ms','averages','Laser',...
                 'SignalGenerator','PowerSupply','keep_bias_on','VDD_VCO','VDD_Driver','Driver_Bias_1','Driver_Bias_2','APD_line','MW_Control_line','APD_Sync_line','VDD_VCO_Channel','VDD_Driver_Channel','Driver_Bias_1_Channel','Driver_Bias_2_Channel'};
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        freq_list = linspace(2.85,2.91,101)*1e9; % Internal, set using MW_freqs_GHz
        data = [] % Useful for saving data from run method
        meta = [] % Useful to store meta data in run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
    end
    properties(SetAccess=private)
        PulseBlaster                 % Hardware handle
    end
    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = CMOS_CW_ODMR()
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

        function set.ip(obj,val) %this loads the pulseblaster driver
            if strcmp('No Server',val)
                obj.PulseBlaster = [];
                delete(obj.listeners)
                obj.source_on = 0;
                obj.ip = val;
                return
            end
            err = [];
            try
                obj.PulseBlaster = Drivers.PulseBlaster.StaticLines.instance(val); %#ok<*MCSUP>
                obj.source_on = obj.PulseBlaster.lines(obj.PBline);
                delete(obj.listeners)
                obj.listeners = addlistener(obj.PulseBlaster,'running','PostSet',@obj.isRunning);
                obj.ip = val;
                obj.isRunning;
            catch err
                obj.PulseBlaster = [];
                delete(obj.listeners)
                obj.source_on = 0;
                obj.ip = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end

        % Set methods allow validating property/pref set values
        function set.MW_freqs_GHz(obj,val)
            obj.freq_list = str2num(val)*1e9;
            obj.MW_freqs_GHz = val;
        end

        function set.keep_bias_on(obj,val)
            % Turn on/off power supply on changing keep_bias_on
            if val
                obj.PowerSupply.on();
            else
                obj.PowerSupply.off();
            end
            obj.keep_bias_on = val;
        end

        function set.VDD_VCO(obj,val)
            % Change power supply settings when changing bias voltage
            obj.PowerSupply.Channel = obj.VDD_VCO_Channel;
            obj.PowerSupply.Voltage = val;
            obj.PowerSupply.Source_Mode = 'Voltage';
            obj.VDD_VCO = val;
        end

        function set.VDD_Driver(obj,val)
            obj.PowerSupply.Channel = obj.VDD_Driver_Channel;
            obj.PowerSupply.Voltage = val;
            obj.PowerSupply.Source_Mode = 'Voltage';
            obj.VDD_Driver = val;
        end
        
        function set.Driver_Bias_1(obj,val)
            obj.PowerSupply.Channel = obj.Driver_Bias_1_Channel;
            obj.PowerSupply.Voltage = val;
            obj.PowerSupply.Source_Mode = 'Voltage';
            obj.Driver_Bias_1 = val;
        end

        function set.Driver_Bias_2 (obj,val)
            obj.PowerSupply.Channel = obj.Driver_Bias_2_Channel;
            obj.PowerSupply.Voltage = val;
            obj.PowerSupply.Source_Mode = 'Voltage';
            obj.Driver_Bias_2 = val;
        end

        function set.VDD_VCO_Channel(obj,val)
            % Check that channel exists and is different from other channels before changing
            if ~isempty(val) % Just set if channel is empty
                assert(~strcmp(val,obj.VDD_Driver_Channel) && ~strcmp(val,obj.Driver_Bias_1_Channel) && ~strcmp(val,obj.Driver_Bias_2_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
            end
            obj.VDD_VCO_Channel = val;
        end

        function set.VDD_Driver_Channel(obj,val)
            if ~isempty(val)
                assert(~strcmp(val,obj.VDD_VCO_Channel) && ~strcmp(val,obj.Driver_Bias_1_Channel) && ~strcmp(val,obj.Driver_Bias_2_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
            end
            obj.VDD_Driver_Channel = val;
        end

        function set.Driver_Bias_1_Channel(obj,val)
            if ~isempty(val)
                assert(~strcmp(val,obj.Driver_VCO_Channel) && ~strcmp(val,obj.VDD_Driver_Channel) && ~strcmp(val,obj.Driver_Bias_2_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
            end
            obj.VDD_Bias_1_Channel = val;
        end
        
        function set.Driver_Bias_2_Channel(obj,val)
            if ~isempty(val)
                assert(~strcmp(val,obj.Driver_VCO_Channel) && ~strcmp(val,obj.VDD_Driver_Channel) && ~strcmp(val,obj.Driver_Bias_1_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
            end
            obj.VDD_Bias_2_Channel = val;
        end
    end
end
