classdef Rabi_singleLaser < Experiments.PulseSequenceSweep.PulseSequenceSweep_invisible
    % Rabi_singleLaser Performs a rabi measurement with a MW drive, and a
    % single laser to initialize and readout

    properties(SetObservable,GetObservable,AbortSet)
        % These should be preferences you want set in default settings method
        Laser =  Prefs.ModuleInstance('help_text','PulseBlaster enabled laser');
        Laser_Time = Prefs.Double(10.,'min',0,'units','us','help_text','Time that the laser is on during readout/initialisation');
        
        APD_line = Prefs.String('APD1','help_text','NIDAQ APD Line');
        APD_Gate_line = Prefs.Integer(1,'help_text','PulseBlaster APDGate output line (1 index)','min',1);
        APD_Time = Prefs.Double(0.2, 'help_text', 'APD exposure time', 'units', 'us','min',0);
        APD_Offset = Prefs.Double(0, 'help_text', 'Delay between laser on and start of APD exposure', 'units', 'us');
        
        SignalGenerator = Prefs.ModuleInstance('help_text','Signal generator used for experiment');
        MW_freq = Prefs.Double(2.87,'units','GHz','help_text','MW frequency that the signal generator outputs');
        MW_Power = Prefs.Double(-30,'units','dBm','help_text','MW power that the signal generator outputs');
        MW_Times = Prefs.String('linspace(1,100,101)','help_text', 'List of times that MW power will be on at','set','set_MW_Times','units','us');
        MW_Pad = Prefs.Double(1,'min',0,'units','us','help_text','Time between laser off and MW on');
    end
    properties
        MW_Times_vals = linspace(0,100,101); % Internal, set using MW_Times
    end
    properties(Constant)
        nCounterBins = 2; %number of APD bins for this pulse sequence
        vars = {'MW_Times_vals'}; %names of variables to be swept
    end
    methods(Static)
        obj = instance()
    end
    methods(Access=private)
        function obj = Rabi_singleLaser()
            obj.prefs = [... %additional preferences not in superclass
                {'MW_Times','MW_freq','MW_Power','Laser_Time'}...
                {'APD_Time','APD_Offset','MW_Pad'},...
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
            obj.SignalGenerator.MWFrequency = obj.MW_freq*1e9;
            obj.SignalGenerator.MWPower = obj.MW_Power;
            obj.SignalGenerator.on;
            
            % Prepare axes for plotting
            y = NaN(1,size(obj.data.sumCounts(1,:,1),2));
            hold(ax,'on');
            
            plotH{1} = errorbar(obj.MW_Times_vals, y, y,'-ok','parent',ax, 'MarkerFaceColor','k','MarkerSize',5);
            ylabel(ax,'Rabi (normalized)');
            plotH{4} = xline(0, 'r--','parent',ax);

            yyaxis(ax, 'right')
            cs = lines(2);
            plotH{2} = plot(obj.MW_Times_vals, y,...
                'color', cs(1,:),'linestyle','-','parent',ax);
            plotH{3} = plot(obj.MW_Times_vals, y,...
                'color', cs(2,:),'linestyle','-','parent',ax);
            
            legend(ax,{'Normalized (left)','Signal (right)','Normalization (right)','Current MW Time'})
            ylabel(ax,'Sum Counts');
            
            ax.UserData.plots = plotH;
            
            xlabel(ax,'\tau (\mus)');
            hold(ax,'off');
            set(ax,'xlimmode','auto','ylimmode','auto','ytickmode','auto');
            drawnow;
        end
        
        function UpdateRun(obj,~,~,ax,j,i)
            
            norm   = obj.data.sumCounts(:,:,1);
            signal = obj.data.sumCounts(:,:,2);
            data = signal ./ norm;
           
            ax.UserData.plots{1}.YData = nanmean(data,1);
            ax.UserData.plots{1}.YNegativeDelta = std(data,1,'omitnan')/sqrt(j);
            ax.UserData.plots{1}.YPositiveDelta = std(data,1,'omitnan')/sqrt(j);
            ax.UserData.plots{2}.YData = nanmean(signal,1);
            ax.UserData.plots{3}.YData = nanmean(norm,1);
            ax.UserData.plots{4}.Value = obj.MW_Times_vals(i);

            drawnow;
        end

        function PostRun(obj,~,~,~)
            obj.SignalGenerator.off; % Ensure signal generator is off
        end
        
        function abort(obj)
            % Callback for when user presses abort in CC
            obj.abort_request = true;
        end
        
        function val = set_MW_Times(obj,val,~)
            %Note that order matters here; setting tauTimes first is
            %important in case of error
            tempvals = eval(val);
            obj.MW_Times_vals = tempvals;
        end
    end
end
