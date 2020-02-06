classdef WidefieldSlowScan_invisible < Modules.Experiment
    % subclasses must create:
    % prep_plot(ax) [called in PreRun]:
    %   Populates the supplied axes (already held) and adds axes labels
    % update_plot(ydata) [called in UpdateRun]
    %   Given the calculated ydata, update plots generated in prep_plot

    properties(SetObservable,AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        imaging = Modules.Imaging.empty(1,0);
    end
    properties
        scan_points = []; %frequency points, either in THz or in percents
    end
    properties(Constant)
        % Required by PulseSequenceSweep_invisible
        vars = {'scan_points'}; %names of variables to be swept
    end

    properties(Abstract,Constant)
        xlabel; % For plotting data
    end
    methods
        function obj = WidefieldSlowScan_invisible()
            obj.prefs = [obj.prefs,{'resLaser','repumpLaser','imaging','repumpTime_us','resOffset_us','resTime_us'}]; %additional preferences not in superclass
        end
        
        function PreRun(obj,~,managers,ax)
            %prepare frequencies
            obj.data.freqs_measured = NaN(obj.averages,length(obj.scan_points));
            %prepare axes for plotting
            hold(ax,'on');
            %plot data
            yyaxis(ax,'left');
            colors = lines(2);
            % plot signal
            plotH{1} = errorfill(obj.scan_points,...
                              obj.data.sumCounts(1,:,1),...
                              obj.data.stdCounts(1,:,1),...
                              'parent',ax,'color',colors(1,:));
            ylabel(ax,'Intensity (a.u.)');
            yyaxis(ax,'right');
            plotH{2} = plot(ax,obj.scan_points,obj.data.freqs_measured(1,:),'color',colors(2,:));
            ylabel(ax,'Measured Frequency (THz)');
            xlabel(ax,obj.xlabel); %#ok<CPROPLC>
            
            % Store for UpdateRun
            ax.UserData.plots = plotH;
            hold(ax,'off');
            set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')
        end
        function UpdateRun(obj,~,~,ax,average,freqIndex)
            %pull frequency that latest sequence was run at
            obj.data.freqs_measured(average,freqIndex) = obj.resLaser.getFrequency;
            
            if obj.averages > 1
                averagedData = squeeze(nanmean(obj.data.sumCounts,3));
                meanError = squeeze(nanmean(obj.data.stdCounts,3))*sqrt(obj.samples);
            else
                averagedData = obj.data.sumCounts;
                meanError = obj.data.stdCounts*sqrt(obj.samples);
            end
            
            %grab handles to data from axes plotted in PreRun
            ax.UserData.plots{1}.YData = averagedData(1,:);
            ax.UserData.plots{1}.YNegativeDelta = meanError(1,:);
            ax.UserData.plots{1}.YPositiveDelta = meanError(1,:);
            ax.UserData.plots{1}.update;
            ax.UserData.plots{2}.YData = nanmean(obj.data.freqs_measured,1);
            drawnow limitrate;
        end
    end
end
