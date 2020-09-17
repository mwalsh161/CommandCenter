classdef Rabi_singleLaser < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    % Rabi_singleLaser Performs a rabi measurement with a MW drive, and a
    % single laser to initialize and readout

    properties(SetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        Laser = Modules.Source.empty(0,1);
        Laser_Time_us = 10;
        
        APD_line = 'APD1';
        APD_Gate_line = 1; % Indexed from 1
        APD_Time_us = 0.2;
        APD_Offset_us = 0;
        
        SignalGenerator = Modules.Source.empty(0,1);
        MW_freq_GHz = 2.87;
        MW_Power_dBm = -30;
        MW_Times_us = 'linspace(1,100,101)';
        MW_Pad_us = 1;
    end
    properties
        MW_Times = linspace(0,100,101); % Internal, set using MW_Times_us
    end
    properties(Constant)
        nCounterBins = 2; %number of APD bins for this pulse sequence
        vars = {'MW_Times'}; %names of variables to be swept
    end
    methods(Static)
        obj = instance()
    end
    methods(Access=private)
        function obj = Rabi_singleLaser()
            obj.prefs = [... %additional preferences not in superclass
                {'MW_Times_us','MW_freq_GHz','MW_Power_dBm','Laser_Time_us'}...
                {'APD_Time_us','APD_Offset_us','MW_Pad_us'},...
                obj.prefs, {'APD_line','Laser','SignalGenerator','APD_Gate_line'}...
            ];
            obj.loadPrefs;
        end
    end

    methods
        pulseSeq = BuildPulseSequence(obj,tauIndex) %Defined in separate file
        
        function PreRun(obj,~,~,ax)
            % Save laser frequency at the beginning, if this is an option
            if ismethod(obj.Laser, 'getFrequency')
                obj.meta.preFreq = obj.Laser.getFrequency;
            end
            
            % Set SignalGenerator
            obj.SignalGenerator.frequency = obj.MW_freq_GHz*1e9 / obj.SignalGenerator.freqUnit2Hz;
            obj.SignalGenerator.power = obj.MW_Power_dBm;
            obj.SignalGenerator.on;
            
            % Prepare axes for plotting
            y = NaN(1,size(obj.data.sumCounts(1,:,1),2));
            hold(ax,'on');
            
            plotH(1) = plot(obj.MW_Times, y,'color', 'k','parent',ax);
            ylabel(ax,'Rabi (normalized)');
            
            yyaxis(ax, 'right')
            cs = lines(2);
            plotH(2) = plot(obj.MW_Times, y,...
                'color', cs(1,:),'linestyle','-','parent',ax);
            plotH(3) = plot(obj.MW_Times, y,...
                'color', cs(2,:),'linestyle','-','parent',ax);
            legend(plotH,{'Normalized (left)','Signal (right)','Normalization (right)'})
            ylabel(ax,'Sum Counts');
            
            ax.UserData.plots = plotH;
            
            xlabel(ax,'\tau (\mus)');
            hold(ax,'off');
            set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto');
            drawnow;
        end
        
        function UpdateRun(obj,~,~,ax,~,~)
            if obj.averages > 1
                averagedData = squeeze(nanmean(obj.data.sumCounts,1));
            else
                averagedData = squeeze(obj.data.sumCounts);
            end
            
            norm   = averagedData(:, 1);
            signal = averagedData(:, 2);
            data = 2 * signal ./ (signal + norm);
           
            ax.UserData.plots(1).YData = data;
            ax.UserData.plots(2).YData = signal;
            ax.UserData.plots(3).YData = norm;

            drawnow;
        end
        
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end
        
        function set.MW_Times_us(obj,val)
            %Note that order matters here; setting tauTimes first is
            %important in case of error
            tempvals = eval(val);
            obj.MW_Times = tempvals;
            obj.MW_Times_us = val;
        end
    end
end
