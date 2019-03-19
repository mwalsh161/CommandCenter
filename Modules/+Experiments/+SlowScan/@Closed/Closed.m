classdef Closed < Experiments.SlowScan.SlowScan_invisible
    %Closed Closed-loop laser sweep for slowscan
    % Set freqs_THz, locks laser to each position (still records measured
    % value, but should be within resolution of the laser

    properties(SetObservable,AbortSet)
        freqs_THz = '470+linspace(-10,10,101)'; %eval(freqs_THz) will define freqs [scan_points]
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = Closed()
            obj.scan_points = eval(obj.freqs_THz);
            obj.prefs = [{'freqs_THz'}, obj.prefs];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        function s = BuildPulseSequence(obj,freqIndex)
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            
            %set resonant laser frequency and read result
            obj.resLaser.TuneSetpoint(obj.scan_points(freqIndex));
            s = BuildPulseSequence@Experiments.SlowScan.SlowScan_invisible(obj,freqIndex);
        end
        function prep_plot(obj,ax)
            % Tune to first point in preparation
            obj.resLaser.TuneCoarse(obj.scan_points(1));
            % plot signal
            plotH = plot(ax,obj.scan_points,obj.data.meanCounts(:,1,1),'color','b');
            % plot errors
            plotH(2) = plot(ax,obj.scan_points,obj.data.meanCounts(:,1,1)+obj.data.stdCounts(:,1,1),'color',[1 .5 0],'LineStyle','--'); %upper bound
            plotH(3) = plot(ax,obj.scan_points,obj.data.meanCounts(:,1,1)-obj.data.stdCounts(:,1,1),'color',[1 .5 0],'LineStyle','--'); %lower bound
            
            ylabel(ax,'Intensity');
            xlabel(ax,'Frequency (THz)');
            % Store for UpdateRun
            ax.UserData.plots = plotH;
        end
        function update_plot(obj,ax,ydata,std)
            %grab handles to data from axes plotted in PreRun
            ax.UserData.plots(1).YData = ydata(:,1);
            ax.UserData.plots(2).YData = ydata(:,1) + std(:,1);
            ax.UserData.plots(3).YData = ydata(:,1) - std(:,1);
            drawnow limitrate;
        end
        
        function set.freqs_THz(obj,val)
            obj.scan_points = eval(val);
            obj.freqs_THz = val;
        end
    end
end
