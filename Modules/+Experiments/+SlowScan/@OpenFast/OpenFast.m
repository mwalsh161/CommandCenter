classdef OpenFast < Experiments.SlowScan.SlowScan_invisible
    %Open Open-loop laser sweep for slowscan
    % Set center freq_THz
    % Sweeps over percents (usually corresponding to a piezo in a resonator)
    %   - If tune_coarse = true, first moves laser to that frequency;
    %   otherwise scan is perfomed wherever the laser is
    %   - If center_scan = true, percents are relative to wherever the
    %   initial percentage is prior to starting sweep. This can be quite
    %   useful in combination with tune_coarse for lasers that don't leave
    %   the percent centered at 50 after tuning.
    %
    % NOTE: plotting averages over average loop, which might not be same
    % frequencies, or even close if laser mode hops. All averages are saved.

    properties(SetObservable,AbortSet)
        freq_THz = 470;
        tune_coarse = false;
        center_scan = false; % When true, percents will be shifted after tune_coarse completes to compensate position of percent
        percents = 'linspace(0,100,101)'; %eval(percents) will define percents for open-loop scan [scan_points]
        solstisDriver = Drivers.msquared.solstis.empty(1,0);
        scan_points_initial = [];
        scan_points_correction = 0;
    end
    properties(SetAccess=private,Hidden)
        percentInitialPosition = 50; % used to center scan if user wants
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
        function obj = OpenFast()
            obj.scan_points = eval(obj.percents);
            obj.prefs = [{'freq_THz','center_scan','tune_coarse','percents'}, obj.prefs];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end
    
    methods
        function s = BuildPulseSequence(obj,freqIndex)
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            tunePoint = obj.scan_points(freqIndex) + obj.scan_points_correction;
%             if obj.center_scan
%                 tunePoint = tunePoint - (50-obj.percentInitialPosition);
%                 % Only allow skipping points if center_scan enabled;
%                 % otherwise user entered a bad range for percents should error
%                 if tunePoint < 0 || tunePoint > 100
%                     s = false;
%                     return % Skip point by returning false
%                 end
%             end
            %obj.resLaser.TunePercent(tunePoint);
            %obj.solstisDriver.set_resonator_percent(tunePoint);
            assert(tunePoint>=0 && tunePoint<=100, 'Resonator percent must be between 0 and 100');
            obj.solstisDriver.com('set_resonator_val',tunePoint);
            s = BuildPulseSequence@Experiments.SlowScan.SlowScan_invisible(obj,freqIndex);
        end
        function PreRun(obj,~,managers,ax)
            %obj.solstisDriver = obj.resLaser.solstisHandle;
            obj.solstisDriver = Drivers.msquared.solstis;
            obj.scan_points_initial = obj.scan_points;
            if obj.tune_coarse
                obj.resLaser.TuneCoarse(obj.freq_THz);
            end
            obj.percentInitialPosition = obj.resLaser.GetPercent;
            %
%             if obj.center_scan
%                 obj.scan_points = obj.scan_points - mean(obj.scan_points) + obj.percentInitialPosition;
%                 if min(obj.scan_points)<0
%                     obj.scan_points = obj.scan_points + abs(min(obj.scan_points));
%                 elseif max(obj.scan_points)>100
%                 	obj.scan_points = obj.scan_points - (max(obj.scan_points)-100);
%                 end
%             end
            %
            if obj.center_scan
                obj.scan_points_correction = obj.percentInitialPosition - mean(obj.scan_points);
                if min(obj.scan_points+obj.scan_points_correction)<0
                    obj.scan_points_correction = obj.scan_points_correction + abs(min(obj.scan_points+obj.scan_points_correction));
                elseif max(obj.scan_points+obj.scan_points_correction)>100
                	obj.scan_points_correction = obj.scan_points_correction - (max(obj.scan_points+obj.scan_points_correction)-100);
                end
            else
                obj.scan_points_correction = 0;
            end
            %
            obj.resLaser.TunePercent(obj.scan_points(1)+obj.scan_points_correction);
            PreRun@Experiments.SlowScan.SlowScan_invisible(obj,[],managers,ax);
        end
        function PostRun(obj,~,~,~)
            obj.scan_points = obj.scan_points_initial;
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
