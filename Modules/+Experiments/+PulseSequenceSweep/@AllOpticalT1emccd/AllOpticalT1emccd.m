classdef AllOpticalT1emccd < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    %AllOpticalT1 Characterizes T1 by optically repumping then resonantly addressing with a swept time delay

    properties(SetObservable,AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        %
        cameraEMCCD = Modules.Imaging.empty(1,0);
        EMCCD_binning = 1;
        %EMCCD_exposure = 100;
        EMCCD_gain = 1200;
        EMCCD_trigger_line = 6;
        %
        APDline = 3;
        repumpTime_us = 1; %us
        resOffset_us = 0.1;
        resPulse1Time_us = 10;
        resPulse2Time_us = 10;
        tauTimes_us = 'linspace(0,100,101)'; %eval(tauTimes_us) will define sweepTimes
        sequenceduration = 0;
        cameraintegration = 0;
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
        function obj = AllOpticalT1emccd()
            obj.prefs = [obj.prefs,{'resLaser','repumpLaser','cameraEMCCD','EMCCD_trigger_line','EMCCD_binning','EMCCD_gain','APDline','repumpTime_us','resOffset_us',...
            'resPulse1Time_us','resPulse2Time_us','tauTimes_us'}]; %additional preferences not in superclass
            obj.loadPrefs;
        end
    end

    methods
        run(obj,status,managers,ax) % Main run method in separate file
        
        pulseSeq = BuildPulseSequence(obj,tauIndex) %Defined in separate file
        
        function PreRun(obj,~,~,ax)
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
            
            %set EMCCD
            obj.cameraEMCCD.binning = obj.EMCCD_binning;
            obj.cameraEMCCD.EMGain = obj.EMCCD_gain;
            
            obj.cameraEMCCD.load_external_trigger('C:\Program Files\Micro-Manager-1.4\Hamamatsu_externaltrigger.cfg');
            maxframes = length(obj.tauTimes)*2;
            obj.sequenceduration = (obj.repumpTime_us+obj.resOffset_us+obj.resPulse1Time_us+max(obj.tauTimes)+obj.resPulse2Time_us); %sequence duration in ms
            obj.cameraintegration = obj.sequenceduration*obj.samples*1e-3; %camera integration in ms
            obj.cameraEMCCD.exposure = obj.cameraintegration;
            obj.cameraEMCCD.start_triggered_acquisition(maxframes,0,0);
            
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
            
            drawnow;
        end
        
        function PostRun(obj,~,~,ax)
            obj.cameraEMCCD.stop_triggered_acquisition(); 
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
