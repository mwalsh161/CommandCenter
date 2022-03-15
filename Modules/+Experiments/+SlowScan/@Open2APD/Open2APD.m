classdef Open2APD < Experiments.SlowScan.SlowScan_invisible
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
        tune_coarse =           Prefs.Boolean(true,     'help_text', 'Whether to tune to the coarse value before the scan.');
        center_scan =           Prefs.Boolean(false,    'help_text', 'When true, percents will be shifted after tune_coarse completes to compensate position of percent.');
        post_scan_tune_max =    Prefs.Boolean(true,     'help_text', 'Whether to tune to the maximum value after the scan has completed.');
    end
    properties(SetObservable,AbortSet)
        freq_THz =      470;
        percents =      'linspace(0,100,101)'; %eval(percents) will define percents for open-loop scan [scan_points]
        APD2line = 5;
        nAPDlines = 2;
%         nCounterBins = 2;
    end
    properties(SetAccess=private,Hidden)
        percentInitialPosition = 50; % used to center scan if user wants
    end
    properties(Constant)
%         nCounterBins = 1;
        xlabel = 'Percent (%)';
    end
    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = Open2APD()
            obj.scan_points = eval(obj.percents);
            obj.prefs = [{'freq_THz','center_scan','tune_coarse','post_scan_tune_max','percents','APD2line'}, obj.prefs];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end
    
    methods
        run(obj,status,managers,ax) % Main run method in separate file
        
        function s = BuildPulseSequence(obj,freqIndex)
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            tunePoint = obj.scan_points(freqIndex);
            if obj.center_scan
                tunePoint = tunePoint - (50-obj.percentInitialPosition);
                % Only allow skipping points if center_scan enabled;
                % otherwise user entered a bad range for percents should error
                if tunePoint < 0 || tunePoint > 100
                    s = false;
                    return % Skip point by returning false
                end
            end
            obj.resLaser.TunePercent(tunePoint);
            %s = BuildPulseSequence@Experiments.SlowScan.SlowScan_invisible(obj,freqIndex);
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            if freqIndex > 1
                s = obj.sequence;
            else
                s = sequence('SlowScan'); %#ok<CPROPLC> Calling HelperFunction
                repumpChannel = channel('Repump','color','g','hardware',obj.repumpLaser.PB_line-1);
                resChannel = channel('Resonant','color','r','hardware',obj.resLaser.PB_line-1);
                APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
                APDchannel2 = channel('APD2gate','color','b','hardware',obj.APD2line-1,'counter','APD2');
                s.channelOrder = [repumpChannel, resChannel, APDchannel APDchannel2];
                g = node(s.StartNode,repumpChannel,'units','us','delta',0);
                g = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);
                r = node(g,resChannel,'units','us','delta',obj.resOffset_us);
                node(r,APDchannel,'units','us','delta',0);
                node(r,APDchannel2,'units','us','delta',0);
                r = node(r,resChannel,'units','us','delta',obj.resTime_us);
                node(r,APDchannel,'units','us','delta',0);
                node(r,APDchannel2,'units','us','delta',0);                
                obj.sequence = s;
            end
        end
        function PreRun(obj,~,managers,ax)
            if obj.tune_coarse
                obj.resLaser.TuneCoarse(obj.freq_THz);
            end
            obj.percentInitialPosition = obj.resLaser.GetPercent;
            
            %prepare frequencies
            obj.data.freqs_measured = NaN(obj.averages,length(obj.scan_points));
            if obj.wavemeter_override
                obj.wavemeter = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu', obj.wavemeter_channel, false);
            end
            %prepare axes for plotting
            hold(ax,'on');
            %plot data
%             subplot(1,2,1)
            yyaxis(ax,'left');
            colors = lines(2);
            % plot signal
            plotH{1} = plot(obj.scan_points,obj.data.data1.sumCounts(1,:,1),'parent',ax);
            plotH{3} = plot(obj.scan_points,obj.data.data2.sumCounts(1,:,1),'parent',ax);
            ylabel(ax,'Intensity (a.u.)');
            yyaxis(ax,'right');
            plotH{2} = plot(ax,obj.scan_points,obj.data.freqs_measured(1,:),'parent',ax);
            ylabel(ax,'Measured Frequency (THz)');
            xlabel(ax,obj.xlabel); %#ok<CPROPLC>
%             subplot(1,2,2)
                          
            % Store for UpdateRun
            ax.UserData.plots = plotH;
            hold(ax,'off');
            set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')
        end
        function UpdateRun(obj,~,~,ax,average,freqIndex)
            %pull frequency that latest sequence was run at
            if obj.wavemeter_override
                try
                    obj.wavemeter.SetSwitcherSignalState(obj.wavemeter_channel);
                catch
                end
                obj.data.freqs_measured(average,freqIndex) = obj.wavemeter.getFrequency;
            else
                obj.data.freqs_measured(average,freqIndex) = obj.resLaser.getFrequency;
            end
            
            if obj.averages > 1
                averagedData1 = squeeze(nanmean(obj.data.data1.sumCounts,3));
                averagedData2 = squeeze(nanmean(obj.data.data2.sumCounts,3));
            else
                averagedData1 = obj.data.data1.sumCounts;
                averagedData2 = obj.data.data2.sumCounts;
            end
            
            %grab handles to data from axes plotted in PreRun
            ax.UserData.plots{1}.YData = averagedData1(1,:);
            ax.UserData.plots{2}.YData = nanmean(obj.data.freqs_measured,1);
            ax.UserData.plots{3}.YData = averagedData2(1,:);

            drawnow limitrate;
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
        function set.percents(obj,val)
            numeric_vals = str2num(val); %#ok<ST2NM> str2num uses eval but is more robust for numeric input
            assert(~isempty(numeric_vals),'Must have at least one value for percents.');
            assert(min(numeric_vals)>=0&&max(numeric_vals)<=100,'Percents must be between 0 and 100 (inclusive).');
            obj.scan_points = numeric_vals;
            obj.percents = val;
        end
    end
end
