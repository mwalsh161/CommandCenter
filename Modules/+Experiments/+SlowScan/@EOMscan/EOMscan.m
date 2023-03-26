classdef EOMscan < Experiments.SlowScan.SlowScan_invisible
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

    properties(SetObservable,GetObservable,AbortSet)
        tune_coarse =           Prefs.Boolean(false,     'help_text', 'Whether to tune to the coarse value before the scan.');
        center_scan =           Prefs.Boolean(false,    'help_text', 'When true, percents will be shifted after tune_coarse completes to compensate position of percent.');
        post_scan_tune_max =    Prefs.Boolean(false,     'help_text', 'Whether to tune to the maximum value after the scan has completed.');
        invert_MW_line =    Prefs.Boolean(false,     'help_text', '.');
    end
    properties(SetObservable,AbortSet)
        laser_freq_THz =      470;
        MW_freq_MHz =      'linspace(0,100,101)'; %eval(percents) will define percents for open-loop scan [scan_points]
        MWsource = Modules.Source.empty(1,0);
    end
    properties(SetAccess=private,Hidden)
        percentInitialPosition = 50; % used to center scan if user wants
    end
    properties(Constant)
        xlabel = 'Modulation Frequency (MHz)';
    end
    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = EOMscan()
            obj.scan_points = eval(obj.MW_freq_MHz);
            obj.prefs = [{'MWsource','laser_freq_THz','post_scan_tune_max','MW_freq_MHz','invert_MW_line'}, obj.prefs];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end
    
    methods
        function s = BuildPulseSequence(obj,freqIndex)
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            tunePoint = obj.scan_points(freqIndex);
%             if obj.center_scan
%                 tunePoint = tunePoint - (50-obj.percentInitialPosition);
%                 % Only allow skipping points if center_scan enabled;
%                 % otherwise user entered a bad range for percents should error
%                 if tunePoint < 0 || tunePoint > 100
%                     s = false;
%                     return % Skip point by returning false
%                 end
%             end
%             obj.resLaser.TunePercent(tunePoint);
            obj.MWsource.set_frequency(tunePoint);
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            if freqIndex > 1
                s = obj.sequence;
            else
                s = sequence('EOMscan'); %#ok<CPROPLC> Calling HelperFunction
                repumpChannel = channel('Repump','color','g','hardware',obj.repumpLaser.PB_line-1);
                resChannel = channel('Resonant','color','r','hardware',obj.resLaser.PB_line-1);
                MWChannel = channel('MW','color','k','hardware',obj.MWsource.PB_line-1);
                APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
                s.channelOrder = [repumpChannel, resChannel, MWChannel, APDchannel];
                g = node(s.StartNode,repumpChannel,'units','us','delta',0);
                if obj.invert_MW_line
                    node(g,MWChannel,'units','us','delta',0);
                end
                g = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);
                r = node(g,resChannel,'units','us','delta',obj.resOffset_us);
                node(r,MWChannel,'units','us','delta',0);
                node(r,APDchannel,'units','us','delta',0);
                r = node(r,resChannel,'units','us','delta',obj.resTime_us);
                node(r,MWChannel,'units','us','delta',0);
                node(r,APDchannel,'units','us','delta',0);
                
                obj.sequence = s;
            end
        end
        function PreRun(obj,~,managers,ax)
            if obj.tune_coarse
                obj.resLaser.TuneCoarse(obj.laser_freq_THz);
            end
            %obj.percentInitialPosition = obj.resLaser.GetPercent;
            PreRun@Experiments.SlowScan.SlowScan_invisible(obj,[],managers,ax);
        end  
        function PostRun(obj,~,managers,ax)
            if obj.post_scan_tune_max
                x = obj.data.freqs_measured;
                y = obj.data.sumCounts;

                % Find the frequency of the maximum value.
                arg = find(y == nanmax(y));
                if isempty(arg)
                    target_max = NaN;
                else
                    target_max = x(arg(1));
                end
                
                obj.meta.post_scan_freq_max = target_max;
                obj.resLaser.tune(obj.resLaser.c/target_max);
            end
        end
        function set.MW_freq_MHz(obj,val)
            numeric_vals = str2num(val); %#ok<ST2NM> str2num uses eval but is more robust for numeric input
            assert(~isempty(numeric_vals),'Must have at least one value for percents.');
            obj.scan_points = numeric_vals(:);
            obj.MW_freq_MHz = val;
        end
    end
end
