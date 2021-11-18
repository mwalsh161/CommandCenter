classdef TransitionRatesCounter < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    %OpticalSpinPolarization measures the time dependence of the PLE signal

    properties(SetObservable,GetObservable, AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        APDline = 3;
        repumpTime_us = 1; %us
        resOffset_us = 0.1;
        resTime_us = 10;
        
        resLaserPower_ang = 0; % angle on filter wheel, might need to calibrate the corresponding laser power
        repumpLaserPower_mW = 1;
        
        resLaserPower_range = 'linspace(0,180,101)';
        repumpLaserPower_range = 'linspace(0.1,10,101)';
        
    end
    properties
        placeHolderVariable = 1; %all APD bins are acquired in one shot, no variable is swept
        counterDuration = 0; %calculated in set.resTime_us
    end
    properties(Constant)
        nCounterBins = 1; %number of APD bins for this pulse sequence (with more than 20 the PB errors)
        counterSpacing = 0.1; %spacing between APD bins
        vars = {'resLaserPower_range', 'repumpLaserPower_range'}; %names of variables to be swept
        
    end
    methods(Static)
        obj = instance()
    end
    methods(Access=private)
        function obj = TransitionRatesCounter()
            obj.prefs = [obj.prefs,{'resLaser','APDline','repumpTime_us','repumpLaser','resOffset_us',...
            'resTime_us', 'resLaserPower_ang', 'repumpLaserPower_mW', 'resLaserPower_range', 'repumpLaserPower_range'}]; %additional preferences not in superclass
            obj.loadPrefs;
        end
    end

    methods
        pulseSeq = BuildPulseSequence(obj) %Defined in separate file
        
        function PreRun(obj,~,~,ax)
            obj.repumpLaser.on
            %prepare axes for plotting
            hold(ax,'on');
% %             colors = lines(2);
%             %plot data bin 1
            resLaser_range = eval(obj.resLaserPower_range);
            for i = 1 : length(resLaser_range)
                plotH{i} = plot(obj.data.APDCounts(:,i),'parent',ax);
            end
            ylabel(ax,'Counts');
            xlabel(ax,'APD Bins');

%             % Store for UpdateRun
            ax.UserData.plots = plotH;
            hold(ax,'off');
            set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')
        end
        function UpdateRun(obj,~,~,ax,~,~)
%             if obj.averages > 1
%                 averagedData = squeeze(nanmean(obj.data.sumCounts,1))';
%                 meanError = squeeze(nanmean(obj.data.stdCounts,1))'*sqrt(obj.samples);
%             else
%             averagedData = obj.data.sumCounts;
%             meanError = obj.data.stdCounts;
%             end
            
            %grab handles to data from axes plotted in PreRun
            for i = 1 : length(eval(obj.resLaserPower_range))
                ax.UserData.plots{i}.YData = obj.data.APDCounts(:,i);
                drawnow limitrate;
            end        
        end
        
        function set.resTime_us(obj,val)
            obj.resTime_us = val;
            obj.counterDuration = obj.resTime_us / obj.nCounterBins - obj.counterSpacing;
        end
    end
end
