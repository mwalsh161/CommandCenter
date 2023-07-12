classdef ResonantOpticalLifetime < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    %ResonantOpticalLifetime measures the lifetime of the emitter with
    %resonant excitation

    properties(GetObservable, SetObservable,AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        APDline = 3;
        repumpTime_us = 1; %us
        resOffset_us = 0.1;
        resTime_us = 10;
        measureTime = Prefs.Double(10, 'help', 'Total time to measure optical lifetime over', 'min', 0, 'units', 'us', 'set', 'set_measureTime');
        measureOffset = Prefs.Double(0.1, 'help', 'Delay tme between resonant and meaurement', 'min', 0, 'units', 'us');
    end
    properties
        placeHolderVariable = 1; %all APD bins are acquired in one shot, no variable is swept
        counterDuration = 0; %calculated in set.resTime_us
        tauTimes = 0; %calculated in set.resTime_us
    end
    properties(Constant)
        nCounterBins = 20; %number of APD bins for this pulse sequence (with more than 20 the PB errors)
        counterSpacing = 0.1; %spacing between APD bins
        vars = {'placeHolderVariable'}; %names of variables to be swept
    end
    methods(Static)
        obj = instance()
    end
    methods(Access=private)
        function obj = ResonantOpticalLifetime()
            obj.prefs = [obj.prefs,{'resLaser','repumpLaser','APDline','repumpTime_us','resOffset_us',...
            'resTime_us', 'measureOffset', 'measureTime'}]; %additional preferences not in superclass
            obj.loadPrefs;
        end
    end

    methods
        pulseSeq = BuildPulseSequence(obj,tauIndex) %Defined in separate file
        
        function PreRun(obj,~,managers,ax)
            %prepare axes for plotting
            hold(ax,'on');
            colors = lines(2);
            %plot data bin 1
            plotH{1} = errorfill(([1:obj.nCounterBins]-1)*(obj.counterDuration+obj.counterSpacing),...
                              squeeze(obj.data.sumCounts(1,1,:))',...
                              squeeze(obj.data.stdCounts(1,1,:))',...
                              'parent',ax,'color',colors(1,:));
            ylabel(ax,'Intensity (a.u.)');
            xlabel(ax,'Delay time (\mus)');
            
            % Store for UpdateRun
            ax.UserData.plots = plotH;
            hold(ax,'off');
            set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')
        end
        function UpdateRun(obj,~,~,ax,~,~)
            if obj.averages > 1
                averagedData = squeeze(nanmean(obj.data.sumCounts,1))';
                meanError = squeeze(nanmean(obj.data.stdCounts,1))'*sqrt(obj.samples);
            else
                averagedData = obj.data.sumCounts;
                meanError = obj.data.stdCounts;
            end
            
            %grab handles to data from axes plotted in PreRun
            ax.UserData.plots{1}.YData = averagedData(1,:);
            ax.UserData.plots{1}.YNegativeDelta = meanError(1,:);
            ax.UserData.plots{1}.YPositiveDelta = meanError(1,:);
            ax.UserData.plots{1}.update;
            drawnow limitrate;
        end
        
        function val = set_measureTime(obj,val,~)
            %Note that order matters here; setting tauTimes first is
            %important in case of error
            obj.counterDuration = val / obj.nCounterBins - obj.counterSpacing;
            obj.tauTimes = linspace(0,val-obj.counterDuration-obj.counterSpacing,obj.nCounterBins);
        end
    end
end
