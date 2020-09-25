classdef PulsedODMR < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    %PulsedODMR optically initialize the spin state, apply a MW pulse of
    %changing frequency, and measures the signal from the initial spin transition.
    %Pulse sequence: Repump -> Resonant(pump) -> MW -> Resonant(probe)
    % It requires SignalGenerator driver and source.

    properties(SetObservable)
        % These should be preferences you want set in default settings method
        resLaser = Modules.Source.empty;
        repumpLaser = Modules.Source.empty;
        SignalGenerator = Modules.Source.empty;
        APDline = 2;
        c = 1;
        MW_buffer_time = 1; %us
        repumpTime = 1; %us
        resOffset = 0.1; %us
        resPulse1Time = 10; %us
        resPulse1Counter1 = 1;
        resPulse1Counter2= 1;
        resPulse2Time = 10; %us
        resPulse2Counter1 = 1;
        resPulse2Counter2 = 1;
        tau_us = 100;
        freqs_GHz = 'linspace(2.85,2.88,101)';
        MW_power_dBm = -30;
        MWPulseTime = 1; %us
    end
    properties
        repumpLaserHandle
        resLaserHandle
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
    end
    properties(Constant)
        nCounterBins = 4; %number of APD bins for this pulse sequence
        vars = {'freq_list'}; %names of variables to be swept
    end

    methods(Static)
        % Static instance method is how to call this experiment
        % This is a separate file
        obj = instance()
    end
    methods(Access=private)
        function obj = PulsedODMR()
            % Constructor (should not be accessible to command line!)
            obj.prefs = [obj.prefs,{'APDline','resLaser','repumpLaser','SignalGenerator','freqs_GHz','MW_power_dBm','repumpTime','resOffset',...
            'MWPulseTime','MW_buffer_time','resPulse1Time','resPulse2Time','tau_us',...
            'resPulse1Counter1','resPulse1Counter2','resPulse2Counter1','resPulse2Counter2'}]; %additional preferences not in superclass
            obj.loadPrefs; % Load prefs specified as obj.prefs
        end
    end

    methods
        pulseSeq = BuildPulseSequence(obj,tauIndex) % In separate file
        
        function PreRun(obj,~,~,ax)
            %save resLaser frequency at the beginning
            if ismethod(obj.resLaser, 'getFrequency')
                obj.meta.resFreq = obj.resLaser.getFrequency;
            end
            %set SignalGenerator
            obj.SignalGenerator.power = obj.MW_power_dBm;
            obj.SignalGenerator.on;
            %prepare axes for plotting
            hold(ax,'on');
            
%             plotH(1) = plot(ax,obj.freq_list/1e9,obj.data.sumCounts(1,:,3)./obj.data.sumCounts(1,:,1),'color','k');
            plotH(1) = plot(ax,obj.freq_list/1e9,obj.data.sumCounts(1,:,3)./obj.data.sumCounts(1,:,1),'color','k');
            
            ax.UserData.plots = plotH;
            ylabel(ax,'Normalized PL');
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
            %grab handles to data from axes plotted in PreRun
            ax.UserData.plots(1).YData = averagedData(:,3)./averagedData(:,1);
            drawnow;
        end
        function PostRun(obj,~,~,~)
            %update resLaser frequency at the end
            obj.meta.resFreq = obj.resLaser.getFrequency;
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
        
        function set.freqs_GHz(obj,val)
            tempvals = eval(val)*1e9;
            obj.freq_list = tempvals;
            obj.freqs_GHz = val;
        end
    end
end