classdef CMOS_Open_Loop_ODMR < Modules.Experiment
    %CMOS_Open_Loop_ODMR Measures CW ODMR with open-loop control of bias on CMOS chip
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

        % CMOS MW control properties
        MW_Control_line_1 = 1;    % Pulse Blaster flag bit (indexed from 1)
        MW_Control_line_2 = 2;    % Pulse Blaster flag bit (indexed from 1) for the other control line
        MW_1_on = false;          % Boolean whether to turn on MW control line 1 during experiment
        MW_2_on = false;          % Boolean whether to turn on MW control line 2 during experiment
        ip = 'No Server';         % ip of host computer (with PB)

        % CMOS bias properties
        PowerSupply = Modules.Source.empty(0,1); % Power supply source object
        keep_bias_on = false; % Boolean whether to keep bias on in between experiments
        VDD_VCO = 1; % Number representing VCO voltage (volts)
        VDD_CTRL = 'linspace(0.7,1.1,100)'; % list representing vco control voltages to evaluate (volts)
        VDD_CTRL_norm = 1; % Double representing normalisation frequency to evaluate at (volts)
        VDD_IND = 1; % Double representing driver bias 1 (volts)
        IND_BIAS = 1; % Double representing driver bias 2 (volts)
        VDD_VCO_Channel = ''; % String channel for VCO; no channel if empty
        VDD_CTRL_Channel = ''; % String channel for Driver voltage; no channel if empty
        VDD_IND_Channel = ''; % String channel for bias 1; no channel if empty
        IND_BIAS_Channel = ''; % String channel for bias 2; no channel if empty
    end
    properties
        prefs = {'Exposure_ms','averages','Laser','PowerSupply',...
            'keep_bias_on','MW_1_on','MW_2_on','VDD_CTRL_norm',...
            'VDD_VCO','VDD_CTRL','VDD_IND','IND_BIAS','APD_line',...
            'MW_Control_line_1', 'MW_Control_line_2','APD_Sync_line',...
            'VDD_VCO_Channel','VDD_CTRL_Channel','VDD_IND_Channel',...
            'IND_BIAS_Channel','ip'};
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        volt_list = linspace(0,2,20); % Internal, set using VDD_CTRL
        VDD_CTRL_voltage = [];
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
        function obj = CMOS_Open_Loop_ODMR()
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
                obj.ip = val;
                return
            end
            err = [];
            try
                obj.PulseBlaster = Drivers.PulseBlaster.StaticLines.instance(val); %#ok<*MCSUP>
                obj.ip = val;
            catch err
                obj.PulseBlaster = [];
                obj.ip = 'No Server';
            end
            if ~isempty(err)
                rethrow(err)
            end
        end

        % Set methods allow validating property/pref set values
        function set.PowerSupply(obj,val)
            val.Channel = val.ChannelNames(1); % Ensure that channel is set
            obj.PowerSupply = val;
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
            if ~isempty(obj.PowerSupply.Channel) % if channel is set
                % Change power supply settings when changing bias voltage
                obj.PowerSupply.Channel = obj.VDD_VCO_Channel;
                obj.PowerSupply.Voltage = val;
                obj.PowerSupply.Source_Mode = 'Voltage';
            end
            obj.VDD_VCO = val;
        end

        function set.VDD_CTRL(obj,val)
            obj.volt_list = str2num(val);
            obj.VDD_CTRL = val;
        end

        function set.VDD_CTRL_voltage(obj,val)
            if ~isempty(obj.PowerSupply.Channel) % if channel is set
                % Change power supply settings when changing bias voltage
                obj.PowerSupply.Channel = obj.VDD_CTRL_Channel;
                obj.PowerSupply.Voltage = val;
                obj.PowerSupply.Source_Mode = 'Voltage';
            end
            obj.VDD_CTRL_voltage = val;
        end
        
        function set.VDD_IND(obj,val)
            if ~isempty(obj.PowerSupply.Channel)
                obj.PowerSupply.Channel = obj.VDD_IND_Channel;
                obj.PowerSupply.Voltage = val;
                obj.PowerSupply.Source_Mode = 'Voltage';
            end
            obj.VDD_IND = val;
        end

        function set.IND_BIAS (obj,val)
            if ~isempty(obj.PowerSupply.Channel)
                obj.PowerSupply.Channel = obj.IND_BIAS_Channel;
                obj.PowerSupply.Voltage = val;
                obj.PowerSupply.Source_Mode = 'Voltage';
            end
            obj.IND_BIAS = val;
        end

        function set.VDD_VCO_Channel(obj,val)
            % Check that channel exists and is different from other channels before changing
            if ~isempty(val) && ~isempty(obj.PowerSupply) % Just set if channel/PowerSupply is not empty
                assert(~strcmp(val,obj.VDD_CTRL_Channel) && ~strcmp(val,obj.VDD_IND_Channel) && ~strcmp(val,obj.IND_BIAS_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
                % Get power supply voltage
                voltage = obj.PowerSupply.Voltages( obj.PowerSupply.getHWIndex(val));
                obj.VDD_VCO = voltage;
            end
            obj.VDD_VCO_Channel = val;
        end

        function set.VDD_CTRL_Channel(obj,val)
            if ~isempty(val) && ~isempty(obj.PowerSupply)
                assert(~strcmp(val,obj.VDD_VCO_Channel) && ~strcmp(val,obj.VDD_IND_Channel) && ~strcmp(val,obj.IND_BIAS_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
                voltage = obj.PowerSupply.Voltages( obj.PowerSupply.getHWIndex(val));
                obj.VDD_CTRL_voltage = voltage;
            end
            obj.VDD_CTRL_Channel = val;
        end

        function set.VDD_IND_Channel(obj,val)
            if ~isempty(val) && ~isempty(obj.PowerSupply)
                assert(~strcmp(val,obj.VDD_VCO_Channel) && ~strcmp(val,obj.VDD_CTRL_Channel) && ~strcmp(val,obj.IND_BIAS_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
                voltage = obj.PowerSupply.Voltages( obj.PowerSupply.getHWIndex(val));
                obj.VDD_IND = voltage;
            end
            obj.VDD_IND_Channel = val;
        end
        
        function set.IND_BIAS_Channel(obj,val)
            if ~isempty(val) && ~isempty(obj.PowerSupply)
                assert(~strcmp(val,obj.VDD_VCO_Channel) && ~strcmp(val,obj.VDD_CTRL_Channel) && ~strcmp(val,obj.VDD_IND_Channel), 'Channel already assigned')
                obj.PowerSupply.checkChannel(val)
                voltage = obj.PowerSupply.Voltages( obj.PowerSupply.getHWIndex(val));
                obj.IND_BIAS = voltage;
            end
            obj.IND_BIAS_Channel = val;
        end
    end
end
