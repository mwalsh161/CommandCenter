classdef Open < Experiments.SlowScan.SlowScan_invisible
    %Open Open-loop laser sweep for slowscan
    % Set center freq_THz
    % Center of sweep is 50 percent (freq_THz might not be *exact* 50% in
    % actual experiment.
    %
    % NOTE: plotting averages over average loop, which might not be same
    % frequencies, or even close if laser mode hops. All averages are saved.

    properties(SetObservable,AbortSet)
        freq_THz = 470;
        tune_coarse = true;
        percents = 'linspace(0,100,101)'; %eval(percents) will define percents for open-loop scan [scan_points]
    end
    properties 
        resonatorInitialPosition = 50;
    end
    properties(Constant)
        xlabel = 'Percent (%)';
    end
    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = Open()
            obj.scan_points = eval(obj.percents);
            obj.prefs = [{'freq_THz','tune_coarse','percents'}, obj.prefs];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end
    
    methods
        function s = BuildPulseSequence(obj,freqIndex)
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            tunePoint = obj.scan_points(freqIndex) - (50-obj.resonatorInitialPosition);
            s = false;
            if tunePoint < 0 || tunePoint > 100
                return % Skip point by returning false
            end
            obj.resLaser.TunePercent(tunePoint);
            s = BuildPulseSequence@Experiments.SlowScan.SlowScan_invisible(obj,freqIndex);
        end
        function PreRun(obj,~,managers,ax)
            if obj.tune_coarse
                obj.resLaser.TuneCoarse(obj.freq_THz);
                obj.resonatorInitialPosition = obj.resLaser.GetPercent;
            else
                obj.resonatorInitialPosition = 50;
            end
            PreRun@Experiments.SlowScan.SlowScan_invisible(obj,[],managers,ax);
        end  
        function set.percents(obj,val)
            obj.scan_points = str2num(val); %#ok<ST2NM> str2num uses eval but is more robust for numeric input
            obj.percents = val;
        end
    end
end
