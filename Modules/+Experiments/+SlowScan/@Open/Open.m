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
            
            %set resonant laser frequency and read result
            obj.resLaser.TunePercent(obj.scan_points(freqIndex));
            s = BuildPulseSequence@Experiments.SlowScan.SlowScan_invisible(obj,freqIndex);
        end
        function prep_plot(obj,ax)
            if obj.tune_coarse
                obj.resLaser.TuneCoarse(obj.freq_THz);
            end
            
            yyaxis(ax,'left');
            % plot signal
            plotH = plot(ax,obj.scan_points,obj.data.meanCounts(1,:,1),'color','b');
            % plot errors
            plotH(2) = plot(ax,obj.scan_points,obj.data.meanCounts(1,:,1)+obj.data.stdCounts(1,:,1),'color',[1 .5 0],'LineStyle','--'); %upper bound
            plotH(3) = plot(ax,obj.scan_points,obj.data.meanCounts(1,:,1)-obj.data.stdCounts(1,:,1),'color',[1 .5 0],'LineStyle','--'); %lower bound
            ylabel(ax,'Intensity');
            yyaxis(ax,'right');
            plotH(4) = plot(ax,obj.scan_points,obj.data.freqs_measured(1,:),'color','r');

            xlabel(ax,'Scan Percentage');
            % Store for UpdateRun
            ax.UserData.plots = plotH;
        end
        function update_plot(obj,ax,ydata,std)
            %grab handles to data from axes plotted in PreRun
            ax.UserData.plots(1).YData = ydata(1,:);
            ax.UserData.plots(2).YData = ydata(1,:) + std(1,:);
            ax.UserData.plots(3).YData = ydata(1,:) - std(1,:);
            ax.UserData.plots(4).YData = nanmean(obj.data.freqs_measured,1);
            drawnow limitrate;
        end
        
        function set.percents(obj,val)
            obj.scan_points = eval(val);
            obj.percents = val;
        end
    end
end
