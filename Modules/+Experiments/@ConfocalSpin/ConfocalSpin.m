classdef ConfocalSpin < Modules.Experiment
    %ConfocalSpin Use MW pulse to go to dark state at each pixel
    % Take confocal scan using ROI and npoints from active imaging device
    % Equipment initialized upon setting

    properties(SetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        n_avg = 1000;  % Per pixel
        MWfreq_GHz = 2.8;
        MWpower_dBm = 0;
        OpticalFreq_THz = 470.48;
        Pi_time_ns = 1000; % Pi pulse
        Repump_time_us = 10;
        Readout_time_ns = 100;
        buffer_time_ns = 500;  % Time between each pulse
        Res_Laser = 'None';
        Repump_Laser = 'None';
        MW_Source = 'None';
        APD_line = 0; % Index from 0
        nidaq = ''; % nidaq name
    end
    properties
        prefs = {'MWfreq_GHz','MWpower_dBm','OpticalFreq_THz','Pi_time_ns','Repump_time_us',...
            'Readout_time_ns','Res_Laser','Repump_Laser','MW_Source','APD_line','nidaq','buffer_time_ns'};
    end
    properties(SetAccess=private,Hidden)
        % Internal properties that should not be accessible by command line
        % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
        data = [] % Useful for saving data from run method
        abort_request = false; % Flag that will be set to true upon abort. Use in run method!
        % Hardware handles
        Res_LaserH
        Repump_LaserH
        MW_SourceH
        nidaqH
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = ConfocalSpin()
            % Constructor (should not be accessible to command line!)
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        run(obj,status,managers,ax) % Main run method in separate file
        ps = setup_PB_sequence(obj);

        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end

        function dat = GetData(obj,stageManager,imagingManager)
            % Callback for saving methods (note, lots more info in the two managers input!)
            dat.data = obj.data;
        end

        function [H,val,err] = attemptInstantiation(obj,prefix,val)
            err = [];
            try
                H = eval(sprintf('%s.%s.instance',prefix,val));
            catch err
                H = [];
                val = 'None';
            end
        end
        % Set methods allow validating property/pref set values
        function set.Res_Laser(obj,val)
            [H,val,err] = obj.attemptInstantiation('Sources',val);
            obj.Res_LaserH = H;
            obj.Res_Laser = val;
            if ~isempty(err)
                rethrow(err);
            end
        end
        function set.Repump_Laser(obj,val)
            [H,val,err] = obj.attemptInstantiation('Sources',val);
            obj.Repump_LaserH = H;
            obj.Repump_Laser = val;
            if ~isempty(err)
                rethrow(err);
            end
        end
        function set.MW_Source(obj,val)
            [H,val,err] = obj.attemptInstantiation('Sources',val);
            obj.MW_SourceH = H;
            obj.MW_Source = val;
            if ~isempty(err)
                rethrow(err);
            end
        end
        function set.nidaq(obj,val)
            try
                obj.nidaqH = Drivers.NIDAQ.dev.instance(val);
                obj.nidaq = val;
            catch err
                obj.nidaqH = [];
                obj.nidaq = '';
                rethrow(err);
            end
        end
    end
end
