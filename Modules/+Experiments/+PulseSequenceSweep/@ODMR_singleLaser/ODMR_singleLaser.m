classdef ODMR_singleLaser < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    % ODMR_singleLaser optically initialize the spin state, apply a MW pulse of
    % changing frequency, and measures the signal from the initial spin transition.
    % Pulse sequence: (Bin1)Laser -> MW -> (Bin2)Laser...
    % It requires SignalGenerator driver and one laser source.

    properties(SetObservable)
        % These should be preferences you want set in default settings method
        Laser = Modules.Source.empty(0,1);
        Laser_Time_us = 10;
        
        APD_line = 'APD1';
        APD_Gate_line = 1; % Indexed from 1
        APD_Time_us = 0.2;
        APD_Offset_us = 0;
        
        SignalGenerator = Modules.Source.empty(0,1);
        MW_freqs_GHz = 'linspace(2.85,2.91,101)';
        MW_Power_dBm = -30;
        MW_Time_us = 1;
        MW_Pad_us = 1;
    end
    properties(SetAccess=protected,Hidden)
        freq_list = linspace(2.85,2.91,101)*1e9; % Internal, set using MW_freqs_GHz
    end
    properties(Constant)
        nCounterBins = 2; %number of APD bins for this pulse sequence
        vars = {'freq_list'}; %names of variables to be swept
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = ODMR_singleLaser()
            % Constructor (should not be accessible to command line!)
            obj.prefs = [... %additional preferences not in superclass
                {'MW_freqs_GHz','MW_Power_dBm','MW_Time_us','Laser_Time_us'}...
                {'APD_Time_us','APD_Offset_us','MW_Pad_us'},...
                obj.prefs, {'APD_line','Laser','SignalGenerator','APD_Gate_line'}...
            ];
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        pulseSeq = BuildPulseSequence(obj,tauIndex) % In separate file [Why is this tauIndex?]
        
        function PreRun(obj,~,~,ax)
            % Save laser frequency at the beginning, if this is an option
            if ismethod(obj.Laser, 'getFrequency')
                obj.meta.preFreq = obj.Laser.getFrequency;
            end
            
            % Set SignalGenerator
            obj.SignalGenerator.power = obj.MW_Power_dBm;
            obj.SignalGenerator.on;
            
            % Prepare axes for plotting
            y = NaN(1,size(obj.data.sumCounts(1,:,1),2));
            hold(ax,'on');
            
            plotH(1) = plot(obj.freq_list/1e9, y,'color', 'k','parent',ax);
            ylabel(ax,'ODMR (normalized)');
            
            yyaxis(ax, 'right')
            cs = lines(2);
            plotH(2) = plot(obj.freq_list/1e9, y,...
                'color', cs(1,:),'linestyle','-','parent',ax);
            plotH(3) = plot(obj.freq_list/1e9, y,...
                'color', cs(2,:),'linestyle','-','parent',ax);
            legend(plotH,{'Normalized (left)','Signal (right)','Normalization (right)'})
            ylabel(ax,'Sum Counts');
            
            ax.UserData.plots = plotH;
            
            xlabel(ax,'MW frequency (GHz)');
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
        function PostRun(obj,~,~,~)
            if ismethod(obj.Laser, 'getFrequency')
                obj.meta.postFreq = obj.Laser.getFrequency;
            end
        end
        
        function AnalyzeData(obj)
        end
        
        function CleanUp(obj,varargin)
            % Run regardless of error/abort/finished
            obj.SignalGenerator.off;
        end
        
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end
        
        function set.MW_freqs_GHz(obj,val)
            tempvals = eval(val)*1e9;
            obj.freq_list = tempvals;
            obj.MW_freqs_GHz = val;
        end
    end
end