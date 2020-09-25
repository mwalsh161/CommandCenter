classdef Rabi_opticalPolarization < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    %AllOpticalT1 Characterizes T1 by optically repumping then resonantly addressing with a swept time delay

    properties(SetObservable,AbortSet)
        resLaser = Modules.Source.empty(1,0); % Allow selection of source
        repumpLaser = Modules.Source.empty(1,0);
        SignalGenerator = Modules.Source.empty(1,0);
        MW_buffer_time_us = 1; %us
        freq_GHz = 2.916;
        MW_power_dBm = -30;
        APDline = 3;       % 
        APDnidaq = 'APD1'; % Counter line for APD on nidaq
        repumpTime_us = 1; %us
        resOffset_us = 0.1;
        resPulse1Time_us = 10;
        resPulse1Counter1_us = 1;
        resPulse1Counter2_us= 1;
        resPulse2Time_us = 10;
        resPulse2Counter1_us = 1;
        resPulse2Counter2_us = 1;

        tauTimes_us = 'linspace(0,100,101)'; %eval(tauTimes_us) will define sweepTimes
    end
    properties
        tauTimes = linspace(0,100,101); %will be in us
    end
    properties(Constant)
        nCounterBins = 4; %number of APD bins for this pulse sequence
        vars = {'tauTimes'}; %names of variables to be swept
    end
    methods(Static)
        obj = instance()
    end
    methods(Access=private)
        function obj = Rabi_opticalPolarization()
            obj.prefs = [obj.prefs,{'resLaser','repumpLaser','APDline','APDnidaq','repumpTime_us','resOffset_us',...
            'SignalGenerator','MW_buffer_time_us','resPulse1Time_us','freq_GHz','MW_power_dBm','resPulse2Time_us','resPulse1Counter1_us',...
            'resPulse1Counter2_us','resPulse2Counter1_us','resPulse2Counter2_us','tauTimes_us'}]; %additional preferences not in superclass
            obj.loadPrefs;
        end
    end

    methods
        pulseSeq = BuildPulseSequence(obj,tauIndex) %Defined in separate file
        
        function PreRun(obj,~,~,ax)
            %save resLaser frequency at the beginning
%             obj.meta.resFreq = obj.resLaser.getFrequency;
            %set SignalGenerator
            obj.SignalGenerator.frequency = obj.freq_GHz*1e9 / obj.SignalGenerator.freqUnit2Hz;
            obj.SignalGenerator.power = obj.MW_power_dBm;
            obj.SignalGenerator.on;
    
            
            %prepare axes for plotting
            hold(ax,'on');
            
            plotH(1) = plot(ax,obj.tauTimes,obj.data.sumCounts(1,:,1),'color','b');
            plotH(2) = plot(ax,obj.tauTimes,obj.data.sumCounts(1,:,2),'color','g');
            plotH(3) = plot(ax,obj.tauTimes,obj.data.sumCounts(1,:,3),'color','r');

%             d = ( obj.data.sumCounts(1,:,3) - obj.data.sumCounts(1,:,2) ) ./ ( obj.data.sumCounts(1,:,3) + obj.data.sumCounts(1,:,2) );
%             
%             plotH(1) = plot(ax,obj.tauTimes, d);
%             plotH(2) = plot(ax,obj.tauTimes, d);
%             plotH(3) = plot(ax,obj.tauTimes, d);
       
            ax.UserData.plots = plotH;
            ylabel(ax,'Normalized PL');
            xlabel(ax,'Delay Time \tau (\mus)');
            hold(ax,'off');
            set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto')
        end
        
        function UpdateRun(obj,~,~,ax,~,~)
            if obj.averages > 1
                averagedData = squeeze(nanmean(obj.data.sumCounts,1));
            else
                averagedData = squeeze(obj.data.sumCounts);
            end
            
%             d = ( averagedData(:,3) - averagedData(:,2) ) ./ ( averagedData(:,3) + averagedData(:,2) );
            d = averagedData(:,3) ./ averagedData(:,2);
            
            %grab handles to data from axes plotted in PreRun
%             ax.UserData.plots(1).YData = averagedData(:,1);
%             ax.UserData.plots(2).YData = averagedData(:,2);
%             ax.UserData.plots(3).YData = averagedData(:,3);

            ax.UserData.plots(1).YData = d;
%             ax.UserData.plots(2).YData = averagedData(:,2);
%             ax.UserData.plots(3).YData = averagedData(:,3);
            drawnow;
        end
        
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end
        
        function set.tauTimes_us(obj,val)
            %Note that order matters here; setting tauTimes first is
            %important in case of error
            tempvals = eval(val);
            assert(tempvals(1)~=0,'Starting tau cannot be 0')
            obj.tauTimes = tempvals;
            obj.tauTimes_us = val;
        end
    end
end
