classdef AllOpticalT1EOM < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    %AllOpticalT1 Characterizes T1 by optically repumping then resonantly addressing with a swept time delay

    properties(SetObservable,AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        MWSource_init = Modules.Source.empty(1,0);
        MWSource_read = Modules.Source.empty(1,0);
        MW_freq_MHz_init = 2000;
        MW_freq_MHz_read = 2000;
        MW_power_dBm_init = -4;
        MW_power_dBm_read = -3;
        
        MWline = 4;
        APDline = 3;
        repumpTime_us = 1; %us
        resOffset_us = 0.1;
        resPulse1Time_us = 10;
        resPulse2Time_us = 10;
        tauTimes_us = 'linspace(0,100,101)'; %eval(tauTimes_us) will define sweepTimes
    end
    properties
        tauTimes = linspace(0,100,101); %will be in us
    end
    properties(Constant)
        nCounterBins = 2; %number of APD bins for this pulse sequence
        vars = {'tauTimes'}; %names of variables to be swept
    end
    methods(Static)
        obj = instance()
    end
    methods(Access=private)
        function obj = AllOpticalT1EOM()
            obj.prefs = [obj.prefs,{'resLaser','repumpLaser','MWSource_init', 'MWSource_read','MW_freq_MHz_init', 'MW_freq_MHz_read','MW_power_dBm_init','MW_power_dBm_read','MWline','APDline','repumpTime_us','resOffset_us',...
            'resPulse1Time_us','resPulse2Time_us','tauTimes_us'}]; %additional preferences not in superclass
            obj.loadPrefs;
        end
    end

    methods
        pulseSeq = BuildPulseSequence(obj,tauIndex) %Defined in separate file
        
        function PreRun(obj,~,~,ax)
            obj.MWSource_init.set_frequency(obj.MW_freq_MHz_init);
            obj.MWSource_read.set_frequency(obj.MW_freq_MHz_read);
            obj.MWSource_init.set_power(obj.MW_power_dBm_init);
            obj.MWSource_read.set_power(obj.MW_power_dBm_read);
            obj.MWSource_init.source_on = 1; % still need to find out which state is which generator
                
%             %prepare axes for plotting
%             hold(ax,'on');
%             %plot data bin 1
%             plotH = plot(ax,obj.tauTimes,obj.data.sumCounts(:,1,1),'color','b');
%             %plot data bin 1 errors
%             plotH(2) = plot(ax,obj.tauTimes,obj.data.sumCounts(:,1,1)+obj.data.stdCounts(:,1,1),'color',[1 .5 0],'LineStyle','--'); %upper bound
%             plotH(3) = plot(ax,obj.tauTimes,obj.data.sumCounts(:,1,1)-obj.data.stdCounts(:,1,1),'color',[1 .5 0],'LineStyle','--'); %lower bound
%             %plot data bin 2
%             plotH(4) = plot(ax,obj.tauTimes,obj.data.sumCounts(:,2,1),'color','b');
%             %plot data bin 2 errors
%             plotH(5) = plot(ax,obj.tauTimes,obj.data.sumCounts(:,2,1)+obj.data.stdCounts(:,2,1),'color',[1 .5 0],'LineStyle','--'); %upper bound
%             plotH(6) = plot(ax,obj.tauTimes,obj.data.sumCounts(:,2,1)-obj.data.stdCounts(:,2,1),'color',[1 .5 0],'LineStyle','--'); %lower bound
%             ax.UserData.plots = plotH;
%             ylabel(ax,'Normalized PL');
%             xlabel(ax,'Delay Time \tau (\mus)');
%             hold(ax,'off');
%             set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')
        end
        
        function UpdateRun(obj,~,~,ax,~,~)
            if obj.averages > 1
                averagedData = squeeze(nanmean(obj.data.sumCounts,3));
                meanError = squeeze(nanmean(obj.data.stdCounts,3));
            else
                averagedData = obj.data.sumCounts;
                meanError = obj.data.stdCounts;
            end
            
            %grab handles to data from axes plotted in PreRun
            ax.UserData.plots(1).YData = averagedData(:,1);
            ax.UserData.plots(2).YData = averagedData(:,1) + meanError(:,1);
            ax.UserData.plots(3).YData = averagedData(:,1) - meanError(:,1);
            ax.UserData.plots(4).YData = averagedData(:,2);
            ax.UserData.plots(5).YData = averagedData(:,2) + meanError(:,2);
            ax.UserData.plots(6).YData = averagedData(:,2) - meanError(:,2);
            drawnow;
        end
        
        function set.tauTimes_us(obj,val)
            %Note that order matters here; setting tauTimes first is
            %important in case of error
            tempvals = eval(val);
            obj.tauTimes = tempvals;
            obj.tauTimes_us = val;
        end
    end
end
