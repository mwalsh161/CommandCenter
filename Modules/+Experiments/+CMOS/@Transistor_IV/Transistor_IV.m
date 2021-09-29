classdef Transistor_IV < Modules.Experiment
    % CMOS_Rabi Performs a rabi measurement with a MW drive, and a
    % single laser to initialize and readout

    properties(SetObservable,GetObservable,AbortSet)
        % Modules
        Vgs_supply = Prefs.ModuleInstance('help_text','Power supply for gate voltage');
        Vgs_channel = Prefs.Integer(1,'help_text','Channel to use on Vgs power supply','min',1)
        Vds_supply = Prefs.ModuleInstance('help_text','Power supply for drain voltage');
        Vds_channel = Prefs.Integer(1,'help_text','Channel to use on Vds power supply','min',1)

        % Sweep parameters
        Vgs = Prefs.String('help_text','Evaluates to voltages to apply to the gate','units','V','set','set_Vgs');
        Vgs_I_limit = Prefs.Double(.01,'help_text','Current Limit for Vgs','units','A');
        Vds = Prefs.String('help_text','Evaluates to voltages to apply to the drain','units','V','set','set_Vds');
        Vds_I_limit = Prefs.Double(.01,'help_text','Current Limit for Vds','units','A');
        settle_time = Prefs.Double(100,'help_text','Time to wait before measuring current','units','ms')

        % Cosmetic
        x_axis_is_Vgs = Prefs.Boolean(false, 'help_text','Whether to plot Vgs or Vds on x-axis (sweep of the other value will show up as multiple lines)')
    end
    properties
        prefs = {'Vds','Vds_I_limit','Vgs','Vgs_I_limit','settle_time','x_axis_is_Vgs','Vds_supply','Vds_channel','Vgs_supply','Vgs_channel'}
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        data = [] % Useful for saving data from run method
        meta = [] % Useful to store meta data in run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
        vgs_vals = []; % Internal, set using Vgs pref
        vds_vals = []; % Internal, set using Vds pref
    end
    methods(Static)
        obj = instance()
    end
    methods(Access=private)
        function obj = Transistor_IV()
            obj.loadPrefs;
        end
    end

    methods
        run(obj,status,managers,ax) % Main run method in separate file

        function dat = GetData(obj,stageManager,imagingManager)
            % Callback for saving methods
            meta = stageManager.position;
            dat.data = obj.data;
            dat.meta = obj.meta;
        end

        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function val = set_Vgs(obj,val,~)
            vals = str2num(val);
            assert(isvector(vals),'Vgs should evaluate to a vector')
            obj.vgs_vals = vals;
        end

        function val = set_Vds(obj,val,~)
            vals = str2num(val);
            assert(isvector(vals),'Vds should evaluate to a vector')
            obj.vds_vals = vals;
        end
    end
end
