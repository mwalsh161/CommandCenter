classdef OpticalSpinPolarization < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    %OpticalSpinPolarization measures the time dependence of the PLE signal

    properties(SetObservable,AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        APDline = 3;
        repumpTime_us = 1; %us
        resOffset_us = 0.1;
        resTime_us = 10;
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
        function obj = OpticalSpinPolarization()
            obj.prefs = [obj.prefs,{'resLaser','repumpLaser','APDline','repumpTime_us','resOffset_us',...
            'resTime_us'}]; %additional preferences not in superclass
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
                averagedData = squeeze(mean(obj.data.sumCounts,1, 'omitnan'))';
                meanError = squeeze(mean(obj.data.stdCounts,1, 'omitnan'))'*sqrt(obj.samples);
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
        
        function set.resTime_us(obj,val)
            %Note that order matters here; setting tauTimes first is
            %important in case of error
            obj.resTime_us = val;
            obj.counterDuration = obj.resTime_us / obj.nCounterBins - obj.counterSpacing;
            obj.tauTimes = linspace(0,obj.resTime_us-obj.counterDuration-obj.counterSpacing,obj.nCounterBins);
        end
    end
end
