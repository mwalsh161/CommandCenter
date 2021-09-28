classdef Transistor_IV < Modules.Experiment
    % CMOS_Rabi Performs a rabi measurement with a MW drive, and a
    % single laser to initialize and readout

    properties(SetObservable,AbortSet)
        % Modules
        Vgs_Power_Supply = Prefs.ModuleInstance('help_text','Power supply for gate voltage');
        Vgs_channel = Prefs.Integer(1,'help_text','Channel to use on Vgs power supply','min',1)
        Vds_Power_Supply = Prefs.ModuleInstance('help_text','Power supply for drain voltage');
        Vds_channel = Prefs.Integer(1,'help_text','Channel to use on Vds power supply','min',1)

        % Sweep parameters
        Vgs = Prefs.String('help_text','Evaluates to voltages to apply to the gate','units','V','set','set_Vgs');
        Vds = Prefs.String('help_text','Evaluates to voltages to apply to the drain','units','V','set','set_Vds');

        % Cosmetic
        x_axis_is_Vgs = Prefs.Boolean(false, 'help_text','Whether to plot Vgs or Vds on x-axis (sweep of the other value will show up as multiple lines)')
    end
    properties
        prefs = {'Vds','Vgs','x_axis_is_Vgs','Vds_Power_Supply','Vds_channel','Vgs_Power_Supply','Vgs_channel'}
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

        function val = set_Vgs(val,~)
            vals = str2num(val);
            assert(isvector(vals),'Vgs should evaluate to a vector')
            vgs_vals = vals;
            val = vals;
        end

        function val = set_Vds(val,~)
            vals = str2num(val);
            assert(isvector(vals),'Vds should evaluate to a vector')
            vds_vals = vals;
            val = vals;
        end
    end
end
