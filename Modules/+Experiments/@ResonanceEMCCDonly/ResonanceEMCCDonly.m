classdef ResonanceEMCCDonly < Modules.Experiment
    % Resonance Description of experiment
    % Useful to list any dependencies here too

    properties(GetObservable,SetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        cameraEMCCD = Modules.Imaging.empty(1,0);
        EMCCD_binning = 1;
        EMCCD_exposure = 100;
        EMCCD_gain = 1200;
        
        percents = 'linspace(0,100,101)';
        tune_coarse = Prefs.Boolean(false,     'help_text', 'Whether to tune to the coarse value before the scan.');
        set_wavelength = 619; %nm
        scan_points = []; %frequency points, either in THz or in percents
        
        wavemeter_override = false;
        wavemeter_channel = 7;
        wavemeter = [];
        
        
        
    end
    
    properties(Constant)
%         vars = {'scan_points'}; %names of variables to be swept
    end
    
    properties
        prefs = {'percents', 'tune_coarse', 'set_wavelength', 'wavemeter_override','wavemeter_channel','resLaser', 'repumpLaser', 'cameraEMCCD','EMCCD_binning', 'EMCCD_exposure', 'EMCCD_gain'};  % String representation of desired prefs
        %show_prefs = {};   % Use for ordering and/or selecting which prefs to show in GUI
        %readonly_prefs = {}; % CC will leave these as disabled in GUI (if in prefs/show_prefs)
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
        data = [] % Useful for saving data from run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
    end
    
    properties
        ax1
        ax2
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = ResonanceEMCCDonly()
            % Constructor (should not be accessible to command line!)
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
            % Callback for saving methods (note, lots more info in the two managers input!)
            objdata = obj.data; % As to not delete obj.data.meta
            if isfield(obj.data,'meta')
                meta = obj.data.meta;
                objdata = rmfield(obj.data,'meta');
            end
            meta.percents = obj.percents;
            
            dat.data = objdata;
            dat.meta = meta;
        end
        
        function PreRun(obj,~,managers,ax)
            %prepare frequencies
%             obj.data.freqs_measured = NaN(obj.averages,length(obj.scan_points));
            %prepare axes for plotting
            %hold(ax,'on');
            subplot(ax);
            obj.ax1 = subplot(2, 1, 1);
            obj.ax2 = subplot(2, 1, 2);
            ax.UserData.plots = plotH;
            %hold(ax,'off');
            
            % center resonant laser range
            if obj.wavemeter_override
                obj.wavemeter = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu', obj.wavemeter_channel, false);
            end
            % center resonant laser range
            if obj.tune_coarse
                obj.resLaser.TuneCoarse(obj.set_wavelength);
            end

        end
        
        function set.percents(obj,val)
            numeric_vals = str2num(val); %#ok<ST2NM> str2num uses eval but is more robust for numeric input
            assert(~isempty(numeric_vals),'Must have at least one value for percents.');
            assert(min(numeric_vals)>=0&&max(numeric_vals)<=100,'Percents must be between 0 and 100 (inclusive).');
            obj.scan_points = numeric_vals;
            obj.percents = val;
        end

    end
end
