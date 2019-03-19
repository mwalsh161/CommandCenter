classdef SlowScan_invisible < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    % subclasses must create:
    % prep_plot(ax) [called in PreRun]:
    %   Populates the supplied axes (already held) and adds axes labels
    % update_plot(ydata) [called in UpdateRun]
    %   Given the calculated ydata, update plots generated in prep_plot

    properties(SetObservable,AbortSet)
        resLaser = Modules.Source.empty; % Allow selection of source
        repumpLaser = Modules.Source.empty;
        APDline = 1;  % Indexed from 1
        repumpTime_us = 1; %us
        resTime_us = 0.1;
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

    methods(Abstract)
        prep_plot(obj,ax);  % ONLY for plot commands and xlabel
        update_plot(obj,ydata);
    end
    methods
        function obj = SlowScan_invisible()
            obj.prefs = [obj.prefs,{'resLaser','repumpLaser','APDline','repumpTime_us','resTime_us'}]; %additional preferences not in superclass
        end
        function s = BuildPulseSequence(obj,freqIndex)
            %BuildPulseSequence Builds pulse sequence for repump pulse followed by APD
            %collection during resonant driving
            if freqIndex > 1
                s = obj.sequence;
            else
                s = sequence('SlowScan'); %#ok<CPROPLC> Calling HelperFunction
                repumpChannel = channel('Repump','color','g','hardware',obj.repumpLaser.PBline-1);
                resChannel = channel('Resonant','color','r','hardware',obj.resLaser.PBline-1);
                APDchannel = channel('APDgate','color','b','hardware',obj.APDline-1,'counter','APD1');
                s.channelOrder = [repumpChannel, resChannel, APDchannel];
                g = node(s.StartNode,repumpChannel,'delta',0);
                g = node(g,repumpChannel,'units','us','delta',obj.repumpTime_us);
                r = node(g,resChannel,'delta',0);
                node(r,APDchannel,'delta',0);
                r = node(r,resChannel,'units','us','delta',obj.resTime_us);
                node(r,APDchannel,'delta',0);
                
                obj.sequence = s;
            end
        end
        
        function PreRun(obj,~,~,ax)
            %prepare frequencies
            obj.data.freqs_measured = NaN(obj.averages,length(obj.scan_points));
            %prepare axes for plotting
            hold(ax,'on');
            %plot data
            obj.prep_plot(ax);
            hold(ax,'off');
            set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')
        end
        
        function UpdateRun(obj,~,~,ax,average,freqIndex)
            %pull frequency that latest sequence was run at
            obj.data.freqs_measured(average,freqIndex) = obj.resLaser.getFrequency;
            
            if obj.averages > 1
                averagedData = squeeze(nanmean(obj.data.meanCounts,3));
                meanError = squeeze(nanmean(obj.data.stdCounts,3));
            else
                averagedData = obj.data.meanCounts;
                meanError = obj.data.stdCounts;
            end
            obj.update_plot(ax, averagedData, meanError);
        end
    end
end
