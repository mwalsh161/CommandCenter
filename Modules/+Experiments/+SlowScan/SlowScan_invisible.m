classdef SlowScan_invisible < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    % subclasses must create:
    % prep_plot(ax) [called in PreRun]:
    %   Populates the supplied axes (already held) and adds axes labels
    % update_plot(ydata) [called in UpdateRun]
    %   Given the calculated ydata, update plots generated in prep_plot

    properties(SetObservable,AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        APDline = 1;  % Indexed from 1
        repumpTime_us = 1; %us
        resOffset_us = 0.1;
        resTime_us = 0.1;
        wavemeter_override = false;
        wavemeter_channel = 1;
        wavemeter = [];
    end
    properties
        scan_points = []; %frequency points, either in THz or in percents
        sequence; %for keeping same sequence from step to step
    end
    properties(Constant)
        % Required by PulseSequenceSweep_invisible
        nCounterBins = 1; %number of APD bins for this pulse sequence
        vars = {'scan_points'}; %names of variables to be swept
    end

    properties(Abstract,Constant)
        xlabel; % For plotting data
    end
    methods
        function obj = SlowScan_invisible()
            obj.path = 'APD1';
            obj.prefs = [obj.prefs,{'resLaser','repumpLaser','APDline','repumpTime_us','resOffset_us','resTime_us','wavemeter_override','wavemeter_channel'}]; %additional preferences not in superclass
        end
        function s = BuildPulseSequence(obj,freqIndex)
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            if freqIndex > 1
                s = obj.sequence;
            else
                s = sequence('SlowScan'); %#ok<CPROPLC> Calling HelperFunction
                repumpChannel = channel('Repump','color','g','hardware',obj.repumpLaser.PB_line-1);
                resChannel = channel('Resonant','color','r','hardware',obj.resLaser.PB_line-1);
                APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
                s.channelOrder = [repumpChannel, resChannel, APDchannel];
                g = node(s.StartNode,repumpChannel,'units','us','delta',0);
                g = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);
                r = node(g,resChannel,'units','us','delta',obj.resOffset_us);
                node(r,APDchannel,'units','us','delta',0);
                r = node(r,resChannel,'units','us','delta',obj.resTime_us);
                node(r,APDchannel,'units','us','delta',0);
                
                obj.sequence = s;
            end
        end
        
        function PreRun(obj,~,managers,ax)
            %prepare frequencies
            obj.data.freqs_measured = NaN(obj.averages,length(obj.scan_points));
            if obj.wavemeter_override
                obj.wavemeter = Drivers.Wavemeter.instance('qplab-hwserver.mit.edu', obj.wavemeter_channel, false);
            end
            %prepare axes for plotting
            hold(ax,'off');
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
            if obj.wavemeter_override
                %obj.wavemeter.SetSwitcherSignalState(obj.wavemeter_channel);
                obj.data.freqs_measured(average,freqIndex) = obj.wavemeter.getFrequency;
            else
                obj.data.freqs_measured(average,freqIndex) = obj.resLaser.getFrequency;
            end
            
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
