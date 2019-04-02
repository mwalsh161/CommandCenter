classdef ODMR_singleLaser < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    % ODMR_singleLaser optically initialize the spin state, apply a MW pulse of
    % changing frequency, and measures the signal from the initial spin transition.
    % Pulse sequence: (Bin1)Laser(Bin2) -> MW -> ...
    % It requires SignalGenerator driver and one laser source.

    properties(SetObservable)
        % These should be preferences you want set in default settings method
        laser = Modules.Source.empty;
        laserTime_us = 10;
        
        APDline = 1;
        APDTime_us = 1;
        
        SignalGenerator = Modules.Source.empty;
        MWfreqs_GHz = 'linspace(2.85,2.91,101)';
        MWPower_dBm = -30;
        MWTime_us = 1;
        MWPad_us = 1;
        
        dummyLine = 15;
    end
    properties
        laserHandle
        SignalGeneratorHandle
        sweepTimes = linspace(0,100,101);
        %pb
    end
    properties(SetAccess=protected,Hidden)
        % Internal properties that should not be accessible by command line
        % Advanced users should feel free to alter these properties (keep in mind methods: abort, GetData)
        %data = [] % Useful for saving data from run method
        %abort_request = false; % Flag that will be set to true upon abort. Use in run method!
        freq_list = linspace(0,100,101)*1e9; % Internal, set using MHz
        isLaserOnAtStart = false;
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
            obj.prefs = [obj.prefs, { 'laser', 'laserTime_us', 'APDline', 'APDTime_us', 'SignalGenerator', 'MWfreqs_GHz', 'MWPower_dBm', 'MWTime_us', 'MWPad_us', 'dummyLine'}]; %additional preferences not in superclass
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        pulseSeq = BuildPulseSequence(obj,tauIndex) % In separate file [Why is this tauIndex?]
        
        function PreRun(obj,~,~,ax)
            % Save laser frequency at the beginning, if this is an option
            if ismethod(obj.laser, 'getFrequency')
                obj.meta.preFreq = obj.laser.getFrequency;
            end
            
            % Set SignalGenerator
            obj.SignalGenerator.MWPower = obj.MWPower_dBm;
            obj.SignalGenerator.on;
            
            % Prepare axes for plotting
            hold(ax,'on');
            
%             plotH(1) = plot(ax,obj.freq_list/1e9,obj.data.sumCounts(1,:,3)./obj.data.sumCounts(1,:,1),'color','k');
%             plotH(1) = plot(ax, obj.freq_list/1e9, obj.data.sumCounts(1,:,2)./obj.data.sumCounts(1,:,1), 'color', 'k');
            plotH(1) = errorbar(ax, obj.freq_list/1e9, obj.data.sumCounts(1,:,1), obj.data.sumCounts(1,:,1), 'color', 'k');
            
            ylabel(ax,'ODMR (a.u.)');
            
            yyaxis(ax, 'right')
            
            plotH(2) = errorbar(ax, obj.freq_list/1e9, obj.data.sumCounts(1,:,1), obj.data.sumCounts(1,:,1), 'color', 'b');
            plotH(3) = errorbar(ax, obj.freq_list/1e9, obj.data.sumCounts(1,:,1), obj.data.sumCounts(1,:,1), 'color', 'r');
            
            ax.UserData.plots = plotH;
            
            ylabel(ax,'Signal (cts) [blue - before, red - after]');
            xlabel(ax,'MW frequency (GHz)');
            
            hold(ax,'off');
            set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto');
            
            drawnow;
        end
        function UpdateRun(obj,~,~,ax,~,~)
            if obj.averages > 1
                averagedData = squeeze(nanmean(obj.data.sumCounts,1))/obj.samples;
%                 summedError =  sqrt(squeeze(nansum(obj.data.stdCounts.^2,1))) ./ numnan(obj.data.stdCounts, 1);
            else
                averagedData = squeeze(obj.data.sumCounts)/obj.samples;
%                 summedError =  squeeze(obj.data.stdCounts);
            end
            
            beforeMW = averagedData(:, 2);
            afterMW =  averagedData(:,   1);
            
            data = 2 * afterMW ./ (afterMW + beforeMW);
            
            ax.UserData.plots(1).YData = data;
            
%             beforeMWfracErrSq = (summedError(:, 2) ./ beforeMW) .^ 2;
%             afterMWfracErrSq =  (summedError(:, 1) ./ afterMW ) .^ 2;
%             
%             err = data .* sqrt(beforeMWfracErrSq + afterMWfracErrSq) * sqrt(2);
%             
%             ax.UserData.plots(1).YPositiveDelta = err;
%             ax.UserData.plots(1).YNegativeDelta = err;

            ax.UserData.plots(2).YData = beforeMW*obj.samples;
            ax.UserData.plots(3).YData = afterMW*obj.samples;
            
%             ax.UserData.plots(2).YPositiveDelta = summedError(:, 2);
%             ax.UserData.plots(2).YNegativeDelta = summedError(:, 2);
%             ax.UserData.plots(3).YPositiveDelta = summedError(:, 1);
%             ax.UserData.plots(3).YNegativeDelta = summedError(:, 1);
            
            drawnow;
        end
        function PostRun(obj,~,~,~)
            if ismethod(obj.laser, 'getFrequency')
                obj.meta.postFreq = obj.laser.getFrequency;
            end
            
            obj.SignalGenerator.off;
        end
        
        function AnalyzeData(obj)
        end
        
        function clean_up_exp(obj,varargin)
            obj.SignalGeneratorHandle.off;
        end
        
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end
        
        function set.MWfreqs_GHz(obj,val)
            tempvals = eval(val)*1e9;
            obj.freq_list = tempvals;
            obj.MWfreqs_GHz = val;
        end
    end
end